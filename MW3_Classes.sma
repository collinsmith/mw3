/*Class System
>Core Class Module
	Ability to register classes
	Perhaps possibility of registering custom weapons as well
>Standard Classes
	Loaded through a plugin
>Create-A-Class
	Clients create their classes which are loaded/saved on connect/disconnect

{
	Class Menu
	
	1. Rifleman
	...
	5. Grenadier
	
	6. Custom Classes
	
	7. Back
	8. Forward
	
	9. Exit
}

{
	My Classes
	
	1. M4 Set
	...
	6. Galil Set
	
	7. Modify Classes
	
	Back, Forward
	
	8. Back to Class Menu
	9. Exit
}

{
	Create-A-Class
	Class: M4A1 Set
	
	1. M4A1 Carbine // Level up weapon, add on "perks"
	2. P228 Compact // Level up weapon, add on "perks"
	3. Semtex
	
	4. Sleight of Hand
	5. Hardline
	6. SitRep
	
	7. Rename Class
	
	8. Back to My Classes
}

*/

#include <amxmodx>
#include <amxmisc>
#include <fm_cstrike>
#include <sqlvault_ex>

#include <MW3_Core>
#include <MW3_Perks>
#include <MW3_Scorechain>
#include <MW3_Commands>
#include <flags32>

#define MENU_OFFSET 25
//#define USES_MySql
#define SAVED_CLASSES		5
//#define SAVED_PERKS		3
#define SAVED_SCORECHAINS	3

static const Plugin [] = "MW3 - Class Module";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const DEFAULT_NAME[] = "MW3 Player";
static VaultName[] = "MW3_Classes";
static SQLVault:g_SqlVault;

#define TASK_GetKey 64483
static g_szAuthID[MAXPLAYERS+1][35];
static g_iMaxPlayers;

enum _:VaultData {
	vault_Name,
	vault_Primary,
	vault_Secondary,
	vault_Equiptment
};

static const g_szVaultData[][] = {
	"name",
	"primary",
	"secondary",
	"equiptment"
};

enum _:Class {
	c_Name[32],
	c_Primary,
	c_Secondary,
	c_Equiptment,
	c_Perks,
	c_Killstreaks
}
static Array:g_classes[MAXPLAYERS+1];
static g_curClass[MAXPLAYERS+1][Class];

//enum _:WeaponFields {
//	Exp,
//	Level
//};
//static g_iWeaponInfo[MAXPLAYERS+1][WeaponFields][CSW_P90+1];

enum eWeaponType {
	wep_Primary,
	wep_Secondary,
	wep_Grenade,
	wep_Knife,
	wep_Null
}

enum _:eMenuInfo {
	menu_class = 0,
	menu_perk,
	menu_endstring
}

static const g_iBPAmmo[][] = {
	{ -1,	-1  }, // 
	{ 26,	52  }, // P228
	{ -1,	-1  }, // 
	{ 20,	60  }, // Scout
	{ 1,	2   }, // HE Grenade
	{ 21,	49  }, // XM1014
	{ -1,	-1  }, // 
	{ 60,	180 }, // Mac-10
	{ 60,	180 }, // AUG
	{ 1,	1   }, // Smoke Grenade
	{ 30,	60  }, // Elite
	{ 40,	100 }, // Fiveseven
	{ 50,	150 }, // UMP45
	{ 30,	60  }, // SG550
	{ 70,	210 }, // Galil
	{ 50,	150 }, // Famas
	{ 24,	48  }, // USP
	{ 40,	80  }, // Glock
	{ 10,	30  }, // AWP
	{ 60, 	180 }, // MP5
	{ 100, 	200 }, // M249
	{ 24, 	48  }, // M3
	{ 60, 	180 }, // M4A1
	{ 60, 	180 }, // TMP
	{ 20, 	40  }, // G3SG1
	{ 1,	2   }, // Flashbang
	{ 14,	28  }, // Deagle
	{ 60,	180 }, // SG552
	{ 60,	180 }, // AK47
	{ -1,	-1  }, // 
	{ 100,	200 }  // P90
}

