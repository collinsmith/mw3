#include <amxmodx>
#include <csdm>
#include <cstrike>

#include <MW3_Core>
#include <MW3_Commands>
#include <MW3_Perks>
#include <MW3_Messages>
#include <cs_playerassist>

static const Plugin [] = "MW3 - Scorechain";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

#define flag_get(%1,%2)		(%1 &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(%1 |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(%1 &= ~(1 << (%2 & 31)))
static g_bHasHardline;

#define playerGetChain(%1,%2)		(g_iCurChains[%1] &   (1 << (%2 & 31)))
#define playerAddChain(%1,%2)		(g_iCurChains[%1] |=  (1 << (%2 & 31)))
#define playerRemChain(%1,%2)		(g_iCurChains[%1] &= ~(1 << (%2 & 31)))
#define playerHasChain(%1,%2)		!!(playerGetChain(%1,%2))
#define isValidPlayerID(%1)		bool:(%1 > 0 || g_iMaxPlayers >= %1)

#define CHAIN_NONE -1
#define ASSIST_NUM 2

static const SCORECHAIN_PATH[] = "mw3/scorechain/%s.wav";

static const g_iHUDColors[3] = { 255, 255, 255 };
static Array:g_aChainQue[MAXPLAYERS+1];
static g_iCurChains[MAXPLAYERS+1];
static CsTeams:g_iCurTeam[MAXPLAYERS+1];
static g_iHardlineAssists[MAXPLAYERS+1];
static g_iMaxPlayers;

enum _:Scorechain {
	ChainName[32],
	ChainSoundSelf[32],
	ChainSoundFriend[32],
	ChainSoundEnemy[32],
	Requirement,
	bool:usesKills
};

static bool:g_bCanLoadChains = false;
static Array:g_aScorechains;
static Trie:g_tScorechainNames;
static g_iScorechainNum;

enum _:Counter {
	counter_Kills,
	counter_Deaths
};
static g_iCounter[MAXPLAYERS+1][Counter];

enum _:eForwardedEvents {
	fwDummy = 0,
	fwScorechainUsed,
	fwChainAdded,
	fwChainsChanged,
	fwLoadChains
};
static g_Forwards[eForwardedEvents];

public plugin_precache() {
	g_aScorechains = ArrayCreate(Scorechain);
	g_tScorechainNames = TrieCreate();
	
	g_bCanLoadChains = true;
	g_Forwards[fwLoadChains] = CreateMultiForward("mw3_fw_sc_load", ET_IGNORE);
	ExecuteForward(g_Forwards[fwLoadChains], g_Forwards[fwDummy]);
	g_bCanLoadChains = false;
	
	new size = MAXPLAYERS+1
	for (new i; i < size; i++) {
		g_aChainQue[i] = ArrayCreate();
	}
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	register_message(get_user_msgid("TeamInfo"), "msgTeamInfo");
	
	mw3_command_register("killstreak", "cmdScorechain", "abcde", "Calls in the next scorechain you have available");
	mw3_command_register("ks", "cmdScorechain");
	mw3_command_register("scorechain", "cmdScorechain");
	mw3_command_register("sc", "cmdScorechain");
	mw3_command_register("chain", "cmdScorechain");
	
	g_Forwards[fwScorechainUsed] = CreateMultiForward("mw3_fw_sc_called", ET_IGNORE, FP_CELL, FP_CELL);
	g_Forwards[fwChainAdded    ] = CreateMultiForward("mw3_fw_sc_added", ET_IGNORE, FP_CELL, FP_CELL);
	g_Forwards[fwChainsChanged ] = CreateMultiForward("mw3_fw_sc_changed", ET_IGNORE, FP_CELL, FP_CELL);
	
	g_iMaxPlayers = get_maxplayers();
}

