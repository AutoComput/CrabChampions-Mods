-- CancelLockedSlots
-- Crab Champions UE4SS Lua mod.
-- Copyright (C) 2026 AutoComput
-- SPDX-License-Identifier: GPL-3.0-or-later
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU General Public License, version 3 or (at your option) any
-- later version. It comes WITHOUT ANY WARRANTY. See LICENSE for details.
--
-- Keep Locked Slots selected in the difficulty menu so the game itself counts
-- all 8 red modifiers (real Prismatic rank, loot luck and victory rewards),
-- while this mod cancels Locked Slots' effect by restoring inventory slot
-- counts to the class defaults at the start of each run.
--
-- Settings: copy config.example.lua to config.lua in this folder and edit it.
-- config.lua is never included in release zips, so updates keep your settings.
--
-- Log: CancelLockedSlots.log in this mod's folder. The previous session is kept
-- as CancelLockedSlots.previous.log, so a crash session survives a relaunch.
-- Bug reports: run tools\CollectDiagnostics.bat.
--
-- Multiplayer: only the host needs this mod. The host's game owns every player's CrabPS.
--
-- Confirmed live (UE4SS 3.0.1, UE 4.27):
--   - Rank = number of red modifiers selected; flex modifiers are not counted.
--   - Locked Slots sets all four slot counts to 8 once, at run start.
--   - Slot defaults (Default__CrabPS): weapon 24, ability 12, melee 12, perks 24.
--   - Restored slots accept items through the game's own pickup path.
local modName = "CancelLockedSlots"
local modVersion = "1.0.0"

------------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------------

local defaultConfig = {
    -- true: keep Locked Slots selected for Prismatic, but cancel its effect.
    cancelLockedSlots = true,
    -- ECrabDifficultyModifier entry name, resolved to its value at startup.
    lockedSlotsModifierName = "LockedSlots",
    -- Slot checks (one per poll) after each island change.
    slotChecksPerIsland = 5,
    pollIntervalMs = 1000,
    -- Circuit breaker: stop the mod after this many failed ticks in a row.
    maxConsecutiveErrors = 20,
    -- Identical errors are logged at most once per this many seconds.
    errorLogIntervalSeconds = 10,
    -- DEBUG, INFO, WARN or ERROR.
    minLogLevel = "INFO",
}

local constants = {
    modifierEnumPath = "/Script/CrabChampions.ECrabDifficultyModifier",
    gameStateClass = "CrabGS",
    playerStateClass = "CrabPS",
    defaultPlayerStatePath = "/Script/CrabChampions.Default__CrabPS",
    lockedSlotLimit = 8,
    slotFields = { "NumWeaponModSlots", "NumAbilityModSlots", "NumMeleeModSlots", "NumPerkSlots" },
    inventoryFields = {
        NumWeaponModSlots = "WeaponMods",
        NumAbilityModSlots = "AbilityMods",
        NumMeleeModSlots = "MeleeMods",
        NumPerkSlots = "Perks",
    },
}

local logLevels = { DEBUG = 1, INFO = 2, OK = 2, WARN = 3, ERROR = 4 }

local config = {}

-- Filled by initialize(); the mod does not start unless every entry resolves.
local resolved = {
    lockedSlotsModifierValue = nil,
    slotDefaults = {},
}

local runState = {
    isDisabled = false,
    consecutiveErrors = 0,
    lastErrorLogTimes = {},
    lastIsland = nil,
    isCancelActive = false,
    pendingSlotChecks = 0,
    -- Keyed by the player state's full name.
    restoredPlayers = {},
    loggedOverLimit = {},
}

local cachedGameState = nil

------------------------------------------------------------------------------
-- Logging
------------------------------------------------------------------------------

-- Mod-specific log file, opened by openLogFile(). Flushed on every line so a crash keeps it.
local logFileState = { handle = nil }

local function writeToLogFile(line)
    local handle = logFileState.handle
    if handle == nil then return end
    local ok, problem = pcall(function()
        handle:write(line, "\n")
        handle:flush()
    end)
    if not ok then
        logFileState.handle = nil
        print(string.format("[%s] [WARN] Log file write failed, file logging stopped: %s\n", modName, tostring(problem)))
    end
end

local function logMessage(level, message)
    local minLevel = logLevels[config.minLogLevel] or logLevels.INFO
    if (logLevels[level] or logLevels.INFO) < minLevel then return end
    print(string.format("[%s] [%s] %s\n", modName, level, message))
    writeToLogFile(string.format("[%s] [%s] %s", os.date("%Y-%m-%d %H:%M:%S"), level, message))
end