static const g_szWpnEntNames[][] = {
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "w;eapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};

static const g_szWeaponNames[][] = {
	"", "P228 Compact", "", "Schmidt Scout", "", "XM1014 M4", "", "Ingram MAC-10",
	"Steyr AUG A1", "", "Dual Elite Berettas", "FiveseveN", "UMP 45", "SG-550 Auto-Sniper",
	"IMI Galil", "Famas", "USP .45 ACP Tactical", "Glock 18C", "AWP Magnum Sniper", "MP5 Navy", "M249 Para Machinegun",
	"M3 Super 90", "M4A1 Carbine", "Schmidt TMP", "G3SG1 Auto-Sniper", "", "Desert Eagle .50 AE", "SG-552 Commando",
	"AK-47 Kalashnikov", "", "ES P90"
};

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	g_iMaxPlayers = get_maxplayers();
	
	#if defined USES_MySql
		new szHost[64], szUser[64], szPass[64], szDb[64];
		get_cvar_string("mw3_sql_host", szHost, 63);
		get_cvar_string("mw3_sql_user", szUser, 63);
		get_cvar_string("mw3_sql_pass", szPass, 63);
		get_cvar_string("mw3_sql_db",   szDb, 	63);
		g_SqlVault = sqlv_open(szHost, szUser, szPass, szDb, VaultName, false);
	#else
		g_SqlVault = sqlv_open_local(VaultName, false);
	#endif
	
	if (g_SqlVault == Invalid_SQLVault) {
		set_fail_state("SqlVault: Could not connect to database");
	} else {
		sqlv_init_ex(g_SqlVault);
	}
	
	mw3_command_register("cmd1", "cmd1");
	mw3_command_register("cmd2", "cmd2");
}

public showClassesMenu() {
	/*
	Class Menu
	
	1. Rifleman
	...
	5. Grenadier
	
	6. Custom Classes
	
	7. Back
	8. Forward
	
	9. Exit
	*/
}

public showCustomClassMenu(id) {
	new menu = menu_create("My Classes", "customClassMenuPressed");
	
	static tempClass[Class], itemInfo[eMenuInfo], output[64];
	new size = ArraySize(g_classes[id]);
	for (new i; i < size; i++) {
		itemInfo[menu_class] = i+MENU_OFFSET;
		ArrayGetArray(g_classes[id], i, tempClass);
		formatex(output, 63, "\r%d. \w%s", i+1, tempClass[c_Name]);
		menu_additem(menu, tempClass[c_Name], itemInfo)
	}
	
	formatex(output, 63, "Back");
	menu_setprop(menu, MPROP_BACKNAME, output);
	formatex(output, 63, "Next");
	menu_setprop(menu, MPROP_NEXTNAME, output);
	formatex(output, 63, "Exit");
	menu_setprop(menu, MPROP_EXITNAME, output);
}

public customClassMenuPressed(id, menuid, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menuid);
		return PLUGIN_HANDLED;
	}
	
	static itemInfo[eMenuInfo], dummy;
	menu_item_getinfo(menuid, item, dummy, itemInfo, eMenuInfo-1, _, _, dummy);
	for (new i; i < eMenuInfo; i++) {
		itemInfo[i] -= MENU_OFFSET;
	}
	
	static tempClass[Class];
	ArrayGetArray(g_classes[id], itemInfo[menu_class], tempClass);
	mw3_printColor(id, "You've selected the ^4%s ^1class", tempClass[c_Name]);
	menu_destroy(menuid);
	return PLUGIN_HANDLED;
}

public showClassMenu(id, class) {
	new tempClass[Class];
	ArrayGetArray(g_classes[id], class, tempClass);
	new menuid = menu_create(tempClass[c_Name], "classMenuPressed");
	
	menu_addtext(menuid, "Weapons");
	menu_additem(menuid, g_szWeaponNames[tempClass[c_Primary]]);
	menu_additem(menuid, g_szWeaponNames[tempClass[c_Secondary]]);
	menu_addblank(menuid);
	
	new tempPerk[Perk], Array:perks = mw3_perks_getBitsPerksList(tempClass[c_Perks]);
	menu_addtext(menuid, "Perks");
	for (new i; i < ArraySize(perks) && i < 3; i++) {
		ArrayGetArray(perks, i, tempPerk);
		menu_additem(menuid, tempPerk[perk_Name]);
	}
	menu_addblank(menuid);
	
	menu_additem(menuid, "Save Changes");
	menu_addblank(menuid);
	
	menu_setprop(menuid, MPROP_EXITNAME, "Exit");
	
	menu_display(id, menuid);
}

