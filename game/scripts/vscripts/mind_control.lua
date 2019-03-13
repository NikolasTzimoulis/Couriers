mind_control = class({})

function mind_control:OnSpellStart()
    local target = self:GetCursorTarget()
    local caster = self:GetCaster()
	local duration = self:GetDuration()
	local originalOwnerID  = target:GetPlayerOwnerID()
	local realplayerID = nil
	for playerid = 0, DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayer(playerid) and not PlayerResource:IsFakeClient(playerid) and PlayerResource:GetTeam(playerid) == caster:GetTeam() then
			realplayerID = playerid
			break
		end
	end
	
    -- Hide the hero 
	caster:AddNewModifier(spawnedUnit, nil, "modifier_tutorial_hide_npc", {duration = duration})
	caster:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = duration})
	PlayerResource:SetDefaultSelectionEntity(realplayerID, target)
	PlayerResource:ResetSelection(realplayerID)
	target:SetControllableByPlayer(realplayerID, true)	
	target.isMindControlled = true
	
	-- Play graphical effect and sound for going inside the host
	local effect_in = ParticleManager:CreateParticle("particles/units/heroes/hero_bane/bane_sap.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, target)
	ParticleManager:SetParticleControlEnt(effect_in, 1, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
	ParticleManager:SetParticleControlEnt(effect_in, 0, target, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
	ParticleManager:ReleaseParticleIndex(effect_in)
	EmitSoundOn( "LootGreevil.Hum", caster )	
	EmitSoundOn( "Hero_Oracle.PreAttack", caster )	
	
	-- Reset everything when duration ends
	Timers:CreateTimer(duration, function()
		PlayerResource:SetDefaultSelectionEntity(realplayerID, caster)
		PlayerResource:ResetSelection(realplayerID)
		target:SetControllableByPlayer(originalOwnerID, true)	
		target.isMindControlled = false
		FindClearSpaceForUnit(caster, target:GetAbsOrigin(), true)
		-- effect and sound for emerging	
		effect_out = ParticleManager:CreateParticle("particles/econ/items/pets/pet_frondillo/pet_spawn_dirt_frondillo.vpcf", PATTACH_WORLDORIGIN, caster)
		ParticleManager:SetParticleControl(effect_out,0,target:GetAbsOrigin())
		EmitSoundOn( "Greevil.Attack", caster )	
	end)	

end

