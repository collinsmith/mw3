#include <amxmodx>
#include <MW3_Core_Const>
#include <hamsandwich>

new const Plugin [] = "MW3 - Kill Assist";
new const Author [] = "Tirant";
new const Version[] = "0.0.1";

#define isUserConnected(%1)	(g_bIsConnected &   (1 << (%1 & 31)))
#define connectUser(%1)		(g_bIsConnected |=  (1 << (%1 & 31)))
#define disconnectUser(%1)	(g_bIsConnected &= ~(1 << (%1 & 31)))
static g_bIsConnected;

enum _:Storage {
	Attacker,
	Float:Damage,
	Float:LastAttack
};

static Array:g_aCurAssists[MAXPLAYERS+1];

enum _:StorageShadow {
	PlayerID,
	Index
};

static Array:g_aCurShadows[MAXPLAYERS+1];

static g_iMaxPlayers;

enum ForwardedEvents {
	fwDummy,
	fwAssist
};

static g_Forwards[ForwardedEvents];

enum ResetModes {
	reset_myAssists,
	reset_theirAssists,
	reset_bothAssists
};

public plugin_precache() {
	for (new i = 1; i < 33; i++) {
		g_aCurAssists[i] = ArrayCreate(Storage);
		g_aCurShadows[i] = ArrayCreate(StorageShadow);
	}
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	RegisterHam(Ham_TakeDamage, "player", "ham_TakeDamage", 0);
	RegisterHam(Ham_Killed,     "player", "ham_Killed",     0);
	
	g_Forwards[fwAssist] = CreateMultiForward("cs_fw_player_assist", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL, FP_FLOAT, FP_FLOAT);
	
	g_iMaxPlayers = get_maxplayers();
}

public client_connect(id) {
	connectUser(id);
}

public client_disconnect(id) {
	disconnectUser(id);
	resetAssists(id, reset_bothAssists);
}

public ham_Killed(victim, killer, shouldgib) {
	forwardAssists(victim, killer);
	resetAssists(victim, reset_myAssists);
}

public ham_TakeDamage(victim, useless, attacker, Float:damage, damagebits) {
	if (victim == attacker || !isUserConnected(victim) || !isUserConnected(attacker)) {
		return HAM_IGNORED;
	}
	
	createAssist(victim, attacker, damage);
	return HAM_IGNORED;
}

createAssist(victim, attacker, Float:damage) {
	static size;
	size = ArraySize(g_aCurAssists[victim]);
	
	static storage[Storage], shadow[StorageShadow];
	for (new i; i <= size; i++) {
		if (i == size) {
			storage[Attacker  ] = attacker;
			storage[Damage    ] = _:damage;
			storage[LastAttack] = _:get_gametime();
			ArrayPushArray(g_aCurAssists[victim], storage);
			
			shadow[PlayerID] = victim;
			shadow[Index   ] = size;
			ArrayPushArray(g_aCurShadows[attacker], shadow);
		} else {
			ArrayGetArray(g_aCurAssists[victim], i, storage);
			if (storage[Attacker] == attacker) {
				storage[Damage    ] += damage;
				storage[LastAttack] = _:get_gametime();
				ArraySetArray(g_aCurAssists[victim], i, storage);
				break;
			}
		}
	}
}

forwardAssists(id, killer) {
	static size;
	size = ArraySize(g_aCurAssists[id]);
	
	static storage[Storage];
	for (new i; i < size; i++) {
		ArrayGetArray(g_aCurAssists[id], i, storage);
		if (storage[Damage] > 0.0) {
			ExecuteForward(g_Forwards[fwAssist], g_Forwards[fwDummy], id, storage[Attacker], killer, storage[Damage], storage[LastAttack]);
		}
	}
}

resetAssists(id, ResetModes:mode) {
	static i, j, size;
	static storage[Storage];
	static shadow[StorageShadow];
	switch (mode) {
		case reset_myAssists: {
			ArrayClear(g_aCurAssists[id]);
			for (i = 1; i <= g_iMaxPlayers; i++) {
				size = ArraySize(g_aCurShadows[i]);
				for (j = 0; j < size; j++) {
					ArrayGetArray(g_aCurShadows[i], j, shadow);
					if (shadow[PlayerID] == id) {
						ArrayDeleteItem(g_aCurShadows[i], j);
						break;
					}
				}
			}
		}
		case reset_theirAssists: {
			size = ArraySize(g_aCurShadows[id]);
			for (i = 0; i < size; i++) {
				ArrayGetArray(g_aCurShadows[id], i, shadow);
				ArrayGetArray(g_aCurAssists[shadow[PlayerID]], shadow[Index], storage);
				storage[Damage] = _:0.0;
				ArraySetArray(g_aCurAssists[shadow[PlayerID]], shadow[Index], storage);
			}
			ArrayClear(g_aCurShadows[id]);
		}
		case reset_bothAssists: {
			ArrayClear(g_aCurAssists[id]);
			for (i = 1; i <= g_iMaxPlayers; i++) {
				size = ArraySize(g_aCurShadows[i]);
				for (j = 0; j < size; j++) {
					ArrayGetArray(g_aCurShadows[i], j, shadow);
					if (shadow[PlayerID] == id) {
						ArrayDeleteItem(g_aCurShadows[i], j);
						break;
					}
				}
			}
			
			size = ArraySize(g_aCurShadows[id]);
			for (i = 0; i < size; i++) {
				ArrayGetArray(g_aCurShadows[id], i, shadow);
				ArrayGetArray(g_aCurAssists[shadow[PlayerID]], shadow[Index], storage);
				storage[Damage] = _:0.0;
				ArraySetArray(g_aCurAssists[shadow[PlayerID]], shadow[Index], storage);
			}
			ArrayClear(g_aCurShadows[id]);
		}
	}
}
