-- Create a frame to capture events
local CombatAlertsFrame = CreateFrame("Frame", "CombatAlertsFrame", UIParent)

------------------------------------
--  Track Health %
------------------------------------
-- Create a table to track who we've already alerted for each threshold,
-- so we only alert once until the HP rises above that threshold again.
local healthAlertState = {
    player = { below50 = false, below25 = false },
    Haymus = { below50 = false, below25 = false },
}

------------------------------------
--  Alert Timers
------------------------------------
-- Track the last alert time to prevent spamming alerts
local lastAlertTime = 0
-- Minimum time (in seconds) between alerts
local ALERT_COOLDOWN = 5

------------------------------------
--  Store IDs
------------------------------------
-- Get the player's name and GUID for comparison purposes
local myName = UnitName("player")           
local myGUID = UnitGUID("player") 

------------------------------------
-- Helper functions 
------------------------------------
-- Send a message in the /say channel
local function say(msg)
    SendChatMessage(msg, "SAY")
end

-- Send a message in the /party channel
local function party(msg)
    SendChatMessage(msg, "PARTY")
end

-- Safely convert a value to a string for debugging
local function safeToString(val)
    if val == nil then
        return "[nil]"
    end
    if val == "" then
        return "[empty]"
    end
    if type(val) == "boolean" then
        return val and "true" or "false"
    end
    return tostring(val)
end

-- Ensure a value is not nil, returning a fallback if it is
local function noNil(val, fallback)
    return val == nil and fallback or val
end

------------------------------------
--  Register Events
------------------------------------
-- Register events for health checks
CombatAlertsFrame:RegisterEvent("UNIT_HEALTH")
CombatAlertsFrame:RegisterEvent("UNIT_MAXHEALTH")

-- Register events for combat state and combat log
CombatAlertsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
CombatAlertsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
CombatAlertsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

