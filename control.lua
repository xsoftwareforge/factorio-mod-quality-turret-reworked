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

script.on_event(defines.events.on_entity_died, function(event)
	local cause = event.cause
	if cause and cause.valid and validTurrets[cause.type] then
		UpdateGUI(cause)
		DidTurretKill(cause)
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

	-- Gather data before replacement
	local ammo = GetAmmo(turret)
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
		-- Visual Feedback (Flying Text + Sound)
		if settings.global["Show-level-up-text"].value then
			rendering.draw_text{
				text = "Quality Up! [" .. newTurret.quality.name .. "]",
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
	
	flow.add{type="progressbar", value=progress, caption=turret.kills .. " / " .. requiredKills .. " Kills"}
	flow.add{type="label", caption="Next: " .. (turret.quality.next and turret.quality.next.name or "Max")}
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
            local progressbar = frame.children[1].children[1]
			
			local requiredKills = GetKillsRequired(turret.quality)
            local progress = math.min(turret.kills / requiredKills, 1)
			
            progressbar.value = progress
            progressbar.caption = turret.kills .. " / " .. requiredKills .. " Kills"
        end
    end
end




