modifier_courier_level = class({})

function modifier_courier_level:GetTexture()
    return "roshan_halloween_levels"
end

function modifier_courier_level:RemoveOnDeath()
    return false
end

function modifier_courier_level:IsPurgable()
    return false
end 

function modifier_courier_level:OnCreated( kv )
    if IsServer() then
        self:SetStackCount(1)
    end
end

function modifier_courier_level:DeclareFunctions()
  local funcs = {MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,}
  return funcs
end

--use charges to remove the cooldown if you have any
function modifier_courier_level:OnAbilityFullyCast(keys)
	if IsServer() then

	end
end

