modifier_hero_exhausted = class({})

function modifier_hero_exhausted:GetTexture()
    return ""
end

function modifier_hero_exhausted:IsDebuff()
	return true
end

function modifier_hero_exhausted:DestroyOnExpire()
    return true
end

function modifier_hero_exhausted:RemoveOnDeath()
    return false
end

function modifier_hero_exhausted:IsPurgable()
    return false
end 