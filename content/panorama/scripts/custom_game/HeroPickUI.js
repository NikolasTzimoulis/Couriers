(function() 
{ 
	//$("#DraftUIContainer").style.visibility = 'visible';
	drawNamesAndAvatars();
	CustomNetTables.SubscribeNetTableListener( "draft", OnNettable2Changed );
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
	if (Object.keys(picked[localTeam]).length == 0)
	{		
		GameEvents.SendCustomGameEventToServer("draft", "")
		$("#DraftUIContainer").style.visibility = 'collapse';
	}
	
}

function OnNettable2Changed( table_name, key, data )
{
	$.Msg( "Table ", table_name, " changed: '", key, "' = ", data );
}