require("libraries/timers")
require('libraries/selection')

if CCouriers == nil then
	CCouriers = class({})
end

function Precache( context )
	PrecacheResource( "particle", "particles/units/heroes/hero_bane/bane_sap.vpcf", context )
	PrecacheResource( "particle", "particles/econ/items/pets/pet_frondillo/pet_spawn_dirt_frondillo.vpcf", context )
	PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_greevils.vsndevts", context)	
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)	
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CCouriers()
	GameRules.AddonTemplate:InitGameMode()
end

function CCouriers:InitGameMode()
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:GetGameModeEntity():SetCustomGameForceHero("npc_dota_hero_wisp")
	GameRules:GetGameModeEntity():SetRecommendedItemsDisabled(true)
	GameRules:SetCustomGameSetupAutoLaunchDelay(0)
	GameRules:SetCustomGameSetupRemainingTime(0)
	GameRules:SetStartingGold(0)
	GameRules:SetGoldPerTick(0)
	GameRules:GetGameModeEntity():SetUseDefaultDOTARuneSpawnLogic(true)
	self.startGold = 3000
	self.PassiveGoldPerSecond = 10
	self.onetimethings = false
	self.courierList = {}
	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(CCouriers,"FilterModifyGold"),self)
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter(Dynamic_Wrap(CCouriers, "BountyRunePickupFilter"), self)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CCouriers,"FilterExecuteOrder"),self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap( CCouriers, "OnNPCSpawned" ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CCouriers, 'OnEntityKilled' ), self )
end

-- Evaluate the state of the game
function CCouriers:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		if self.onetimethings == false then
			self.onetimethings = true
			self:SpawnBots()
			self:StartingGold()
			Timers:CreateTimer(function()			
				self:DoOncePerSecond()			
				return 1
			end)
		end
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end

function CCouriers:DoOncePerSecond()
	-- appropriate items in each hero's possession
	local heroes = HeroList:GetAllHeroes()
   	for _,hero in pairs(heroes) do 
   		if IsValidEntity(hero) and hero:IsRealHero() then 
			for itemSlot = 0, 11, 1 do 
				local item = hero:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) and item:GetPurchaser() ~= hero then 
					--print(item:GetName().." "..item:GetOwnerEntity():GetName())
					local itemname = item:GetName()
					item:RemoveSelf()
					hero:AddItem(CreateItem(itemname, hero, hero))
				end
			end	
   		end
	end 
	-- reset ownership of items in courier 
	for i, courier in pairs(self.courierList) do
		if IsValidEntity(courier) then 
			for itemSlot = 0, 11, 1 do 
				local item = courier:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) then 
					item:SetOwner(nil)
				end
			end	
   		end
	end
	-- give passive gold to each team's leader
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		PlayerResource:ModifyGold(PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_GOODGUYS, 1), self.PassiveGoldPerSecond, false, DOTA_ModifyGold_CheatCommand)
		PlayerResource:ModifyGold(PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_BADGUYS, 1), self.PassiveGoldPerSecond, false, DOTA_ModifyGold_CheatCommand)
	end
end

function CCouriers:OnNPCSpawned( event )
	local spawnedUnit = EntIndexToHScript( event.entindex )
	if spawnedUnit:IsRealHero() then
		Timers:CreateTimer(1, function()
			if PlayerResource:GetNumCouriersForTeam(spawnedUnit:GetTeamNumber()) == 0 then
				local courier_item = CreateItem("item_courier", spawnedUnit, spawnedUnit)
				spawnedUnit:AddItem(courier_item)
				spawnedUnit:CastAbilityNoTarget(courier_item, 0)
				if not PlayerResource:IsFakeClient(spawnedUnit:GetPlayerOwnerID()) then
					spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_tutorial_hide_npc", {duration = -1})
					spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = -1})
					spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rooted", {duration = -1})
				end
			end
		end)
	end
	--when the courier/leader spawns:
	if string.find(spawnedUnit:GetUnitName(), "courier") then
		Timers:CreateTimer(1, function() spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rune_arcane", {duration = -1}) end)
		--if this is the first time this courier has spawned:
		if spawnedUnit:FindAbilityByName("mind_control") == nil then
			table.insert(self.courierList, spawnedUnit)
			local playerID = PlayerResource:GetNthPlayerIDOnTeam(spawnedUnit:GetTeamNumber(), 1)			
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
	if string.find(killedUnit:GetUnitName(), "courier") then
		killedUnit:RespawnUnit()
	end
end

function CCouriers:SpawnBots()
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 6 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 6 )
	for i=1, 5 do
		Tutorial:AddBot("npc_dota_hero_wisp", "", "", true)
		Tutorial:AddBot("npc_dota_hero_wisp", "", "", false)
    end
	GameRules:GetGameModeEntity():SetBotThinkingEnabled(true)
	Tutorial:StartTutorialMode()
	local heroes = HeroList:GetAllHeroes()
   	for _,hero in pairs(heroes) do 
   		if IsValidEntity(hero) and hero:IsRealHero() then 
			hero:SetBotDifficulty(3)
		end
	end
end

function CCouriers:FilterModifyGold(event)
	local gold = event.gold
    local playerID = event.player_id_const
    local reason = event.reason_const
	if reason ~= DOTA_ModifyGold_CheatCommand then
		local recepient = PlayerResource:GetNthPlayerIDOnTeam(PlayerResource:GetTeam(playerID), 1)
		PlayerResource:ModifyGold(recepient, gold, false, DOTA_ModifyGold_CheatCommand)
		--print(gold.."("..reason..") from "..PlayerResource:GetPlayerName(playerID).." to "..PlayerResource:GetPlayerName(recepient))
		return false		
	end
	return true
end

function CCouriers:BountyRunePickupFilter(event)
	local recepient = PlayerResource:GetNthPlayerIDOnTeam(PlayerResource:GetTeam(event.player_id_const), 1)
	PlayerResource:ModifyGold(recepient, event.gold_bounty, false, DOTA_ModifyGold_CheatCommand)
	event.gold_bounty = 0
	return true
end

function CCouriers:StartingGold()
	PlayerResource:ModifyGold(PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_GOODGUYS, 1), self.startGold, false,  DOTA_ModifyGold_CheatCommand)
	PlayerResource:ModifyGold(PlayerResource:GetNthPlayerIDOnTeam(DOTA_TEAM_BADGUYS, 1), self.startGold, false,  DOTA_ModifyGold_CheatCommand)	
end


function CCouriers:FilterExecuteOrder(event)
	if event.issuer_player_id_const == -1 then
		for n,unit_index in pairs(event.units) do
			local unit = EntIndexToHScript(unit_index)	
			if unit.isMindControlled ~= nil and unit.isMindControlled then	
				return false
			end
		end
	end
	return true
end

function PrintEventData(event)
	for k, v in pairs( event ) do
        print(k .. " " .. tostring(v).." ("..type(v)..")" )
    end
end

