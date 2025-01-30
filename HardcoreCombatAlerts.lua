--------------------------------------------------------------------------------
--#1 DECLARATIONS
--------------------------------------------------------------------------------

local CombatAlertsFrame = CreateFrame("Frame", "CombatAlertsFrame", UIParent)

-- Table of monitored names so we can watch multiple party members
local monitoredNames = {
    ["Haymus"]    = true,
    ["HexCypher"] = true,
}

-- Health thresholds so we alert only once until HP rises above the threshold
local healthAlertState = {
    Haymus = {
        below75 = false,
        below50 = false,
        below25 = false,
    },
    HexCypher = {
        below75 = false,
        below50 = false,
        below25 = false,
    },
}

-- Track whether each monitored member is in combat
local lastInCombatState = {}

-- Shock spells to detect for cooldown or resist notifications
local SHOCK_SPELLS = {
    -- Earth Shock
    [8042]  = "Earth Shock (Rank 1)",
    [8044]  = "Earth Shock (Rank 2)",
    [8045]  = "Earth Shock (Rank 3)",
    [8046]  = "Earth Shock (Rank 4)",
    [10412] = "Earth Shock (Rank 5)",
    [10413] = "Earth Shock (Rank 6)",
    [10414] = "Earth Shock (Rank 7)",

    -- Flame Shock
    [8050]  = "Flame Shock (Rank 1)",
    [8052]  = "Flame Shock (Rank 2)",
    [8053]  = "Flame Shock (Rank 3)",
    [10447] = "Flame Shock (Rank 4)",
    [10448] = "Flame Shock (Rank 5)",

    -- Frost Shock
    [8056]  = "Frost Shock (Rank 1)",
    [8058]  = "Frost Shock (Rank 2)",
    [10472] = "Frost Shock (Rank 3)",
    [10473] = "Frost Shock (Rank 4)",
}

--------------------------------------------------------------------------------
--#2 HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- (Removed or commented out the party chat function)
-- local function party(msg)
--    SendChatMessage(msg, "PARTY")
-- end

local function safeToString(val)
    if val == nil then
        return "[nil]"
    elseif val == "" then
        return "[empty]"
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    end
    return tostring(val)
end

local function noNil(val, fallback)
    return val == nil and fallback or val
end

--------------------------------------------------------------------------------
--#3 REGISTER EVENTS
--------------------------------------------------------------------------------

CombatAlertsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Monitor party members’ health
CombatAlertsFrame:RegisterEvent("UNIT_HEALTH")
CombatAlertsFrame:RegisterEvent("UNIT_MAXHEALTH")

-- Track party members entering/leaving combat
CombatAlertsFrame:RegisterUnitEvent("UNIT_FLAGS", "party1", "party2", "party3", "party4")

--------------------------------------------------------------------------------
--#4 MAIN EVENT HANDLER
--------------------------------------------------------------------------------

CombatAlertsFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then

        ----------------------------------------------------------------------------
        --#4.1 COMBAT_LOG_EVENT_UNFILTERED SUB-SECTION
        ----------------------------------------------------------------------------
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

        -- Sanitize values
        timestamp   = noNil(timestamp, 0)
        subEvent    = noNil(subEvent, "[event]")
        sourceName  = noNil(sourceName, "[nil]")
        destName    = noNil(destName, "[nil]")
        spellID     = noNil(spellID, 0)
        spellName   = noNil(spellName, "[spell]")
        amount      = noNil(amount, 0)
        critical    = noNil(critical, false)

        -- Determine if this event is about someone we are monitoring
        local isSourceMonitored = monitoredNames[sourceName] ~= nil
        local isDestMonitored   = monitoredNames[destName]   ~= nil

        ----------------------------------------------------------------------------
        -- 4.1.a: Death Alert (UNIT_DIED)
        ----------------------------------------------------------------------------
        if subEvent == "UNIT_DIED" and isDestMonitored then
            print("|cffff0000[Hardcore Alert]|r " .. destName .. " just died!")
        end

        ----------------------------------------------------------------------------
        -- 4.1.b: Critical Damage Alert (with damage amount if > 0)
        ----------------------------------------------------------------------------
        if (subEvent == "SWING_DAMAGE" or subEvent:find("_DAMAGE"))
           and critical
           and (isSourceMonitored or isDestMonitored)
        then
            -- If the amount is positive, include it in the message
            local amountText = ""
            if amount and amount > 0 then
                amountText = " for " .. amount
            end

            print("|cffff0000[Hardcore Alert]|r "
                .. destName
                .. " took a CRITICAL HIT"
                .. amountText
                .. " from "
                .. sourceName
                .. "!")
        end

        ----------------------------------------------------------------------------
        -- 4.1.c: Spell Cast Start (e.g., if monitored Shaman is casting something)
        ----------------------------------------------------------------------------
        if subEvent == "SPELL_CAST_START" and isSourceMonitored then
            local casterName = sourceName
            local targetName = (destName == "[nil]" and "No Target") or destName

            if targetName == "No Target" then
                print(string.format("|cff00ff00[Hardcore Alert]|r %s is casting %s!",
                                    casterName, spellName))
            else
                print(string.format("|cff00ff00[Hardcore Alert]|r %s is casting %s on %s!",
                                    casterName, spellName, targetName))
            end
        end

        ----------------------------------------------------------------------------
        -- 4.1.d: Spell Cast Success (Shock Spell => Start 6s Cooldown)
        ----------------------------------------------------------------------------
        if subEvent == "SPELL_CAST_SUCCESS" and isSourceMonitored then
            local shockName = SHOCK_SPELLS[spellID]
            if shockName then
                print("|cff00ff00[Hardcore Alert]|r " .. sourceName .. " used " .. shockName .. "!")
                -- After 6 seconds, let them know it's ready again
                C_Timer.After(6, function()
                    print("|cff00ff00[Hardcore Alert]|r " .. sourceName .. "'s " .. shockName .. " is off cooldown!")
                end)
            end
        end

        ----------------------------------------------------------------------------
        -- 4.1.e: Shock Resist Check (SPELL_MISSED with missType == "RESIST")
        ----------------------------------------------------------------------------
        if subEvent == "SPELL_MISSED" and isSourceMonitored then
            local missType = select(15, CombatLogGetCurrentEventInfo())
            missType = noNil(missType, "UNKNOWN")

            local shockName = SHOCK_SPELLS[spellID]
            if shockName and missType == "RESIST" then
                print("|cffff0000[Hardcore Alert]|r " .. sourceName
                    .. "'s " .. shockName
                    .. " was |cffFF0000RESISTED|r by "
                    .. destName
                    .. "!")
            end
        end

    ----------------------------------------------------------------------------
    --#4.2 UNIT_HEALTH / UNIT_MAXHEALTH SUB-SECTION
    ----------------------------------------------------------------------------
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local unitID = ...
        -- Only if it's a party unit
        if unitID and unitID:match("^party%d$") then
            local name = UnitName(unitID)
            if not name then return end

            -- If we’re only tracking certain party members, skip the rest
            if not monitoredNames[name] then
                return
            end

            -- If table fields are missing for a newly discovered name, initialize them
            if not healthAlertState[name] then
                healthAlertState[name] = { below75 = false, below50 = false, below25 = false }
            end

            local currentHP = UnitHealth(unitID)
            local maxHP     = UnitHealthMax(unitID)
            if maxHP > 0 then
                local percent = (currentHP / maxHP) * 100

                -- 75% threshold
                if percent <= 75 and not healthAlertState[name].below75 then
                    print("|cff808080[Hardcore Alert]|r " .. name .. " is at or below 75% health!")
                    healthAlertState[name].below75 = true
                elseif percent > 75 then
                    healthAlertState[name].below75 = false
                end

                -- 50% threshold
                if percent <= 50 and not healthAlertState[name].below50 then
                    print("|cffff8000[Hardcore Alert]|r " .. name .. " is at or below 50% health!")
                    healthAlertState[name].below50 = true
                elseif percent > 50 then
                    healthAlertState[name].below50 = false
                end

                -- 25% threshold
                if percent <= 25 and not healthAlertState[name].below25 then
                    print("|cffff0000[Hardcore Alert]|r " .. name .. " is below 25% health!")
                    healthAlertState[name].below25 = true
                elseif percent > 25 then
                    healthAlertState[name].below25 = false
                end
            end
        end

    ----------------------------------------------------------------------------
    --#4.3 UNIT_FLAGS SUB-SECTION (Party Member Combat State)
    ----------------------------------------------------------------------------
    elseif event == "UNIT_FLAGS" then
        local unitID = ...
        if not unitID then return end

        local inCombat = UnitAffectingCombat(unitID)
        local name     = UnitName(unitID)
        if not name then return end

        -- Only track if it's one of our monitored names
        if not monitoredNames[name] then
            return
        end

        if inCombat and not lastInCombatState[name] then
            -- Entered combat
            lastInCombatState[name] = true
        elseif not inCombat and lastInCombatState[name] then
            -- Left combat
            lastInCombatState[name] = false
            print("|cff00ff00[Alert]|r " .. name .. " left combat.")
        end
    end
end)
