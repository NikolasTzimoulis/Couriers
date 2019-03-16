mind_control = class({})
LinkLuaModifier("modifier_mind_control", "modifier_mind_control.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_speed_burst_charges", "modifier_speed_burst_charges.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_hero_no_charges", "modifier_hero_no_charges.lua", LUA_MODIFIER_MOTION_NONE)

function mind_control:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local host = self:GetCursorTarget()
		--give the mind control modifier which is what is actually doing all the mind control logic
		host:AddNewModifier(caster, nil, "modifier_mind_control", {duration = self:GetDuration()})
		--recharge burst speed 
		local rechargeCooldown = self:GetSpecialValueFor("recharge_cooldown")
		local timeNow = GameRules:GetDOTATime(true, true)
		if not host:HasModifier("modifier_hero_no_charges") then
			local abil = caster:FindAbilityByName("courier_burst")
			if abil:IsCooldownReady() then
				local stackCount = caster:GetModifierStackCount("modifier_speed_burst_charges", caster) 
				caster:SetModifierStackCount("modifier_speed_burst_charges", caster, stackCount+1)
			else
				abil:EndCooldown()
			end
			host:AddNewModifier(caster, nil, "modifier_hero_no_charges", {duration = rechargeCooldown})
		end
	end
end

function mind_control:OnUpgrade()
	if IsServer() then
		local caster = self:GetCaster()
		caster:AddNewModifier(caster, nil, "modifier_speed_burst_charges", {duration = -1})
	end
end

