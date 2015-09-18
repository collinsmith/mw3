#if defined _MW3_StaticIcon
	#endinput
#endif
#define _MW3_StaticIcon

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib MW3_StaticIcon
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib MW3_StaticIcon
	#endif
#else
	#pragma library MW3_StaticIcon
#endif

#include <cstrike>

enum iconStatus {
	icon_Hidden = 0,
	icon_Showing,
	icon_None
};

native mw3_si_createIcon(ent, CsTeams:team, bool:canWithHacker, spriteID, const spritePath[]); // return ent id
native bool:mw3_si_removeIcon(ent); // return true/false
native iconStatus:mw3_si_setIconState(ent, iconStatus:iconState); // return icon.iconStatus
native iconStatus:mw3_si_getIconState(ent); // return icon.iconStatus
native mw3_si_changeIconTeam(ent, CsTeams:team); // must enter sprite id returned in _createIcon