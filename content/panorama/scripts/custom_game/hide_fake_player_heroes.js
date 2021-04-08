/* Initialization */
(function() 
{ 
	hideFakeHeroes();
})();

function hideFakeHeroes() 
{
	var fakeheroRadiant = $.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("topbar").FindChildTraverse("TopBarRadiantTeam").FindChildTraverse("TopBarRadiantPlayers").FindChildTraverse("RadiantTeamScorePlayers").FindChildTraverse("TopBarRadiantPlayersContainer").GetChild(0);
	var fakeheroDire = $.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("topbar").FindChildTraverse("TopBarDireTeam").FindChildTraverse("TopBarDirePlayers").FindChildTraverse("DireTeamScorePlayers").FindChildTraverse("TopBarDirePlayersContainer").GetChild(0);
	var teamBalance = 0;
	for (id = 0; id <= DOTALimits_t.DOTA_MAX_TEAM_PLAYERS; id++)
	{
		if (Players.GetTeam(id) == DOTATeam_t.DOTA_TEAM_GOODGUYS) teamBalance += 1;
		if (Players.GetTeam(id) == DOTATeam_t.DOTA_TEAM_BADGUYS) teamBalance -= 1;
	}
	if (fakeheroRadiant && teamBalance >= 0) fakeheroRadiant.style.visibility = "collapse";
	if (fakeheroDire && teamBalance <= 0) fakeheroDire.style.visibility = "collapse"; 
	
	//make neutral stash invisible
	$.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("shop").FindChildTraverse("Main").FindChildTraverse("HeightLimiter").FindChildTraverse("GridMainShop").FindChildTraverse("GridShopHeaders").FindChildTraverse("GridMainTabs").GetChild(3).style.visibility = "collapse";
	$.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("shop").FindChildTraverse("Main").FindChildTraverse("HeightLimiter").FindChildTraverse("GridMainShop").FindChildTraverse("GridMainShopContents").FindChildTraverse("GridNeutralsCategory").style.visibility = "collapse";
	
	if (Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS))
	{
		$.Schedule(1.0, hideFakeHeroes);		
	}
}