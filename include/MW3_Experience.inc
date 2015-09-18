#if defined _MW3_Experience
	#endinput
#endif
#define _MW3_Experience

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib MW3_Experience
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib MW3_Experience
	#endif
#else
	#pragma library MW3_Experience
#endif

forward mw3_fw_exp_rankUp(id, rank);
forward mw3_fw_exp_gainExp(id, xp_gained, xp_before, xp_after);

native mw3_exp_changeUserExp(id, exp, bool:notifyLevelChange = true);
native mw3_exp_getUserExp(id);
native mw3_exp_setUserExp(id, exp, bool:notifyLevelChange = true);
	
native mw3_exp_setUserRank(id, rank, bool:notifyLevelChange = true);
native mw3_exp_getUserRank(id);
	
native mw3_exp_getRankName(rank, string[], length);
native mw3_exp_getRankExp(rank);
	
native mw3_exp_getMaxRank();
native mw3_exp_queryRank(exp);