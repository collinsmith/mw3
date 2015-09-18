//#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <csx>
#include <hamsandwich>
#include <fakemeta>
#include <frc>
#include <screenfade_util>
#include <cvar_util>

#include <MW3_Core>

#define HUD_CHANNEL 2

static const Plugin [] = "MW3 - Damage Effects";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const cDamage[] = "x";
new const SOUND_BREATH[] = "mw3/hbb.wav";
new const SOUND_HITMARKER[] = "mw3/hit_marker.wav";

#define flag_get(%1,%2)		(g_playerInfo[%1] &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(g_playerInfo[%1] |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(g_playerInfo[%1] &= ~(1 << (%2 & 31)))

enum _:ePlayerInfo {
	info_isConnected,
	info_isAlive,
	info_isBot,
	info_isFlashed,
	info_isHealDelay
};

static g_playerInfo[ePlayerInfo];

enum _:ePlayerDelays {
	Float:delay_Heal,
	Float:delay_Damage,
	Float:delay_Flash
};

static Float:g_playerDelays[MAXPLAYERS+1][ePlayerDelays];

enum _:pCvars {
	CVAR_HEALDELAY,
	CVAR_SOUNDDELAY,
	CVAR_HITMARKER
};

enum _:CvarModes {
	Pointer,
	Value
};

static g_pCvars[CvarModes][pCvars];

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	RegisterHam(Ham_Spawn, "player", "ham_PlayerSpawn_Post", 1);
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage");
	
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
	
	g_pCvars[Pointer][CVAR_HITMARKER ] = CvarRegister("mw3_dmg_hitmarker", "1", "Show a hit marker when one player hits another", FCVAR_SERVER, true, 0.0, true, 1.0);
	g_pCvars[Pointer][CVAR_SOUNDDELAY] = CvarRegister("mw3_dmg_damagesound", "1.5", "Show a hit marker when one player hits another", FCVAR_SERVER, true, 0.0);
	g_pCvars[Pointer][CVAR_HEALDELAY ] = CvarRegister("mw3_dmg_healtime", "8.0", "Show a hit marker when one player hits another", FCVAR_SERVER, true, 0.0);
	
	CvarCache(g_pCvars[Pointer][CVAR_HITMARKER ], CvarType_Int,   g_pCvars[Value][CVAR_HITMARKER ]);
	CvarCache(g_pCvars[Pointer][CVAR_SOUNDDELAY], CvarType_Float, g_pCvars[Value][CVAR_SOUNDDELAY]);
	CvarCache(g_pCvars[Pointer][CVAR_HEALDELAY ], CvarType_Float, g_pCvars[Value][CVAR_HEALDELAY ]);
}

public plugin_precache() {
	precache_sound(SOUND_BREATH);
	precache_sound(SOUND_HITMARKER);
}

public client_putinserver(id) {
	flag_set(info_isConnected, id);
	if (is_user_bot(id)) {
		flag_set(info_isBot,id);
	}
}

public client_disconnect(id) {
	resetVars(id);
}

resetVars(id) {
	for (new i; i < ePlayerInfo; i++) {
		flag_unset(i,id);
	}
	
	for (new i; i < ePlayerDelays; i++) {
		g_playerDelays[id][i] = 0.0;
	}
}

public client_death(killer, victim, wpnindex, hitplace, TK) {
	flag_unset(info_isAlive,victim);
	flag_unset(info_isFlashed,victim);
	flag_unset(info_isHealDelay,victim);
}

public ham_PlayerSpawn_Post(id) {
	if (!is_user_alive(id)) {
		return HAM_IGNORED;
	}
	
	flag_set(info_isAlive,id);
	return HAM_IGNORED;
}

public ham_TakeDamage(victim, useless, attacker, Float:damage, damagebits) {
	if (g_pCvars[Value][CVAR_HEALDELAY] == 0.0) {
		return HAM_IGNORED;
	}
	
	static bool:isConnected, iHealth, bool:isTeamKill;
	isConnected = true;
	if (!flag_get(info_isConnected,attacker) || flag_get(info_isBot,attacker)) {
		isConnected = false;
	}
	
	if (!flag_get(info_isAlive,victim)) {
		return HAM_IGNORED;
	}
	
	iHealth = pev(victim, pev_health);
	if (iHealth == 100) {
		return HAM_IGNORED;
	}
	
	if (isConnected) {
		if (get_user_team(attacker) == get_user_team(victim) && victim != attacker) {
			isTeamKill = true;
		}
	}
	
	if (!isTeamKill) {
		if (isConnected && victim != attacker) {
			showDamageHUD(attacker);
		}
			
		if (!flag_get(info_isFlashed,victim)) {
			UTIL_ScreenFade(victim, {225, 25, 25}, g_pCvars[Value][CVAR_HEALDELAY]*0.15, g_pCvars[Value][CVAR_HEALDELAY]*0.85, (150-iHealth), FFADE_IN, false, false);
		}
		
		flag_set(info_isHealDelay,victim);
		g_playerDelays[victim][delay_Heal] = get_gametime() + g_pCvars[Value][CVAR_HEALDELAY];
	}
	
	return HAM_HANDLED;
}

showDamageHUD(id) {
	mw3_playSound(id, SOUND_HITMARKER);
	if (g_pCvars[Value][CVAR_HITMARKER]) {
		set_hudmessage(255, 255, 255, -1.0, -1.0, 0, 0.0, 0.5, 0.02, 0.02, HUD_CHANNEL);
		show_hudmessage(id, cDamage);
	}
}

public fw_PlayerPreThink(id) {
	if (!flag_get(info_isConnected,id) || flag_get(info_isBot,id) || g_pCvars[Value][CVAR_HEALDELAY] == 0.0) {
		return FMRES_IGNORED;
	}
		
	static Float:fGameTime;
	fGameTime = get_gametime();
	if (flag_get(info_isAlive,id)) {
		if (flag_get(info_isHealDelay,id)) {
			if (g_playerDelays[id][delay_Heal] < fGameTime) {
				set_pev(id, pev_health, 100.0);
				flag_unset(info_isHealDelay,id);
			} else if (g_playerDelays[id][delay_Damage] < fGameTime) {
				mw3_playSound(id, SOUND_BREATH);
				g_playerDelays[id][delay_Damage] = fGameTime + g_pCvars[Value][CVAR_SOUNDDELAY];
			}
			
		} else if (pev(id, pev_health) < 100) {
			flag_set(info_isHealDelay,id);
			g_playerDelays[id][delay_Heal] = fGameTime + g_pCvars[Value][CVAR_HEALDELAY];
		}
	}
	
	if (flag_get(info_isFlashed,id) && g_playerDelays[id][delay_Flash] < fGameTime) {
		flag_unset(info_isFlashed,id);
	}
	
	return FMRES_IGNORED;
}


public fw_FRC_preflash(flasher, flashed, flashbang, amount) {
	if (!flag_get(info_isConnected,flasher) || !flag_get(info_isConnected,flashed)) {
		return PLUGIN_HANDLED;
	}
		
	flag_set(info_isFlashed,flashed);
	new iFlashed = get_FRC_duration(flashed) + get_FRC_holdtime(flashed);
	g_playerDelays[flashed][delay_Flash] = get_gametime() + float(iFlashed / 10);
	if (flasher != flashed) {
		showDamageHUD(flasher);
	}
	
	return PLUGIN_CONTINUE;
}
