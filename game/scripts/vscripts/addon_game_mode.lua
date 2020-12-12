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
	PrecacheResource("soundfile", "soundevents/soundevents_dota_ui.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_announcer.vsndevts", context)

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
	GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)
	GameRules:SetCustomGameSetupAutoLaunchDelay(45)
	GameRules:SetCustomGameSetupRemainingTime(0)
	GameRules:SetStartingGold(0)
	GameRules:SetGoldPerTick(0)
	self.startGold = 3000
	self.PassiveGoldPerSecond = 10
	self.CourierBounty = 500
	self.heroBountyMultiplier = 0.01
	self.botGoldMultiplier = 1.0
	self.courierList = {}
	self.fakeHero = {}
	self.botHeroes = {}
	self.oneTimeSetup = 0
	self.spawnCount = 0
	self.teamsReversed = false
	self.fountainPos = {[DOTA_TEAM_GOODGUYS] = Vector(-6935, -6385, 0), [DOTA_TEAM_BADGUYS] = Vector(7010, 6345, 0)}
	self.hasEnoughCouriers = {[DOTA_TEAM_GOODGUYS] = false, [DOTA_TEAM_BADGUYS] = false}
	self.draftPicks = {[DOTA_TEAM_GOODGUYS] = {}, [DOTA_TEAM_BADGUYS] = {}}
	self.draftOptions = {[DOTA_TEAM_GOODGUYS] = true, [DOTA_TEAM_BADGUYS] = true}
	CustomNetTables:SetTableValue( "draft", "picked", self.draftPicks)
	CustomNetTables:SetTableValue( "draft", "options", self.draftOptions)
	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(CCouriers,"FilterModifyGold"),self)
	GameRules:GetGameModeEntity():SetModifyExperienceFilter(Dynamic_Wrap(CCouriers,"FilterModifyXP"),self)
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter(Dynamic_Wrap(CCouriers, "BountyRunePickupFilter"), self)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CCouriers,"FilterExecuteOrder"),self)
	ListenToGameEvent("npc_spawned", Dynamic_Wrap( CCouriers, "OnNPCSpawned" ), self )
	ListenToGameEvent("entity_killed", Dynamic_Wrap( CCouriers, 'OnEntityKilled' ), self )	
	ListenToGameEvent("entity_hurt", Dynamic_Wrap( CCouriers, 'OnEntityHurt' ), self )		
	ListenToGameEvent("dota_player_gained_level", Dynamic_Wrap( CCouriers, 'OnHeroLevelUp' ), self )		
	CustomGameEventManager:RegisterListener("draft", function(id, ...) Dynamic_Wrap(self, "DoDraft")(self, ...) end)
	CustomGameEventManager:RegisterListener("variant_option", function(id, ...) Dynamic_Wrap(self, "OnDraftOptionChanged")(self, ...) end)
	CustomGameEventManager:RegisterListener("handicap", function(id, ...) Dynamic_Wrap(self, "OnHandicapChanged")(self, ...) end)
	GameRules:GetGameModeEntity():SetCustomRadiantScore(0)
	GameRules:GetGameModeEntity():SetCustomDireScore(0)
end

-- Evaluate the state of the game
function CCouriers:OnThink()
	if GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME and self.oneTimeSetup == 0 then
		GameRules:LockCustomGameSetupTeamAssignment(true)
		self.oneTimeSetup = 1
		self:DraftingCountdown()
		Timers:CreateTimer(-GameRules:GetDOTATime(true, true)-0.5, function() 
			self:TeamReversionCheck()
		end)
	end		
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME and self.oneTimeSetup <= 1 and self:PlayersFullyLoaded() then
		Entities:FindByName(nil, "radiant_neutral_item_stash"):RemoveSelf()
		Entities:FindByName(nil, "dire_neutral_item_stash"):RemoveSelf()
		self:SpawnBots()
		if self.draftOptions[DOTA_TEAM_GOODGUYS] == "UltraLate" and self.draftOptions[DOTA_TEAM_BADGUYS] == "UltraLate" then
			self:UltraLate()
		end
		self.oneTimeSetup = 2
		self:StartingGold()
		Timers:CreateTimer(function()			
			self:DoOncePerSecond()			
			return 1
		end)
	end
	if GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		CreateHTTPRequest("GET","http://tzimoulis.eu/dota_couriers/"..tostring(PlayerResource:GetPlayerCount()-10).."/"..tostring(self.draftOptions[DOTA_TEAM_GOODGUYS]).."/"..tostring(self.draftOptions[DOTA_TEAM_BADGUYS]).."/"..tostring(math.floor(GameRules:GetDOTATime(false, false)/60))):Send(nil)		
		return nil
	end
	return 1
