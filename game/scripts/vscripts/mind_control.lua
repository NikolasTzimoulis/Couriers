mind_control = class({})
LinkLuaModifier("modifier_mind_control", "modifier_mind_control.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_courier_level", "modifier_courier_level.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_hero_exhausted", "modifier_hero_exhausted.lua", LUA_MODIFIER_MOTION_NONE)

function mind_control:OnSpellStart()
	if IsServer() then
		local caster = self:GetCaster()
		local host = self:GetCursorTarget()
		--give the mind control modifier which is what is actually doing all the mind control logic
		host:AddNewModifier(caster, nil, "modifier_mind_control", {duration = self:GetDuration()})
		--level up
		local timeNow = GameRules:GetDOTATime(true, true)
		if not host:HasModifier("modifier_hero_exhausted") then
			local level = caster:GetModifierStackCount("modifier_courier_level", caster) 
			caster:SetModifierStackCount("modifier_courier_level", caster, level+1)
			caster:FindAbilityByName("courier_burst"):EndCooldown()
			caster:FindAbilityByName("courier_shield"):EndCooldown()
			caster:SetBaseMaxHealth( caster:GetBaseMaxHealth() + self:GetSpecialValueFor("hp_per_level") )
			caster:SetBaseMoveSpeed( caster:GetBaseMoveSpeed() + self:GetSpecialValueFor("speed_per_level") )
			if level+1 == 5 then
				--caster:UpgradeToFlyingCourier()
			elseif level+1 == 10 then
				local abil = caster:FindAbilityByName("courier_burst")
				abil:SetActivated(true)
				abil:SetLevel(abil:GetMaxLevel())
			elseif level+1 == 20 then
				local abil = caster:FindAbilityByName("courier_shield")
				abil:SetActivated(true)
				abil:SetLevel(abil:GetMaxLevel())
			end
			host:AddNewModifier(caster, nil, "modifier_hero_exhausted", {duration = self:GetSpecialValueFor("recharge_cooldown")})
		end
	end
end

function mind_control:OnUpgrade()
	if IsServer() then
		local caster = self:GetCaster()
		if not caster:HasModifier("modifier_courier_level") then
			caster:AddNewModifier(caster, nil, "modifier_courier_level", {duration = -1})
			caster:SetModifierStackCount("modifier_courier_level", caster, 1)
		end
	end
end

