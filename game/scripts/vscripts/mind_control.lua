mind_control = class({})

function mind_control:OnSpellStart()
    local target = self:GetCursorTarget()
    local caster = self:GetCaster()
	local duration = self:GetDuration()
	local originalOwner  = target:GetOwner()
	local originalOwnerID  = target:GetPlayerOwnerID()
	local realplayerID = PlayerResource:GetNthPlayerIDOnTeam(caster:GetTeamNumber(), 1)
	

	
    -- Hide the hero 
	caster:AddNewModifier(spawnedUnit, nil, "modifier_tutorial_hide_npc", {duration = duration})
	caster:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = duration})
	PlayerResource:SetOverrideSelectionEntity(realplayerID, target)	
	target:SetControllableByPlayer(realplayerID, true)	
	target.isMindControlled = true
	--target:SetOwner(PlayerResource:GetPlayer(realplayerID))
	--target:SetPlayerID(realplayerID)
	
	-- Reset everything when duration ends
	Timers:CreateTimer(duration, function()

		PlayerResource:SetOverrideSelectionEntity(realplayerID, caster)
		target:SetControllableByPlayer(originalOwnerID, true)	
		--target:SetOwner(originalOwner)
		--target:SetPlayerID(originalOwnerID)
		target.isMindControlled = false
		caster:SetAbsOrigin(target:GetAbsOrigin())
	end)
end

