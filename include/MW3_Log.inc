#if defined _MW3_Log
	#endinput
#endif
#define _MW3_Log

#include <amxmisc>
#include <MW3_Core_Const>

stock mw3_log(message[], any:...) {
	static message_fmt[256], filename[96], dir[64];
	vformat(message_fmt, 255, message, 2);
	if(!dir[0]) {
		get_basedir(dir, sizeof(dir) - 1);
	}
	
	format_time(filename, 95, "%Y%m%d");
	format(filename, 95, "%s/logs/ModernWarfare3_%s.log", dir, filename);
	log_to_file(filename, "%s", message_fmt);
}

stock mw3_log_err(error[], any:...) {
	if (numargs() == 1) {
		sendErrorMessage(error);
	} else {
		static buffer[128];
		vformat(buffer, 127, error, 2);
		sendErrorMessage(buffer);
	}
}

static stock sendErrorMessage(error[]) {
	mw3_log(error);
	log_error(AMX_ERR_NATIVE, "%s %s", _errorMessageHeader, error);
}
