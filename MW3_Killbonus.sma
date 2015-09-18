#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <fm_cstrike>
#include <hamsandwich>

#include <csdm>
#if !defined _csdm_included
	#include <csx>
#endif

#include <MW3_Experience>
#include <MW3_Core>
#include <MW3_Messages>
#include <cs_playerassist>

static const Plugin [] = "MW3 - Scorechain";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const SOUND_BONUS   [] = "mw3/bonus.wav";
static const SOUND_PAYBACK [] = "mw3/payback.wav";
static const SOUND_HEADSHOT[] = "player/bhit_helmet-1.wav";

#define flag_get(%1,%2)		(%1 &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(%1 |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(%1 &= ~(1 << (%2 & 31)))

#define ADMIN_EXP	15
#define EXP_MULTIPLIER 	1

#define ASSIST_ZONE_1 30
#define ASSIST_ZONE_2 80

#define MIN_FOR_FLAGS 4
#define FLAGS_ROUNDXP 250
#define FLAGS_MATCHXP 500

static const g_iHUDKillbonus [3] = { 000, 240, 240 };
static const Float:g_flHUDLoc[3] = { 0.52, 0.43 };

enum eKillbonuses {
	BONUS_NONE = 0,
	BONUS_ASSIST1,
	BONUS_ASSIST2,
	BONUS_ASSIST3,
	BONUS_FIRSTBLOOD,
	BONUS_HEADSHOT,
	BONUS_PAYBACK,
	BONUS_ASSASSINATION,
	BONUS_COMEBACK,
	BONUS_COMEBACK2,
	BONUS_FINALKILL,
	BONUS_POSITIONSECURE,
	BONUS_POSITIONSECURE2,
	BONUS_ONEHITONEKILL,
	BONUS_BUZZKILL,
	BONUS_STUCK
};

static const g_szKillbonuses[eKillbonuses][][] = {
	{ "Kill!",		  "You've killed an enemy player"		 },
	{ "Assist",		  "You've assisted in a kill"			 },
	{ "Assist",		  "You've assisted in a kill"			 },
	{ "Assist",		  "You've assisted in a kill"			 },
	{ "First Blood!",	  "You've gotten the first kill"		 },
	{ "Headshot",		  "You've killed an enemy with a headshot"	 },
	{ "Payback!",		  "You've gotten revenge"			 },
	{ "Assassination!",	  "You've knifed an enemy player"		 },
	{ "Comeback!",		  "Come back from a streak of deaths"		 },
	{ "Comeback!",		  "Come back from a streak of deaths"		 },
	{ "Final Kill!",	  "You've gotten the final kill"		 },
	{ "Area Secure!",	  "You've captured the enemy flag"		 },
	{ "Area Secure!",	  "You've captured the enemy flag"		 },
	{ "One shot... one kill", "You've killed an enemy player with one shot"	 },
	{ "Buzzkill!",		  "You've cut an enemy short of their killstreak"},
	{ "Stuck!",		  "You've stuck a semtex to another player"	 }
}

static const g_iKillbonuses[eKillbonuses][2] = {
	{ 50,	0 },
	{ 10,	1 },
	{ 20,	1 },
	{ 35,	1 },
	{ 100,	1 },
	{ 50,	1 },
	{ 50,	1 },
	{ 200,	1 },
	{ 75,	1 },
	{ 150,	1 },
	{ 300,	1 },
	{ 100,	2 },
	{ 50,	2 },
	{ 50,	1 },
	{ 100,	1 },
	{ 50,	2 }
};

static bool:g_bIsFirstKill;
static g_iKiller;

enum _:ePlayerStats {
	LastKiller,
	DeathCounter,
	LastHitter
};
static g_iPlayerStats[MAXPLAYERS+1][ePlayerStats];

static g_bIsBot;

#if defined FLAGS_ROUNDXP
	static g_szFlagRound[64];
#endif

#if defined FLAGS_MATCHXP
	static g_szFlagMatch[64];
#endif

public plugin_precache() {
	precache_sound(SOUND_BONUS);
	precache_sound(SOUND_PAYBACK);
	precache_sound(SOUND_HEADSHOT);
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0");
	register_logevent("logevent_round_end", 2, "1=Round_End");
	
	#if !defined _csdm_included
		RegisterHam(Ham_Spawn,	"player", "ham_PlayerSpawn_Post", 1);
	#endif
	
	formatex(g_szFlagRound, 63, "You've received ^4%dXP ^1for winning the flag round", FLAGS_ROUNDXP);
	formatex(g_szFlagMatch, 63, "You've received ^4%dXP ^1for winning the flag match", FLAGS_MATCHXP);
}

public event_round_start() {
	g_bIsFirstKill = false;
	g_iKiller = 0;
	new size = get_playersnum();
	for (new i; i < size; i++) {
		arrayset(g_iPlayerStats[i], 0, ePlayerStats);
	}
}

