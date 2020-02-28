(function() 
{ 
	$("#R_BotLane1").style.visibility = 'visible';
	$("#D_TopLane1").style.visibility = 'visible';
	$("#VariantDropdown1").enabled = false;
	$("#VariantDropdown2").enabled = false;
	Game.AutoAssignPlayersToTeams()
	CustomNetTables.SubscribeNetTableListener( "draft", OnDraftChanged );
	timer();
	$.Schedule(1, drawNamesAndAvatars);
})();

function timer()
{
	$("#timer").text = Math.abs(Math.round(Game.GetDOTATime(true, true)));
	$.Schedule(0.2, timer);
}

function drawNamesAndAvatars()
{
	playerNameLabel = "#PlayerName1";
	playerAvaLabel = "#SteamAvatar1";
	for (team =  DOTATeam_t.DOTA_TEAM_GOODGUYS; team <= DOTATeam_t.DOTA_TEAM_BADGUYS; team++)
	{
		for (id = 0; id <= DOTALimits_t.DOTA_MAX_TEAM_PLAYERS; id++)
		{
			if (Players.IsValidPlayerID(id) && Players.GetTeam(id) == team)
			{
				$(playerNameLabel).text = Players.GetPlayerName(id);
				$(playerAvaLabel).BCreateChildren('<DOTAAvatarImage hittest="false" id="player_avatar_' + id + '" class="UserAvatar"/>', false, false);
				$("#player_avatar_" + id).steamid = Game.GetPlayerInfo(id).player_steamid; 
				break; 
			}
		}
		playerNameLabel = "#PlayerName2";
		playerAvaLabel = "#SteamAvatar2";
	}	
	
	var localTeam =  Players.GetTeam(Players.GetLocalPlayer());
	if (localTeam == DOTATeam_t.DOTA_TEAM_GOODGUYS) 
		$("#VariantDropdown1").enabled = true;
	else 
		$("#VariantDropdown2").enabled = true;
}

function OnOptionChanged()
{
	var localTeam =  Players.GetTeam(Players.GetLocalPlayer());
	var optionSelected = "";
	if (localTeam == DOTATeam_t.DOTA_TEAM_GOODGUYS)
		optionSelected = $("#VariantDropdown1").GetSelected().id;
	else
		optionSelected = $("#VariantDropdown2").GetSelected().id;	
	optionSelected = optionSelected.slice(0,-1);
	GameEvents.SendCustomGameEventToServer("variant_option", {variant:optionSelected})
}

function OnSkipDraftButtonPressed()
{
	var localTeam =  Players.GetTeam(Players.GetLocalPlayer());
	var picked = CustomNetTables.GetTableValue( "draft", "picked");
	//$.Msg( localPlayer, localTeam, picked );
	if (Object.keys(picked[localTeam]).length == 0)
	{		
		GameEvents.SendCustomGameEventToServer("draft", {done:true})
	}	
}

