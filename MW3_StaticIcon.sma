#include <amxmodx>
#include <amxmisc>

#include <cstrike>
#include <MW3_Core>
#include <MW3_Perks>

#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <fakemeta_util>
#include <xs>

#define GetEntState(%1)		(entity_get_int(%1, EV_INT_iuser1))
#define SetEntState(%1,%2)	(entity_set_int(%1,EV_INT_iuser1,%2))

#define GetEntSprite(%1)	(entity_get_int(%1, EV_INT_iuser2))
#define SetEntSprite(%1,%2)	(entity_set_int(%1,EV_INT_iuser2,%2))

#define GetEntTeamID(%1)	(entity_get_int(%1,EV_INT_iuser3))
#define SetEntTeamID(%1,%2)	(entity_set_int(%1,EV_INT_iuser3,%2))

#define GetEntHacker(%1)	(entity_get_int(%1,EV_INT_iuser4))
#define SetEntHacker(%1,%2)	(entity_set_int(%1,EV_INT_iuser4,%2))

new const Plugin [] = "MW3 - StaticIcon";
new const Author [] = "Tirant";
new const Version[] = "0.0.1";

new bool:OnFirstPersonView[MAXPLAYERS+1];
new SpectatingUser[MAXPLAYERS+1];
new CsTeams:g_iCurTeam[MAXPLAYERS+1];

#define playerHasSitRep(%1)		(g_bHasSitRep &   (1 << (%1 & 31)))
#define playerAddSitRep(%1)		(g_bHasSitRep |=  (1 << (%1 & 31)))
#define playerRemSitRep(%1)		(g_bHasSitRep &= ~(1 << (%1 & 31)))
new g_bHasSitRep;

enum _:Vector {
	X,
	Y,
	Z
};

enum Individual {
	Spectated,
	Viewed
};

enum OriginOffset {
	FrameSide,
	FrameTop,
	FrameBottom,
};

enum FramePoint {
	TopLeft,
	TopRight,
	BottomLeft,
	BottomRight
};

new Float:OriginOffsets[OriginOffset] =  {_:13.0,_:25.0,_:36.0};

new Float:ScaleMultiplier = 0.013;
new Float:ScaleLower = 0.005;

new Float:SomeNonZeroValue = 1.0;

new EntitiesOwner;

new MaxPlayers;

enum iconStatus {
	icon_Hidden = 0,
	icon_Showing,
	icon_None
};

public plugin_precache() {
	EntitiesOwner = create_entity("info_target");
	MaxPlayers = get_maxplayers();
}

public plugin_init() {
	register_plugin(Plugin, Version, Author);
	
	register_event("TextMsg",	"specMode",	"b",	"2&#Spec_Mode");
	register_event("StatusValue",	"specTarget",	"bd",	"1=2");
	register_event("SpecHealth2",	"specTarget",	"bd");
	
	register_message(get_user_msgid("TeamInfo"), "msgTeamInfo");
	
	RegisterHam(Ham_Spawn,	"player", "playerSpawn", 1);
	RegisterHam(Ham_Killed,	"player", "playerDeath", 1);
	
	register_forward(FM_AddToFullPack, "addToFullPackPost", 1);
}

public msgTeamInfo(msgid, dest) {
	if (dest != MSG_ALL && dest != MSG_BROADCAST) {
		return;
	}
	
	new team[2], id = get_msg_arg_int(1);
	get_msg_arg_string(2, team, charsmax(team));
	switch (team[0]) {
		case 'T': {
			g_iCurTeam[id] = CS_TEAM_T;
		}
		case 'C': {
			g_iCurTeam[id] = CS_TEAM_CT;
		}
		case 'S': {
			g_iCurTeam[id] = CS_TEAM_SPECTATOR;
		}
		default: {
			g_iCurTeam[id] = CS_TEAM_UNASSIGNED;
		}
	}
}

