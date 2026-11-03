-- MoreRVers - main.lua
-- Host-side UE4SS Lua mod that raises the multiplayer cap of RV There Yet?
--
-- How the game enforces the cap (game build 1.4, UE 5.6):
--   ARGGameSession (the game's native session class) reads the cap from
--   GetDefault<AGameSession>()->MaxPlayers, i.e. the *engine base class* default
--   object /Script/Engine.Default__GameSession, in three places:
--     * ApproveLogin       -> rejects with "Session is full." once players >= cap
--     * InitOptions        -> copies it onto the live session (overwrites live edits)
--     * UpdateSessionSettings -> lobby slots. The Steam lobby is created with a
--       hard-coded 4 slots, but the game updates it right after the host enters
--       the map, and the engine then calls SetLobbyMemberLimit with this value.
--   So the value that matters is Default__GameSession.MaxPlayers. Patching only
--   the live GameSession, or the CDO of its subclass, has no effect anymore.
--
--   Levels can also carry ARGWorldSettings.MaxPlayersOverride (0 = no override).
--   If a level sets it below the target cap it is raised as well.

local VERSION = "1.1.0"
local HARD_MAX = 24
local DEFAULT_CAP = 8
local SESSION_CDO_PATH = "/Script/Engine.Default__GameSession"

local function log(level, msg)
  print(string.format("[MoreRVers] [%s] %s\n", level, tostring(msg)))
end

----------------------------------------------------------------------------
-- Config
----------------------------------------------------------------------------

local function script_dir()
  local src = debug.getinfo(1, "S").source or ""
  src = src:gsub("^@", ""):gsub("\\", "/")
  return src:match("^(.*/)") -- nil if no directory part
end

local function read_cap()
  local dir = script_dir()
  if not dir then
    log("WARN", "Could not locate the mod folder; using MaxPlayers = " .. DEFAULT_CAP)
    return DEFAULT_CAP
  end
  local path = dir .. "../config.ini"
  local f = io.open(path, "r")
  if not f then
    log("WARN", "Could not open " .. path .. "; using MaxPlayers = " .. DEFAULT_CAP)
    return DEFAULT_CAP
  end
  local value
  for line in f:lines() do
    line = line:gsub("^\239\187\191", "")   -- UTF-8 BOM
    line = line:gsub("%s*[;#].*$", "")       -- comments
    local key, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and key:lower() == "maxplayers" then
      value = tonumber(v)
      break
    end
  end
  f:close()
  if not value then
    log("WARN", "MaxPlayers not found in config.ini; using " .. DEFAULT_CAP)
    return DEFAULT_CAP
  end
  value = math.floor(value)
  if value < 1 then value = 1 end
  if value > HARD_MAX then value = HARD_MAX end
  return value
end

local CAP = read_cap()

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------

local function is_valid(obj)
  if obj == nil then return false end
  local ok, res = pcall(function() return obj:IsValid() end)
  return ok and res == true
end

local function name_of(obj)
  local ok, n = pcall(function() return obj:GetFullName() end)
  return ok and n or "<object>"
end

local function read_int(obj, prop)
  local ok, v = pcall(function() return obj[prop] end)
  if ok and type(v) == "number" then return v end
  return nil
end

-- Writes obj[prop] = value and reads it back. Returns true if the value stuck.
local function write_int(obj, prop, value, why)
  local before = read_int(obj, prop)
  if before == nil then return false end
  if before == value then return true end
  local ok, err = pcall(function() obj[prop] = value end)
  local after = read_int(obj, prop)
  if ok and after == value then
    log("INFO", string.format("%s %d -> %d (%s) %s", prop, before, value, why, name_of(obj)))
    return true
  end
  log("WARN", string.format("Failed to set %s on %s (%s): %s", prop, name_of(obj), why,
    tostring(err or ("read back " .. tostring(after)))))
  return false
end

----------------------------------------------------------------------------
-- Patching
----------------------------------------------------------------------------

local base_cdo_patched = false

-- The value the game actually enforces.
local function patch_base_cdo(why)
  local cdo = StaticFindObject(SESSION_CDO_PATH)
  if not is_valid(cdo) then return false end
  local ok = write_int(cdo, "MaxPlayers", CAP, why)
  if ok and not base_cdo_patched then
    base_cdo_patched = true
    log("INFO", "Session cap is now " .. CAP .. " players")
  end
  return ok
end

-- Live session plus the CDO of its own (sub)class, for engine code paths that use them.
local function patch_session(session, why)
  if not is_valid(session) then return end
  write_int(session, "MaxPlayers", CAP, why)
  local ok, cdo = pcall(function() return session:GetClass():GetCDO() end)
  if ok and is_valid(cdo) then
    write_int(cdo, "MaxPlayers", CAP, why .. "/class default")
  end
end

-- Per-level override: only raise it when a level sets it below our target.
local function patch_world_settings(why)
  local list = FindAllOf("RGWorldSettings")
  if not list then return end
  for _, ws in ipairs(list) do
    if is_valid(ws) then
      local v = read_int(ws, "MaxPlayersOverride")
      if v and v > 0 and v < CAP then
        write_int(ws, "MaxPlayersOverride", CAP, why)
      end
    end
  end
end

local function patch_all(why)
  patch_base_cdo(why)
  local sessions = FindAllOf("GameSession")
  if sessions then
    for _, s in ipairs(sessions) do patch_session(s, why) end
  end
  patch_world_settings(why)
end

local function safe(why, fn)
  local ok, err = pcall(fn)
  if not ok then log("ERROR", "[" .. why .. "] " .. tostring(err)) end
end

----------------------------------------------------------------------------
-- Triggers
----------------------------------------------------------------------------

-- 1) As early as possible. The engine class default object usually exists
--    already; if not, retry once a second until it does.
safe("startup", function()
  if not patch_base_cdo("startup") then
    local queued = false
    LoopAsync(1000, function()
      if base_cdo_patched then return true end -- stop the loop
      if not queued then
        queued = true
        ExecuteInGameThread(function()
          safe("startup retry", function() patch_base_cdo("startup retry") end)
          queued = false
        end)
      end
      return false
    end)
  end
end)

