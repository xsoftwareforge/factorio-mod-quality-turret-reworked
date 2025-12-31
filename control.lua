local xpStartValue = settings.startup["XP-Start-Value"].value
local xpScalingAlgo = settings.startup["XP-Scaling-Algo"].value
local xpScalingFactor = settings.startup["XP-Scaling-Factor"].value

local limitQualityUnlocked = settings.startup["Limit-quality-to-unlocked"].value

local validTurrets = {
	["ammo-turret"] = true,
	["fluid-turret"] = true,
	["electric-turret"] = true,
	["artillery-turret"] = true
}

local aai_active = script.active_mods and script.active_mods["aai-programmable-vehicles"]
local deadzone_block_types = {"unit-spawner", "turret", "ammo-turret", "electric-turret", "fluid-turret", "inserter"}
local deadzone_block_type_set = {
	["unit-spawner"] = true,
	["turret"] = true,
	["ammo-turret"] = true,
	["electric-turret"] = true,
	["fluid-turret"] = true,
	["inserter"] = true
}

local function EnsureState()
	global = global or {}
	global.quality_turrets = global.quality_turrets or {}
	global.quality_turrets.pending_upgrades = global.quality_turrets.pending_upgrades or {}
end

script.on_init(EnsureState)
script.on_configuration_changed(EnsureState)

local function GetState()
	EnsureState()
	return global.quality_turrets
end

local function GetDeadzoneRange()
	if not aai_active then return 0 end
	local setting = settings.global["deadzone-construction-denial-range"]
	if not setting then return 0 end
	local range = setting.value or 0
	if range < 0 then return 0 end
	return range
end

local function IsForceHostile(force, other_force)
	if not (force and force.valid and other_force and other_force.valid) then return false end
	local name = other_force.name
	if name == "neutral" or name == "capture" or name == "conquest" or name == "ignore" or name == "friendly"
		or name == "kr-internal-turrets" then
		return false
	end
	if other_force == force then return false end
	if force.get_cease_fire(other_force) then return false end
	if force.get_friend(other_force) then return false end
	return true
end