public plugin_natives() {
	register_library("MW3_StaticIcon");
	
	register_native("mw3_si_createIcon",	"_createIcon",	  0);
	register_native("mw3_si_removeIcon",	"_removeIcon",	  0);
	register_native("mw3_si_setIconState",	"_setIconState",  0);
	register_native("mw3_si_getIconState",	"_getIconState",  0);
	register_native("mw3_si_changeIconTeam","_changeIconTeam",0);
}

public createSprite(aiment,owner) {
	new sprite = create_entity("info_target");
	
	assert is_valid_ent(sprite);
	
	entity_set_edict(sprite,EV_ENT_aiment,aiment);
	set_pev(sprite,pev_movetype,MOVETYPE_FOLLOW);
	set_pev(sprite,pev_owner,owner);
	set_pev(sprite,pev_solid,SOLID_NOT);
	fm_set_rendering(sprite,.render=kRenderTransAlpha,.amount=0);
	
	return sprite;
}

public mw3_fw_perks_perksChanged(id, bits) {
	static sitRep;
	if (!sitRep) {
		sitRep = mw3_perks_getPerkByName("SitRep");
		sitRep = mw3_perks_convertPerkToBits(sitRep);
	}
	
	if (bits & sitRep) {
		playerAddSitRep(id);
	} else if (playerHasSitRep(id)) {
		playerRemSitRep(id);
	}
}

public mw3_fw_perks_perkAdded(id, perk) {
	static sitRep;
	if (!sitRep) {
		sitRep = mw3_perks_getPerkByName("SitRep");
	}
	
	if (perk == sitRep) {
		playerAddSitRep(id);
	} else if (playerHasSitRep(id)) {
		playerRemSitRep(id);
	}
}

public addToFullPackPost(es, e, ent, host, hostflags, player, pSet) {
	if((1<=host<=MaxPlayers) && is_valid_ent(ent) && OnFirstPersonView[host] && SpectatingUser[host]) {
		if(pev(ent,pev_owner) == EntitiesOwner) {
			if(engfunc(EngFunc_CheckVisibility,ent,pSet)) {
				static spectated, aiment;
				spectated = OnFirstPersonView[host] ? SpectatingUser[host] : host;
				aiment = pev(ent,pev_aiment);
				
				static CsTeams:team;
				team = CsTeams:GetEntTeamID(ent);
		
				if((spectated != aiment) && is_valid_ent(aiment) && GetEntState(ent) == _:icon_Showing && (g_iCurTeam[spectated] == team || team == CS_TEAM_UNASSIGNED || (GetEntHacker(ent) && playerHasSitRep(spectated) && g_iCurTeam[spectated] != team))) {
					static ID[Individual];
		
					ID[Spectated] = spectated;
					ID[Viewed] = ent;
					
					static Float:origin[Individual][Vector];
					
					entity_get_vector(ID[Spectated],EV_VEC_origin,origin[Spectated]);
					get_es(es,ES_Origin,origin[Viewed]);
					
					static Float:diff[Vector];
					static Float:diffAngles[Vector];
					
					xs_vec_sub(origin[Viewed],origin[Spectated],diff);			
					xs_vec_normalize(diff,diff);
					
					vector_to_angle(diff,diffAngles);
					
					diffAngles[0] = -diffAngles[0];
					
					static Float:framePoints[FramePoint][Vector];
					
					calculateFramePoints(origin[Viewed],framePoints,diffAngles);			
					
					static Float:eyes[Vector];
					
					xs_vec_copy(origin[Spectated],eyes);
					
					static Float:viewOfs[Vector];
					entity_get_vector(ID[Spectated],EV_VEC_view_ofs,viewOfs);
					xs_vec_add(eyes,viewOfs,eyes);
					
					static Float:framePointsTraced[FramePoint][Vector];
					
					static FramePoint:closerFramePoint;
					
					traceEyesFrame(ID[Spectated],eyes,framePoints,framePointsTraced,closerFramePoint)
					static Float:otherPointInThePlane[Vector];
					static Float:anotherPointInThePlane[Vector];
					
					static Float:sideVector[Vector];
					static Float:topBottomVector[Vector];
					
					angle_vector(diffAngles,ANGLEVECTOR_UP,topBottomVector);
					angle_vector(diffAngles,ANGLEVECTOR_RIGHT,sideVector);
						
					xs_vec_mul_scalar(sideVector,SomeNonZeroValue,otherPointInThePlane);
					xs_vec_mul_scalar(topBottomVector,SomeNonZeroValue,anotherPointInThePlane);
					
					xs_vec_add(otherPointInThePlane,framePointsTraced[closerFramePoint],otherPointInThePlane);
					xs_vec_add(anotherPointInThePlane,framePointsTraced[closerFramePoint],anotherPointInThePlane);
					
					static Float:plane[4];
					xs_plane_3p(plane,framePointsTraced[closerFramePoint],otherPointInThePlane,anotherPointInThePlane);
						
					moveToPlane(plane,eyes,framePointsTraced,closerFramePoint);
						
					static Float:middle[Vector];
						
					static Float:half = 2.0;
						
					xs_vec_add(framePointsTraced[TopLeft],framePointsTraced[BottomRight],middle);
					xs_vec_div_scalar(middle,half,middle);
						
					new Float:scale = ScaleMultiplier * vector_distance(framePointsTraced[TopLeft],framePointsTraced[TopRight]);
						
					if(scale < ScaleLower) {
						scale = ScaleLower;
					}
						
					set_es(es,ES_AimEnt,0);
					set_es(es,ES_MoveType,MOVETYPE_NONE);
					set_es(es,ES_ModelIndex,GetEntSprite(ID[Viewed]));
					set_es(es,ES_Scale,scale);
					set_es(es,ES_Angles,diffAngles);
					set_es(es,ES_Origin,middle);
					set_es(es,ES_RenderMode,kRenderNormal);
				}
			}
		}
	}
}