public classMenuPressed(id, menuid, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menuid);
		return PLUGIN_HANDLED;
	}
	
	new access, info[1], name[32];
	menu_item_getinfo(menuid, item, access, info, 0, name, 31, access);
	mw3_printColor(id, "Selected: %s", name);
	return PLUGIN_HANDLED;
}

//public showCustomClassMenu() {
	/*
	M4A1 Set
	
	1. M4A1 Carbine // Level up weapon, add on "perks"
	2. P228 Compact // Level up weapon, add on "perks"
	3. Semtex
	
	4. Sleight of Hand
	5. Hardline
	6. SitRep
	
	7. Rename Class
	
	8. Create A Class
	*/
//}

public cmd1(id) {
	showClassMenu(id, 0);
}

public cmd2(id) {
	showPerkSelectionMenu(id, 0, 0);
}

public showPerkSelectionMenu(id, class, type) {
	static perk;
	perk = mw3_perks_getUserPerksByType(id, type);
	perk = mw3_perks_convertBitsToPerk(perk);
	
	static menu, output[64];
	mw3_perks_getPerkTypeName(type, output, 63);
	menu = menu_create(output, "perkMenuKeyPressed");
	
	static Array:perkList, size, tempPerk, perkInfo[Perk], itemInfo[eMenuInfo];
	itemInfo[menu_class] = class+MENU_OFFSET;
	perkList = mw3_perks_getPerkList(type);
	size = ArraySize(perkList);
	
	for (new i; i < size; i++) {
		tempPerk = ArrayGetCell(perkList, i);
		mw3_perks_getPerkInfo(tempPerk, perkInfo);
		itemInfo[menu_perk] = i+MENU_OFFSET;
		if (tempPerk == perk) {
			formatex(output, 63, "\w[\rX\w] \y%s", perkInfo[perk_Name]);
		} else {
			formatex(output, 63, "\w[  ] \y%s", perkInfo[perk_Name]);
		}
		menu_additem(menu, output, itemInfo);
	}
	
	formatex(output, 63, "Back");
	menu_setprop(menu, MPROP_BACKNAME, output);
	formatex(output, 63, "Next");
	menu_setprop(menu, MPROP_NEXTNAME, output);
	formatex(output, 63, "Exit");
	menu_setprop(menu, MPROP_EXITNAME, output);
	menu_display(id, menu);
}

public perkMenuKeyPressed(id, menuid, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menuid);
		//showCreateAClassMenu(id, class);
		return PLUGIN_HANDLED;
	}
	
	static itemInfo[eMenuInfo], dummy;
	menu_item_getinfo(menuid, item, dummy, itemInfo, eMenuInfo-1, _, _, dummy);
	for (new i; i < eMenuInfo; i++) {
		itemInfo[i] -= MENU_OFFSET;
	}
	
	static tempPerk[Perk];
	mw3_perks_getPerkInfo(itemInfo[menu_perk], tempPerk);
	
	// (itemInfo[menu_class]) = 
	mw3_perks_setUserPerksByType(id, tempPerk[PerkType], false);
	mw3_perks_addUserPerk(id, itemInfo[menu_perk]);
	
	static temp[32];
	mw3_perks_getPerkTypeName(tempPerk[PerkType], temp, 31);
	mw3_printColor(id, "You've changed your ^4%s ^1perk to ^4%s", temp, tempPerk[perk_Name]);
	
	menu_destroy(menuid);
	//showCreateAClassMenu(id, class);
	return PLUGIN_HANDLED;
}

