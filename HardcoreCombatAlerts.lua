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
local lastAlertTime = 0
local ALERT_COOLDOWN = 5

------------------------------------
--  Store IDs
------------------------------------
local myName = UnitName("player")           
local myGUID = UnitGUID("player") 

------------------------------------
-- Helper functions 
------------------------------------
local function say(msg)
    SendChatMessage(msg, "SAY")
end
local function party(msg)
    SendChatMessage(msg, "PARTY")
end
local function safeToString(val)
    -- If it's nil, return a placeholder string
    if val == nil then
        return "[nil]"
    end
    -- If it's an empty string, mark as "[empty]"
    if val == "" then
        return "[empty]"
    end
    -- If it’s a boolean, convert to "true"/"false"
    if type(val) == "boolean" then
        return val and "true" or "false"
    end
    -- If it’s a number or anything else, just do tostring
    return tostring(val)
end
-- Example: We want to ensure we have an integer (or 0).
local function noNil(val, fallback)
    if val == nil then
        return fallback
    end
    return val
end


------------------------------------
--  Register Events
------------------------------------
-- For health checks
CombatAlertsFrame:RegisterEvent("UNIT_HEALTH")
CombatAlertsFrame:RegisterEvent("UNIT_MAXHEALTH")

-- For combat state + combat log
CombatAlertsFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
CombatAlertsFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
CombatAlertsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

