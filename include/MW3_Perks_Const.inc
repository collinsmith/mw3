#if defined _MW3_PerkModule_C
	#endinput
#endif
#define _MW3_PerkModule_C

#define PERKTYPE_NONE -1
#define PERK_NONE -1

enum _:PerkType {
	perkt_Name[32],
	Array:perkt_PerkList
};

enum _:perktype_params {
	perktype_param_name = 1
};

enum _:Perk {
	perk_TypeID,
	perk_Name[32],
	perk_Desc[64]//,
	//perk_Stats[33]
};

enum _:perk_params {
	perk_param_type = 1,
	perk_param_name,
	perk_param_desc
};
