#if defined _MW3_PerkModule
	#endinput
#endif
#define _MW3_PerkModule

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib MW3_PerkModule
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib MW3_PerkModule
	#endif
#else
	#pragma library MW3_PerkModule
#endif

#include <MW3_Perks_Const>

/**
 * Called after the appropriate data structures for registering perks have
 * been initialized.  Perks can be created/loaded only at this time.
 */
forward mw3_fw_perks_load()

/**
 * Called when a players perks are set to a new bitsum.
 * 
 * @param id		Player index for perks change
 * @param bits		The new bitsum of perks
 */
forward mw3_fw_perks_perksChanged(id, bits);

/**
 * Called when a specific perk is added to a player.
 * 
 * @param id		Player index receiving perk
 * @param perk		The perk being added
 */
forward mw3_fw_perks_perkAdded(id, perk);

/**
 * Retrieves the perk array from the database and places
 * it into an array of size Perk.
 * 
 * @param perk		The perk to retrieve.
 * @param perkArray	The array to place the information into.
 * @return		True if successful, false otherwise.
 */
native bool:mw3_perks_getPerkInfo(perk, perkArray[Perk]);

/**
 * Resets a players perks to none.
 * 
 * @param id		Player index to run this operation on.
 */
native mw3_perks_resetPerks(id);

/**
 * Converts a given perk into the bitsum value.
 * 
 * @param perk		The perk to convert.
 * @return		The bitsum value of this perk.
 */
native mw3_perks_convertPerkToBits(perk);

/**
 * Converts a given bitsum into the perk value.
 * 
 * @note		Only use bitsums of single perks.
 * 
 * @param bits		The bitsum to convert.
 * @return		The perk value of this bitsum.
 */
native mw3_perks_convertBitsToPerk(bits);

/**
 * Adds a perk into a players currently applied perks.
 * 
 * @param id		Player index to add perk to.
 * @param perk		The perk to add.
 */
native mw3_perks_addUserPerk(id, perk);

/**
 * Removes a perk from a players currently applied perks.
 * 
 * @param id		Player index to remove perk from.
 * @param perk		The perk to remove.
 */
native mw3_perks_removeUserPerk(id, perk);

/**
 * Returns whether or not a perk is in a players currently
 * applied perks.
 * 
 * @param id		Player index to check.
 * @param perk		The perk to check.
 */
native bool:mw3_perks_checkUserPerk(id, perk);

/**
 * Retrieves a bitsum representation of every perk currently
 * applied on a given player.
 * 
 * @param id		Player index to retrieve.
 * @return		A bitsum of all perks this player has.
 */
native mw3_perks_getUserPerks(id);

/**
 * Sets a players perks to a given bitsum value.
 * 
 * @param id		Player index to retrieve data.
 * @param bits		The new bitsum.
 * @return		The current bitsum of this player.
 */
native mw3_perks_setUserPerks(id, bits);

/**
 * Retrieves a bitsum of all current perks of a given type
 * that a player has applied.
 * 
 * @param id		Player index to retrieve data from.
 * @param type		The type of perk to get.
 * @return		Bitsum of all perks applied of this type.
 */
native mw3_perks_getUserPerksByType(id, type);

/**
 * Sets a given perk type on a player to add/remove all of
 * the perks of this type.
 * 
 * @param id		Player index to (un)set perks to.
 * @param type		The type of perk to (un)set.
 * @param enable	True to enable all perks of this type,
 *			false otherwise.
 * @return		True if the given operation was successful,
 *			false otherwise.
 */
native bool:mw3_perks_setUserPerksByType(id, type, bool:enable = false);

/**
 * Attempts to register a new perk into the perks system.
 * 
 * @param name		The name of the perk type to register.
 * @return		The MW3_PerkType of the new type.
 * 			PERKTYPE_NONE if is there is an error.
 */
native mw3_perks_registerPerkType(const name[]);

/**
 * Retrieves the number of perk types registered.
 * 
 * @return		The number of perk types registered.
 */
native mw3_perks_getPerkTypeNum();

/**
 * Retrieves a list of integers containing all perks
 * within a given type.
 * 
 * @param type		MW3 perk type to look up.
 * @return		A list of perks. An empty list is
 * 			returned if an invalid type is entered.
 */
native Array:mw3_perks_getPerkList(type);

/**
 * Retrieves a list of integers containing all perks
 * within a given type.
 * 
 * @param name		The name of the MW3 perk type to look up.
 * @return		A list of perks. An empty list is
 * 			returned if an invalid type is entered.
 */
native Array:mw3_perks_getPerkListByName(const name[]);

/**
 * Retrieves a MW3_PerkType value using the name of a given
 * perk type.
 * 
 * @param name		The name of the perk type to look up.
 * @return		A MW3_PerkType corresponding to that name.
 * 			PERKTYPE_NONE if there is an error.
 */
native mw3_perks_getPerkTypeByName(const name[]);

/**
 * Gets the name of a given perk type using a MW3_PerkType.
 * 
 * @param type		The MW3_PerkType to look up.
 * @param dest		An array to place the name into.
 * @param len		The length of the array to retrieve.
 * @return		True if successful, false otherwise.
 */
native bool:mw3_perks_getPerkTypeName(type, dest[], len);

/**
 * Attempts to register a new perk into a MW3_PerkType.
 * 
 * @param type		The MW3_PerkType to register this perk into.
 * @param name		The name of this new perk.
 * @param desc		(Optional) A brief description of this perks effect.
 * @return		The MW3_Perk of the new perk.
 * 			PERK_NONE if is there is an error.
 */
native mw3_perks_registerPerk(const type, const name[], const description[] = "");

/**
 * Retrieves the total number of perks registered in a given MW3_PerkType.
 * 
 * @return		The total number of MW3_Perk in all MW3_PerkTypes.
 */
native mw3_perks_getPerkNum();

/**
 * Retrieves a MW3_Perk using the name of that perk.
 * 
 * @param name		The name of the MW3_Perk to look up.
 * @return		The MW3_Perk with that given name.
 * 			PERK_NONE if is there is an error.
 */
native mw3_perks_getPerkByName(const name[]);

/**
 * Retrieves a MW3_PerkType from a perk using a MW3_Perk.
 * 
 * @param perk		The MW3_Perk to look up.
 * @return		The MW3_PerkType that this MW3_Perk is located.
 * 			PERKTYPE_NONE if there is an error.
 */
native mw3_perks_getPerkType(perk);

/**
 * Retrieves a list of all perks within a bitsum.
 * 
 * @param bits		The bitsum to check.
 * @return		A list of all perks within the bits.
 */
native Array:mw3_perks_getBitsPerksList(bits);
