mind_control = class({})
LinkLuaModifier("modifier_mind_control", "modifier_mind_control.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_hero_exhausted", "modifier_hero_exhausted.lua", LUA_MODIFIER_MOTION_NONE)

function mind_control:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local host = self:GetCursorTarget()
		--give the mind control modifier which is what is actually doing all the mind control logic
		host:AddNewModifier(caster, nil, "modifier_mind_control", {duration = self:GetDuration()})
		--level up
		if not host:HasModifier("modifier_hero_exhausted") then
			GameRules.AddonTemplate:LevelUp(caster:GetTeamNumber())
			host:AddNewModifier(caster, nil, "modifier_hero_exhausted", {duration = self:GetSpecialValueFor("recharge_cooldown")})
		end
	end
end

