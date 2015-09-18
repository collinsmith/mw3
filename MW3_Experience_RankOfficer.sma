#include <amxmodx>
#include <MW3_Core>
#include <MW3_Experience>

static const Plugin [] = "MW3 - XP (Ranking Officer)";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

static const SOUND_RANKOFFICER[] = "buttons/bell1.wav";
static g_iHighestRankID;

public plugin_precache() {
	precache_sound(SOUND_RANKOFFICER);
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
}

public client_connect(id) {
	checkRankingOfficer(id);
}

public client_disconnect(id) {
	/**
	 * Yes, I know that this means they need to gain XP to become the new ranking
	 * officer, but it's better then a 32 player loop
	 */
	if (id == g_iHighestRankID) {
		g_iHighestRankID = 0;
	}
}

public mw3_fw_exp_gainExp(id, xp_gained, xp_before) {
	checkRankingOfficer(id);	
}

checkRankingOfficer(id) {
	if (!g_iHighestRankID || mw3_exp_getUserExp(g_iHighestRankID) < mw3_exp_getUserExp(id)) {
		g_iHighestRankID = id;

		new szPlayerName[32], szRankName[32];
		mw3_exp_getRankName(mw3_exp_getUserRank(g_iHighestRankID), szRankName, 31);
		get_user_name(g_iHighestRankID, szPlayerName, 31);
		
		mw3_printColor(0, "^4%s ^3is now the new highest ranking officer in the server at ^1%s", szPlayerName, szRankName);
		client_cmd(0, "spk %s", SOUND_RANKOFFICER);
	}
}
