modifier_mind_control = class({})
 
--Should be invisible
function modifier_mind_control:IsHidden()
    return true
end
 
--Should be removed when duration expires
function modifier_mind_control:DestroyOnExpire()
    return true
end
 
--Should be removed when unit dies
function modifier_mind_control:RemoveOnDeath()
    return true
end
 
--Not really sure if default is true or false but just in case
--Should not be purgable
function modifier_mind_control:IsPurgable()
    return false
end 
 
function modifier_mind_control:OnCreated(event)
    if IsServer() then
        local caster = self:GetCaster()
        local host = self:GetParent()
        self.originalOwnerID = host:GetPlayerOwnerID()
        for playerid = 0, DOTA_MAX_PLAYERS do
            if PlayerResource:IsValidPlayer(playerid) and not PlayerResource:IsFakeClient(playerid) and PlayerResource:GetTeam(playerid) == self:GetCaster():GetTeam() then
                self.realplayerID = playerid
                break
            end
        end
       
        -- Hide the courier
        self.hidemod1 = caster:AddNewModifier(nil, nil, "modifier_tutorial_hide_npc", {})
        self.hidemod2 = caster:AddNewModifier(nil, nil, "modifier_invulnerable", {})
		self.hidemod3 = caster:AddNewModifier(nil, nil, "modifier_stunned", { duration = self:GetRemainingTime() + 0.1 })
        
		-- Switch control to hero from courier
		PlayerResource:SetDefaultSelectionEntity(self.realplayerID, host)
        PlayerResource:ResetSelection(self.realplayerID)
        host:SetControllableByPlayer(self.realplayerID, true)
        host.isMindControlled = true
       
        -- Play graphical effect and sound for going inside the host
        local effect_in = ParticleManager:CreateParticle("particles/units/heroes/hero_bane/bane_sap.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, host)
        ParticleManager:SetParticleControlEnt(effect_in, 1, caster, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
        ParticleManager:SetParticleControlEnt(effect_in, 0, host, PATTACH_ABSORIGIN_FOLLOW, "attach_hitloc", host:GetAbsOrigin(), true)
        ParticleManager:ReleaseParticleIndex(effect_in)
        EmitSoundOn( "LootGreevil.Hum", caster )
        EmitSoundOn( "Hero_Oracle.PreAttack", caster )
		
		-- set up logic for time remaining particles and sounds
		self:StartIntervalThink(1)
		self.phase = 4
    end
end
 
function modifier_mind_control:OnRemoved(event)
    if IsServer() then
        local caster = self:GetCaster()
        local host = self:GetParent()
		-- Switch control to courier from hero
        PlayerResource:SetDefaultSelectionEntity(self.realplayerID, caster)
        PlayerResource:ResetSelection(self.realplayerID)
        host:SetControllableByPlayer(self.originalOwnerID, true)
        host.isMindControlled = false
        --Show the courier
		caster:Interrupt()
        if self.hidemod1 then
            self.hidemod1:Destroy()
        end
        if self.hidemod2 then
            self.hidemod2:Destroy()
        end
		if self.hidemod3 then
            self.hidemod3:Destroy()
        end
        FindClearSpaceForUnit(caster, host:GetAbsOrigin(), true)
		caster:AddNewModifier(nil, nil, "modifier_silence", { duration = 0.1 })
        -- effect and sound for emerging
        local effect_out = ParticleManager:CreateParticle("particles/econ/items/pets/pet_frondillo/pet_spawn_frondillo.vpcf", PATTACH_WORLDORIGIN, caster)
        ParticleManager:SetParticleControl(effect_out,0,host:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(effect_out)
        EmitSoundOn( "Greevil.Attack", caster )
		if self.effect_counter then 
			ParticleManager:DestroyParticle(self.effect_counter, true) 
			ParticleManager:ReleaseParticleIndex(self.effect_counter)
		end
    end
end

function modifier_mind_control:OnIntervalThink()
	if IsServer() then
		if self:GetRemainingTime() < self.phase then
			local host = self:GetParent()
			local effect_during = ParticleManager:CreateParticleForTeam("particles/econ/items/pets/pet_frondillo/pet_flee_vapor_frondillo.vpcf", PATTACH_WORLDORIGIN, host, host:GetTeamNumber())
			ParticleManager:SetParticleControl(effect_during,0,host:GetAbsOrigin())
			ParticleManager:ReleaseParticleIndex(effect_during)
			if self.effect_counter then 
				ParticleManager:DestroyParticle(self.effect_counter, false) 
			end
			self.effect_counter = ParticleManager:CreateParticleForTeam("particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_stack_number.vpcf", PATTACH_OVERHEAD_FOLLOW, host, host:GetTeamNumber())
			ParticleManager:SetParticleControl(self.effect_counter,0,host:GetAbsOrigin())
			ParticleManager:SetParticleControl(self.effect_counter, 1, Vector(0,self.phase,0))
			EmitSoundOnLocationForAllies(host:GetAbsOrigin(), "greevil_courier.grunt_big", host)
			EmitSoundOnLocationForAllies(host:GetAbsOrigin(), "Tutorial.TaskProgress", host)
			self.phase = self.phase - 1
		end
	end
end

