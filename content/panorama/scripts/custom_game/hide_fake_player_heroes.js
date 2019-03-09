/* Initialization */
(function() 
{ 
	hideFakeHeroes();
})();

function hideFakeHeroes() 
{
	var fakeheroRadiant = $.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("topbar").FindChildTraverse("TopBarRadiantTeam").FindChildTraverse("TopBarRadiantPlayers").FindChildTraverse("RadiantTeamScorePlayers").FindChildTraverse("TopBarRadiantPlayersContainer").FindChildTraverse("RadiantPlayer0");
	var fakeheroDire = $.GetContextPanel().GetParent().GetParent().FindChildTraverse("HUDElements").FindChildTraverse("topbar").FindChildTraverse("TopBarDireTeam").FindChildTraverse("TopBarDirePlayers").FindChildTraverse("DireTeamScorePlayers").FindChildTraverse("TopBarDirePlayersContainer").FindChildTraverse("DirePlayer0");
	var tooSoon = Game.GameStateIsBefore(DOTA_GameState.DOTA_GAMERULES_STATE_PRE_GAME);
	
	if (fakeheroRadiant) fakeheroRadiant.style.visibility = "collapse";
	if (fakeheroDire) fakeheroDire.style.visibility = "collapse"; 
	
	if (tooSoon || !fakeheroRadiant || !fakeheroDire)
	{
		$.Schedule(1.0, hideFakeHeroes);	
	}
	
}