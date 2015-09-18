#if defined _MW3_Scorechain
	#endinput
#endif
#define _MW3_Scorechain

#if AMXX_VERSION_NUM >= 175
	#pragma reqlib MW3_Scorechain
	#if !defined AMXMODX_NOAUTOLOAD
		#pragma loadlib MW3_Scorechain
	#endif
#else
	#pragma library MW3_Scorechain
#endif

enum _:Counter {
	counter_Kills,
	counter_Deaths
};

/**
 * Called after the appropriate data structures for registering score
 * chains have been initialized.  Scorechains can only be registered
 * during this time.
 */
forward mw3_fw_sc_load();

/**
 * Called when a player has a perk added onto his chain list.  This means
 * that if the players chain counter is reached, the added scorechain will
 * be added.
 * 
 * @param id		Player index having chain added.
 * @param chain		Index of the chain that was added.
 */
forward mw3_fw_sc_added(id, chain);

/**
 * Called when a players score chains change via setPlayerChains.
 * 
 * @param id		Player index having chain changed.
 * @param bits		The new active bitsum of score chains.
 */
forward mw3_fw_sc_changed(id, bits);

/**
 * Called when a player calls the next available killstreak in
 * their list.
 * 
 * @param id		Player index calling in their reward.
 * @param chainid	Index of the chain being called.
 */
forward mw3_fw_sc_called(id, chainid);

/**
 * Converts a given scorechain into the bitsum value.
 * 
 * @param chain		The chain to convert.
 * @return		The bitsum value of this chain.
 */
native mw3_sc_convChainToBits(chain);

/**
 * Converts a given bitsum into the chain value.
 * 
 * @note		Only use bitsums of single chain.
 * 
 * @param bits		The bitsum to convert.
 * @return		The chain value of this bitsum.
 */
native mw3_sc_convBitsToChain(bits);

/**
 * Adds a given number of kills to a players counter.
 * 
 * @param id		Player index to add points to.
 * @param counter	Counter to add to. Kills = 0, Deaths = 1
 * @param kills		The number of kills to add.
 * 
 * @note		May use counter_Kills and counter_Deaths
 */
native mw3_sc_addToCounter(id, counter = counter_Kills, kills = 1);

/**
 * Retrieves the current counter for either kills or deaths for
 * a player.
 * 
 * @param id		Player index to retrieve counter from.
 * @param counter	Counter to retrieve. Kills = 0, Deaths = 1
 * 
 * @note		May use counter_Kills and counter_Deaths
 */
native mw3_sc_getCurCounter(id, counter =  counter_Kills);

/**
 * Places the name for a specified scorechain into a given string.
 * 
 * @param chain		Index of the chain to look up.
 * @param where		Array to place string result into.
 * @param len		Length of the string to use.
 * 
 * @return		1 if a valid chain exists, -1 if none found.
 */
native mw3_sc_getChainName(chain, where[], len);

/**
 * Retrieves a chain index for a chain by the specified name.
 * 
 * @param chainName	Name of the chain to look up.
 * 
 * @return		The chain index, -1 if none found.
 */
native mw3_sc_getChainByName(const chainName[]);

/**
 * Registers a new score chain into the chain list.
 * 
 * @note		If usesKills is true, then chain must
 * 			have pont added manually.
 * 
 * @param name		The name of the score chain
 * @param usesKills	True to add point on kills, false otherwise.
 * @param req		When the point reachest req, reward the streak.
 * @param soundSelf	File to play when player receives the chain.
 * @param soundFriend	File to play to friendlies when called.
 * @param soundEnemy	File to play to enemies when called.
 * 
 * @return		Chain index for the created score chain.
 */
native mw3_sc_registerChain(const name[], bool:usesKills = true, req, const soundSelf[] = "", const soundFriend[] = "", const soundEnemy[] = "");

native mw3_sc_resetChains(id);
native mw3_sc_addScorechain(id, chain);
native mw3_sc_removeScorechain(id, chain);
native bool:mw3_sc_checkPlayerChain(id, chain);
native mw3_sc_getScorechains(id);
native mw3_sc_setScorechains(id, bits);
native Array:mw3_sc_getBitsChainList(id);
