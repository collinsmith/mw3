#include <amxmodx>
#include <amxmisc>

#include <MW3_Perks_Const>
#include <MW3_Core>

static const Plugin	[] = "MW3 - Perks";
static const Version	[] = "0.0.1";
static const Author	[] = "Tirant";

#define playerGetPerk(%1,%2)		(g_iCurPerks[%1] &   (1 << (%2 & 31)))
#define playerAddPerk(%1,%2)		(g_iCurPerks[%1] |=  (1 << (%2 & 31)))
#define playerRemPerk(%1,%2)		(g_iCurPerks[%1] &= ~(1 << (%2 & 31)))
#define playerHasPerk(%1,%2)		bool:(playerGetPerk(%1,%2) ? true : false)

#define isValidPlayerID(%1)		bool:(%1 > 0 || g_iMaxPlayers >= %1)

static Array:g_aPerkTypeList;
static Trie:g_tPerkTypeNames;
static g_perkTypeNum;

static Array:g_aPerkList;
static Trie:g_tPerkNames;
static g_perkNum;

static bool:g_bCanLoadPerks = false;
static g_iMaxPlayers;
static g_iCurPerks[MAXPLAYERS+1];

enum ForwardedEvents {
	fwDummy,
	fwPerksChanged,
	fwPerkAdded,
	fwLoadPerks
}
static g_Forwards[ForwardedEvents];

public plugin_precache() {
	g_aPerkTypeList = ArrayCreate(PerkType);
	g_tPerkTypeNames = TrieCreate();
	
	g_aPerkList = ArrayCreate(Perk);
	g_tPerkNames = TrieCreate();
	
	g_bCanLoadPerks = true;
	g_Forwards[fwLoadPerks] = CreateMultiForward("mw3_fw_perks_load", ET_IGNORE);
	ExecuteForward(g_Forwards[fwLoadPerks], g_Forwards[fwDummy]);
	g_bCanLoadPerks = false;
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	g_iMaxPlayers = get_maxplayers();
	
	g_Forwards[fwPerksChanged] = CreateMultiForward("mw3_fw_perks_perksChanged", ET_IGNORE, FP_CELL, FP_CELL);
	g_Forwards[fwPerkAdded   ] = CreateMultiForward("mw3_fw_perks_perkAdded", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives() {
	register_library("MW3_PerkModule");
	
	register_native("mw3_perks_registerPerkType",	"_registerPerkType",		0);
	register_native("mw3_perks_getPerkTypeNum",	"_getPerkTypeNum",		0);
	register_native("mw3_perks_getPerkTypeByName",	"_getPerkTypeByName",		0);
	register_native("mw3_perks_getPerkList",	"_getPerkList",			0);
	register_native("mw3_perks_getPerkListByName",	"_getPerkListByName",		0);
	register_native("mw3_perks_getPerkTypeName",	"_getPerkTypeName",		0);
	register_native("mw3_perks_getPerkType",	"_getPerkType",			0);
	
	register_native("mw3_perks_registerPerk",	"_registerPerk",		0);
	register_native("mw3_perks_getPerkNum",		"_getPerkNum",			0);
	register_native("mw3_perks_getPerkByName",	"_getPerkByName",		0);
	register_native("mw3_perks_getPerkInfo",	"_getPerkInfo",			0);
	register_native("mw3_perks_getBitsPerksList",	"_getBitsPerksList",		1);
	
	register_native("mw3_perks_resetPerks",		"_resetPerks",			1);
	register_native("mw3_perks_convertPerkToBits",	"_convertPerkToBits",		1);
	register_native("mw3_perks_convertBitsToPerk",	"_convertBitsToPerk",		1);
	register_native("mw3_perks_addUserPerk",	"_addPlayerPerk",		1);
	register_native("mw3_perks_removeUserPerk",	"_removePlayerPerk",		1);
	register_native("mw3_perks_checkUserPerk",	"_checkPlayerPerk",		1);
	register_native("mw3_perks_getUserPerks",	"_getPlayerPerks",		1);
	register_native("mw3_perks_setUserPerks",	"_setPlayerPerks",		1);
	register_native("mw3_perks_getUserPerksByType",	"_getPlayerPerksByType",	1);
	register_native("mw3_perks_setUserPerksByType",	"_setPlayerPerksByType",	1);
}

public client_disconnect(id) {
	_resetPerks(id);
}

public _resetPerks(id) {
	_setPlayerPerks(id, 0);
}

public _convertPerkToBits(perk) {
	if (!_perkExists(perk)) {
		mw3_log_err("Function: _convertPerkToBits; Error: Invalid perk (%d)", perk);
		return -1;
	}
	
	return (1<<perk);
}

public _convertBitsToPerk(bits) {
	if (bits < 0) {
		mw3_log_err("Function: _convertBitsToPerk; Error: Invalid bitsum (%d)", bits);
		return -1;
	}
	
	new i;
	while (bits > 0) {
		bits >>= 1;
		i++;
	}
	
	return clamp(i-1, 0);
}

public _addPlayerPerk(id, perk) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _addPlayerPerk; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (!_perkExists(perk)) {
		mw3_log_err("Function: _addPlayerPerk; Error: Invalid perk (%d)", perk);
		return -1;
	}
	
	playerAddPerk(id, perk);
	ExecuteForward(g_Forwards[fwPerkAdded], g_Forwards[fwDummy], id, perk);
	return g_iCurPerks[id];
}

public _removePlayerPerk(id, perk) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _removePlayerPerk; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (!_perkExists(perk)) {
		mw3_log_err("Function: _removePlayerPerk; Error: Invalid perk (%d)", perk);
		return -1;
	}
	
	playerRemPerk(id, perk);
	return g_iCurPerks[id];
}

