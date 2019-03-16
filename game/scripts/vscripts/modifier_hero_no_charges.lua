modifier_hero_no_charges = class({})

function modifier_hero_no_charges:GetTexture()
    return "courier_burst"
end

function modifier_hero_no_charges:IsDebuff()
	return true
end

function modifier_hero_no_charges:DestroyOnExpire()
    return true
end

function modifier_hero_no_charges:RemoveOnDeath()
    return false
end

function modifier_hero_no_charges:IsPurgable()
    return false
end 