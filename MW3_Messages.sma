#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <MW3_Core>
#include <MW3_Commands>

#define flag_get(%1,%2)		(g_PlayerInfo[%1] &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(g_PlayerInfo[%1] |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(g_PlayerInfo[%1] &= ~(1 << (%2 & 31)))

static const Plugin [] = "MW3 - Messages";
static const Version[] = "0.0.2";
static const Author [] = "Tirant";

#define MESSAGE_MAX		10
#define MESSAGE_DELAY		2.0
#define MESSAGE_DELAY_WRITE	4.0

#define HUD_CHANNEL 1

enum MessageTypes {
	effect_Fade = 0,
	effect_Flicker,
	effect_Write
};

enum _:eMessageInfo {
	MessageTypes:MB_iMsgType = 0,
	MB_iRed,
	MB_iGreen,
	MB_iBlue,
	Float:MB_flXLoc,
	Float:MB_flYLoc,
	MB_szMessage[64],
	MB_szSound[64]
};
static Array:g_Messages[MAXPLAYERS+1];
static Float:g_fMessageDelay[MAXPLAYERS+1];

enum _:ePlayerInfo {
	g_bIsConnected,
	g_bIsBot,
	g_bAreSoundsEnabled
}
static g_PlayerInfo[ePlayerInfo];

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink");
	mw3_command_register("sounds", "cmdToggleSounds", _, "Toggles the message hud sounds on and off");
}

public plugin_natives() {
	register_library("MW3_Messages");
	
	register_native("mw3_set_message", "setMessage", 0);
}

public client_connect(id) {
	flag_set(g_bIsConnected,id);
	flag_set(g_bAreSoundsEnabled,id);
	if (is_user_bot(id)) {
		flag_set(g_bIsBot,id);
	}
	g_Messages[id] = ArrayCreate(eMessageInfo);
}

public client_disconnect(id) {
	ArrayDestroy(g_Messages[id]);
	resetPlayerInfo(id);
}

resetPlayerInfo(id) {
	for (new i; i < ePlayerInfo; i++) {
		flag_unset(i,id);
	}
}

public fw_PlayerPreThink(id) {
	if (!flag_get(g_bIsConnected,id) || flag_get(g_bIsBot,id)) {
		return FMRES_IGNORED;
	}
		
	static Float:fGameTime;
	fGameTime = get_gametime();
	
	static tempMessage[eMessageInfo];
	if (g_fMessageDelay[id] < fGameTime && ArraySize(g_Messages[id])) {
		ArrayGetArray(g_Messages[id], 0, tempMessage);
		switch (tempMessage[MB_iMsgType]) {
			case effect_Fade: {
				set_hudmessage(tempMessage[MB_iRed], tempMessage[MB_iGreen], tempMessage[MB_iBlue], tempMessage[MB_flXLoc], tempMessage[MB_flYLoc], _:tempMessage[MB_iMsgType], 0.0, MESSAGE_DELAY + 0.5, 0.1, 0.1, HUD_CHANNEL);
				g_fMessageDelay[id] = fGameTime + MESSAGE_DELAY;
			}
			case effect_Flicker: {
				set_hudmessage(tempMessage[MB_iRed], tempMessage[MB_iGreen], tempMessage[MB_iBlue], tempMessage[MB_flXLoc], tempMessage[MB_flYLoc], _:tempMessage[MB_iMsgType], 0.0, MESSAGE_DELAY + 0.5, 0.1, 0.1, HUD_CHANNEL);
				g_fMessageDelay[id] = fGameTime + MESSAGE_DELAY;
			}
			case effect_Write: {
				set_hudmessage(tempMessage[MB_iRed], tempMessage[MB_iGreen], tempMessage[MB_iBlue], tempMessage[MB_flXLoc], tempMessage[MB_flYLoc], _:tempMessage[MB_iMsgType], MESSAGE_DELAY_WRITE, 4.0, 0.1, 0.1 , HUD_CHANNEL);
				g_fMessageDelay[id] = fGameTime + MESSAGE_DELAY_WRITE;
			}
		}
		
		show_hudmessage(id, tempMessage[MB_szMessage]);
		if (flag_get(g_bAreSoundsEnabled,id) && tempMessage[MB_szSound][0] != '^0') {
			mw3_playSound(id, tempMessage[MB_szSound]);
		}
		ArrayDeleteItem(g_Messages[id], 0);
	}
	
	return FMRES_IGNORED;
}

public setMessage(iPlugin, iParams) {
	if (iParams != 9) {
		return -1;
	}
	
	new id = get_param(1);
	if (!flag_get(g_bIsConnected,id) || flag_get(g_bIsBot,id)) {
		return -1;
	}
	
	static tempMessage[eMessageInfo];
	tempMessage[MB_iMsgType] = get_param(4);
	tempMessage[MB_iRed    ] = get_param(5);
	tempMessage[MB_iGreen  ] = get_param(6);
	tempMessage[MB_iBlue   ] = get_param(7);
	tempMessage[MB_flXLoc  ] = _:get_param_f(8);
	tempMessage[MB_flYLoc  ] = _:get_param_f(9);
	get_string(2, tempMessage[MB_szMessage], 63);
	get_string(3, tempMessage[MB_szSound  ], 63);
	ArrayPushArray(g_Messages[id], tempMessage);
	return 1;
}

public cmdToggleSounds(id) {
	if (flag_get(g_bAreSoundsEnabled,id)) {
		flag_unset(g_bAreSoundsEnabled,id);
	} else {
		flag_set(g_bAreSoundsEnabled,id);
	}
	
	static const en [] = "en";
	static const dis[] = "dis";
	mw3_printColor(id, "You have just ^3%sabled ^1message sounds", (!!flag_get(g_bAreSoundsEnabled,id) ? en : dis));
}