public bool:_checkPlayerPerk(id, perk) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _checkPlayerPerk; Error: Invalid player id (%d)", id);
		return false;
	}
	
	if (!_perkExists(perk)) {
		mw3_log("Function: _checkPlayerPerk; Error: Invalid perk (%d)", perk);
		return false;
	}
	
	return playerHasPerk(id, perk);
}

public _getPlayerPerks(id) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _getPlayerPerks; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	return g_iCurPerks[id];
}

public _setPlayerPerks(id, bits) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _setPlayerPerks; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (bits < 0) {
		mw3_log_err("Function: _setPlayerPerks; Error: Invalid bitsum (%d)", bits);
		return -1;
	}
	
	g_iCurPerks[id] = bits;
	ExecuteForward(g_Forwards[fwPerksChanged], g_Forwards[fwDummy], id, bits);
	return g_iCurPerks[id];
}

public Array:_getBitsPerksList(bits) {
	static Array:perkList;
	perkList = ArrayCreate();
	
	static size;
	size = ArraySize(g_aPerkList);
	for (new i; i < size; i++) {
		if (bits & (1<<i)) {
			ArrayPushCell(perkList, i);
		}
	}
	
	return perkList;
}

public bool:_setPlayerPerksByType(id, perkType, bool:enablePerks) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _setPlayerPerksByType; Error: Invalid player id (%d)", id);
		return false;
	}
	
	if (!_perkTypeExists(perkType)) {
		mw3_log_err("Function: _setPlayerPerksByType; Error: Invalid perk type (%d)", perkType);
		return false;
	}
	
	new tempPerkType[PerkType];
	ArrayGetArray(g_aPerkTypeList, perkType, tempPerkType);
	
	new iSize = ArraySize(tempPerkType[perkt_PerkList]);
	for (new i; i < iSize; i++) {
		if (enablePerks) {
			_addPlayerPerk(id, ArrayGetCell(tempPerkType[perkt_PerkList], i));
		} else {
			_removePlayerPerk(id, ArrayGetCell(tempPerkType[perkt_PerkList], i));
		}
	}
	
	return true;
}

