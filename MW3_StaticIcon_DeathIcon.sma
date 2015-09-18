#include <amxmodx>
#include <MW3_Core>
#include <MW3_StaticIcon>
#include <csdm>

static const Plugin [] = "MW3 - StaticIcon (Death Icons)";
static const Author [] = "Tirant";
static const Version[] = "0.0.1";

#define ICON_TASK 1010587

static const g_deathIcon[] = "sprites/mw3/SACB.spr";
static g_deathSprite;

static g_iPlayerIconID[MAXPLAYERS+1];

public plugin_precache() {
	g_deathSprite = precache_model(g_deathIcon);
	
	new MaxPlayers = get_maxplayers();
	for(new id = 1; id <= MaxPlayers; id++) {
		g_iPlayerIconID[id] = mw3_si_createIcon(id, CS_TEAM_SPECTATOR, false, g_deathSprite, g_deathIcon);
	}
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	register_message(get_user_msgid("TeamInfo"), "msgTeamInfo");
}

public client_disconnect(id) {
	remove_task(id+ICON_TASK);
	mw3_si_changeIconTeam(g_iPlayerIconID[id], CS_TEAM_SPECTATOR);
	mw3_si_setIconState(g_iPlayerIconID[id], icon_Hidden);
}

public msgTeamInfo(msgid, dest) {
	if (dest != MSG_ALL && dest != MSG_BROADCAST) {
		return;
	}
	
	static id, team[2];
	id = get_msg_arg_int(1);

	get_msg_arg_string(2, team, charsmax(team));
	switch (team[0]) {
		case 'T': {
			mw3_si_changeIconTeam(g_iPlayerIconID[id], CS_TEAM_T);
		}
		case 'C': {
			mw3_si_changeIconTeam(g_iPlayerIconID[id], CS_TEAM_CT);
		}
		default: {
			mw3_si_changeIconTeam(g_iPlayerIconID[id], CS_TEAM_SPECTATOR);
		}
	}
}

public csdm_PostDeath(killer, victim, headshot, const weapon[]) {
	mw3_si_setIconState(g_iPlayerIconID[victim], icon_Showing);
	set_task(7.5, "hidePlayerIcon", victim+ICON_TASK);
}

public hidePlayerIcon(taskid) {
	taskid -= ICON_TASK;
	mw3_si_setIconState(g_iPlayerIconID[taskid], icon_Hidden);
}

public csdm_PostSpawn(id, bool:fake) {
	remove_task(id+ICON_TASK);
	mw3_si_setIconState(g_iPlayerIconID[id], icon_Hidden);
}