------------------------------------
--  Main Event Handler
------------------------------------
-- Main function to handle registered events
CombatAlertsFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Alert when entering combat
        print("|cffff0000[Alert]|r You have entered combat!")
        say("Contact!")
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Alert when leaving combat
        print("|cff00ff00[Alert]|r You have left combat.")

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -------------------------------------
        -- 1) Parse Combat Log
        -------------------------------------
        -- Extract combat log information
        local timestamp,
              subEvent,
              hideCaster,
              sourceGUID,
              sourceName,
              sourceFlags,
              sourceRaidFlags,
              destGUID,
              destName,
              destFlags,
              destRaidFlags,
              spellID,
              spellName,
              spellSchool,
              amount,
              overkill,
              school,
              resisted,
              blocked,
              absorbed,
              critical,
              glancing,
              crushing,
              isOffHand = CombatLogGetCurrentEventInfo()

        -- Sanitize extracted values to ensure they are not nil
        timestamp       = noNil(timestamp, 0)
        subEvent        = noNil(subEvent, "[event]")
        hideCaster      = noNil(hideCaster, false)
        sourceGUID      = noNil(sourceGUID, "[nil]")
        sourceName      = noNil(sourceName, "[nil]")
        sourceFlags     = noNil(sourceFlags, 0)
        sourceRaidFlags = noNil(sourceRaidFlags, 0)
        destGUID        = noNil(destGUID, "[nil]")
        destName        = noNil(destName, "[nil]")
        destFlags       = noNil(destFlags, 0)
        destRaidFlags   = noNil(destRaidFlags, 0)
        spellID         = noNil(spellID, 0)
        spellName       = noNil(spellName, "[spell]")
        spellSchool     = noNil(spellSchool, 0)
        amount          = noNil(amount, 0)
        overkill        = noNil(overkill, 0)
        school          = noNil(school, 0)
        resisted        = noNil(resisted, 0)
        blocked         = noNil(blocked, 0)
        absorbed        = noNil(absorbed, 0)
        critical        = noNil(critical, false)
        glancing        = noNil(glancing, false)
        crushing        = noNil(crushing, false)
        isOffHand       = noNil(isOffHand, false)

        -- Print detailed combat log information for debugging
		print("Time-"         .. safeToString(timestamp) ..
			  " Event-"       .. safeToString(subEvent) ..
			  " Hide-"        .. safeToString(hideCaster) ..
			  " sGUID-"       .. safeToString(sourceGUID) ..
			  " sName-"       .. safeToString(sourceName) ..
			  " sFlags-"      .. safeToString(sourceFlags) ..
			  " sRaidFlags-"  .. safeToString(sourceRaidFlags) ..
			  " dGUID-"       .. safeToString(destGUID) ..
			  " dName-"       .. safeToString(destName) ..
			  " dFlags-"      .. safeToString(destFlags) ..
			  " dRaidFlags-"  .. safeToString(destRaidFlags) ..
			  " spellID-"     .. safeToString(spellID) ..
			  " spellName-"   .. safeToString(spellName) ..
			  " spellSchool-" .. safeToString(spellSchool) ..
			  " amount-"      .. safeToString(amount) ..
			  " overkill-"    .. safeToString(overkill) ..
			  " school-"      .. safeToString(school) ..
			  " resisted-"    .. safeToString(resisted) ..
			  " blocked-"     .. safeToString(blocked) ..
			  " absorbed-"    .. safeToString(absorbed) ..
			  " critical-"    .. safeToString(critical) ..
			  " glancing-"    .. safeToString(glancing) ..
			  " crushing-"    .. safeToString(crushing) ..
			  " offhand-"     .. safeToString(isOffHand))

        -- Variable to monitor specific targets (e.g., "ALL" for global monitoring)
        local watchName = "ALL"

        -- Check if the event involves the monitored name
        local isMonitoredName = (watchName == "ALL") or
                                 (sourceName == watchName) or
                                 (destName == watchName)

        -- Determine if the player is involved in the event
        local isPlayer = (sourceName == myName or sourceGUID == myGUID)

        ------------------------------------
        --  Death Alert
        ------------------------------------
        if subEvent == "UNIT_DIED" then
            print("|cffff0000[Hardcore Alert]|r " .. (destName or "Someone") .. " just died!")
        end

        ------------------------------------
        --  Critical Damage Alert
        ------------------------------------
        if subEvent == "SWING_DAMAGE" or subEvent:find("_DAMAGE") then
            if critical and isMonitoredName then
                print("|cffff0000[Hardcore Alert]|r " ..
                      (destName or "Someone") .. " took a CRITICAL HIT from " ..
                      (sourceName or "Unknown") .. "!")
            end
        end

        ------------------------------------
        --  Spell Cast Alert (Non-Player)
        ------------------------------------
        if not isPlayer and subEvent == "SPELL_CAST_START" then
            local casterName = sourceName or "Unknown"
            local spell      = spellName or "Unknown Spell"
            local targetName = destName  or "No Target"

            print(string.format("|cff00ff00[Hardcore Alert]|r %s is casting %s on %s!",
                                casterName, spell, targetName))
        end

        ------------------------------------
        --  Combat Action Alert
        ------------------------------------
        local isCombatAction = subEvent:find("_DAMAGE") or
                               subEvent:find("_MISSED") or
                               subEvent:find("_CAST") or
                               subEvent:find("_AURA_APPLIED")

        if isCombatAction and isMonitoredName then
            local now = GetTime()
            if (now - lastAlertTime) > ALERT_COOLDOWN then
                print("|cffffff00[Alert]|r " ..
                      (sourceName or "Party member") .. " appears to have engaged in combat!")
                lastAlertTime = now
            end
        end

    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -------------------------------------
        -- 2) Track Health Thresholds
        -------------------------------------
        local unitID = ...
        local name = UnitName(unitID)

        -- Ensure the unit is either the player or a party member
        if unitID == "player" or unitID:match("^party%d$") then
            if not name then return end

            -- Initialize health tracking for new units
            if not healthAlertState[name] then
                healthAlertState[name] = { below50 = false, below25 = false }
            end

            -- Calculate current health percentage
            local currentHP = UnitHealth(unitID)
            local maxHP     = UnitHealthMax(unitID)
            if maxHP > 0 then
                local percent = (currentHP / maxHP) * 100

                -- Alert if health drops below 25%
                if percent <= 25 and not healthAlertState[name].below25 then
                    print("|cffff0000[Hardcore Alert]|r " .. name .. " is below 25% health!")
                    healthAlertState[name].below25 = true
                elseif percent > 25 then
                    healthAlertState[name].below25 = false
                end

                -- Alert if health drops below 50%
                if percent <= 50 and not healthAlertState[name].below50 then
                    print("|cffff8000[Hardcore Alert]|r " .. name .. " is at or below 50% health!")
                    healthAlertState[name].below50 = true
                elseif percent > 50 then
                    healthAlertState[name].below50 = false
                end
            end
        end
    end
end)