end

function CCouriers:DoOncePerSecond()
	local heroes = HeroList:GetAllHeroes()
   	for _,hero in pairs(heroes) do 
   		if IsValidEntity(hero) and hero:IsRealHero() then 
			-- appropriate items in each hero's possession
			for itemSlot = 0, 20 do 
				local item = hero:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) and item:GetPurchaser() ~= hero then 
					--print(item:GetName().." "..item:GetOwnerEntity():GetName())
					local charges = item:GetCurrentCharges()
					local itemname = item:GetName()
					item:RemoveSelf()
					local newItem = hero:AddItem(CreateItem(itemname, hero, hero))
					newItem:SetCurrentCharges(charges)
					hero:EjectItemFromStash(newItem)
				end
			end	
   		end
		self:CheckPassGold(hero)
	end 
	
	-- courier items
	for i, courier in pairs(self.courierList) do
		if IsValidEntity(courier) then 
			local fhero = self.fakeHero[courier:GetTeamNumber()]
			local itemCount = 0
			for itemSlot = 0, 11, 1 do 
				local item = courier:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) then
					itemCount = itemCount + 1
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
			-- swap abilities if no item is held
			if itemCount == 0 and not courier:FindAbilityByName("courier_return_to_base"):IsActivated() then
				courier:SwapAbilities("targetted_transfer_items", "courier_return_to_base", false, true)		
				courier:FindAbilityByName("courier_return_to_base"):SetActivated(true)
			elseif itemCount > 0 and courier:FindAbilityByName("courier_return_to_base"):IsActivated() then
				courier:SwapAbilities("courier_return_to_base", "targetted_transfer_items", false, true)
				courier:FindAbilityByName("courier_return_to_base"):SetActivated(false)
			end
   		end
	end
	
	-- dropped items revert to courier ownership
	for _, itemContainer in pairs(Entities:FindAllByClassname("dota_item_drop")) do
       local item = itemContainer:GetContainedItem()
	   if self.fakeHero[item:GetTeam()] then
			local fhero = self.fakeHero[item:GetTeam()]
			if item:GetPurchaser() ~= fhero then
				local charges = item:GetCurrentCharges()
				local itemname = item:GetName()
				local pos = itemContainer:GetAbsOrigin()
				item:RemoveSelf()
				itemContainer:RemoveSelf()
				local newItem = CreateItemOnPositionSync(pos, CreateItem(itemname, fhero, fhero)) 
				newItem:GetContainedItem():SetCurrentCharges(charges)
			end
		end
	end
	
	-- give passive gold to each team
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:GiveGold(self.PassiveGoldPerSecond, DOTA_TEAM_GOODGUYS, DOTA_ModifyGold_GameTick)
		self:GiveGold(self.PassiveGoldPerSecond, DOTA_TEAM_BADGUYS, DOTA_ModifyGold_GameTick)
	end
	
	-- fix scoreboard
	GameRules:GetGameModeEntity():SetCustomRadiantScore(GetTeamHeroKills(DOTA_TEAM_GOODGUYS))
	GameRules:GetGameModeEntity():SetCustomDireScore(GetTeamHeroKills(DOTA_TEAM_BADGUYS))
end

