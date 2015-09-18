#include <amxmodx>
#include <hamsandwich>
#include <MW3_Core_Const>

#define FLAG_EXP	ADMIN_RCON

static const Plugin [] = "MW3 - XP";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

#define flag_get(%1,%2)		(g_playerInfo[%1] &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(g_playerInfo[%1] |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(g_playerInfo[%1] &= ~(1 << (%2 & 31)))

enum _:ePlayerInfo {
	info_isConnected,
	info_isAlive
}

static g_playerInfo[ePlayerInfo];

enum _:eRankInfo {
	rank_Exp,
	rank_Rank
};

static g_iRankInfo[MAXPLAYERS+1][eRankInfo];

enum eForwardedEvents {
	fwDummy,
	fwRankUp,
	fwChangeXP
};

static g_forwardedEvents[eForwardedEvents];

static const g_szRankName[][] = { 
	"Rank 1",
	"Rank 2",
	"Rank 3",
	"Rank 4",
	"Rank 5",
	"Rank 6",
	"Rank 7",
	"Rank 8",
	"Rank 9",
	"Rank 10"
};

const g_iRankMax = sizeof g_szRankName;

static const g_iRankXP[g_iRankMax-1] = {
	250,
	500,
	750,
	1000,
	1250,
	1500,
	1750,
	2000,
	2500
};

const g_iRankSize = g_iRankMax-1;
const g_iRankXPSize = g_iRankMax-2;
static g_iMaxXP;