public _getPlayerPerksByType(id, perkType) {
	if (!isValidPlayerID(id)) {
		mw3_log_err("Function: _getPlayerPerksByType; Error: Invalid player id (%d)", id);
		return -1;
	}
	
	if (!_perkTypeExists(perkType)) {
		mw3_log_err("Function: _getPlayerPerksByType; Error: Invalid perk type (%d)", perkType);
		return -1;
	}
	
	new tempPerkType[PerkType];
	ArrayGetArray(g_aPerkTypeList, perkType, tempPerkType);
	
	new iSize = ArraySize(tempPerkType[perkt_PerkList]);
	new tempPerk, iReturn;
	for (new i; i < iSize; i++) {
		tempPerk = ArrayGetCell(tempPerkType[perkt_PerkList], i);
		if (_checkPlayerPerk(id, tempPerk)) {
			iReturn += _convertPerkToBits(tempPerk);
		}
	}
	
	return iReturn;
}

bool:_perkTypeExists(type) {
	if (type < 0 || type >= g_perkTypeNum) {
		return false;
	}
	
	return true;
}

bool:_perkExists(perk) {
	if (perk < 0 || perk >= g_perkNum) {
		return false;
	}
	
	return true;
}

public _registerPerkType(iPlugin, iParams) {
	if (iParams != (perktype_params-1)) {
		mw3_log_err("Function: _registerPerkType; Error: Invalid parameter number! (Expected %d, Found %d)", perktype_params-1, iParams);
		return PERKTYPE_NONE;
	}
	
	if (!g_bCanLoadPerks) {
		mw3_log_err("Function: _registerPerkType; Error: Loaded outside of time slot!");
		return PERKTYPE_NONE;
	}
	
	static tempPerkType[PerkType];
	get_string(perktype_param_name, tempPerkType[perkt_Name], 31);

	if (!strlen(tempPerkType[perkt_Name])) {
		mw3_log_err("Function: _registerPerkType; Error: No type name found!");
		return PERKTYPE_NONE;
	}
	
	static i;
	if (TrieGetCell(g_tPerkTypeNames, tempPerkType[perkt_Name], i)) {
		mw3_log_err("Function: _registerPerkType; Error: Perk type already exists with this name! (%s)", tempPerkType[perkt_Name]);
		return i;
	}
	
	tempPerkType[perkt_PerkList] = _:ArrayCreate();
	
	ArrayPushArray(g_aPerkTypeList, tempPerkType);
	TrieSetCell(g_tPerkTypeNames, tempPerkType[perkt_Name], g_perkTypeNum);
	
	g_perkTypeNum++;
	return (g_perkTypeNum-1);
}

public _getPerkTypeNum(iPlugin, iParams) {
	if (iParams != 0) {
		mw3_log_err("Function: _getPerkTypeNum; Error: Invalid parameter number! (Expected %d, Found %d)", 0, iParams);
		return -1;
	}
	
	return g_perkTypeNum;
}

public _getPerkTypeByName(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getPerkTypeByName; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return PERKTYPE_NONE;
	}
	
	static szName[32];
	get_string(1, szName, 31);
	
	static i;
	if (TrieGetCell(g_tPerkTypeNames, szName, i)) {
		return i;
	}
	
	mw3_log("Perk type not found under name (%s)!", szName);
	return PERKTYPE_NONE;
}

public Array:_getPerkList(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getperkt_PerkList; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return ArrayCreate();
	}
	
	static perkType;
	perkType = get_param(1);
	
	if (!_perkTypeExists(perkType)) {
		mw3_log_err("Function: _getperkt_PerkList; Error: Invalid perk typeid!");
		return ArrayCreate();
	}
	
	static tempPerkType[PerkType];
	ArrayGetArray(g_aPerkTypeList, perkType, tempPerkType);
	return tempPerkType[perkt_PerkList];
}

public Array:_getPerkListByName(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getperkt_PerkListByName; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return ArrayCreate();
	}
	
	static szName[32];
	get_string(1, szName, 31);
	
	static i;
	if (TrieGetCell(g_tPerkTypeNames, szName, i)) {
		static tempPerkType[PerkType];
		ArrayGetArray(g_aPerkTypeList, i, tempPerkType);
		
		return tempPerkType[perkt_PerkList];
	}
	
	return ArrayCreate();
}