public plugin_natives() {
	register_library("MW3_Scorechain");
	
	register_native("mw3_sc_addToCounter",		"_addToCounter",	1);
	register_native("mw3_sc_getCurCounter",		"_getCurCounter",	1);
	register_native("mw3_sc_getChainName",		"_getChainName",	1);
	register_native("mw3_sc_getChainByName",	"_getChainByName",	0);
	register_native("mw3_sc_registerChain",		"_registerChain",	0);
	
	register_native("mw3_sc_resetChains",		"_resetChains",		1);
	register_native("mw3_sc_convChainToBits",	"_convChainToBits",	0);
	register_native("mw3_sc_convBitsToChain",	"_convBitsToChain",	0);
	register_native("mw3_sc_addScorechain",		"_addScorechain",	1);
	register_native("mw3_sc_removeScorechain",	"_removeScorechain",	1);
	register_native("mw3_sc_checkPlayerChain",	"_checkPlayerChain",	1);
	register_native("mw3_sc_getScorechains",	"_getScorechains",	1);
	register_native("mw3_sc_setScorechains",	"_setScorechains",	1);
	register_native("mw3_sc_getBitsChainList",	"_getBitsChainList",	1);

}

public _resetChains(id) {
	_setScorechains(id, 0);
}

public _addScorechain(id, chain) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _addScorechain; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (!_chainExists(chain)) {
		mw3_log_err("Function: _addScorechain; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	playerAddChain(id, chain);
	ExecuteForward(g_Forwards[fwChainAdded], g_Forwards[fwDummy], id, chain);
	return g_iCurChains[id];
}

public _removeScorechain(id, chain) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _removeScorechain; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (!_chainExists(chain)) {
		mw3_log_err("Function: _removeScorechain; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	playerRemChain(id, chain);
	return g_iCurChains[id];
}

public bool:_checkPlayerChain(id, chain) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _checkPlayerChain; Error: Invalid player id (%d)", id);
		return false;
	}
	
	if (!_chainExists(chain)) {
		mw3_log_err("Function: _checkPlayerChain; Error: Invalid perk (%d)", chain);
		return false;
	}
	
	return playerHasChain(id, chain);
}

public _getScorechains(id) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _getScorechains; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	return g_iCurChains[id];
}

public _setScorechains(id, bits) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _setScorechains; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (bits < 0) {
		mw3_log_err("Function: _setScorechains; Error: Invalid bitsum (%d)", bits);
		return -1;
	}
	
	g_iCurChains[id] = bits;
	ExecuteForward(g_Forwards[fwChainsChanged], g_Forwards[fwDummy], id, bits);
	return g_iCurChains[id];
}

public Array:_getBitsChainList(bits) {
	new Array:chainList = ArrayCreate();
	new size = ArraySize(g_aScorechains);
	for (new i; i < size; i++) {
		if (bits & (1<<i)) {
			ArrayPushCell(chainList, i);
		}
	}
	
	return chainList;
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
			g_iCurTeam[id] = CS_TEAM_T;
		}
		case 'C': {
			g_iCurTeam[id] = CS_TEAM_CT;
		}
		case 'S': {
			g_iCurTeam[id] = CS_TEAM_SPECTATOR;
		}
		default: {
			g_iCurTeam[id] = CS_TEAM_UNASSIGNED;
		}
	}
}

public cmdScorechain(id) {
	processQue(id);
}

public client_disconnect(id) {
	g_iHardlineAssists[id] = 0;
	resetCounters(id);
}

resetCounters(id) {
	flag_unset(g_bHasHardline, id);
	for (new i; i < Counter; i++) {
		setCounter(id, i);
	}
}

public mw3_fw_perks_perksChanged(id, bits) {
	static hardline;
	if (!hardline) {
		hardline = mw3_perks_getPerkByName("Hardline");
		hardline = mw3_perks_convertPerkToBits(hardline);
	}
	
	if (bits & hardline) {
		flag_set(g_bHasHardline,id);
	} else if (flag_get(g_bHasHardline,id)) {
		flag_unset(g_bHasHardline,id);
	}
}

public mw3_fw_perks_perkAdded(id, perk) {
	static hardline;
	if (!hardline) {
		hardline = mw3_perks_getPerkByName("Hardline");
	}
	
	if (perk == hardline) {
		flag_set(g_bHasHardline,id);
	} else if (flag_get(g_bHasHardline,id)) {
		flag_unset(g_bHasHardline,id);
	}
}

public cs_fw_player_assist(victim, assister, killer, Float:damage_done, Float:last_attack) {
	if (assister != killer) {
		g_iHardlineAssists[assister]++;
		if (g_iHardlineAssists[assister] % ASSIST_NUM == 0) {
			_addToCounter(assister, counter_Kills, 1);
		}
	}
}

