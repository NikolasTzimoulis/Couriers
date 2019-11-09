(function() 
{ 
	//$("#DraftUIContainer").style.visibility = 'visible';
	Game.AutoAssignPlayersToTeams()
	CustomNetTables.SubscribeNetTableListener( "draft", OnNettable2Changed );
	timer();
})();

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
}

function OnSkipDraftButtonPressed()
{
	var localPlayer = Players.GetLocalPlayer();
	var localTeam =  Players.GetTeam(localPlayer);
	var picked = CustomNetTables.GetTableValue( "draft", "picked");
	$.Msg( localPlayer, localTeam, picked );
	if (Object.keys(picked[localTeam]).length == 0)
	{		
		GameEvents.SendCustomGameEventToServer("draft", {done:true})
	}
	
}

function OnNettable2Changed( table_name, key, data )
{
	//$.Msg( "Table ", table_name, " changed: '", key, "' = ", data );
	var localPlayer = Players.GetLocalPlayer();
	var localTeam =  Players.GetTeam(localPlayer);
	//show hero as selected and in lane
	//sound, minimap, picked list portrait, remove skip button
	if (Object.keys(data[localTeam]).length > 0)
	{
		$("#SkipDraftButton").style.visibility = 'collapse';	
	}
	Game.EmitSound("General.SelectAction")
	for (var t in data)
	{
		for (var h in data[t])
		{
			$("#HeroCard_"+data[t][h]).style.visibility = 'collapse';	
		}
	}
	
	$("#R_BotLane1").heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][1];
	$("#R_TopLane1").heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][2];
	$("#R_TopLane2").heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][3];
	$("#R_MidLane").heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][4];
	$("#R_BotLane2").heroname = data[ DOTATeam_t.DOTA_TEAM_GOODGUYS ][5];
	
	$("#D_TopLane1").heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][1];
	$("#D_BotLane1").heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][2];
	$("#D_BotLane2").heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][3];
	$("#D_MidLane").heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][4];
	$("#D_TopLane2").heroname = data[ DOTATeam_t.DOTA_TEAM_BADGUYS ][5];	
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


function timer()
{
	$("#timer").text = Math.abs(Math.round(Game.GetDOTATime(true, true)));
	$.Schedule(0.2, timer);
	drawNamesAndAvatars();
}