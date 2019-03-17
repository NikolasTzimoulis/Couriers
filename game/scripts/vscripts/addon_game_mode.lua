require("libraries/timers")
require('libraries/selection')

if CCouriers == nil then
	CCouriers = class({})
end

function Precache( context )
	PrecacheResource("particle", "particles/units/heroes/hero_bane/bane_sap.vpcf", context )
	PrecacheResource("particle", "particles/econ/items/pets/pet_frondillo/pet_spawn_frondillo.vpcf", context )
	PrecacheResource("particle", "particles/econ/items/pets/pet_frondillo/pet_flee_vapor_frondillo.vpcf", context )
	PrecacheResource("particle", "particles/units/heroes/hero_monkey_king/monkey_king_quad_tap_stack_number.vpcf", context )
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_greevils.vsndevts", context)	
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)	
	PrecacheResource("soundfile", "soundevents/game_sounds_ui_imported.vsndevts", context)	
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CCouriers()
	GameRules.AddonTemplate:InitGameMode()
end

function CCouriers:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:GetGameModeEntity():SetCustomGameForceHero("npc_dota_hero_wisp")
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 1 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 1 )
	GameRules:GetGameModeEntity():SetRecommendedItemsDisabled(true)
	GameRules:GetGameModeEntity():SetUseDefaultDOTARuneSpawnLogic(true)
	GameRules:GetGameModeEntity():SetTowerBackdoorProtectionEnabled(true)
	GameRules:SetCustomGameSetupAutoLaunchDelay(0)
	GameRules:SetCustomGameSetupRemainingTime(0)
	GameRules:SetStartingGold(0)
	GameRules:SetGoldPerTick(0)
	self.startGold = 3000
	self.PassiveGoldPerSecond = 10
	self.courierList = {}
	self.fakeHero = {}
	self.oneTimeSetup = 0
	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(CCouriers,"FilterModifyGold"),self)
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter(Dynamic_Wrap(CCouriers, "BountyRunePickupFilter"), self)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CCouriers,"FilterExecuteOrder"),self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap( CCouriers, "OnNPCSpawned" ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CCouriers, 'OnEntityKilled' ), self )				
end

-- Evaluate the state of the game
function CCouriers:OnThink()
	if 	self.oneTimeSetup == 0 then	
		self.oneTimeSetup = 1
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME and self.oneTimeSetup == 1 and self:PlayersFullyLoaded() then
		self.oneTimeSetup = 2
		self:StartingGold()
		self:SpawnBots()
		Timers:CreateTimer(function()			
			self:DoOncePerSecond()			
			return 1
		end)
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then

	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function CCouriers:DoOncePerSecond()
	local heroes = HeroList:GetAllHeroes()
   	for _,hero in pairs(heroes) do 
   		if IsValidEntity(hero) and hero:IsRealHero() then 
			-- appropriate items in each hero's possession
			for itemSlot = 0, 11, 1 do 
				local item = hero:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) and item:GetPurchaser() ~= hero then 
					--print(item:GetName().." "..item:GetOwnerEntity():GetName())
					local charges = item:GetCurrentCharges()
					local itemname = item:GetName()
					item:RemoveSelf()
					local newItem = hero:AddItem(CreateItem(itemname, hero, hero))
					newItem:SetCurrentCharges(charges)
				end
			end	
   		end
		self:CheckPassGold(hero)
	end 
	
	-- courier items
	for i, courier in pairs(self.courierList) do
		if IsValidEntity(courier) then 
			local fhero = self.fakeHero[courier:GetTeamNumber()]
			for itemSlot = 0, 11, 1 do 
				local item = courier:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) then
					-- reset ownership of tp scrolls 
					if item:GetName() == "item_tpscroll" then
						item:SetPurchaser(nil)
					-- appropriate other items on courier
					elseif item:GetPurchaser() ~= fhero then
						local charges = item:GetCurrentCharges()
						local itemname = item:GetName()
						item:RemoveSelf()
						local newItem = courier:AddItem(CreateItem(itemname, fhero, fhero))
						newItem:SetCurrentCharges(charges)
					end
				end
			end	
   		end
	end
	-- give passive gold to each team's leader
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		if self.fakeHero[DOTA_TEAM_GOODGUYS] then 
			PlayerResource:ModifyGold(self.fakeHero[DOTA_TEAM_GOODGUYS]:GetPlayerOwnerID(), self.PassiveGoldPerSecond, false,  DOTA_ModifyGold_Unspecified)
		end
		if self.fakeHero[DOTA_TEAM_BADGUYS] then 
			PlayerResource:ModifyGold(self.fakeHero[DOTA_TEAM_BADGUYS]:GetPlayerOwnerID(), self.PassiveGoldPerSecond, false,  DOTA_ModifyGold_Unspecified)
		end
	end
end

