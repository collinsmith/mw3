#if defined _tutor_messages_included
	#endinput
#endif
#define _tutor_messages_included

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib tutor_messages
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib tutor_messages
	#endif
#else
	#pragma library tutor_messages
#endif

enum (<<=1) {
	Tutor_Green = 1,
	Tutor_Red,
	Tutor_Blue,
	Tutor_Yellow
};

/**
 * Creates and displays a CZ tutor message window on the
 * upper right-hand side of a players screen.
 * 
 * @param id		Player index to display message (0 for all)
 * @param tutorMode	The color message to display
 * @param flTime	The amount of time for this message to remain shown
 * @param szMsg		The message to display
 */
native tutor_createTutorMsg(id, tutorMode, Float:flTime = 5.0, const szMsg[], any:...);

/**
 * Removes any tutor messages on a given player if it exists.
 * 
 * @param id		Player index to remove message (0 for all)
 */
native tutor_removeTutorMsg(id);