calculateFramePoints(Float:origin[Vector],Float:framePoints[FramePoint][Vector],Float:perpendicularAngles[Vector]) {
	new Float:sideVector[Vector];
	new Float:topBottomVector[Vector];
	
	angle_vector(perpendicularAngles,ANGLEVECTOR_UP,topBottomVector);
	angle_vector(perpendicularAngles,ANGLEVECTOR_RIGHT,sideVector);
	
	new Float:sideDislocation[Vector];
	new Float:bottomDislocation[Vector];
	new Float:topDislocation[Vector];
	
	xs_vec_mul_scalar(sideVector,Float:OriginOffsets[FrameSide],sideDislocation);
	xs_vec_mul_scalar(topBottomVector,Float:OriginOffsets[FrameTop],topDislocation);
	xs_vec_mul_scalar(topBottomVector,Float:OriginOffsets[FrameBottom],bottomDislocation);
	
	xs_vec_copy(topDislocation,framePoints[TopLeft]);
	
	xs_vec_add(framePoints[TopLeft],sideDislocation,framePoints[TopRight]);
	xs_vec_sub(framePoints[TopLeft],sideDislocation,framePoints[TopLeft]);
	
	xs_vec_neg(bottomDislocation,framePoints[BottomLeft]);
	
	xs_vec_add(framePoints[BottomLeft],sideDislocation,framePoints[BottomRight]);
	xs_vec_sub(framePoints[BottomLeft],sideDislocation,framePoints[BottomLeft]);
	
	for(new FramePoint:i = TopLeft; i <= BottomRight; i++) {
		xs_vec_add(origin,framePoints[i],framePoints[i]);
	}
	
}