function CCouriers:OnNPCSpawned( event )
	local spawnedUnit = EntIndexToHScript( event.entindex )
	-- spawn the courier and hide the fakehero
	if spawnedUnit:IsRealHero() and PlayerResource:GetNumCouriersForTeam(spawnedUnit:GetTeamNumber()) == 0 and not PlayerResource:IsFakeClient(spawnedUnit:GetPlayerOwnerID()) then
		self.fakeHero[spawnedUnit:GetTeamNumber()] = spawnedUnit
		Timers:CreateTimer(1, function()
			local courier_item = CreateItem("item_courier", spawnedUnit, spawnedUnit)
			spawnedUnit:AddItem(courier_item)
			spawnedUnit:CastAbilityNoTarget(courier_item, 0)
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_tutorial_hide_npc", {duration = -1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = -1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rooted", {duration = -1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_disarmed", {duration = -1})
		end)
	end
	--when the courier/leader spawns:
	if spawnedUnit:IsCourier() then
		--make it briefly invulnerable
		Timers:CreateTimer(0.01, function() 
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = 1})
		end)
		--if this is the first time this courier has spawned:
		if spawnedUnit:FindAbilityByName("mind_control") == nil and self.fakeHero[spawnedUnit:GetTeamNumber()] then
			table.insert(self.courierList, spawnedUnit)
			local playerID = self.fakeHero[spawnedUnit:GetTeamNumber()]:GetPlayerOwnerID()
			PlayerResource:SetDefaultSelectionEntity(playerID, spawnedUnit)
			PlayerResource:ResetSelection(playerID)
			local abil = spawnedUnit:AddAbility("mind_control")
			abil:SetLevel(abil:GetMaxLevel())
			local abil = spawnedUnit:AddAbility("courier_burst")
			abil:SetLevel(abil:GetMaxLevel())
			spawnedUnit:SwapAbilities("courier_transfer_items", "mind_control", false, true)
			spawnedUnit:SwapAbilities("courier_return_stash_items", "courier_burst", false, true)		
			spawnedUnit:FindAbilityByName("courier_take_stash_and_transfer_items"):SetActivated(false)
			spawnedUnit:FindAbilityByName("courier_transfer_items_to_other_player"):SetActivated(false)
		end
	end
end

function CCouriers:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript( event.entindex_killed )
	-- courier instant respawn
	if killedUnit:IsCourier() then
		killedUnit:RespawnUnit()
	end
	local heroes = HeroList:GetAllHeroes()
	for _,hero in pairs(heroes) do 
		self:CheckPassGold(hero)
	end
end