local function GetHostileForceNames(force)
	local names = {}
	for _, other_force in pairs(game.forces) do
		if IsForceHostile(force, other_force) then
			names[#names + 1] = other_force.name
		end
	end
	return names
end

local function IsDeadzoneBlocked(turret)
	local range = GetDeadzoneRange()
	if range <= 0 then return false end
	if not (turret and turret.valid) then return false end
	local hostile_forces = GetHostileForceNames(turret.force)
	if #hostile_forces == 0 then return false end
	local blockers = turret.surface.find_entities_filtered{
		radius = range,
		position = turret.position,
		type = deadzone_block_types,
		force = hostile_forces,
		limit = 1
	}
	return blockers[1] ~= nil
end

local function QueuePendingUpgrade(turret)
	if not (turret and turret.valid and turret.unit_number) then return end
	local state = GetState()
	if state.pending_upgrades[turret.unit_number] then return end
	state.pending_upgrades[turret.unit_number] = {entity = turret}
end

local function ClearPendingUpgrade(unit_number)
	if not unit_number then return end
	local state = GetState()
	state.pending_upgrades[unit_number] = nil
end

local function RecheckPendingUpgradesNear(entity)
	local range = GetDeadzoneRange()
	if range <= 0 then return end
	local state = GetState()
	local pending = state.pending_upgrades
	if not next(pending) then return end
	if not (entity and entity.valid) then return end
	local surface = entity.surface
	local position = entity.position
	local max_dist_sq = range * range
	for unit_number, data in pairs(pending) do
		local turret = data.entity
		if not (turret and turret.valid) then
			pending[unit_number] = nil
		elseif turret.surface == surface then
			local dx = turret.position.x - position.x
			local dy = turret.position.y - position.y
			if (dx * dx + dy * dy) <= max_dist_sq then
				DidTurretKill(turret)
				if not (turret and turret.valid) then
					pending[unit_number] = nil
				end
			end
		end
	end
end

script.on_event(defines.events.on_entity_died, function(event)
	local cause = event.cause
	if cause and cause.valid and validTurrets[cause.type] then
		UpdateGUI(cause)
		DidTurretKill(cause)
	end

	local entity = event.entity
	if entity and entity.unit_number and validTurrets[entity.type] then
		ClearPendingUpgrade(entity.unit_number)
	end
	if entity and entity.valid and deadzone_block_type_set[entity.type] then
		RecheckPendingUpgradesNear(entity)
	end
end)

function GetKillsRequired(quality)
	local level = quality.level or 0
	
	if xpScalingAlgo == "linear" then
		return math.floor(xpStartValue + (level * xpScalingFactor))
	elseif xpScalingAlgo == "exponential" then
		return math.floor(xpStartValue * (xpScalingFactor ^ level))
	else -- constant
		return xpStartValue
	end
end

function DidTurretKill(turret)
	local requiredKills = GetKillsRequired(turret.quality)
	
	if turret.kills < requiredKills then return end
	if not turret.quality.next then return end
	
	-- Check for quality unlock limit
	local nextQuality = turret.quality.next
	if limitQualityUnlocked then
		-- Create a safe check for unlocking
		if turret.force.is_quality_unlocked then
			if not turret.force.is_quality_unlocked(nextQuality) then
				return
			end
		end
	end
	
	-- Ensure we are upgrading a turret
	if not validTurrets[turret.type] then return end

	if IsDeadzoneBlocked(turret) then
		QueuePendingUpgrade(turret)
		return
	end

	-- Gather data before replacement
	local ammo = GetAmmo(turret)
	local turretUnitNumber = turret.unit_number
	-- Carry over excess kills (fairness) instead of full reset or keeping all
	local newKills = turret.kills - requiredKills
	local damage_dealt = turret.damage_dealt 
	local turretSurface = turret.surface
	local turretPosition = turret.position
	local turretForce = turret.force
	local turretDirection = turret.direction
	local turretName = turret.name
	
	-- Capture fluids (for flamethrower turrets)
	local fluids = {}
	if turret.fluidbox then
		for i = 1, #turret.fluidbox do
			fluids[i] = turret.fluidbox[i]
		end
	end

	-- fast_replace=true attempts to preserve connections and settings
	local newTurret = turretSurface.create_entity{
		name = turretName,
		position = turretPosition, 
		force = turretForce, 
		direction = turretDirection, 
		quality = nextQuality,
		fast_replace = true, 
		spill = false,
		raise_built = true
	}

	if newTurret and newTurret.valid then
		if turretUnitNumber then
			ClearPendingUpgrade(turretUnitNumber)
		end

		-- Visual Feedback (Flying Text + Sound)
		if settings.global["Show-level-up-text"].value then
			rendering.draw_text{
				text = {"", "Quality Up! [", newTurret.quality.localised_name or newTurret.quality.name, "]"},
				surface = newTurret.surface,
				target = newTurret,
				target_offset = {0, -1}, -- Slightly above
				color = {r=1, g=0.8, b=0},
				scale = 1.5,
				alignment = "center",
				time_to_live = 120 -- 2 Seconds
			}
		end
		
		if settings.global["Play-level-up-sound"].value then
			newTurret.surface.play_sound{
				path = "utility/new_objective",
				position = newTurret.position
			}
		end

		-- Restore Stats (Reset kills for balance)
		newTurret.kills = newKills
		newTurret.damage_dealt = damage_dealt or 0

		-- Restore Fluids
		if #fluids > 0 then
			for i, fluid in pairs(fluids) do
				newTurret.fluidbox[i] = fluid
			end
		end

		-- If fast_replace didn't kill the old turret (rare), destroy it.
		if turret.valid then
			newTurret.copy_settings(turret)
			turret.destroy()
		end

		-- Restore Ammo
		if ammo then
			for _, item in pairs(ammo) do
				newTurret.insert(item)
			end
		end
		
		-- Update GUI for any player who might have had the old turret open (unlikely due to replace)
		-- or if they are hovering near it.
	end
end

function GetAmmo(turret)
	-- Try standard ammo inventory
	local inv = turret.get_inventory(defines.inventory.turret_ammo) or turret.get_inventory(defines.inventory.artillery_turret_ammo)
	-- Fallback for some modded turrets or general inventory
	if not inv then
		inv = turret.get_inventory(defines.inventory.chest) or turret.get_inventory(defines.inventory.car_trunk) or turret.get_inventory(1)
	end
	
	if inv and inv.valid then
		return inv.get_contents()
	end
	
	return nil
end

-- GUI Logic
script.on_event(defines.events.on_gui_opened, function(event)
	local player = game.get_player(event.player_index)
	local entity = event.entity
	if entity and entity.valid and validTurrets[entity.type] then
		CreateProgressGUI(player, entity)
	end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if event.element and event.element.name == "quality_turrets_frame" then
		event.element.destroy()
	elseif player.gui.relative["quality_turrets_frame"] then
		player.gui.relative["quality_turrets_frame"].destroy()
	end
end)

function CreateProgressGUI(player, turret)
	if player.gui.relative["quality_turrets_frame"] then
		player.gui.relative["quality_turrets_frame"].destroy()
	end

	-- Simple Relative GUI attached to the turret inventory container usually works best
	-- However, relative GUIs require defining anchor in data.lua which we haven't touched.
	-- So we use a floating frame pinned to the side or center, or attached to relative if supported.
	-- Given we only edit control.lua, we'll try a small frame in `screen` or `left` or simply relative generic.
	-- Factorio 2.0 relative GUI is powerful.
	
	local anchor = {gui=defines.relative_gui_type.entity_with_inventory, position=defines.relative_gui_position.right}
	-- But type depends on turret. ammo-turret has its own ID.
	-- Without data.lua changes, relative GUI might not stick perfectly to all windows.
	-- Let's stick to a valid simple frame or check relative types.
	
	local frame = player.gui.relative.add{
		type = "frame",
		name = "quality_turrets_frame",
		caption = "Quality Progress",
		anchor = {
			gui = defines.relative_gui_type.turret_gui, -- generic for turrets?
			position = defines.relative_gui_position.right
		}
	}
	-- Add specific anchors for other types if needed, or just let it fail gracefully/fallback.
	-- Actually, let's try to make it work for ammo-turret specifically.
	-- If that fails, we can put it in player.gui.screen using entity positions, but that's messy.
	
	-- Note: defines.relative_gui_type.turret_gui does not exist in 1.1, assume 2.0 has specific types?
	-- "ammo-turret" uses container_gui usually. 
	-- Safe bet: just use player.gui.relative without complex anchor for now or create a floating one if relative fails.
	-- Actually, without data stage definition, relative GUI *should* work if we guess the type right.
	-- Let's try anchor for ammo-turret.
	
	if not frame then
		-- Fallback if relative add fails (shouldn't) or if we want safe implementation
		frame = player.gui.relative.add{
			type="frame", 
			name="quality_turrets_frame", 
			caption="Quality Progress",
			anchor = {gui=defines.relative_gui_type.container_gui, position=defines.relative_gui_position.right} -- generic
		}
	end

	local flow = frame.add{type="flow", direction="vertical"}
	
	local requiredKills = GetKillsRequired(turret.quality)
	local progress = math.min(turret.kills / requiredKills, 1)
	
	-- Read Settings
	local separateCounter = player.mod_settings["UI-Separate-Kill-Counter"].value
	local barHeight = 10 -- player.mod_settings["UI-Progress-Bar-Height"].value
	local spacerHeight = player.mod_settings["UI-Spacer-Height"].value

	-- Progress Bar
	local pbarCaption = ""
	if not separateCounter then
		pbarCaption = turret.kills .. " / " .. requiredKills .. " Kills"
	end
	
	local pbar = flow.add{type="progressbar", name="quality_progressbar", value=progress, caption=pbarCaption}
	pbar.style.horizontally_stretchable = true
	pbar.style.height = barHeight
	
	-- Spacer & Kill Label (Conditional)
	if separateCounter then
		local spacer = flow.add{type="empty-widget", name="quality_spacer"}
		spacer.style.height = spacerHeight
		
		flow.add{type="label", name="quality_kill_label", caption=turret.kills .. " / " .. requiredKills .. " Kills"}
	else
		-- Need a dummy label if we want UpdateGUI to be simpler? 
		-- actually UpdateGUI checks if label exists.
	end

	local next_quality_name = "Max"
	if turret.quality.next then
		next_quality_name = turret.quality.next.localised_name or turret.quality.next.name
	end

	flow.add{
		type = "label",
		name = "quality_next_label",
		caption = {"", "Next: ", next_quality_name}
	}
end

-- Update GUI on kills (only if open)
-- We hook into DidTurretKill? No, DidTurretKill is for LEVEL UP.
-- We need on_entity_died to update progress even if NOT leveling up.
-- But on_entity_died event is filtered.
-- We need to check if we should update GUI in the main event.

function UpdateGUI(turret)
    -- Iterate all players, check if they have this turret open
    for _, player in pairs(game.connected_players) do
        if player.opened == turret and player.gui.relative["quality_turrets_frame"] then
            local frame = player.gui.relative["quality_turrets_frame"]
            local flow = frame.children[1]
            local pbar = flow["quality_progressbar"]
            local label = flow["quality_kill_label"]
            
            if pbar then
                local requiredKills = GetKillsRequired(turret.quality)
                local progress = math.min(turret.kills / requiredKills, 1)
                
                pbar.value = progress
				
				-- Check if we are in separate mode or merged mode
				if label then
					label.caption = turret.kills .. " / " .. requiredKills .. " Kills"
				else
					pbar.caption = turret.kills .. " / " .. requiredKills .. " Kills"
				end
            end
        end
    end
end

-- Mining Logic (Preserve Kills)
function OnEntityMined(event)
	local entity = event.entity
	local buffer = event.buffer
	
	if not (entity and entity.valid and validTurrets[entity.type]) then return end
	if entity.kills == 0 then return end
    
    -- Check mod setting
    if not settings.global["Preserve-kill-counter"].value then return end
	
	if buffer and buffer.valid then
        -- Iterate manually to find the stack (safest method)
		for i = 1, #buffer do
			local stack = buffer[i]
			if stack and stack.valid_for_read and stack.name == entity.name then
				stack.set_tag("kills", entity.kills)
				
                -- stack.label MUST be a string. We cannot use localised names here easily in control stage.
                -- Using the internal name is safe.
                stack.label = stack.name .. " (" .. entity.kills .. " Kills)"
                
				-- custom_description supports LocalisedString
				stack.custom_description = {"", "Kills: ", entity.kills}
				break 
			end
		end
	end
end

-- Building Logic (Restore Kills)
function OnEntityBuilt(event)
	local entity = event.created_entity or event.entity -- robot built vs player built
	
	if not (entity and entity.valid and validTurrets[entity.type]) then return end
    
    -- Debugging
    -- game.print("DEBUG: OnEntityBuilt for " .. entity.name)
	
    -- When placing the last item, stack is invalid, but event.tags should be present
	local tags = event.tags
    
    -- Fallback to stack tags if available (e.g. infinite creative stack or not consumed)
    if not tags and event.stack and event.stack.valid_for_read then
        tags = event.stack.tags
    end

    if tags then
        -- game.print("DEBUG: Tags found: " .. serpent.block(tags))
        if tags.kills then
    		entity.kills = tags.kills
            -- game.print("DEBUG: Restored kills: " .. tags.kills)
        else
            -- game.print("DEBUG: Tags exist but no 'kills' key")
        end
    else
        -- game.print("DEBUG: No tags found on stack or event")
    end
end

script.on_event(defines.events.on_player_mined_entity, OnEntityMined)
script.on_event(defines.events.on_robot_mined_entity, OnEntityMined)

script.on_event(defines.events.on_built_entity, OnEntityBuilt)
script.on_event(defines.events.on_robot_built_entity, OnEntityBuilt)





-- Smart Ghost Logic
function OnPostEntityDied(event)
	local ghost = event.ghost
	if not ghost then return end
	
	-- Check if the dying entity was a supported turret
	local prototype = event.prototype
	if not (prototype and validTurrets[prototype.type]) then return end

	local strategy = settings.global["Ghost-Strategy"].value
	if strategy == "same" then return end

	if strategy == "exact" then
		local targetQualityName = settings.global["Ghost-Fixed-Quality"].value
		if ghost.quality.name == targetQualityName then return end
		ReplaceGhost(ghost, targetQualityName)
		return
	end

	if strategy == "downgrade" then
		-- Check network coverage
		local network = ghost.surface.find_logistic_network_by_position(ghost.position, ghost.force)
		if not network then
			ghost.force.print({"message.no-logistic-network", ghost.ghost_prototype.localised_name, math.floor(ghost.position.x), math.floor(ghost.position.y)})
			return
		end


		-- Check if current quality is available in logistic network
		if IsQualityAvailable(ghost, ghost.quality) then 
			ghost.force.print({"message.found-same-quality", ghost.ghost_prototype.localised_name, ghost.quality.localised_name})
			return 
		end
		
		-- Find next lowest available quality
		local lowerQuality = GetLowerAvailableQuality(ghost, ghost.quality)
		
		if lowerQuality and lowerQuality.name ~= ghost.quality.name then
			ghost.force.print({"message.downgraded-quality", ghost.ghost_prototype.localised_name, ghost.quality.localised_name, lowerQuality.localised_name})
			ReplaceGhost(ghost, lowerQuality.name)
		else
			-- No lower quality found. Check for fallback
			if settings.global["Ghost-Fallback-Normal"].value and ghost.quality.name ~= "normal" then
				ghost.force.print({"message.fallback-to-normal", ghost.ghost_prototype.localised_name})
				ReplaceGhost(ghost, "normal")
			else
				ghost.force.print({"message.no-lower-quality-found", ghost.ghost_prototype.localised_name})
			end
		end
	end
end

function IsQualityAvailable(ghost, quality)
	local network = ghost.surface.find_logistic_network_by_position(ghost.position, ghost.force)
	if not network then 
		-- game.print("DEBUG: No network found at " .. serpent.line(ghost.position))
		return false 
	end
	
	-- We must check the ITEM count, not the Entity Name.
	local prototype = ghost.ghost_prototype
	local items = prototype.items_to_place_this
	
	if items then
		for _, itemStack in pairs(items) do
			local count = network.get_item_count({name=itemStack.name, quality=quality.name})
			-- game.print("DEBUG: Checking " .. itemStack.name .. " (" .. quality.name .. "): " .. count)
			if count > 0 then return true end
		end
	end
	
	return false
end

function GetLowerAvailableQuality(ghost, startQuality)
	local currentLevel = startQuality.level
	local bestQuality = nil
	local bestLevel = -1
	
	-- Iterate all qualities to find candidates
	for name, q in pairs(prototypes.quality) do
		if not q.hidden and q.level < currentLevel then
			-- We want the highest possible level that is lower than current
			if q.level > bestLevel then
				-- Check availability
				if IsQualityAvailable(ghost, q) then
					bestQuality = q
					bestLevel = q.level
				end
			end
		end
	end
	
	-- game.print("DEBUG: Best lower quality found: " .. (bestQuality and bestQuality.name or "None"))
	return bestQuality
end

function ReplaceGhost(ghost, newQualityName)
	local surface = ghost.surface
	local position = ghost.position
	local force = ghost.force
	local direction = ghost.direction
	local inner_name = ghost.ghost_name
	
	-- Preserve other ghost properties if possible?
	-- For now, simple replacement
	
	ghost.destroy()
	surface.create_entity{
		name = "entity-ghost",
		inner_name = inner_name,
		position = position,
		force = force,
		direction = direction,
		quality = newQualityName,
		raise_built = true
	}
end

script.on_event(defines.events.on_post_entity_died, OnPostEntityDied)