public giveWeapons(id) {
	fm_strip_user_weapons(id);
	fm_give_item(id, g_szWpnEntNames[CSW_KNIFE]);
	
	static bool:hasScavenger;
	hasScavenger = mw3_perks_checkUserPerk(id, mw3_perks_getPerkByName("Scavenger"));

	giveWeapon(id, g_curClass[id][c_Primary  ], hasScavenger);
	giveWeapon(id, g_curClass[id][c_Secondary], hasScavenger);
}

giveWeapon(id, csw, bool:hasScavenger) {
	fm_give_item(id, g_szWpnEntNames[csw]);
	fm_cs_set_user_bpammo(id, csw, g_iBPAmmo[csw][hasScavenger]);
}

eWeaponType:getWeaponType(csw) {
	switch (csw) {
		case CSW_AK47, CSW_AUG, CSW_AWP, CSW_FAMAS, CSW_G3SG1, CSW_GALIL, CSW_M249,
		CSW_M3, CSW_M4A1, CSW_MAC10, CSW_MP5NAVY, CSW_P90, CSW_SCOUT, CSW_SG550,
		CSW_SG552, CSW_TMP, CSW_UMP45, CSW_XM1014: {
			return wep_Primary;
		}
		case CSW_GLOCK18, CSW_USP, CSW_P228, CSW_DEAGLE, CSW_FIVESEVEN, CSW_ELITE: {
			return wep_Secondary;
		}
		case CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE: {
			return wep_Grenade;
		}
		case CSW_KNIFE: {
			return wep_Knife;
		}
		case CSW_C4, CSW_VEST, CSW_VESTHELM: {
			return wep_Null;
		}
	}
	
	return wep_Null;
}

public plugin_end() {
	if (g_SqlVault == Invalid_SQLVault) {
		return;
	}
	
	new iPruneDays = get_cvar_num("mw3_exp_prune");
	if (iPruneDays) {
		iPruneDays *= -86400;
		sqlv_prune_ex(g_SqlVault, 0, get_systime(iPruneDays));
	}
	
	sqlv_close(g_SqlVault);
}

public client_putinserver(id) {
	g_classes[id] = ArrayCreate(Class);
	g_szAuthID[id][0] = '^0';
	if (!is_user_bot(id)) {
		getSteamID(id);
	}
}

public client_disconnect(id) {
	if (!is_user_bot(id)) {
		remove_task(id+TASK_GetKey);
		saveClasses(id);
	}
	g_szAuthID[id][0] = '^0';
	ArrayDestroy(g_classes[id]);
}

public getSteamID(taskid) {
	if (taskid > g_iMaxPlayers) {
		taskid -= TASK_GetKey;
	}
	
	static szTempAuthID[35];
	get_user_authid(taskid, szTempAuthID, 34);
	if (szTempAuthID[0] == '^0' || equal(szTempAuthID, "STEAM_ID_PENDING")) {
		set_task(1.0, "getSteamID", taskid+TASK_GetKey);
	} else {
		copy(g_szAuthID[taskid], 34, szTempAuthID);
		loadClasses(taskid);
	}
}

loadClasses(id) {
	static tempSaveID[45], tempItem[32], tempClass[Class], perkNum;
	if (!perkNum) {
		perkNum = mw3_perks_getPerkTypeNum();
	}
	
	ArrayClear(g_classes[id]);
	sqlv_connect(g_SqlVault); {
	for (new i; i < SAVED_CLASSES; i++) {
		formatex(tempSaveID, 44, "%s_class%d", g_szAuthID[id], i);
		sqlv_get_data_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Name], tempClass[c_Name], 31);
		tempClass[c_Primary    ] = sqlv_get_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Primary]);
		tempClass[c_Secondary  ] = sqlv_get_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Secondary]);
		tempClass[c_Equiptment ] = sqlv_get_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Equiptment]);
		tempClass[c_Perks      ] = 0;
		tempClass[c_Killstreaks] = 0;
		for (new j; j < perkNum; j++) {
			mw3_perks_getPerkTypeName(j, tempItem, 31);
			sqlv_get_data_ex(g_SqlVault, tempSaveID, tempItem, tempItem, 31); 
			tempClass[c_Perks] |= mw3_perks_convertPerkToBits(mw3_perks_getPerkByName(tempItem));
		}
		for (new j; j < SAVED_SCORECHAINS; j++) {
			formatex(tempItem, 31, "chain%d", j);
			sqlv_get_data_ex(g_SqlVault, tempSaveID, tempItem, tempItem, 31); 
			tempClass[c_Killstreaks] |= mw3_sc_convChainToBits(mw3_sc_getChainByName(tempItem));
		}
		ArrayPushArray(g_classes[id], tempClass);
	}
	} sqlv_disconnect(g_SqlVault);
}

