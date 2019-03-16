modifier_speed_burst_charges = class({})

function modifier_speed_burst_charges:GetTexture()
    return "courier_burst"
end

function modifier_speed_burst_charges:RemoveOnDeath()
    return false
end

function modifier_speed_burst_charges:IsPurgable()
    return false
end 

function modifier_speed_burst_charges:OnCreated( kv )
    if IsServer() then
        self:SetStackCount(0)
    end
end

function modifier_speed_burst_charges:DeclareFunctions()
  local funcs = {MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,}
  return funcs
end

--use charges to remove the cooldown if you have any
function modifier_speed_burst_charges:OnAbilityFullyCast(keys)
	if IsServer() then
		local abil = keys.ability
		local caster = self:GetCaster()
		if keys.unit == caster and abil:GetAbilityName() == "courier_burst" then
			if self:GetStackCount() > 0 then
				self:DecrementStackCount()
				abil:EndCooldown()
			end
		end	
	end
end

