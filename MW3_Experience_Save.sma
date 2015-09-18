#include <amxmodx>
#include <sqlvault_ex>

#include <MW3_Experience>
#include <MW3_Core>
#include <MW3_Commands>

//#define USES_MySql

static const Plugin [] = "MW3 - XP (Save)";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const DEFAULT_NAME[] = "MW3 Player";
static VaultName[] = "MW3_Experience";
new SQLVault:g_SqlVault;

#define TASK_GetKey 64483
static g_iMaxPlayers;
static g_szAuthID[MAXPLAYERS+1][35];
static g_szTopPlayersMotD[2048];

enum _:VaultData {
	vault_Exp,
	vault_Name
};

static const g_szVaultData[][] = {
	"exp",
	"name"
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
	
	mw3_command_register("top15", "getTop15", _, "Displays a window containing the top number of players");
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
	if (!is_user_bot(id)) {
		getSteamID(id);
	} else {
		mw3_exp_setUserRank(id, random_num(1, mw3_exp_getMaxRank()), false);
	}
}

public client_disconnect(id) {
	if (!is_user_bot(id)) {
		remove_task(id+TASK_GetKey);
		saveLevel(id);
	}
	g_szAuthID[id][0] = '^0';
}

public getSteamID(taskid) {
	if (taskid > g_iMaxPlayers) {
		taskid -= TASK_GetKey;
	}
	
	new szTempAuthID[35];
	get_user_authid(taskid, szTempAuthID, 34);
	if (szTempAuthID[0] == '^0' || equali(szTempAuthID, "STEAM_ID_PENDING")) {
		set_task(1.0, "getSteamID", taskid+TASK_GetKey);
	} else {
		copy(g_szAuthID[taskid], 34, szTempAuthID);
		loadLevel(taskid);
	}
}

loadLevel(id) {
	sqlv_connect(g_SqlVault);
	new exp = sqlv_get_num_ex(g_SqlVault, g_szAuthID[id], g_szVaultData[vault_Exp]);
	sqlv_disconnect(g_SqlVault);
	mw3_exp_setUserExp(id, exp, false);
}

saveLevel(id) {
	if (g_szAuthID[id][0] == '^0' || equali(g_szAuthID[id], "STEAM_ID_PENDING")) {
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
	
	sqlv_connect(g_SqlVault); {
	sqlv_set_num_ex (g_SqlVault, g_szAuthID[id], g_szVaultData[vault_Exp ], mw3_exp_getUserExp(id));
	sqlv_set_data_ex(g_SqlVault, g_szAuthID[id], g_szVaultData[vault_Name], szPlayerName);
	} sqlv_disconnect(g_SqlVault);
}

public getTop15(id) {
	getTopX(id, 15);
}

public getTopX(id, iTopNum) {
	if (g_SqlVault == Invalid_SQLVault) {
		return;
	}
	
	new tempstring[128];
	if (g_szTopPlayersMotD[0] == '^0') {
		static Array:aVaultData, iVaultNum;
		iVaultNum = sqlv_read_all_ex(g_SqlVault, aVaultData);
		iVaultNum /= VaultData;
		ArraySort(aVaultData, "sortTopByExperience");

		if (iVaultNum < iTopNum) {
			iTopNum = iVaultNum;
		}
		
		new eVaultData[SQLVaultEntry], szPlayerName[32];
		add(g_szTopPlayersMotD, 2047, "<html><body bgcolor=^"#474642^"><font size=^"3^" face=^"courier new^" color=^"FFFFFF^"><center>");
		formatex(tempstring, 127, "<h1>%s: Top %d Players v%s</h1>By %s<br><br>", _pluginName, iTopNum, _pluginVersion, _pluginAuthor);
		add(g_szTopPlayersMotD, 2047, tempstring);
		add(g_szTopPlayersMotD, 2047, "<STYLE TYPE=^"text/css^"><!--TD{color: ^"FFFFFF^"}---></STYLE><table border=^"1^"><tr><td>Rank</td><td>Name</td><td>Steam ID</td><td>Level</td><td>Experience</td></tr>");
		for(new i; i < iTopNum; i++) {
			ArrayGetArray(aVaultData, i, eVaultData);
			sqlv_get_data_ex(g_SqlVault, eVaultData[SQLVEx_Key1], g_szVaultData[vault_Name], szPlayerName, 31);
			formatex(tempstring, 127, "<tr><td>%d.</td><td> %s</td><td>%s</td><td>%d</td><td>%s</td></tr>", i+1, szPlayerName, eVaultData[SQLVEx_Key1], mw3_exp_queryRank(str_to_num(eVaultData[SQLVEx_Data])), eVaultData[SQLVEx_Data]);
			add(g_szTopPlayersMotD, 2047, tempstring);
		}
			
		add(g_szTopPlayersMotD, 2047, "</table></center></font></body></html>");
	}
	
	formatex(tempstring, 127, "%s: Top %d Players", _pluginName, iTopNum);
	show_motd(id, g_szTopPlayersMotD, tempstring);
}

public sortTopByExperience(Array:array, item1, item2, const data[], data_size) {
	static eVaultData[2][SQLVaultEntryEx];
	ArrayGetArray(array, item1, eVaultData[0]);
	ArrayGetArray(array, item2, eVaultData[1]);
	
	static isEqual[2];
	isEqual[0] = equal(g_szVaultData[vault_Exp], eVaultData[0][SQLVEx_Key2])
	isEqual[1] = equal(g_szVaultData[vault_Exp], eVaultData[1][SQLVEx_Key2])
	if (!isEqual[0] && !isEqual[1]) {
		return 0;
	} else if (!isEqual[0]) {
		return 1;
	} else if (!isEqual[1]) {
		return -1;
	}
	
	static iExperiences[2];
	iExperiences[0] = str_to_num(eVaultData[0][SQLVEx_Data]);
	iExperiences[1] = str_to_num(eVaultData[1][SQLVEx_Data]);
	if (iExperiences[0] == iExperiences[1]) {
		return 0;
	} else if (iExperiences[0] < iExperiences[1]) {
		return 1;
	} else {
		return -1;
	}
	
	return 0;
}
