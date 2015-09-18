#if defined _MW3_Messages
	#endinput
#endif
#define _MW3_Messages

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib MW3_Messages
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib MW3_Messages
	#endif
#else
	#pragma library MW3_Messages
#endif

enum MessageTypes {
	effect_Fade = 0,
	effect_Flicker,
	effect_Write
};

native mw3_set_message(id, const szMessage[], const szSound[] = {0}, MessageTypes:iMsgType, iRed, iGreen, iBlue, Float:flLocX = -1.00, Float:flLocY = 0.35)
