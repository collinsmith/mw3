#if defined _MW3_Core
	#endinput
#endif
#define _MW3_Core

#include <amxmodx>
#include <amxmisc>
#include <colorchat>
#include <tutor_messages>
#include <MW3_Core_Const>
#include <MW3_Log>

stock mw3_playSound(id, const szSound[]) {
	client_cmd(id, "spk %s", szSound);
}

stock mw3_printColor(id, szMsg[], any:...) {
	static buffer[192];
	switch (numargs()) {
		case 2: client_print_color(id, DontChange, "%s %s", _formattedHeader, szMsg);
		default: {
			vformat(buffer, 191, szMsg, 3);
			client_print_color(id, DontChange, "%s %s", _formattedHeader, buffer);
		}
	}
}

stock mw3_createTutorMsg(id, pid, tutorMode, Float:flTime, szAnnouncement[]) {
	static buffer[128], szPlayerName[32];
	get_user_name(pid, szPlayerName, 31);
	formatex(buffer, 127, "%s^n->%s<-", szPlayerName, szAnnouncement);
	tutor_createTutorMsg(id, tutorMode, flTime, buffer);
}