public csdm_PostSpawn(id, bool:fake) {
	if (fake) {
		return;
	}
	
	setCounter(id, counter_Kills);
	remindPlayer(id);
	
	g_iHardlineAssists[id] = 0;
}

public csdm_PostDeath(killer, victim, headshot, const weapon[]) {
	_addToCounter(killer, counter_Kills, 1);
	setCounter(killer, counter_Deaths);
	
	_addToCounter(victim, counter_Deaths, 1);
	setCounter(victim, counter_Kills);
}

setCounter(id, counter, kills = 0) {
	g_iCounter[id][counter] = kills;
	checkForStreaks(id);
}

public _addToCounter(id, counter, kills) {
	g_iCounter[id][counter] += kills;
	checkForStreaks(id);
}

getCounter(id, counter) {
	return g_iCounter[id][counter];
}

checkForStreaks(id) {
	new tempScorechain[Scorechain];
	for (new i; i < g_iScorechainNum; i++) {
		ArrayGetArray(g_aScorechains, i, tempScorechain);
		if (!flag_get(g_iCurChains[id],i)) {
			continue;
		}
		
		if (getCounter(id, tempScorechain[usesKills]) == (tempScorechain[Requirement] - _:!!flag_get(g_bHasHardline,id))) {
			addToQue(id, i);
		}
	}
}

processQue(id) {
	if (!ArraySize(g_aChainQue[id])) {
		return;
	}
	
	new chain = ArrayGetCell(g_aChainQue[id], 0);
	removeFromQue(id, chain, false);
	
	sendMessages(id, chain);
	ExecuteForward(g_Forwards[fwScorechainUsed], g_Forwards[fwDummy], id, chain);
}

remindPlayer(id) {
	if (!ArraySize(g_aChainQue[id])) {
		return;
	}
	
	new chain, tempScorechain[Scorechain], temp[64];
	chain = ArrayGetCell(g_aChainQue[id], 0);
	ArrayGetArray(g_aScorechains, chain, tempScorechain);
	formatex(temp, 63, SCORECHAIN_PATH, tempScorechain[ChainSoundSelf]);
	mw3_playSound(id, temp);
}