function CCouriers:OnNPCSpawned(event)
	local spawnedUnit = EntIndexToHScript( event.entindex )
	-- spawn the courier and hide the fakehero
	if spawnedUnit:IsRealHero() and PlayerResource:GetNumCouriersForTeam(spawnedUnit:GetTeamNumber()) == 0 and not PlayerResource:IsFakeClient(spawnedUnit:GetPlayerOwnerID()) then
		self.fakeHero[spawnedUnit:GetTeamNumber()] = spawnedUnit
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_tutorial_hide_npc", {duration = -1})
		Timers:CreateTimer(1, function()
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = -1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rooted", {duration = -1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_disarmed", {duration = -1})
		end)
	elseif spawnedUnit:IsRealHero() then 
	--bot hero spawn counter
		self.spawnCount = self.spawnCount + 1
	end
	
	--when the courier/leader spawns:
	if spawnedUnit:IsCourier() then
		--make it briefly invulnerable but silenced
		Timers:CreateTimer(0.01, function() 
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = 1})
			spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_silence", {duration = 1})
		end)
		--if this is the first time this courier has spawned:
		if spawnedUnit:FindAbilityByName("mind_control") == nil and self.fakeHero[spawnedUnit:GetTeamNumber()] then
			if self.hasEnoughCouriers[spawnedUnit:GetTeamNumber()] then
				Timers:CreateTimer(0.1, function() 
					spawnedUnit:RemoveSelf()
				end)
			else
				self.hasEnoughCouriers[spawnedUnit:GetTeamNumber()] = true
				table.insert(self.courierList, spawnedUnit)
				local playerID = self.fakeHero[spawnedUnit:GetTeamNumber()]:GetPlayerOwnerID()
				Timers:CreateTimer(0.01, function() 
					spawnedUnit:SetControllableByPlayer(playerID, true)
					PlayerResource:SetDefaultSelectionEntity(playerID, spawnedUnit)
					PlayerResource:ResetSelection(playerID)
				end)
				local abil = spawnedUnit:AddAbility("mind_control")
				abil:SetLevel(abil:GetMaxLevel())
				if self.draftOptions[DOTA_TEAM_GOODGUYS] == "NoMindControl" and self.draftOptions[DOTA_TEAM_BADGUYS] == "NoMindControl" then
					abil:SetActivated(false)
				end
				local abil = spawnedUnit:AddAbility("targetted_transfer_items")
				abil:SetLevel(abil:GetMaxLevel())
				local abil = spawnedUnit:AddAbility("courier_return_to_base")
				abil:SetLevel(abil:GetMaxLevel())
				abil:SetActivated(false)
				spawnedUnit:SwapAbilities("courier_transfer_items", "mind_control", false, true)
				spawnedUnit:SwapAbilities("courier_take_stash_items", "targetted_transfer_items", false, true)		
				spawnedUnit:FindAbilityByName("courier_take_stash_items"):SetActivated(false)
				spawnedUnit:FindAbilityByName("courier_return_stash_items"):SetActivated(false)
				spawnedUnit:FindAbilityByName("courier_return_stash_items"):SetHidden(true)
				spawnedUnit:FindAbilityByName("courier_transfer_items"):SetActivated(false)
				spawnedUnit:FindAbilityByName("courier_transfer_items"):SetHidden(true)
			end
		end
	end
end

function CCouriers:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript( event.entindex_killed )
	if killedUnit:IsRealHero() then
		if self.fakeHero[killedUnit:GetOpposingTeamNumber()] then
			EmitSoundOnLocationForAllies(killedUnit:GetAbsOrigin(), "General.Coins", self.fakeHero[killedUnit:GetOpposingTeamNumber()])
		end
		local heroes = HeroList:GetAllHeroes()
		for _,hero in pairs(heroes) do 
			self:CheckPassGold(hero)		
		end
		if self.draftOptions[DOTA_TEAM_GOODGUYS] == "Deathmatch" and self.draftOptions[DOTA_TEAM_BADGUYS] == "Deathmatch" then
			self:Deathmatch(killedUnit)
		end
		if self.draftOptions[DOTA_TEAM_GOODGUYS] == "BuybackDeathmatch" and self.draftOptions[DOTA_TEAM_BADGUYS] == "BuybackDeathmatch" then
			self:BuybackDeathmatch(killedUnit)
		end
	end
end