-- 2) Whenever a GameSession is spawned (hosting, map travel). Runs before the
--    session's InitOptions copies the default value onto it.
safe("register NotifyOnNewObject", function()
  NotifyOnNewObject("/Script/Engine.GameSession", function(session)
    safe("new GameSession", function()
      patch_base_cdo("GameSession spawned")
      patch_session(session, "GameSession spawned")
    end)
  end)
end)

-- 3) After the game mode has initialized (InitOptions has run by now).
safe("register InitGameState hook", function()
  RegisterInitGameStatePostHook(function(ctx)
    safe("InitGameState", function()
      local gm = ctx:get()
      patch_base_cdo("game initialized")
      if is_valid(gm) then patch_session(gm.GameSession, "game initialized") end
      patch_world_settings("game initialized")
    end)
  end)
end)

-- 4) After every map load (world settings of the new level exist now).
safe("register LoadMap hook", function()
  RegisterLoadMapPostHook(function()
    safe("LoadMap", function() patch_all("map loaded") end)
  end)
end)

----------------------------------------------------------------------------
-- Diagnostics: F10 in game, or "morervers" in the UE4SS console
----------------------------------------------------------------------------

local function diagnostics()
  log("INFO", "v" .. VERSION .. " target MaxPlayers = " .. CAP)
  local cdo = StaticFindObject(SESSION_CDO_PATH)
  if is_valid(cdo) then
    log("INFO", "Default__GameSession.MaxPlayers = " .. tostring(read_int(cdo, "MaxPlayers")) .. " (this is the enforced cap)")
  else
    log("WARN", "Default__GameSession not found")
  end
  local sessions = FindAllOf("GameSession") or {}
  for _, s in ipairs(sessions) do
    if is_valid(s) then
      log("INFO", "live MaxPlayers = " .. tostring(read_int(s, "MaxPlayers")) .. "  " .. name_of(s))
    end
  end
  if #sessions == 0 then log("INFO", "No live GameSession (host a game first)") end
  -- World partition creates one RGWorldSettings per streamed cell; only report real overrides.
  local total, overrides = 0, 0
  for _, ws in ipairs(FindAllOf("RGWorldSettings") or {}) do
    if is_valid(ws) then
      total = total + 1
      local v = read_int(ws, "MaxPlayersOverride")
      if v and v > 0 then
        overrides = overrides + 1
        log("INFO", "MaxPlayersOverride = " .. v .. "  " .. name_of(ws))
      end
    end
  end
  log("INFO", string.format("RGWorldSettings: %d found, %d with a MaxPlayersOverride", total, overrides))
end

safe("register F10", function()
  RegisterKeyBind(Key.F10, function()
    ExecuteInGameThread(function()
      safe("F10", function()
        patch_all("F10")
        diagnostics()
      end)
    end)
  end)
end)

safe("register console command", function()
  RegisterConsoleCommandHandler("morervers", function()
    safe("console", function()
      patch_all("console")
      diagnostics()
    end)
    return true
  end)
end)

log("INFO", "v" .. VERSION .. " loaded. Target MaxPlayers = " .. CAP .. " (F10 = status)")