------------------------------------
--  Main Event Handler
------------------------------------
CombatAlertsFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        print("|cffff0000[Alert]|r You have entered combat!")
        say("Contact!")
    elseif event == "PLAYER_REGEN_ENABLED" then
        print("|cff00ff00[Alert]|r You have left combat.")

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -------------------------------------
        -- 1) Parse Combat Log
        -------------------------------------
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
			  
			  -- Apply noNil() with type-appropriate fallbacks:
		timestamp       = noNil(timestamp, 0)        -- number
		subEvent        = noNil(subEvent, "[event]") -- string
		hideCaster      = noNil(hideCaster, false)   -- boolean
		sourceGUID      = noNil(sourceGUID, "[nil]")
		sourceName      = noNil(sourceName, "[nil]")
		sourceFlags     = noNil(sourceFlags, 0)      -- number bitmask
		sourceRaidFlags = noNil(sourceRaidFlags, 0)
		destGUID        = noNil(destGUID, "[nil]")
		destName        = noNil(destName, "[nil]")
		destFlags       = noNil(destFlags, 0)
		destRaidFlags   = noNil(destRaidFlags, 0)
		spellID         = noNil(spellID, 0)          -- number
		spellName       = noNil(spellName, "[spell]")
		spellSchool     = noNil(spellSchool, 0)      -- often a bitmask
		amount          = noNil(amount, 0)
		overkill        = noNil(overkill, 0)
		school          = noNil(school, 0)
		resisted        = noNil(resisted, 0)
		blocked         = noNil(blocked, 0)
		absorbed        = noNil(absorbed, 0)
		critical        = noNil(critical, false)     -- boolean
		glancing        = noNil(glancing, false)
		crushing        = noNil(crushing, false)
		isOffHand       = noNil(isOffHand, false)

		print("Time: "         .. safeToString(timestamp) ..
			  " Event: "       .. safeToString(subEvent) ..
			  " Hide: "        .. safeToString(hideCaster) ..
			  " sGUID: "       .. safeToString(sourceGUID) ..
			  " sName: "       .. safeToString(sourceName) ..
			  " sFlags: "      .. safeToString(sourceFlags) ..
			  " sRaidFlags: "  .. safeToString(sourceRaidFlags) ..
			  " dGUID: "       .. safeToString(destGUID) ..
			  " dName: "       .. safeToString(destName) ..
			  " dFlags: "      .. safeToString(destFlags) ..
			  " dRaidFlags: "  .. safeToString(destRaidFlags) ..
			  " spellID: "     .. safeToString(spellID) ..
			  " spellName: "   .. safeToString(spellName) ..
			  " spellSchool: " .. safeToString(spellSchool) ..
			  " amount: "      .. safeToString(amount) ..
			  " overkill: "    .. safeToString(overkill) ..
			  " school: "      .. safeToString(school) ..
			  " resisted: "    .. safeToString(resisted) ..
			  " blocked: "     .. safeToString(blocked) ..
			  " absorbed: "    .. safeToString(absorbed) ..
			  " critical: "    .. safeToString(critical) ..
			  " glancing: "    .. safeToString(glancing) ..
			  " crushing: "    .. safeToString(crushing) ..
			  " offhand: "     .. safeToString(isOffHand))

			  
        -- Set up watchName variable
        local watchName = "ALL"

        -- Determine if this combat action involves the watched name
		local isMonitoredName = (watchName == "ALL") or
								(sourceName == watchName) or
								(destName == watchName)
		
		-- Check if me
		if sourceName and sourceGUID then
			if sourceName == myName or sourceGUID == myGUID then
				isPlayer = true
			else
				isPlayer = false
			end
		end
		------------------------------------
		--  Death
		------------------------------------
        -- A) Alert when something dies
        if subEvent == "UNIT_DIED" then
            print("|cffff0000[Hardcore Alert]|r " .. (destName or "Someone") .. " just died!")
        end

        -- B) Alert if CRITICAL DAMAGE occurs and it’s the monitored name
        if subEvent == "SWING_DAMAGE" or subEvent:find("_DAMAGE") then
            if critical then
                -- Right now we say "You took a CRITICAL HIT" if the monitored entity is involved.
                -- In a typical scenario, you'd also check if destGUID == UnitGUID("player") 
                -- for a truly "You took a CRIT" message. But we'll keep it as is:
                if isMonitoredName then
                    print("|cffff0000[Hardcore Alert]|r " ..
                          (destName or "Someone") .. " took a CRITICAL HIT from " ..
                          (sourceName or "Unknown") .. "!")
                end
            end
        end

		if isPlayer == false then
			------------------------------------
			--  Spells
			------------------------------------
			-- C) Alert on ANY spell cast START (showing caster and target)
			if subEvent == "SPELL_CAST_START" then
				local casterName = sourceName or "Unknown"
				local spell      = spellName or "Unknown Spell"
				local targetName = destName  or "No Target"

				print(string.format("|cff00ff00[Hardcore Alert]|r %s is casting %s on %s!",
									casterName, spell, targetName))
			end

			-- D) Mark any relevant subEvent as a “combat action” 
			local isCombatAction = false
			if subEvent:find("_DAMAGE") or
			   subEvent:find("_MISSED") or
			   subEvent:find("_CAST")   or
			   subEvent:find("_AURA_APPLIED") then
				isCombatAction = true
			end

			-- E) If the monitored name was involved in a combat action, alert (with cooldown)
			if isCombatAction and isMonitoredName then
				local now = GetTime()
				if (now - lastAlertTime) > ALERT_COOLDOWN then
					print("|cffffff00[Alert]|r " ..
						  (sourceName or "Party member") .. " appears to have engaged in combat!")
					lastAlertTime = now
				end
			end
		end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        -------------------------------------
        -- 2) Track Health Thresholds
        -------------------------------------
        local unitID = ...
        local name = UnitName(unitID)

        -- Check if this is the player or a party unit 
        if unitID == "player" or unitID:match("^party%d$") then
            if not name then return end  -- No name, bail out

            -- Ensure we have an entry for this name
            if not healthAlertState[name] then
                healthAlertState[name] = { below50 = false, below25 = false }
            end

            local currentHP = UnitHealth(unitID)
            local maxHP     = UnitHealthMax(unitID)
            if maxHP > 0 then
                local percent = (currentHP / maxHP) * 100

                -- A) 25% threshold
                if percent <= 25 then
                    if not healthAlertState[name].below25 then
                        print("|cffff0000[Hardcore Alert]|r " .. name .. " is below 25% health!")
                        healthAlertState[name].below25 = true
                    end
                else
                    healthAlertState[name].below25 = false
                end

                -- B) 50% threshold
                if percent <= 50 then
                    if not healthAlertState[name].below50 then
                        print("|cffff8000[Hardcore Alert]|r " .. name .. " is at or below 50% health!")
                        healthAlertState[name].below50 = true
                    end
                else
                    healthAlertState[name].below50 = false
                end
            end
        end
    end
end)