saveClasses(id) {
	if (g_szAuthID[id][0] == '^0' || equal(g_szAuthID[id], "STEAM_ID_PENDING")) {
		mw3_log("Failed to save experience for player due to invalid authorization");
		return;
	}
	
	new szPlayerName[32];
	get_user_name(id, szPlayerName, 31);

	static const INVALID_STRINGS[][] = { ";", "'", "--", "/*", "*/", "xp_" };
	static Trie:tINVALID_STRINGS;
	if (tINVALID_STRINGS == Invalid_Trie) {
		tINVALID_STRINGS = TrieCreate();
		for (new i; i < sizeof INVALID_STRINGS; i++) {
			TrieSetCell(tINVALID_STRINGS, INVALID_STRINGS[i], i);
		}
	}
	
	new i;
	if (TrieGetCell(tINVALID_STRINGS, szPlayerName, i)) {
		copy(szPlayerName, 31, DEFAULT_NAME);
	}
	
	new size = ArraySize(g_classes[id]);
	for (new i; i < size; i++) {
		saveClass(id, i);
	}
}

saveClass(id, class) {
	if (g_szAuthID[id][0] == '^0' || equal(g_szAuthID[id], "STEAM_ID_PENDING")) {
		mw3_log("Failed to save experience for player due to invalid authorization");
		return;
	}
	
	static szPlayerName[32];
	get_user_name(id, szPlayerName, 31);

	static const INVALID_STRINGS[][] = { ";", "'", "--", "/*", "*/", "xp_" };
	static Trie:tINVALID_STRINGS;
	if (tINVALID_STRINGS == Invalid_Trie) {
		tINVALID_STRINGS = TrieCreate();
		for (new i; i < sizeof INVALID_STRINGS; i++) {
			TrieSetCell(tINVALID_STRINGS, INVALID_STRINGS[i], i);
		}
	}
	
	new i;
	if (TrieGetCell(tINVALID_STRINGS, szPlayerName, i)) {
		copy(szPlayerName, 31, DEFAULT_NAME);
	}
	
	static tempSaveID[45], tempItem[32], temp[32], tempClass[Class], perkNum, perk[Perk];
	ArrayGetArray(g_classes[id], class, tempClass);
	formatex(tempSaveID, 44, "%s_class%d", g_szAuthID[id], class);
	
	sqlv_connect(g_SqlVault); {
	sqlv_set_data_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Name], tempClass[c_Name]);
	sqlv_set_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Primary], tempClass[c_Primary]);
	sqlv_set_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Secondary], tempClass[c_Secondary]);
	sqlv_set_num_ex(g_SqlVault, tempSaveID, g_szVaultData[vault_Equiptment], tempClass[c_Equiptment]);
	new Array:perkList = mw3_perks_getBitsPerksList(tempClass[c_Perks]);
	perkNum = ArraySize(perkList);
	for (new i; i < perkNum; i++) {
		mw3_perks_getPerkInfo(ArrayGetCell(perkList, i), perk);
		mw3_perks_getPerkTypeName(perk[perk_TypeID], tempItem, 31);
		sqlv_set_data_ex(g_SqlVault, tempSaveID, tempItem, perk[perk_Name]); 
	}
	for (new j; j < SAVED_SCORECHAINS; j++) {
		formatex(tempItem, 31, "chain%d", j);
		mw3_sc_getChainName(j, temp, 31);
		sqlv_set_data_ex(g_SqlVault, tempSaveID, tempItem, temp);
	}
	} sqlv_disconnect(g_SqlVault);
}
