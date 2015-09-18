#include <amxmodx>
#include <hamsandwich>
#include <MW3_Core>
#include <MW3_Experience>
#include <MW3_Messages>
#include <MW3_Commands>

#define FLAG_EXP ADMIN_RCON

static const Plugin [] = "MW3 - XP (HUD)";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const HUD_HEADER[] = "[MW3]";

static g_msgStatusText;

static const SOUND_LEVEL[] = "mw3/levelup.wav";
static const g_iHUDRank[3] = { 120, 000, 120 };

public plugin_precache() {
	precache_sound(SOUND_LEVEL);
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	register_concmd("mw3_setrank",	"cmdSetRank", FLAG_EXP, " <name> <rank>");
	register_concmd("mw3_addxp",	"cmdAddExperience", FLAG_EXP, " <name> <experience>");
	
	RegisterHam(Ham_Spawn,	"player", "ham_PlayerSpawn_Post", 1);
	
	mw3_command_register("playerranks", "cmdPlayerRanks", _, "Opens a window display all players and their ranks");
	mw3_command_register("who", "cmdPlayerRanks");
	
	g_msgStatusText = get_user_msgid("StatusText");
}

public cmdPlayerRanks(id) {
	new players[32], num, pid;
	get_players(players, num);
	
	static g_szPlayersMotD[2047], szTemp[128];
	
	static szLocalBeginning[512];
	if (szLocalBeginning[0] == '^0') {
		add(szLocalBeginning, 511, "<html><body bgcolor=^"#474642^"><font size=^"3^" face=^"courier new^" color=^"FFFFFF^"><center>");
		formatex(szTemp, 127, "<h1>%s: Player List v%s</h1>By %s<br><br>", _pluginName, _pluginVersion, _pluginAuthor);
		add(szLocalBeginning, 511, szTemp);
		add(szLocalBeginning, 511, "<STYLE TYPE=^"text/css^"><!--TD{color: ^"FFFFFF^"}---></STYLE><table border=^"1^"><tr><td></td><td>Name</td><td>Level</td><td>Experience</td></tr>");
	}
	copy(g_szPlayersMotD, 2047, szLocalBeginning);
	
	new szPlayerName[32];
	for (new i; i < num; i++) {
		pid = players[i];
		
		get_user_name(pid, szPlayerName, 31);
		formatex(szTemp, 127, "<tr><td>%d.</td><td>%s</td><td>%d</td><td>%d</td></tr>", i+1, szPlayerName, mw3_exp_getUserRank(pid), mw3_exp_getUserExp(pid));
		add(g_szPlayersMotD, 2047, szTemp);
	}
	
	static const FORMAT_END[] = "</table></center></font></body></html>";
	add(g_szPlayersMotD, 2047, FORMAT_END);
	
	static szLocalTitle[64];
	if (szLocalTitle[0] == '^0') {
		formatex(szLocalTitle, 63, "%s: Current Player Ranks", _pluginName);
	}
	show_motd(id, g_szPlayersMotD, szLocalTitle);
}

public ham_PlayerSpawn_Post(id) {
	if (!is_user_alive(id)) {
		return HAM_IGNORED;
	}
	
	displayHUD(id);
	return HAM_IGNORED;
}

public mw3_fw_exp_rankUp(id, rank) {
	static szPlayerName[32], szRankName[32], szMessage[64];
	mw3_exp_getRankName(rank, szRankName, 31);
	formatex(szMessage, 63, "You've been promoted!^n%s", szRankName);
	mw3_set_message(id, szMessage, SOUND_LEVEL, effect_Write, g_iHUDRank[0], g_iHUDRank[1], g_iHUDRank[2]);

	get_user_name(id, szPlayerName, 31);
	mw3_printColor(0, "^3%s^1 has ranked up and is now a ^4%s^1", szPlayerName, szRankName);
	
	displayHUD(id);
}

public mw3_fw_exp_gainExp(id, xp_gained, xp_before) {
	displayHUD(id);
}

displayHUD(id) {
	static szHUD[128], iRank, iXPCur, iXPNext, szRankName[32];
	iRank	 = mw3_exp_getUserRank(id);
	iXPCur	 = mw3_exp_getUserExp(id);
	iXPNext	 = mw3_exp_getRankExp(iRank);
	mw3_exp_getRankName(iRank, szRankName, 31);
	formatex(szHUD, 127, "%s %d/%d (%d) %s (%d)", HUD_HEADER, iXPCur, iXPNext, clamp(iXPNext-iXPCur, 0), szRankName, iRank);
	
	message_begin(MSG_ONE_UNRELIABLE, g_msgStatusText, _, id); {
	write_byte(0);
	write_string(szHUD);
	} message_end();
}

public cmdSetRank(id, level, cid) {
	if(!cmd_access(id, level, cid, 3)) {
		return PLUGIN_HANDLED;
	}
		
	new szTarget[32], player;
    	read_argv(1, szTarget, 31);
	player = cmd_target(id, szTarget, 8);
   	if(!player) {
		client_print(id, print_console, "%s Invalid player index (%d)", HUD_HEADER, player);
		return PLUGIN_CONTINUE;
	}
	
	read_argv(2, szTarget, 31);
	if (!is_str_num(szTarget)) {
		client_print(id, print_console, "%s Invalid rank entered (%s)", HUD_HEADER, szTarget);
		return PLUGIN_CONTINUE;
	}
	
	
	new iRank = str_to_num(szTarget)
	iRank = mw3_exp_setUserRank(id, iRank);
	if (iRank) {
		get_user_name(player, szTarget, 31);
		client_print(id, print_console, "%s You have set %s's to rank %d", HUD_HEADER, szTarget, iRank);
		
		new szRankName[32];
		mw3_exp_getRankName(player, szRankName, 31);
		mw3_printColor(player, "An admin has set your rank to ^4%d^1 (^3%s^1)", iRank, szRankName);
		
		new szAuth[32];
		get_user_authid(id, szAuth, 31);
		get_user_authid(player, szTarget, 31);
		mw3_log("[RANK] Admin [%s] changed player [%s] rank to %d (%s)", szAuth, szTarget, iRank, szRankName);
	}
	
	return PLUGIN_CONTINUE;
}

public cmdAddExperience(id, level, cid) {
	if(!cmd_access(id, level, cid, 3)) {
		return PLUGIN_HANDLED;
	}
		
	static szTarget[32], player;
    	read_argv(1, szTarget, 31);
	player = cmd_target(id, szTarget, 8);
   	if(!player) {
		client_print(id, print_console, "%s Invalid player index (%d)", HUD_HEADER, player);
		return PLUGIN_CONTINUE;
	}
	
	read_argv(2, szTarget, 31);
	if (!is_str_num(szTarget)) {
		client_print(id, print_console, "%s Invalid experience amount entered (%s)", HUD_HEADER, szTarget);
		return PLUGIN_CONTINUE;
	}
	
	new iExp = str_to_num(szTarget);
	iExp = mw3_exp_changeUserExp(id, iExp);
	if (iExp > -1) {
		get_user_name(player, szTarget, 31);
		client_print(id, print_console, "%s You have awarded %s with %d XP", HUD_HEADER, szTarget, iExp);
		mw3_printColor(player, "An admin has awarded you with ^4%d^1XP", iExp);
		
		new szAuth[32];
		get_user_authid(id, szAuth, 31);
		get_user_authid(player, szTarget, 31);
		mw3_log("[EXP] Admin [%s] awarded player [%s] with %d XP (%d)", szAuth, szTarget, iExp, mw3_exp_getUserExp(player));
	}
	
	return PLUGIN_CONTINUE;
}