traceEyesFrame(id,Float:eyes[Vector],Float:framePoints[FramePoint][Vector],Float:framePointsTraced[FramePoint][Vector],&FramePoint:closerFramePoint) {
	new Float:smallFraction = 1.0;
	
	for(new FramePoint:i = TopLeft; i <= BottomRight; i++) {
		new trace;
		engfunc(EngFunc_TraceLine,eyes,framePoints[i],IGNORE_GLASS,id,trace);
		
		new Float:fraction;
		get_tr2(trace, TR_flFraction,fraction);
		
		if(fraction < smallFraction) {
			smallFraction = fraction;
			closerFramePoint = i;
		}
		
		get_tr2(trace,TR_EndPos,framePointsTraced[i]);
	}
}

moveToPlane(Float:plane[4],Float:eyes[Vector],Float:framePointsTraced[FramePoint][Vector],FramePoint:alreadyInPlane) {
	new Float:direction[Vector];
	
	for(new FramePoint:i=TopLeft;i<alreadyInPlane;i++) {
		xs_vec_sub(eyes,framePointsTraced[i],direction);
		xs_plane_rayintersect(plane,framePointsTraced[i],direction,framePointsTraced[i]);
	}
	
	for(new FramePoint:i=alreadyInPlane+FramePoint:1;i<=BottomRight;i++) {
		xs_vec_sub(eyes,framePointsTraced[i],direction);
		xs_plane_rayintersect(plane,framePointsTraced[i],direction,framePointsTraced[i]);
	}
}	
	
handleJoiningFirstPersonView(id) {	
	OnFirstPersonView[id] = true;
}

handleQuitingFirstPersonView(id) {
	OnFirstPersonView[id] = false;
	SpectatingUser[id] = 0;
}

public playerSpawn(id) {
	SpectatingUser[id] = id;
	handleJoiningFirstPersonView(id);
}

public playerDeath(id) {
	if(OnFirstPersonView[id]) {
		handleQuitingFirstPersonView(id);
	}
}

public client_disconnect(id) {
	if(OnFirstPersonView[id]) {
		handleQuitingFirstPersonView(id);
	}
}

public specMode(id) {
	new specMode[12];
	read_data(2,specMode,11);
		
	if(specMode[10] == '4') {
		handleJoiningFirstPersonView(id);
	} else if(OnFirstPersonView[id]) {
		handleQuitingFirstPersonView(id);
	}
}

public specTarget(id) {
	new spectated = read_data(2);
		
	if(spectated) {
		if(OnFirstPersonView[id]) {
			if(spectated != SpectatingUser[id]) {
				handleQuitingFirstPersonView(id);
				SpectatingUser[id] = spectated;				
				handleJoiningFirstPersonView(id);
			}
		} else {
			SpectatingUser[id] = spectated;
		}
	}
}

public _createIcon(iPlugin, iParams) {
	if (iParams != 5) {
		return -1;
	}
	
	static ent, spritePath[64];
	ent = get_param(1);
	ent = createSprite(ent,EntitiesOwner);
	SetEntTeamID(ent,_:get_param(2));
	SetEntHacker(ent,_:get_param(3));
	SetEntSprite(ent,get_param(4));
	
	get_string(5, spritePath, 63);
	entity_set_model(ent,spritePath);
	
	return ent;
}

public _changeIconTeam(iPlugin, iParams) {
	if (iParams != 2) {
		return PLUGIN_HANDLED;
	}
	
	SetEntTeamID(get_param(1),_:get_param(2));
	return PLUGIN_HANDLED;
}

public bool:_removeIcon(iPlugin, iParams) {
	if (iParams != 1) {
		return false;
	}
	
	new ent = get_param(1);
	remove_entity(ent);
	return true;
}

public iconStatus:_setIconState(iPlugin, iParams) {
	if (iParams != 2) {
		return icon_None;
	}
	
	static ent, mode;
	ent = get_param(1);
	mode = _:get_param(2);
	SetEntState(ent,_:mode);
	return iconStatus:GetEntState(ent);
}

public iconStatus:_getIconState(iPlugin, iParams) {
	if (iParams != 1) {
		return icon_None;
	}
	
	return iconStatus:GetEntState(get_param(1));
}