function CCouriers:OnEntityHurt(event)
	local hurtUnit = EntIndexToHScript(event.entindex_killed)
	local damage = event.damagebits
	if hurtUnit:IsCourier() then
		if damage >= hurtUnit:GetHealth() then
			Timers:CreateTimer(0.1, function() 
				hurtUnit:AddNewModifier(hurtUnit, nil, "modifier_invulnerable", {duration = 1})
				hurtUnit:AddNewModifier(hurtUnit, nil, "modifier_silence", {duration = 1})
				hurtUnit:AddNewModifier(hurtUnit, nil, "modifier_no_healthbar", {duration = 1})
			end)
			hurtUnit:SetHealth(hurtUnit:GetMaxHealth())
			EmitAnnouncerSoundForTeam("announcer_ann_custom_end_09", hurtUnit:GetTeamNumber())
			self:GiveGold(self.CourierBounty, hurtUnit:GetOpposingTeamNumber(), DOTA_ModifyGold_Unspecified)
			if self.fakeHero[hurtUnit:GetOpposingTeamNumber()] then 				
				EmitSoundOnLocationForAllies(hurtUnit:GetAbsOrigin(), "General.CoinsBig", self.fakeHero[hurtUnit:GetOpposingTeamNumber()])
			end
			return false
		end
	end
end