public logevent_round_end() {
	if (g_iKiller) {
		triggerBonus(g_iKiller, BONUS_FINALKILL);
	}
}

public client_connect(id) {
	if (is_user_bot(id)) {
		flag_set(g_bIsBot,id);
	}
}

public client_disconnect(id) {
	resetPlayerStats(id);
}

resetPlayerStats(id) {
	flag_unset(g_bIsBot,id);
	arrayset(g_iPlayerStats[id], 0, ePlayerStats);
}

public cs_fw_player_assist(victim, assister, killer, Float:damage, Float:lastattack) {
	if (assister == killer) {
		return;
	}
	
	static iDmg;
	iDmg = floatround(damage);
	switch (iDmg) {
		case 0..ASSIST_ZONE_1: {
			triggerBonus(assister, BONUS_ASSIST1);
		}
		case (ASSIST_ZONE_1+1)..ASSIST_ZONE_2: {
			triggerBonus(assister, BONUS_ASSIST2);
		}
		default: {
			triggerBonus(assister, BONUS_ASSIST3);
		}
	}
}

public client_damage(attacker, victim, damage, wpnindex, hitplace, TA) {
	if (!is_user_connected(attacker) || TA) {
		return PLUGIN_HANDLED;
	}
		
	if (hitplace == HIT_HEAD) {
		mw3_playSound(attacker, SOUND_HEADSHOT);
	}
	
	if (g_iPlayerStats[victim][LastHitter] != attacker)  {
		g_iPlayerStats[victim][LastHitter] = attacker;
		if (wpnindex == CSW_SCOUT || wpnindex == CSW_AWP) {
			new iHealth = pev(victim, pev_health)+damage
			if (damage  >= iHealth) {
				triggerBonus(attacker, BONUS_ONEHITONEKILL);
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

#if defined _csdm_included
public csdm_PostSpawn(id, bool:fake) {
	if (fake) {
		return PLUGIN_CONTINUE;
	}
	
	g_iPlayerStats[id][LastHitter] = 0;
	return PLUGIN_CONTINUE;
}

public csdm_PostDeath(killer, victim, headshot, const weapon[]) {
	if (!is_user_connected(killer)) {
		return PLUGIN_CONTINUE;
	}
	
	if (killer == victim || get_user_team(killer) == get_user_team(victim)) {
		return PLUGIN_CONTINUE;
	}
	
	triggerBonus(killer, BONUS_NONE);
	g_iKiller = killer;
	if (!is_user_connected(victim)) {
		return PLUGIN_CONTINUE;
	}
		
	g_iPlayerStats[victim][LastHitter] = 0;
	if (!g_bIsFirstKill) {
		g_bIsFirstKill = true;
		triggerBonus(killer, BONUS_FIRSTBLOOD);
		mw3_createTutorMsg(0, killer, Tutor_Red, 5.0, g_szKillbonuses[BONUS_FIRSTBLOOD][0]);
	}
	
	if (headshot) {
		triggerBonus(killer, BONUS_HEADSHOT);
	}
		
	if (victim == g_iPlayerStats[killer][LastKiller]) {
		client_cmd(victim, "spk %s", SOUND_PAYBACK);
		g_iPlayerStats[killer][LastKiller] = 0;
		triggerBonus(killer, BONUS_PAYBACK);
		mw3_createTutorMsg(victim, killer, Tutor_Red, 5.0, "Has gotten revenge!");
	}
	g_iPlayerStats[victim][LastKiller] = killer;

	if (equal(weapon, "knife")) {
		triggerBonus(killer, BONUS_ASSASSINATION);
	}
	
	if (g_iPlayerStats[killer][DeathCounter] > 4) {
		g_iPlayerStats[killer][DeathCounter] = 0;
		triggerBonus(killer, BONUS_COMEBACK2);
	} else if (g_iPlayerStats[killer][DeathCounter] > 2) {
		g_iPlayerStats[killer][DeathCounter] = 0;
		triggerBonus(killer, BONUS_COMEBACK);
	}
	
	return PLUGIN_CONTINUE;
}
#else
public ham_PlayerSpawn_Post(id) {
	if (!is_user_alive(id)) {
		return HAM_IGNORED;
	}
	
	g_iPlayerStats[id][LastHitter] = 0;
	return HAM_IGNORED;
}

public client_death(killer, victim, wpnindex, hitplace, tk) {
	if (!is_user_connected(killer)) {
		return PLUGIN_CONTINUE;
	}
	
	if (killer == victim || tk) {
		return PLUGIN_CONTINUE;
	}
	
	triggerBonus(killer, BONUS_NONE);
	g_iKiller = killer;
	if (!is_user_connected(victim)) {
		return PLUGIN_CONTINUE;
	}
		
	g_iPlayerStats[victim][LastHitter] = 0;
	if (!g_bIsFirstKill) {
		g_bIsFirstKill = true;
		triggerBonus(killer, BONUS_FIRSTBLOOD);
		mw3_createTutorMsg(0, killer, Tutor_Red, 5.0, g_szKillbonuses[BONUS_FIRSTBLOOD][0]);
	}
	
	if (hitplace == HIT_HEAD) {
		triggerBonus(killer, BONUS_HEADSHOT);
	}
		
	if (victim == g_iPlayerStats[killer][LastKiller]) {
		client_cmd(victim, "spk %s", SOUND_PAYBACK);
		g_iPlayerStats[killer][LastKiller] = 0;
		triggerBonus(killer, BONUS_PAYBACK);
		mw3_createTutorMsg(victim, killer, Tutor_Red, 5.0, "Has gotten revenge!");
	}
	g_iPlayerStats[victim][LastKiller] = killer;

	if (wpnindex == CSW_KNIFE) {
		triggerBonus(killer, BONUS_ASSASSINATION);
	}
	
	if (g_iPlayerStats[killer][DeathCounter] > 4) {
		g_iPlayerStats[killer][DeathCounter] = 0;
		triggerBonus(killer, BONUS_COMEBACK2);
	} else if (g_iPlayerStats[killer][DeathCounter] > 2) {
		g_iPlayerStats[killer][DeathCounter] = 0;
		triggerBonus(killer, BONUS_COMEBACK);
	}
}
#endif

triggerBonus(id, eKillbonuses:iBonus) {
	if (flag_get(g_bIsBot, id)) {
		return false;
	}

	static szMessage[64], szSound[64], iExp;
	iExp = (g_iKillbonuses[iBonus][0] * EXP_MULTIPLIER) + (access(id, ADMIN_LEVEL_A) ? ADMIN_EXP : 0);
	if (iBonus != BONUS_POSITIONSECURE) {
		formatex(szSound, 63, SOUND_BONUS);
	} else {
		szSound[0] = '^0';
	}
	
	switch (g_iKillbonuses[iBonus][1]) {
		case 0: {
			formatex(szMessage, 63, "+%dXP", iExp);
			mw3_set_message(id, szMessage, szSound, effect_Fade, g_iHUDKillbonus[0], g_iHUDKillbonus[1], g_iHUDKillbonus[2], g_flHUDLoc[0], g_flHUDLoc[1]);
		}
		case 1: {
			formatex(szMessage, 63, "+%dXP^n%s", iExp, g_szKillbonuses[iBonus][0]);
			mw3_set_message(id, szMessage, szSound, effect_Fade, g_iHUDKillbonus[0], g_iHUDKillbonus[1], g_iHUDKillbonus[2], g_flHUDLoc[0], g_flHUDLoc[1]);
		}
		case 2: {
			formatex(szMessage, 63, "%s^n%s [+%dXP]", g_szKillbonuses[iBonus][0], g_szKillbonuses[iBonus][1], iExp);
			mw3_set_message(id, szMessage, szSound, effect_Fade, g_iHUDKillbonus[0], g_iHUDKillbonus[1], g_iHUDKillbonus[2]);
		}
	}
	
	mw3_exp_changeUserExp(id, iExp);
	return true;
}

public csf_flag_taken(id) {
	if (get_playersnum() < MIN_FOR_FLAGS) {
		return;
	}
	
	mw3_createTutorMsg(0, id, Tutor_Green, 5.0, g_szKillbonuses[BONUS_POSITIONSECURE][0]);
	triggerBonus(id, BONUS_POSITIONSECURE);
}

public csf_flag_taken_assist(id) {
	if (get_playersnum() < MIN_FOR_FLAGS) {
		return;
	}
	
	triggerBonus(id, BONUS_POSITIONSECURE2);
}

#if defined FLAGS_ROUNDXP
public csf_round_won(CsTeams:team) {
	if (get_playersnum() < MIN_FOR_FLAGS) {
		return;
	}

	static iPlayers[32], iCount;
	get_players(iPlayers, iCount, "ce", team == CS_TEAM_CT ? "CT" : "TERRORIST");
	for (new id; id < iCount; id++) {
		mw3_exp_changeUserExp(id, FLAGS_ROUNDXP);
		mw3_printColor(id, g_szFlagRound);
	}
}
#endif

#if defined FLAGS_MATCHXP
public csf_match_won(CsTeams:team) {
	if (get_playersnum() < MIN_FOR_FLAGS) {
		return;
	}
	
	static iPlayers[32], iCount;
	get_players(iPlayers, iCount, "ce", team == CS_TEAM_CT ? "CT" : "TERRORIST");
	for (new id; id < iCount; id++) {
		mw3_exp_changeUserExp(id, FLAGS_MATCHXP);
		mw3_printColor(id, g_szFlagRound);
	}
}
#endif
