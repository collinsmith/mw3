#include <amxmodx>
#include <csdm>
#include <MW3_Perks>
#include <MW3_Scorechain>

static const Plugin [] = "MW3 - Perks (Test)";
static const Version[] = "0.0.1";
static const Author [] = "Tirant";

enum _:pluginPerks {
	Tier1,
	Tier2,
	Tier3
};
static g_perkTypes[pluginPerks];

enum tier1Perks {
	perk_Recon,
	perk_SleightOfHand,
	perk_BlindEye,
	perk_ExtremeCondit,
	perk_Scavenger
};
static g_perksTier1[tier1Perks];

enum tier2Perks {
	perk_Quickdraw,
	perk_BlastShield,
	perk_Hardline,
	perk_Assassin,
	perk_Overkill
};
static g_perksTier2[tier2Perks];

enum tier3Perks {
	perk_Marksman,
	perk_Stalker,
	perk_SitRep,
	perk_SteadyAim,
	perk_DeadSilence
};
static g_perksTier3[tier3Perks];

public plugin_init() {
	register_plugin(Plugin, Version, Author);
}

public mw3_fw_perks_load() {	
	g_perkTypes[Tier1] = mw3_perks_registerPerkType("Tier 1");
	g_perksTier1[perk_Recon        ] = mw3_perks_registerPerk(g_perkTypes[Tier1], "Recon");
	g_perksTier1[perk_SleightOfHand] = mw3_perks_registerPerk(g_perkTypes[Tier1], "Sleight of Hand");
	g_perksTier1[perk_BlindEye     ] = mw3_perks_registerPerk(g_perkTypes[Tier1], "Blind Eye");
	g_perksTier1[perk_ExtremeCondit] = mw3_perks_registerPerk(g_perkTypes[Tier1], "Extreme Conditioning");
	g_perksTier1[perk_Scavenger    ] = mw3_perks_registerPerk(g_perkTypes[Tier1], "Scavenger");
	
	g_perkTypes[Tier2] = mw3_perks_registerPerkType("Tier 2");
	g_perksTier2[perk_Quickdraw  ] = mw3_perks_registerPerk(g_perkTypes[Tier2], "Quickdraw");
	g_perksTier2[perk_BlastShield] = mw3_perks_registerPerk(g_perkTypes[Tier2], "Blast Shield");
	g_perksTier2[perk_Hardline   ] = mw3_perks_registerPerk(g_perkTypes[Tier2], "Hardline");
	g_perksTier2[perk_Assassin   ] = mw3_perks_registerPerk(g_perkTypes[Tier2], "Assassin");
	g_perksTier2[perk_Overkill   ] = mw3_perks_registerPerk(g_perkTypes[Tier2], "Overkill");
	
	g_perkTypes[Tier3] = mw3_perks_registerPerkType("Tier 3");
	g_perksTier3[perk_Marksman   ] = mw3_perks_registerPerk(g_perkTypes[Tier3], "Marksman");
	g_perksTier3[perk_Stalker    ] = mw3_perks_registerPerk(g_perkTypes[Tier3], "Stalker");
	g_perksTier3[perk_SitRep     ] = mw3_perks_registerPerk(g_perkTypes[Tier3], "SitRep");
	g_perksTier3[perk_SteadyAim  ] = mw3_perks_registerPerk(g_perkTypes[Tier3], "Steady Aim");
	g_perksTier3[perk_DeadSilence] = mw3_perks_registerPerk(g_perkTypes[Tier3], "Dead Silence");
}

public csdm_PostSpawn(id, bool:fake) {
	if (fake) {
		return;
	}
	
	if (mw3_perks_checkUserPerk(id, g_perksTier2[perk_Hardline])) {
		mw3_sc_addToCounter(id, counter_Kills, 1);
	}
}