function CCouriers:SpawnBots() 
	self.botHeroes = {'npc_dota_hero_bane', 'npc_dota_hero_bounty_hunter', 'npc_dota_hero_bloodseeker', 'npc_dota_hero_bristleback', 'npc_dota_hero_chaos_knight', 'npc_dota_hero_crystal_maiden', 'npc_dota_hero_dazzle', 'npc_dota_hero_death_prophet', 'npc_dota_hero_drow_ranger', 'npc_dota_hero_earthshaker', 'npc_dota_hero_jakiro', 'npc_dota_hero_kunkka', 'npc_dota_hero_lina', 'npc_dota_hero_lion', 'npc_dota_hero_luna', 'npc_dota_hero_necrolyte', 'npc_dota_hero_omniknight', 'npc_dota_hero_oracle', 'npc_dota_hero_phantom_assassin', 'npc_dota_hero_pudge', 'npc_dota_hero_sand_king', 'npc_dota_hero_nevermore', 'npc_dota_hero_skywrath_mage', 'npc_dota_hero_sniper', 'npc_dota_hero_sven', 'npc_dota_hero_tiny', 'npc_dota_hero_viper', 'npc_dota_hero_warlock', 'npc_dota_hero_windrunner', 'npc_dota_hero_zuus'}
	--self.botHeroes = {'npc_dota_hero_axe', 'npc_dota_hero_dragon_knight', 'npc_dota_hero_lich', 'npc_dota_hero_razor', 'npc_dota_hero_tidehunter', 'npc_dota_hero_vengefulspirit', 'npc_dota_hero_witch_doctor', 'npc_dota_hero_skeleton_king'}
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 6 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 6 )
	Tutorial:StartTutorialMode()	
	local heroNumber = RandomInt(1, #self.botHeroes)	
	if self.draftPicks[DOTA_TEAM_GOODGUYS][1] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_GOODGUYS][1], "bot", "hard", true )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_GOODGUYS][1]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "bot", "hard", true )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_GOODGUYS][2] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_GOODGUYS][2], "top", "hard", true )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_GOODGUYS][2]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "top", "hard", true )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_GOODGUYS][3] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_GOODGUYS][3], "top", "hard", true )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_GOODGUYS][3]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "top", "hard", true )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_GOODGUYS][4] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_GOODGUYS][4], "mid", "hard", true )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_GOODGUYS][4]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "mid", "hard", true )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_GOODGUYS][5] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_GOODGUYS][5], "bot", "hard", true )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_GOODGUYS][5]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "bot", "hard", true )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end	
	
	if self.draftPicks[DOTA_TEAM_BADGUYS][1] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_BADGUYS][1], "top", "hard", false )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_BADGUYS][1]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "top", "hard", false )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_BADGUYS][2] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_BADGUYS][2], "bot", "hard", false )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_BADGUYS][2]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "bot", "hard", false )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_BADGUYS][3] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_BADGUYS][3], "bot", "hard", false )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_BADGUYS][3]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "bot", "hard", false )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end
	if self.draftPicks[DOTA_TEAM_BADGUYS][4] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_BADGUYS][4], "mid", "hard", false )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_BADGUYS][4]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "mid", "hard", false )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end			
	if self.draftPicks[DOTA_TEAM_BADGUYS][5] then
		Tutorial:AddBot( self.draftPicks[DOTA_TEAM_BADGUYS][5], "top", "hard", false )
		table.remove(self.botHeroes, tablefind(self.botHeroes, self.draftPicks[DOTA_TEAM_BADGUYS][5]))
	else
		Tutorial:AddBot( self.botHeroes[heroNumber], "top", "hard", false )
		table.remove(self.botHeroes, heroNumber)
		heroNumber = RandomInt(1, #self.botHeroes)
	end	
	
	GameRules:GetGameModeEntity():SetBotThinkingEnabled(true)
end

function CCouriers:FilterModifyGold(event)
	local gold = event.gold
    local playerID = event.player_id_const
    local reason = event.reason_const
	if reason == DOTA_ModifyGold_HeroKill then
		local extra = self:BonusBounty(playerID)
		--print("bounty = "..gold.."+"..extra)
		gold = gold + extra
		event.gold = gold
		if extra > 0 then
			local extraBountyEffect = ParticleManager:CreateParticleForTeam("particles/msg_fx/msg_gold.vpcf", PATTACH_OVERHEAD_FOLLOW, PlayerResource:GetSelectedHeroEntity(playerID), PlayerResource:GetTeam(playerID))
			ParticleManager:SetParticleControl(extraBountyEffect, 1, Vector(0, extra, 0))
			ParticleManager:SetParticleControl(extraBountyEffect, 2, Vector(5, #tostring(extra)+1, 0))
			ParticleManager:SetParticleControl(extraBountyEffect, 3, Vector(255, 200, 33))
			ParticleManager:ReleaseParticleIndex(extraBountyEffect)
			EmitSoundOnLocationForAllies(PlayerResource:GetSelectedHeroEntity(playerID):GetAbsOrigin(), "ui.comp_coins_tick", PlayerResource:GetSelectedHeroEntity(playerID))
		end
	end
	if self.fakeHero[PlayerResource:GetTeam(playerID)] and playerID ~= self.fakeHero[PlayerResource:GetTeam(playerID)]:GetPlayerOwnerID() then
		local recepient = self.fakeHero[PlayerResource:GetTeam(playerID)]:GetPlayerOwnerID()		
		PlayerResource:ModifyGold(recepient, gold, false, reason)
		--print(gold.."("..reason..") from "..PlayerResource:GetPlayerName(playerID).." to "..PlayerResource:GetPlayerName(recepient))
		return false	
	else	
		gold = gold * self.botGoldMultiplier
	end
	return true
end

function CCouriers:FilterModifyXP(event)
	if self.draftOptions[DOTA_TEAM_GOODGUYS] == "DoubleXP" and self.draftOptions[DOTA_TEAM_BADGUYS] == "DoubleXP" then
		event.experience = 2 * event.experience
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
	self:GiveGold(self.startGold, DOTA_TEAM_GOODGUYS, DOTA_ModifyGold_Unspecified)
	self:GiveGold(self.startGold, DOTA_TEAM_BADGUYS, DOTA_ModifyGold_Unspecified)
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
	for n,unit_index in pairs(event.units) do
		local unit = EntIndexToHScript(unit_index)	
		-- block orders from mind-controlled bots 
		if event.issuer_player_id_const == -1 and unit.isMindControlled ~= nil and unit.isMindControlled then	
			return false
		end
		
		if event.order_type == DOTA_UNIT_ORDER_STOP and unit.isMindControlled ~= nil and unit.isMindControlled then	
			print("CANCEL", event.issuer_player_id_const, event.entindex_ability, unit.GetName())
		end
		
		-- block orders from bots to human-controlled courier
		if unit:IsCourier() and self.fakeHero[unit:GetTeamNumber()] and self.fakeHero[unit:GetTeamNumber()]:GetPlayerID() ~= event.issuer_player_id_const then
			return false
		end
		-- drop items from heroes without mind control 
		if event.order_type == DOTA_UNIT_ORDER_DROP_ITEM and self.fakeHero[unit:GetTeamNumber()] then
			local item = EntIndexToHScript(event.entindex_ability)	
			local carrier = item:GetParent()
			if (carrier.isMindControlled == nil or not carrier.isMindControlled) and carrier:IsRealHero() and PlayerResource:GetTeam(event.issuer_player_id_const) == carrier:GetTeamNumber() then
				local charges = item:GetCurrentCharges()
				local itemname = item:GetName()
				local pos = carrier:GetAbsOrigin()
				item:RemoveSelf()
				local newItem = CreateItemOnPositionSync(pos, CreateItem(itemname, carrier, carrier)) 
				newItem:GetContainedItem():SetCurrentCharges(charges)			
				return false
			end
		end
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
					local targets = FindUnitsInRadius(pingedTeam, ability:GetOwner():GetAbsOrigin(), nil, 1500, ability:GetAbilityTargetTeam(), targetType, DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE, 0, false) 
					if #targets > 0 then
						if behaviour % DOTA_ABILITY_BEHAVIOR_UNIT_TARGET == 0 then
							ability:GetOwner():CastAbilityOnTarget(GetRandomUnit(targets), ability, -1)
						else
							ability:GetOwner():CastAbilityOnPosition(GetRandomUnit(targets):GetAbsOrigin(), ability, -1)
						end
					end
				end
			end)
		end
	end
	
	return true
end

function CCouriers:CheckPassGold(hero)
	-- transfer any remaining gold to the human player
	if IsValidEntity(hero) and hero:IsRealHero() and self.fakeHero[hero:GetTeamNumber()] and hero ~= self.fakeHero[hero:GetTeamNumber()] then
		local recepient = self.fakeHero[hero:GetTeamNumber()]:GetPlayerOwnerID()
		PlayerResource:ModifyGold(recepient, hero:GetGold(), false, DOTA_ModifyGold_Unspecified)
		hero:SetGold(0, false)
		hero:SetGold(0, true)
	end
end

function CCouriers:BonusBounty(playerID)	
	-- get max net worth of team
	local killerTeam = PlayerResource:GetSelectedHeroEntity(playerID):GetTeamNumber()
	local victimTeam = PlayerResource:GetSelectedHeroEntity(playerID):GetOpposingTeamNumber()
	local maxNetWorth = 0
	local heroes = HeroList:GetAllHeroes()
	for _,hero in pairs(heroes) do 
		if hero:GetTeamNumber() == victimTeam and hero ~= self.fakeHero[victimTeam] then
			local netWorth = PlayerResource:GetNetWorth(hero:GetPlayerOwnerID())
			if netWorth > maxNetWorth then
				maxNetWorth = netWorth
				--print(hero:GetName().." is max net worth: "..tostring(maxNetWorth))
			end		
		end		
	end	

	-- gold bounty formula
	return math.floor(maxNetWorth * self.heroBountyMultiplier)
end

function CCouriers:OnHeroLevelUp(event)
	local playerID = EntIndexToHScript(event.player):GetPlayerID()
	--print(event.player, playerID, PlayerResource:GetPlayerName(playerID), PlayerResource:GetTeam(playerID), event.level)
	if self.fakeHero[PlayerResource:GetTeam(playerID)] and self.fakeHero[PlayerResource:GetTeam(playerID)]:GetPlayerOwnerID() ~= playerID then
		self:LevelUp(PlayerResource:GetTeam(playerID))
	end
end

function CCouriers:LevelUp(team)
	self.fakeHero[team]:HeroLevelUp(false)
	for i, courier in pairs(self.courierList) do
		if IsValidEntity(courier) and courier:GetTeamNumber() == team then
			courier:FindAbilityByName("courier_burst"):EndCooldown()
			courier:FindAbilityByName("courier_shield"):EndCooldown()
		end
	end
end

function CCouriers:DoDraft(event)
	if event.done then
		GameRules:FinishCustomGameSetup()
	else
		if not self:HeroAlreadyPicked(event.pick) then	
			if #self.draftPicks[PlayerResource:GetTeam(event.PlayerID)] < 5 then
				table.insert(self.draftPicks[PlayerResource:GetTeam(event.PlayerID)], event.pick)
				CustomNetTables:SetTableValue( "draft", "picked", self.draftPicks)
			end
			local numPlayersDone = 0
			if #self.draftPicks[DOTA_TEAM_GOODGUYS] >= 5 then numPlayersDone = numPlayersDone + 1 end
			if #self.draftPicks[DOTA_TEAM_BADGUYS] >= 5 then numPlayersDone = numPlayersDone + 1 end
			if numPlayersDone >= PlayerResource:GetPlayerCount() then
				self:TeamReversionCheck()
				GameRules:FinishCustomGameSetup()
			end
		end		
	end
end

function CCouriers:OnDraftOptionChanged(event)
	if PlayerResource:GetPlayerCount() == 2 then
		self.draftOptions[PlayerResource:GetTeam(event.PlayerID)]  = event.variant
	elseif PlayerResource:GetPlayerCount() == 1 then
		self.draftOptions[DOTA_TEAM_GOODGUYS]  = event.variant
		self.draftOptions[DOTA_TEAM_BADGUYS]  = event.variant
	else
		print("This should literally never happen")
	end
	CustomNetTables:SetTableValue( "draft", "options", self.draftOptions)
end

function CCouriers:OnHandicapChanged(event)
	if PlayerResource:GetPlayerCount() == 1 then
		self.botGoldMultiplier = event.handicap
	end
end


function CCouriers:HeroAlreadyPicked(heroName)
	for _, team in ipairs({DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS}) do
		for k, v in pairs( self.draftPicks[team] ) do
			if v == heroName then
				return true
			end
		end
	end
	return false
end

function CCouriers:GiveGold(gold, team, reason)
	--print(tostring(gold).." to team "..tostring(team).." [GiveGold]")
	if self.fakeHero[team] then 
		PlayerResource:ModifyGold(self.fakeHero[team]:GetPlayerOwnerID(), gold, false, reason ) 
		--print(gold.." to courier "..team)
	else
		for playerid = 0, DOTA_MAX_PLAYERS do
			if PlayerResource:IsValidPlayer(playerid) and PlayerResource:IsFakeClient(playerid) and PlayerResource:GetTeam(playerid) == team then
				PlayerResource:ModifyGold(playerid, self.botGoldMultiplier*gold/5, false, reason ) 
				--print((gold/5).." to "..PlayerResource:GetSelectedHeroName(playerid))
			end
		end
	end
end

function CCouriers:DraftingCountdown()
	EmitAnnouncerSound("announcer_ann_custom_draft_01")
	Timers:CreateTimer(1, function()
		local t = math.floor(GameRules:GetDOTATime(true, true))
		--print(t)
		if GameRules:State_Get() >= DOTA_GAMERULES_STATE_PRE_GAME then
			return nil
		elseif t == -31 then
			EmitAnnouncerSound("announcer_ann_custom_timer_sec_30")
		elseif t == -16 then
			EmitAnnouncerSound("announcer_ann_custom_timer_sec_15")
		elseif t == -11 then
			EmitAnnouncerSound("announcer_ann_custom_timer_sec_10")
		elseif t == -6 then
			EmitAnnouncerSound("announcer_ann_custom_timer_sec_05")
			return nil
		end
		return 1
	end)
end

function CCouriers:TeamReversionCheck()
	if not self.teamsReversed and self.draftOptions[DOTA_TEAM_GOODGUYS] == "ReverseDraft" and self.draftOptions[DOTA_TEAM_BADGUYS] == "ReverseDraft" then
		self.teamsReversed = true
		for playerid = 0, DOTA_MAX_PLAYERS do
			if PlayerResource:IsValidPlayer(playerid) then
				if PlayerResource:GetCustomTeamAssignment(playerid) == DOTA_TEAM_GOODGUYS then 
					PlayerResource:SetCustomTeamAssignment(playerid, DOTA_TEAM_BADGUYS)
				elseif PlayerResource:GetCustomTeamAssignment(playerid) == DOTA_TEAM_BADGUYS then 
					PlayerResource:SetCustomTeamAssignment(playerid, DOTA_TEAM_GOODGUYS)
				end
			end
		end
		if GameRules:State_Get() < DOTA_GAMERULES_STATE_PRE_GAME then
			GameRules:FinishCustomGameSetup()
		end
	end
end

function CCouriers:UltraLate()
	self.startGold = 100000
	GameRules:SetUseUniversalShopMode(true)
	Timers:CreateTimer(1, function()
		if self.spawnCount < 10 then
			return 1
		else
			for _,hero in pairs(HeroList:GetAllHeroes()) do 
				if IsValidEntity(hero) and hero:IsRealHero() then 
					for _ = 1, 29 do
						hero:HeroLevelUp(false)
					end
				end
			end
		end
	end)
	GameRules:GetGameModeEntity():SetBotsInLateGame(true)
    for i, buildingClassname in pairs({ "npc_dota_tower", "npc_dota_barracks", "npc_dota_filler"}) do
		for _, tower in pairs (Entities:FindAllByClassname(buildingClassname)) do
			tower:ForceKill(false)
		end
	end
	
end

function CCouriers:Deathmatch(hero)
	Timers:CreateTimer(0.1, function()
		if #self.botHeroes > 0 then
			local oldLevel = hero:GetLevel()
			local heroNumber = RandomInt(1, #self.botHeroes)
			local oldItems = {}
			for itemSlot = 0, 11, 1 do 
				local item = hero:GetItemInSlot( itemSlot ) 
				if IsValidEntity(item) then 
					table.insert(oldItems, item:GetName())
				end
			end
			newHero = PlayerResource:ReplaceHeroWith(hero:GetPlayerID(), self.botHeroes[heroNumber], 0, 0)
			UTIL_Remove(hero)
			table.remove(self.botHeroes, heroNumber)
			FindClearSpaceForUnit(newHero, self.fountainPos[newHero:GetTeamNumber()], true)
			newHero:AddNewModifier(spawnedUnit, nil, "modifier_invulnerable", {duration = 5})
			newHero:AddNewModifier(spawnedUnit, nil, "modifier_stunned", {duration = 5})
			for _ = 2, oldLevel do
				newHero:HeroLevelUp(false)
			end
			for i, itemname in pairs(oldItems) do
				newHero:AddItem(CreateItem(itemname, newHero, newHero))
			end
			if #self.botHeroes == 10 then
				EmitAnnouncerSound("announcer_ann_custom_countdown_10")
			elseif #self.botHeroes >= 1 and #self.botHeroes <= 9 then
				EmitAnnouncerSound("announcer_ann_custom_countdown_0"..tostring(#self.botHeroes))
			elseif #self.botHeroes == 0 then
				EmitAnnouncerSound("announcer_ann_custom_sudden_death")
				for _,hero in pairs(HeroList:GetAllHeroes()) do 
					if IsValidEntity(hero) and hero:IsRealHero() then 
						hero:SetRespawnsDisabled(true)
					end
				end				
			end
		end
	end)
end

function CCouriers:BuybackDeathmatch(hero)
	hero:SetBuybackCooldownTime(0)
	if self.fakeHero[hero:GetTeamNumber()] then 
		if self.fakeHero[hero:GetTeamNumber()]:GetGold() >= hero:GetBuybackCost(false) then
			--print(hero:GetName()..": My courier has "..tostring(self.fakeHero[hero:GetTeamNumber()]:GetGold()).." so we can afford the buyback cost of "..tostring(hero:GetBuybackCost(false)))
			PlayerResource:ModifyGold(self.fakeHero[hero:GetTeamNumber()]:GetPlayerOwnerID(), -(hero:GetBuybackCost(false)), false, DOTA_ModifyGold_Buyback)
			Timers:CreateTimer(0.25, function() 
				hero:SetGold(hero:GetBuybackCost(false), true)
				hero:Buyback() 			
			end)
		else
			--print(hero:GetName()..": My courier has "..tostring(self.fakeHero[hero:GetTeamNumber()]:GetGold()).." so we CANNOT afford the buyback cost of "..tostring(hero:GetBuybackCost(false)))
			self:Deathmatch(hero)
		end
	elseif hero:GetGold() < hero:GetBuybackCost(false) then
		--print(hero:GetName()..": I have "..tostring(hero:GetGold()).." so I CANNOT afford the buyback cost of "..tostring(hero:GetBuybackCost(false)))
		self:Deathmatch(hero)
	end		 
end

function GetRandomUnit(units) 
	--prioritise heroes
	local heroes = {}
	for _, u in pairs(units) do
		if u:IsHero() then
			table.insert(heroes, u)
		end
	end
	if #heroes > 0 then
		return heroes[RandomInt(1, #heroes)]
	else
		return units[RandomInt(1, #units)]
	end
end

function PrintTable(aTable)
	for k, v in pairs( aTable ) do
        print(k .. "(" .. type(k) .. ") " .. tostring(v).." ("..type(v)..")" )
    end
	print("")
end

function tablefind(tab,el)
    for index, value in pairs(tab) do
        if value == el then
            return index
        end
    end
end