function CCouriers:SpawnBots() 
	local botHeroes = {'npc_dota_hero_bane', 'npc_dota_hero_bounty_hunter', 'npc_dota_hero_bloodseeker', 'npc_dota_hero_bristleback', 'npc_dota_hero_chaos_knight', 'npc_dota_hero_crystal_maiden', 'npc_dota_hero_dazzle', 'npc_dota_hero_death_prophet', 'npc_dota_hero_drow_ranger', 'npc_dota_hero_earthshaker', 'npc_dota_hero_jakiro', 'npc_dota_hero_kunkka', 'npc_dota_hero_lina', 'npc_dota_hero_lion', 'npc_dota_hero_luna', 'npc_dota_hero_necrolyte', 'npc_dota_hero_omniknight', 'npc_dota_hero_oracle', 'npc_dota_hero_phantom_assassin', 'npc_dota_hero_pudge', 'npc_dota_hero_sand_king', 'npc_dota_hero_nevermore', 'npc_dota_hero_skywrath_mage', 'npc_dota_hero_sniper', 'npc_dota_hero_sven', 'npc_dota_hero_tiny', 'npc_dota_hero_viper', 'npc_dota_hero_warlock', 'npc_dota_hero_windrunner', 'npc_dota_hero_zuus'}
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 6 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 6 )
	Tutorial:StartTutorialMode()	
	local heroNumber = RandomInt(1, #botHeroes)	
	Tutorial:AddBot( botHeroes[heroNumber], "top", "hard", true )
	table.remove(botHeroes, heroNumber)
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "top", "hard", false )
	table.remove(botHeroes, heroNumber)	
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "top", "hard", true )
	table.remove(botHeroes, heroNumber)
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "top", "hard", false )
	table.remove(botHeroes, heroNumber)	
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "mid", "hard", true )
	table.remove(botHeroes, heroNumber)
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "mid", "hard", false )
	table.remove(botHeroes, heroNumber)	
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "bot", "hard", true )
	table.remove(botHeroes, heroNumber)
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "bot", "hard", false )
	table.remove(botHeroes, heroNumber)	
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "bot", "hard", true )
	table.remove(botHeroes, heroNumber)	
	heroNumber = RandomInt(1, #botHeroes)
	Tutorial:AddBot( botHeroes[heroNumber], "bot", "hard", false )
	GameRules:GetGameModeEntity():SetBotThinkingEnabled(true)
end

function CCouriers:FilterModifyGold(event)
	local gold = event.gold
    local playerID = event.player_id_const
    local reason = event.reason_const
	if self.fakeHero[PlayerResource:GetTeam(playerID)] and playerID ~= self.fakeHero[PlayerResource:GetTeam(playerID)]:GetPlayerOwnerID() then
		local recepient = self.fakeHero[PlayerResource:GetTeam(playerID)]:GetPlayerOwnerID()
		PlayerResource:ModifyGold(recepient, gold, false, DOTA_ModifyGold_Unspecified)
		--print(gold.."("..reason..") from "..PlayerResource:GetPlayerName(playerID).." to "..PlayerResource:GetPlayerName(recepient))
		return false		
	end
	return true
end

function CCouriers:BountyRunePickupFilter(event)
	if self.fakeHero[PlayerResource:GetTeam(event.player_id_const)] then
		local recepient = self.fakeHero[PlayerResource:GetTeam(event.player_id_const)]:GetPlayerOwnerID()
		PlayerResource:ModifyGold(recepient, event.gold_bounty, false, DOTA_ModifyGold_Unspecified)
		event.gold_bounty = 0
	end
	return true
end

function CCouriers:StartingGold()
	if self.fakeHero[DOTA_TEAM_GOODGUYS] then 
		PlayerResource:ModifyGold(self.fakeHero[DOTA_TEAM_GOODGUYS]:GetPlayerOwnerID(), self.startGold, false,  DOTA_ModifyGold_Unspecified ) 
	end
	if self.fakeHero[DOTA_TEAM_BADGUYS] then 
		PlayerResource:ModifyGold(self.fakeHero[DOTA_TEAM_BADGUYS]:GetPlayerOwnerID(), self.startGold, false,  DOTA_ModifyGold_Unspecified )	
	end
end


function CCouriers:PlayersFullyLoaded()
	if PlayerResource:GetPlayerCount() == 1 then
		return self.fakeHero[DOTA_TEAM_GOODGUYS] or self.fakeHero[DOTA_TEAM_BADGUYS]
	elseif PlayerResource:GetPlayerCount() == 2 then
		return self.fakeHero[DOTA_TEAM_GOODGUYS] and self.fakeHero[DOTA_TEAM_BADGUYS]
	else
		print("This should literally never happen")
		return false
	end
end

function CCouriers:FilterExecuteOrder(event)
	-- block orders from mind-controlled bots
	if event.issuer_player_id_const == -1 then
		for n,unit_index in pairs(event.units) do
			local unit = EntIndexToHScript(unit_index)	
			if unit.isMindControlled ~= nil and unit.isMindControlled then	
				return false
			end
		end
	end
	
	-- refuse to buy a courier
	if event.order_type == DOTA_UNIT_ORDER_PURCHASE_ITEM and event.entindex_ability == 45 then
		EmitSoundOn("General.InvalidTarget_Invulnerable", PlayerResource:GetPlayer(event.issuer_player_id_const))
		return false
	end
	
	-- use abilities & items when pinged
	if event.order_type == DOTA_UNIT_ORDER_PING_ABILITY then
		local ability = EntIndexToHScript(event.entindex_ability)
		local pingedTeam = ability:GetOwner():GetTeamNumber()
		if PlayerResource:GetTeam(event.issuer_player_id_const) == pingedTeam and ability:IsFullyCastable() and not ability:GetOwner():IsCourier() then
			Timers:CreateTimer(1, function()
				local behaviour = ability:GetBehavior()
				local targetType = ability:GetAbilityTargetType()			
				if behaviour % DOTA_ABILITY_BEHAVIOR_UNIT_TARGET > 0 and behaviour % DOTA_ABILITY_BEHAVIOR_POINT > 0 then
					ability:GetOwner():CastAbilityNoTarget(ability, -1)
				else
					local targets = FindUnitsInRadius(pingedTeam, ability:GetOwner():GetAbsOrigin(), nil, 1000, ability:GetAbilityTargetTeam(), targetType, DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE, 0, false) 
					if #targets > 0 then
						if behaviour % DOTA_ABILITY_BEHAVIOR_UNIT_TARGET == 0 then
							ability:GetOwner():CastAbilityOnTarget(targets[RandomInt(1, #targets )], ability, -1)
						else
							ability:GetOwner():CastAbilityOnPosition(targets[RandomInt(1, #targets )]:GetAbsOrigin(), ability, -1)
						end
					end
				end
			end)
		end
	end
	
	return true
end

function CCouriers:CheckPassGold(hero)
	-- pass any remaining gold to the leader
	if IsValidEntity(hero) and hero:IsRealHero() and self.fakeHero[hero:GetTeamNumber()] and hero ~= self.fakeHero[hero:GetTeamNumber()] then
		local recepient = self.fakeHero[hero:GetTeamNumber()]:GetPlayerOwnerID()
		PlayerResource:ModifyGold(recepient, hero:GetGold(), false, DOTA_ModifyGold_Unspecified)
		hero:SetGold(0, false)
		hero:SetGold(0, true)
	end
end

function PrintTable(aTable)
	for k, v in pairs( aTable ) do
        print(k .. " " .. tostring(v).." ("..type(v)..")" )
    end
end