public bool:_getPerkTypeName(iPlugin, iParams) {
	if (iParams != 3) {
		mw3_log_err("Function: _getPerkTypeName; Error: Invalid parameter number! (Expected %d, Found %d)", 3, iParams);
		return false;
	}
	
	static typeID;
	typeID = get_param(1);
	
	if (!_perkTypeExists(typeID)) {
		mw3_log_err("Function: _getPerkTypeName; Error: Invalid perk type entered. (%d)", typeID);
		return false;
	}
	
	static tempPerkType[PerkType];
	ArrayGetArray(g_aPerkTypeList, typeID, tempPerkType);
	set_string(2, tempPerkType[perkt_Name], get_param(3));
	
	return true;
}

public _registerPerk(iPlugin, iParams) {
	if (iParams != perk_params-1) {
		mw3_log_err("Function: _registerPerk; Error: Invalid parameter number! (Expected %d, Found %d)", perk_params-1, iParams);
		return PERK_NONE;
	}
	
	if (!g_bCanLoadPerks) {
		mw3_log_err("Function: _registerPerk; Error: Loaded outside of time slot!");
		return PERKTYPE_NONE;
	}
	
	static tempPerk[Perk];
	tempPerk[perk_TypeID] = get_param(perk_param_type);
	
	get_string(perk_param_name, tempPerk[perk_Name], 31);
	if (!strlen(tempPerk[perk_Name])) {
		mw3_log_err("Function: _registerPerk; Error: No name found!");
		return PERK_NONE;
	}
	
	static i;
	if (TrieGetCell(g_tPerkNames, tempPerk[perk_Name], i)) {
		mw3_log_err("Function: _registerPerk; Error: Perk type already exists with this name! (%s)", tempPerk[perk_Name]);
		return i;
	}
	
	get_string(perk_param_desc, tempPerk[perk_Desc], 63);
	
	static tempPerkType[PerkType];
	ArrayGetArray(g_aPerkTypeList, tempPerk[perk_TypeID], tempPerkType);
	ArrayPushCell(tempPerkType[perkt_PerkList], g_perkNum);
	ArraySetArray(g_aPerkTypeList, tempPerk[perk_TypeID], tempPerkType);
	
	ArrayPushArray(g_aPerkList, tempPerk);
	TrieSetCell(g_tPerkNames, tempPerk[perk_Name], g_perkNum);
	
	g_perkNum++;
	return (g_perkNum-1);
}

public _getPerkNum(iPlugin, iParams) {
	if (iParams != 0) {
		mw3_log_err("Function: _getPerkNum; Error: Invalid parameter number! (Expected %d, Found %d)", 0, iParams);
		return -1;
	}
	
	return g_perkNum;
}

public _getPerkByName(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getPerkByName; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return PERK_NONE;
	}
	
	static szName[32];
	get_string(1, szName, 31);
	
	static i;
	if (TrieGetCell(g_tPerkNames, szName, i)) {
		return i;
	}
	
	mw3_log("Perk not found under name (%s)!", szName);
	return PERK_NONE;
}

public bool:_getPerkInfo(iPlugin, iParams) {
	if (iParams != 2) {
		mw3_log_err("Function: _getPerkInfo; Error: Invalid parameter number! (Expected %d, Found %d)", 2, iParams);
		return false;
	}
	
	static perk;
	perk = get_param(1);
	
	if (!_perkExists(perk)) {
		mw3_log_err("Function: _getPerkInfo; Error: Invalid perk (%d)", perk);
		return false;
	}
	
	static tempPerk[Perk];
	ArrayGetArray(g_aPerkList, perk, tempPerk);
	set_array(2, tempPerk, Perk);
	
	return true;
}

public _getPerkType(iPlugin, iParams) {
	if (iParams != 1) {
		mw3_log_err("Function: _getPerkType; Error: Invalid parameter number! (Expected %d, Found %d)", 1, iParams);
		return PERKTYPE_NONE;
	}
	
	static perkID;
	perkID = get_param(1);
	
	if (!_perkExists(perkID)) {
		mw3_log_err("Function: _getPerkType; Error: Invalid perk id entered. (%d)", perkID);
		return PERKTYPE_NONE;
	}
	
	new tempPerk[Perk];
	ArrayGetArray(g_aPerkList, perkID, tempPerk);
	
	return tempPerk[perk_TypeID];
}