public plugin_precache() {
	g_iMaxXP = g_iRankXP[g_iRankXPSize];
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	new ip[32];
	get_user_ip(0, ip, 31, 0);
	if (!equali(ip, "192.168.", 8)) {
		server_print("You are running an illegal version of this mod. To purchase access to this mod, please contact Tirant (tiranthunter@hotmail.com) for more information");
		set_fail_state("You are running an illegal version of this mod. To purchase access to this mod, please contact Tirant (tiranthunter@hotmail.com) for more information");
		return;
	}
	
	RegisterHam(Ham_Spawn,	"player", "ham_PlayerSpawn_Post", 1);
	RegisterHam(Ham_Killed,	"player", "ham_PlayerDeath_Post", 1);
	
	g_forwardedEvents[fwRankUp  ] = CreateMultiForward("mw3_fw_exp_rankUp", ET_IGNORE, FP_CELL, FP_CELL);
	g_forwardedEvents[fwChangeXP] = CreateMultiForward("mw3_fw_exp_gainExp", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
}

public plugin_natives() {
	register_library("MW3_Experience");
	
	register_native("mw3_exp_changeUserExp",	"_changeUserExperience", 1);
	register_native("mw3_exp_getUserExp",		"_getUserExperience",	 1);
	register_native("mw3_exp_setUserExp",		"_setUserExperience",	 1);
	
	register_native("mw3_exp_setUserRank",		"_setUserRank",		 1);
	register_native("mw3_exp_getUserRank",		"_getUserRank",		 1);
	
	register_native("mw3_exp_getRankName",		"_getRankName",		 0);
	register_native("mw3_exp_getRankExp",		"_getRankExperience",	 1);
	
	register_native("mw3_exp_getMaxRank",		"_getMaxRank",		 1);
	register_native("mw3_exp_queryRank",		"_queryRank",		 1);
}

public client_connect(id) {
	resetPlayerInfo(id);
	flag_set(info_isConnected,id);
	arrayset(g_iRankInfo[id], 0, eRankInfo);
}

public client_disconnect(id) {
	resetPlayerInfo(id);
}

resetPlayerInfo(id) {
	for (new i; i < ePlayerInfo; i++) {
		flag_unset(i,id);
	}
}

public ham_PlayerDeath_Post(victim, killer, shouldgib) {
	if (!flag_get(info_isConnected,victim)) {
		return HAM_IGNORED;
	}
	
	flag_unset(info_isAlive,victim);
	return HAM_IGNORED;
}

public ham_PlayerSpawn_Post(id) {
	if (!is_user_alive(id)) {
		return HAM_IGNORED;
	}
	
	flag_set(info_isAlive,id);
	return HAM_IGNORED;
}

public _changeUserExperience(id, exp, bool:notifyLevelChange) {
	if (exp != 0) {
		g_iRankInfo[id][rank_Exp] = clamp(g_iRankInfo[id][rank_Exp]+exp, 0, g_iMaxXP);
		while (checkPlayerRank(id, notifyLevelChange)) {}
		ExecuteForward(g_forwardedEvents[fwChangeXP], g_forwardedEvents[fwDummy], id, exp, g_iRankInfo[id][rank_Exp]);
		return g_iRankInfo[id][rank_Exp];
	}
	return -1;
}

public _setUserExperience(id, exp, bool:notifyLevelChange) {
	g_iRankInfo[id][rank_Exp ] = clamp(exp, 0, g_iMaxXP);
	g_iRankInfo[id][rank_Rank] = _queryRank(g_iRankInfo[id][rank_Exp])-1;
	if (notifyLevelChange) {
		ExecuteForward(g_forwardedEvents[fwRankUp], g_forwardedEvents[fwDummy], id, g_iRankInfo[id][rank_Rank]+1);
	}
	
	return g_iRankInfo[id][rank_Rank]+1;
}

public _queryRank(exp) {
	static rank, low, high;
	rank = 0;
	if (g_iRankXP[0] <= exp < _:g_iRankXP[g_iRankXPSize]) {
		low = 0;
		high = g_iRankXPSize;
		while (!(g_iRankXP[rank] <= exp < g_iRankXP[rank+1]) && low <= high) {
			rank = (low+high)>>>1;
			if (g_iRankXP[rank] < exp) {
				low = rank+1;
			} else {
				high = rank-1;
			}
		}
		rank++;
	} else if (exp == _:g_iRankXP[g_iRankXPSize]) {
		rank = g_iRankXPSize+1;
	}
	return rank+1;
}

bool:checkPlayerRank(id, bool:notifyLevelChange) {
	if (!flag_get(info_isConnected,id)) {
		return false;
	}
	
	if (g_iRankInfo[id][rank_Rank] < g_iRankSize) {
		if (g_iRankInfo[id][rank_Exp] < g_iRankXP[g_iRankInfo[id][rank_Rank]]) {
			return false;
		}

		g_iRankInfo[id][rank_Rank]++;
		if (notifyLevelChange) {
			ExecuteForward(g_forwardedEvents[fwRankUp], g_forwardedEvents[fwDummy], id, g_iRankInfo[id][rank_Rank]+1);
		}		
		return true;
	}	
	return false;
}

public _getUserExperience(id) {
	return g_iRankInfo[id][rank_Exp];
}

public _getUserRank(id) {
	return g_iRankInfo[id][rank_Rank]+1;
}

public _setUserRank(id, rank, bool:notifyLevelChange) {
	rank = clamp(rank-1, 0, g_iRankSize);
	if (g_iRankInfo[id][rank_Rank] != rank) {
		g_iRankInfo[id][rank_Rank] = rank;
		g_iRankInfo[id][rank_Exp ] = (rank ? g_iRankXP[clamp(rank-1, 0, g_iRankXPSize)] : 0);
		if (notifyLevelChange) {
			ExecuteForward(g_forwardedEvents[fwRankUp], g_forwardedEvents[fwDummy], id, g_iRankInfo[id][rank_Rank]+1);
		}
		return g_iRankInfo[id][rank_Rank]+1;
	}
	return 0;
}

public _getRankName(iPlugin, iParams) {
	if (iParams != 3) {
		return PLUGIN_HANDLED;
	}
	
	static rank;
	rank = clamp(get_param(1)-1, 0, g_iRankSize);
	set_string(2, g_szRankName[rank], get_param(3));
	return PLUGIN_CONTINUE;
}

public _getRankExperience(rank) {
	rank--;
	rank = clamp(rank, 0, g_iRankXPSize);
	return g_iRankXP[rank];
}

public _getMaxRank() {
	return g_iRankMax;
}