-- Returns this mod's folder (the parent of scripts) from this file's own path, or nil.
local function getModDirectory()
    if debug == nil or debug.getinfo == nil then return nil end
    local info = debug.getinfo(1, "S")
    local source = info and info.source or ""
    if source:sub(1, 1) ~= "@" then return nil end
    local scriptsDirectory = source:sub(2):match("^(.*)[/\\][^/\\]+$")
    return scriptsDirectory and scriptsDirectory:match("^(.*)[/\\][^/\\]+$") or nil
end

-- Keeps the previous session's log (the crash session, after a crash) and starts a new one.
-- Paths are never written to the log, since they contain the Windows username.
local function openLogFile()
    local modDirectory = getModDirectory()
    if modDirectory == nil then
        logMessage("WARN", "Could not determine the mod folder, logging to UE4SS.log only")
        return
    end
    local currentPath = modDirectory .. "/" .. modName .. ".log"
    local previousPath = modDirectory .. "/" .. modName .. ".previous.log"
    os.remove(previousPath)
    local isRotated = os.rename(currentPath, previousPath)

    -- A failed rename with the file still present means an earlier session in this
    -- process still has it open (a mod reload). Append instead of wiping it.
    local existingHandle = (not isRotated) and io.open(currentPath, "r") or nil
    if existingHandle then existingHandle:close() end
    local openMode = existingHandle and "a" or "w"

    local handle, problem = io.open(currentPath, openMode)
    if handle == nil then
        logMessage("WARN", "Could not open the mod log file, logging to UE4SS.log only: " .. tostring(problem))
        return
    end
    logFileState.handle = handle
    writeToLogFile(string.format("==== %s v%s session started %s (%s)%s ====",
        modName, modVersion, os.date("%Y-%m-%d %H:%M:%S"), _VERSION,
        openMode == "a" and ", appended after a mod reload" or ""))
end

-- Logs a repeated message at most once per interval and reports how many were suppressed.
local function logRateLimited(key, level, message)
    local now = os.time()
    local entry = runState.lastErrorLogTimes[key]
    if entry and now - entry.time < config.errorLogIntervalSeconds then
        entry.suppressed = entry.suppressed + 1
        return
    end
    local suffix = (entry and entry.suppressed > 0) and string.format(" (repeated %d more times)", entry.suppressed) or ""
    runState.lastErrorLogTimes[key] = { time = now, suppressed = 0 }
    logMessage(level, message .. suffix)
end

------------------------------------------------------------------------------
-- Generic helpers
------------------------------------------------------------------------------

local function isValidObject(object)
    return object ~= nil and object:IsValid()
end

local function isPositiveNumber(value)
    return type(value) == "number" and value > 0
end

local function getGameState()
    if not isValidObject(cachedGameState) then
        local foundObject = FindFirstOf(constants.gameStateClass)
        cachedGameState = isValidObject(foundObject) and foundObject or nil
    end
    return cachedGameState
end