function OnDraftChanged( table_name, key, data )
{
	//$.Msg( "Table ", table_name, " changed: '", key, "' = ", data );
	var localTeam =  Players.GetTeam(Players.GetLocalPlayer());
	if (key == "picked")
	{
		//show hero as selected and in lane
		//sound, minimap, picked list portrait, remove skip button
		if (Object.keys(data[localTeam]).length > 0)
		{
			$("#SkipDraftButton").style.visibility = 'collapse';	
		}
		Game.EmitSound("Draft.PickMade")
		for (var t in data)
		{
			for (var h in data[t])
			{
				$("#HeroCard_"+data[t][h]).style.visibility = 'collapse';	
			}
		}
		
		var rList = ["#R_BotLane1", "#R_TopLane1", "#R_TopLane2", "#R_MidLane", "#R_BotLane2"];
		var dList = ["#D_TopLane1", "#D_BotLane1", "#D_BotLane2", "#D_MidLane", "#D_TopLane2"];
		var rPicksLength = Object.keys(data[DOTATeam_t.DOTA_TEAM_GOODGUYS]).length;
		var dPicksLength = Object.keys(data[DOTATeam_t.DOTA_TEAM_BADGUYS]).length;
		
		for (var i = 0; i < rPicksLength; i++) 
		{
			$(rList[i]).heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][i+1];
			if (i+1 < 5)
				$(rList[i+1]).style.visibility = 'visible';
		}
		
		for (var i = 0; i < dPicksLength; i++) 
		{
			$(dList[i]).heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][i+1];
			if (i+1 < 5)
				$(dList[i+1]).style.visibility = 'visible';
		}
	}
	else if (key == "options")
	{
		//$.Msg( data[DOTATeam_t.DOTA_TEAM_GOODGUYS], " ", data[DOTATeam_t.DOTA_TEAM_BADGUYS] );
		$("#VariantDropdown1").SetSelected(data[DOTATeam_t.DOTA_TEAM_GOODGUYS]+"1");
		$("#VariantDropdown2").SetSelected(data[DOTATeam_t.DOTA_TEAM_BADGUYS]+"2");
		if ($("#VariantDropdown1").GetSelected().text == $("#VariantDropdown2").GetSelected().text)
		{
			$("#VariantDropdown1").RemoveClass("warning")
			$("#VariantDropdown2").RemoveClass("warning")
			Game.EmitSound("Relic.Highlight");
		}
		else
		{
			$("#VariantDropdown1").AddClass("warning");
			$("#VariantDropdown2").AddClass("warning");
			Game.EmitSound("General.InvalidTarget_Invulnerable");
		}
	}

}

function HeroSelected(hero_name)
{
	GameEvents.SendCustomGameEventToServer("draft", {pick:hero_name})
}

function BaneSelected() { HeroSelected("npc_dota_hero_bane"); }
function BHSelected() { HeroSelected("npc_dota_hero_bounty_hunter"); }
function BloodSeekerSelected() { HeroSelected("npc_dota_hero_bloodseeker"); }
function BristlebackSelected() { HeroSelected("npc_dota_hero_bristleback"); }
function ChaosKnightSelected() { HeroSelected("npc_dota_hero_chaos_knight"); }
function CrystalMaidenSelected() { HeroSelected("npc_dota_hero_crystal_maiden"); }
function DazzleSelected() { HeroSelected("npc_dota_hero_dazzle"); }
function DeathProphetSelected() { HeroSelected("npc_dota_hero_death_prophet"); }
function DrowRangerSelected() { HeroSelected("npc_dota_hero_drow_ranger"); }
function EarthshakerSelected() { HeroSelected("npc_dota_hero_earthshaker"); }
function JakiroSelected() { HeroSelected("npc_dota_hero_jakiro"); }
function KunkkaSelected() { HeroSelected("npc_dota_hero_kunkka"); }
function LinaSelected() { HeroSelected("npc_dota_hero_lina"); }
function LionSelected() { HeroSelected("npc_dota_hero_lion"); }
function LunaSelected() { HeroSelected("npc_dota_hero_luna"); }
function NecrophosSelected() { HeroSelected("npc_dota_hero_necrolyte"); }
function OmniknightSelected() { HeroSelected("npc_dota_hero_omniknight"); }
function OracleSelected() { HeroSelected("npc_dota_hero_oracle"); }
function PhantomAssassinSelected() { HeroSelected("npc_dota_hero_phantom_assassin"); }
function PudgeSelected() { HeroSelected("npc_dota_hero_pudge"); }
function SandKingSelected() { HeroSelected("npc_dota_hero_sand_king"); }
function SFSelected() { HeroSelected("npc_dota_hero_nevermore"); }
function SkywrathSelected() { HeroSelected("npc_dota_hero_skywrath_mage"); }
function SniperSelected() { HeroSelected("npc_dota_hero_sniper"); }
function SvenSelected() { HeroSelected("npc_dota_hero_sven"); }
function TinySelected() { HeroSelected("npc_dota_hero_tiny"); }
function ViperSelected() { HeroSelected("npc_dota_hero_viper"); }
function WarlockSelected() { HeroSelected("npc_dota_hero_warlock"); }
function WindrangerSelected() { HeroSelected("npc_dota_hero_windrunner"); }
function ZeusSelected() { HeroSelected("npc_dota_hero_zuus"); }


