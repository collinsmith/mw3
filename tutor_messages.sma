#include <amxmodx>

static const Plugin [] = "MW3 - Tutor Messages";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

#define TASK_HIDE_TUTOR 1500

#define flag_get(%1,%2)		!!(%1 &   (1 << (%2 & 31)))
#define flag_set(%1,%2)		(%1 |=  (1 << (%2 & 31)))
#define flag_unset(%1,%2)	(%1 &= ~(1 << (%2 & 31)))

static g_msgTutorClose;
static g_msgTutorText;
static g_iMaxPlayers;
static g_iConnected;

new const g_szTutorSound[] = "mw3/tutor.wav";

enum (<<=1) {
	Tutor_Green = 1,
	Tutor_Red,
	Tutor_Blue,
	Tutor_Yellow
};

public plugin_precache() {
        precache_generic("resource/TutorScheme.res");
        precache_generic("resource/UI/TutorTextWindow.res");
        precache_generic("gfx/career/icon_!.tga");
        precache_generic("gfx/career/icon_!-bigger.tga");
        precache_generic("gfx/career/icon_i.tga");
        precache_generic("gfx/career/icon_i-bigger.tga");
        precache_generic("gfx/career/icon_skulls.tga");
        precache_generic("gfx/career/round_corner_ne.tga");
        precache_generic("gfx/career/round_corner_nw.tga");
        precache_generic("gfx/career/round_corner_se.tga");
        precache_generic("gfx/career/round_corner_sw.tga");
	
	precache_sound(g_szTutorSound);
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	g_msgTutorClose = get_user_msgid("TutorClose");
	g_msgTutorText  = get_user_msgid("TutorText");
	g_iMaxPlayers   = get_maxplayers();
}

public plugin_natives() {
	register_library("tutor_messages");
	register_native("tutor_createTutorMsg", "_createTutorMsg", 0);
	register_native("tutor_removeTutorMsg", "_removeTutorMsg", 0);
}

public client_connect(id) {
	flag_set(g_iConnected,id);
}

public client_disconnect(id) {
	flag_unset(g_iConnected,id);
	remove_task(TASK_HIDE_TUTOR+id);
}

public _createTutorMsg(iPlugin, iParams) {
	static id, tutorMode, Float:flTime;
	id	  = get_param(1);
	tutorMode = get_param(2);
	flTime	  = get_param_f(3);
	
	static count, players[32];
	if (id) {
		count = 1;
		players[0] = id;
	} else {
		get_players(players, count, "ch");
	}

	static numArguments, buffer[128];
	numArguments = numargs();
	if (numArguments == 4) {
		get_string(4, buffer, 127);
	} else {
		vdformat(buffer, 127, 4, 5);
	}
	
	for (new i; i < count; i++) {
		id = players[i];
		if (!flag_get(g_iConnected,id)) {
			continue;
		}
		
		// I think we can remove this but this is called by the original
		// Hide Tutor
		message_begin(MSG_ONE_UNRELIABLE, g_msgTutorClose, {0, 0, 0}, id); {
		} message_end();
		
		client_cmd(id, "spk %s", g_szTutorSound);
		
		// Create a Tutor message
		message_begin(MSG_ONE_UNRELIABLE, g_msgTutorText, {0, 0, 0}, id); {
		write_string(buffer);		// displayed message
		write_byte(0);			// ???
		write_short(0);			// ???
		write_short(0);			// ???
		write_short(tutorMode);		// class of a message
		} message_end();
		
		// Hide Tutor in X seconds 
		remove_task(TASK_HIDE_TUTOR+id);
		set_task(flTime, "sendRemoveTutor", TASK_HIDE_TUTOR+id);
	}
}

public _removeTutorMsg(iPlugin, iParams) {
	static id;
	id = get_param(1);
	if (id > g_iMaxPlayers) {
		id -= TASK_HIDE_TUTOR;
	}
	
	static count, players[32];
	if (id) {
		count = 1;
		players[0] = id;
	} else {
		get_players(players, count, "ch");
	}
	
	for (new i; i < count; i++) {
		id = players[i];
		sendRemoveTutor(id);
	}
}

public sendRemoveTutor(id) {
	if (id > g_iMaxPlayers) {
		id -= TASK_HIDE_TUTOR;
	}
	
	if (!flag_get(g_iConnected,id)) {
		return;
	}
	
	message_begin(MSG_ONE_UNRELIABLE, g_msgTutorClose, {0, 0, 0}, id); {
	} message_end();
}