-- Returns valid, non-default instances of a class. Not cached: players join and leave mid-run.
local function getLiveInstances(className)
    local instances = {}
    for _, instance in ipairs(FindAllOf(className) or {}) do
        if isValidObject(instance) and not instance:GetFullName():find("Default__", 1, true) then
            instances[#instances + 1] = instance
        end
    end
    return instances
end

local function getPlayerLabel(playerState)
    local ok, playerName = pcall(function() return playerState:GetPlayerName():ToString() end)
    if ok and type(playerName) == "string" and playerName ~= "" then return playerName end
    return playerState:GetFName():ToString()
end

local function hasModifier(gameState, modifierValue)
    local modifiers = gameState.DifficultyModifiers
    if modifiers == nil then return false end
    local found = false
    modifiers:ForEach(function(index, element)
        if element:get() == modifierValue then
            found = true
            return true
        end
    end)
    return found
end

------------------------------------------------------------------------------
-- Startup validation
------------------------------------------------------------------------------

-- Returns the table from config.lua, or {} when there is none. Never throws.
local function loadUserConfig()
    local ok, result = pcall(require, "config")
    if not ok then
        if tostring(result):find("module 'config' not found", 1, true) then
            return {}, false, nil
        end
        return {}, false, "config.lua failed to load, using defaults: " .. tostring(result)
    end
    if type(result) ~= "table" then
        return {}, false, "config.lua must return a table (see config.example.lua), using defaults"
    end
    return result, true, nil
end

-- Applies defaults, then known keys from config.lua. Returns where settings came from.
local function validateConfig()
    for key, defaultValue in pairs(defaultConfig) do
        config[key] = defaultValue
    end

    local userConfig, hasUserConfig, loadProblem = loadUserConfig()
    if loadProblem then logMessage("WARN", loadProblem) end

    for key, value in pairs(userConfig) do
        local defaultValue = defaultConfig[key]
        if defaultValue == nil then
            logMessage("WARN", string.format("Unknown setting '%s' in config.lua ignored (check spelling)", tostring(key)))
        elseif type(value) ~= type(defaultValue) then
            logMessage("WARN", string.format("Setting '%s' must be a %s, using default %s", key, type(defaultValue), tostring(defaultValue)))
        else
            config[key] = value
        end
    end

    for _, key in ipairs({ "slotChecksPerIsland", "pollIntervalMs", "maxConsecutiveErrors", "errorLogIntervalSeconds" }) do
        if not isPositiveNumber(config[key]) then
            logMessage("WARN", string.format("Setting '%s' must be above 0, using default %s", key, tostring(defaultConfig[key])))
            config[key] = defaultConfig[key]
        end
    end
    if logLevels[config.minLogLevel] == nil then
        logMessage("WARN", "Setting 'minLogLevel' must be DEBUG, INFO, WARN or ERROR, using INFO")
        config.minLogLevel = "INFO"
    end

    return hasUserConfig and "config.lua" or "defaults"
end
-- Resolved by name so a game update that reorders the enum cannot misfire the mod.
local function resolveLockedSlotsValue()
    local modifierEnum = StaticFindObject(constants.modifierEnumPath)
    if not isValidObject(modifierEnum) then
        return false, "enum not found: " .. constants.modifierEnumPath
    end
    modifierEnum:ForEachName(function(name, value)
        local entryName = name:ToString():match("::(.+)$") or name:ToString()
        if entryName == config.lockedSlotsModifierName then resolved.lockedSlotsModifierValue = value end
    end)
    if resolved.lockedSlotsModifierValue == nil then
        return false, "modifier not found in enum: " .. config.lockedSlotsModifierName
    end
    return true, nil
end

local function resolveSlotDefaults()
    local defaultPlayerState = StaticFindObject(constants.defaultPlayerStatePath)
    if not isValidObject(defaultPlayerState) then
        return false, "class default not found: " .. constants.defaultPlayerStatePath
    end
    for _, field in ipairs(constants.slotFields) do
        local value = defaultPlayerState[field]
        if not isPositiveNumber(value) then
            return false, string.format("unexpected default for %s: %s", field, tostring(value))
        end
        resolved.slotDefaults[field] = value
    end
    return true, nil
end

local function initialize()
    local configSource = validateConfig()

    local ok, problem = resolveLockedSlotsValue()
    if not ok then return false, problem end

    ok, problem = resolveSlotDefaults()
    if not ok then return false, problem end

    logMessage("INFO", string.format("v%s settings=%s cancelLockedSlots=%s LockedSlots=%s(%d) slotDefaults=%d/%d/%d/%d",
        modVersion, configSource, tostring(config.cancelLockedSlots), config.lockedSlotsModifierName, resolved.lockedSlotsModifierValue,
        resolved.slotDefaults.NumWeaponModSlots, resolved.slotDefaults.NumAbilityModSlots,
        resolved.slotDefaults.NumMeleeModSlots, resolved.slotDefaults.NumPerkSlots))
    return true, nil
end

------------------------------------------------------------------------------
-- Cancel Locked Slots
------------------------------------------------------------------------------

-- Only ever raises a slot count back to its default, never lowers one.
local function restoreSlotCounts(playerState)
    local changes = {}
    for _, field in ipairs(constants.slotFields) do
        local currentValue = playerState[field]
        local defaultValue = resolved.slotDefaults[field]
        if type(currentValue) == "number" and currentValue < defaultValue then
            playerState[field] = defaultValue
            changes[#changes + 1] = string.format("%s %d->%d", field, currentValue, defaultValue)
        end
    end
    if #changes > 0 then
        local ok, errorMessage = pcall(function() playerState:OnRep_Inventory() end)
        if not ok then
            logRateLimited("onRepInventory", "WARN", "OnRep_Inventory failed (inventory UI may not refresh): " .. tostring(errorMessage))
        end
    end
    return changes
end

-- Logs the first time a category holds more items than Locked Slots would allow.
local function logSlotUsage(playerState, playerKey, playerLabel, currentIsland)
    for _, field in ipairs(constants.slotFields) do
        local inventoryField = constants.inventoryFields[field]
        local usageKey = playerKey .. ":" .. inventoryField
        local inventory = playerState[inventoryField]
        local itemCount = inventory ~= nil and #inventory or 0
        if itemCount > constants.lockedSlotLimit and not runState.loggedOverLimit[usageKey] then
            runState.loggedOverLimit[usageKey] = true
            logMessage("OK", string.format("[%s] %s holds %d items (over Locked Slots limit of %d) on island %d",
                playerLabel, inventoryField, itemCount, constants.lockedSlotLimit, currentIsland))
        end
    end
end

local function updatePlayerSlots(playerState, currentIsland)
    local playerKey = playerState:GetFullName()
    local playerLabel = getPlayerLabel(playerState)

    local changes = restoreSlotCounts(playerState)
    if #changes > 0 then
        local wasRestored = runState.restoredPlayers[playerKey] == true
        local level = wasRestored and "WARN" or "INFO"
        local prefix = wasRestored and "Game re-locked slots, restored again" or "Locked Slots cancelled"
        logMessage(level, string.format("[%s] %s (island %d): %s", playerLabel, prefix, currentIsland, table.concat(changes, ", ")))
        runState.restoredPlayers[playerKey] = true
    end

    logSlotUsage(playerState, playerKey, playerLabel, currentIsland)
end

local function updateAllPlayerSlots(currentIsland)
    for _, playerState in ipairs(getLiveInstances(constants.playerStateClass)) do
        local ok, errorMessage = pcall(updatePlayerSlots, playerState, currentIsland)
        if not ok then
            logRateLimited("updatePlayerSlots", "WARN", "Slot update failed for one player: " .. tostring(errorMessage))
        end
    end
end

------------------------------------------------------------------------------
-- Run tracking
------------------------------------------------------------------------------

local function onIslandChanged(gameState, currentIsland)
    runState.lastIsland = currentIsland

    if currentIsland < 1 then
        runState.isCancelActive = false
        runState.pendingSlotChecks = 0
        runState.restoredPlayers = {}
        runState.loggedOverLimit = {}
        return
    end

    local wasActive = runState.isCancelActive
    runState.isCancelActive = hasModifier(gameState, resolved.lockedSlotsModifierValue)
    runState.pendingSlotChecks = runState.isCancelActive and config.slotChecksPerIsland or 0

    if currentIsland == 1 or wasActive ~= runState.isCancelActive then
        local status = runState.isCancelActive and "ON, cancelling its effect" or "off, nothing to cancel"
        logMessage("INFO", string.format("Island %d: %s %s, rank=%s",
            currentIsland, config.lockedSlotsModifierName, status, tostring(gameState.Difficulty)))
    end
end

local function onPollTick()
    local gameState = getGameState()
    -- No game state during level transitions; not an error.
    if not gameState then return end

    local currentIsland = gameState.CurrentIsland
    if type(currentIsland) ~= "number" then
        logRateLimited("islandType", "WARN", "CurrentIsland is not a number: " .. tostring(currentIsland))
        return
    end

    if currentIsland ~= runState.lastIsland then
        onIslandChanged(gameState, currentIsland)
    end

    if runState.pendingSlotChecks > 0 then
        runState.pendingSlotChecks = runState.pendingSlotChecks - 1
        updateAllPlayerSlots(currentIsland)
    end
end

------------------------------------------------------------------------------
-- Scheduling and circuit breaker
------------------------------------------------------------------------------

local function handleCallbackError(label, errorMessage)
    runState.consecutiveErrors = runState.consecutiveErrors + 1
    logRateLimited(label .. ":" .. tostring(errorMessage), "ERROR", string.format("%s failed (%d/%d): %s",
        label, runState.consecutiveErrors, config.maxConsecutiveErrors, tostring(errorMessage)))
    if runState.consecutiveErrors >= config.maxConsecutiveErrors then
        runState.isDisabled = true
        logMessage("ERROR", "Too many consecutive errors, mod disabled until restart. Check the errors above.")
    end
end

local function runGuardedOnGameThread(label, callback)
    ExecuteInGameThread(function()
        if runState.isDisabled then return end
        local ok, errorMessage = pcall(callback)
        if ok then
            runState.consecutiveErrors = 0
        else
            handleCallbackError(label, errorMessage)
        end
    end)
end

local logOk, logProblem = pcall(openLogFile)
if not logOk then
    print(string.format("[%s] [WARN] Mod log file unavailable, logging to UE4SS.log only: %s\n", modName, tostring(logProblem)))
end

local initOk, initResult, initProblem = pcall(initialize)
if not initOk then
    logMessage("ERROR", "Startup crashed, mod not started: " .. tostring(initResult))
elseif not initResult then
    logMessage("ERROR", "Startup check failed, mod not started: " .. tostring(initProblem))
elseif not config.cancelLockedSlots then
    logMessage("INFO", "cancelLockedSlots is false in config.lua, Locked Slots plays normally. Mod idle.")
else
    LoopAsync(config.pollIntervalMs, function()
        if runState.isDisabled then return true end
        runGuardedOnGameThread("pollTick", onPollTick)
        return false
    end)
    logMessage("OK", "Loaded v" .. modVersion)
end