sendMessages(id, chain) {
	if (!_chainExists(chain)) {
		mw3_log_err("Function: sendMessages; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	new tempScorechain[Scorechain];
	ArrayGetArray(g_aScorechains, chain, tempScorechain);
	
	new szMessage[128];
	get_user_name(id, szMessage, 127);
	format(szMessage, 127, "%s called in by %s", tempScorechain[ChainName], szMessage);
	
	new szFriendly[64], szEnemy[64];
	formatex(szEnemy,    63, SCORECHAIN_PATH, tempScorechain[ChainSoundEnemy ]);
	formatex(szFriendly, 63, SCORECHAIN_PATH, tempScorechain[ChainSoundFriend]);
	
	new players[32], num, player;
	get_players(players, num, "c");
	for (new i; i < num; i++) {
		player = players[i];
		if (g_iCurTeam[id] == g_iCurTeam[player]) {
			mw3_playSound(player, szFriendly);
			mw3_createTutorMsg(player, id, Tutor_Green, 5.0, tempScorechain[ChainName]);
			mw3_printColor(player, "Friendly %s", szMessage);
		} else {
			mw3_playSound(player, szEnemy);
			mw3_createTutorMsg(player, id, Tutor_Red, 5.0, tempScorechain[ChainName]);
			mw3_printColor(player, "Enemy %s", szMessage);
		}
	}
	return 1;
}

addToQue(id, chain) {
	if (!_chainExists(chain)) {
		mw3_log_err("Function: addToQue; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	ArrayPushCell(g_aChainQue[id], chain);
	
	new tempScorechain[Scorechain];
	ArrayGetArray(g_aScorechains, chain, tempScorechain);
	
	new szMessage[64], szSound[64];
	static const KS_TYPES[][] = { "Death", "Point" };
	formatex(szMessage, 63, "%s^n%d %s Streak!^nType /scorechain to use it", tempScorechain[ChainName], tempScorechain[Requirement] - _:!!flag_get(g_bHasHardline,id), KS_TYPES[tempScorechain[usesKills]]);
	formatex(szSound, 63, SCORECHAIN_PATH, tempScorechain[ChainSoundSelf]);
	mw3_set_message(id, szMessage, szSound, effect_Write, g_iHUDColors[0], g_iHUDColors[1], g_iHUDColors[2]);
	return 1;
}

removeFromQue(id, chain, bool:removeAll) {
	if (!_chainExists(chain)) {
		mw3_log_err("Function: removeFromQue; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	new size = ArraySize(g_aChainQue[id]);
	for (new i; i < size; i++) {
		if (chain == ArrayGetCell(g_aChainQue[id], i)) {
			ArrayDeleteItem(g_aChainQue[id], i);
			if (!removeAll) {
				break;
			}
		}
	}
	return 1;
}

bool:_chainExists(chain) {
	if (chain < 0 || chain >= g_iScorechainNum) {
		return false;
	}
	
	return true;
}

public _convChainToBits(chain) {
	if (!_chainExists(chain)) {
		mw3_log_err("Function: _convChainToBits; Error: Invalid chain (%d)", chain);
		return -1;
	}
	
	return (1<<(chain));
}

public _convBitsToChain(bits) {
	if (bits < 0) {
		mw3_log_err("Function: _convBitsToChain; Error: Invalid bitsum (%d)", bits);
		return -1;
	}
	
	new i;
	while (bits > 0) {
		bits >>= 1;
		i++;
	}
	
	return clamp(i-1, 0);
}

public _getCurCounter(id, counter) {
	if (counter < 0 || counter >= Counter) {
		return -1;
	}
	
	return g_iCounter[id][counter];
}

enum _:eParamChain {
	ParamChain_name = 1,
	ParamChain_useskills,
	ParamChain_requirement,
	ParamChain_soundSelf,
	ParamChain_soundFriend,
	ParamChain_soundEnemy
};

public _registerChain(iPlugin, iParams) {
	if (iParams != (eParamChain-1)) {
		mw3_log_err("Function: _registerChain; Error: Invalid parameter number! (Expected %d, Found %d)", (eParamChain-1), iParams);
		return CHAIN_NONE;
	}
	
	if (!g_bCanLoadChains) {
		mw3_log_err("Function: _registerChain; Error: Loaded outside of time slot!");
		return CHAIN_NONE;
	}
	
	new tempScorechain[Scorechain], szTemp[32], i;
	get_string(ParamChain_name, tempScorechain[ChainName], 31);
	copy(szTemp, 31, tempScorechain[ChainName]);
	strtolower(szTemp);
	if (TrieGetCell(g_tScorechainNames, szTemp, i)) {
		return i;
	}
	
	get_string(ParamChain_soundSelf,   tempScorechain[ChainSoundSelf  ], 31);
	get_string(ParamChain_soundFriend, tempScorechain[ChainSoundFriend], 31);
	get_string(ParamChain_soundEnemy,  tempScorechain[ChainSoundEnemy ], 31);
	tempScorechain[usesKills  ] = get_param(ParamChain_useskills);
	tempScorechain[Requirement] = get_param(ParamChain_requirement);
	
	ArrayPushArray(g_aScorechains, tempScorechain);
	TrieSetCell(g_tScorechainNames, szTemp, g_iScorechainNum);
	
	g_iScorechainNum++;
	return g_iScorechainNum-1;
}

public _getChainByName(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getChainByName; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return CHAIN_NONE;
	}
	
	new szChainName[32], i;
	get_string(1, szChainName, 31);
	strtolower(szChainName);
	if (TrieGetCell(g_tScorechainNames, szChainName, i)) {
		return i;
	}
	
	return -1;
}

public _getChainName(iPlugin, iParams) {
	if (iParams != 3) {
		mw3_log_err("Function: _getChainName; Error: Invalid parameter number! (Expected %d, Found %d)", 3, iParams);
		return -1;
	}

	new chain = get_param(1);
	if (!_chainExists(chain)) {
		return -1;
	}
	
	new tempScorechain[Scorechain];
	ArrayGetArray(g_aScorechains, chain, tempScorechain);
	set_string(2, tempScorechain[ChainName], get_param(3));
	return 1;
}
