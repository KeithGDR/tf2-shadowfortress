/*
"Shadowrun Fortress. Blu is corp security and red are the runners. Runners need to break in and steal the intel or assassinate a specific player and then get out, blu needs to stop them. Blue respawns in waves, increasing in power each spawn. Runners join the corp on death but by far outpower the corp. runners have the choice between race and abilities. Troll is slow but has %50 all damage resist and are 1.5 size. Dwarf is a bit faster but still slow with %25 damage resist and is 0.5 size. Human is base line. Elf is faster and jumps higher but takes %25 more damage but has a 3hp a second regen. Abilities are mage, borg and decker. Mages get to cast spells from a list they can choose. Borgs get man up powers that they get one from the start. Deckers get grappling hooks and can see outlines of everything on both teams."
*/

//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_DESCRIPTION "A Team Fortress 2 custom gamemode."
#define PLUGIN_VERSION "1.0.0"

#define CLASS_NONE	0
#define CLASS_TROLL 1
#define CLASS_DWARF 2
#define CLASS_HUMAN 3
#define CLASS_ELF 	4

#define ABILITY_NONE	0
#define ABILITY_MAGE 	1
#define ABILITY_BORG 	2
#define ABILITY_DECKER 	3

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <sdkhooks>
#include <tf2_stocks>

//External Includes
#include <sourcemod-misc>
#include <colorvariables>
#include <tf2attributes>

//Globals
Handle g_hTimer_Regen;
int g_iClass[MAXPLAYERS + 1];
int g_iAbility[MAXPLAYERS + 1];
int g_iGlowDispenser[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

//Plugin Info
public Plugin myinfo =
{
	name = "[TF2] Gamemode: Shadowrun Fortress",
	author = "Keith Warren (Shaders Allen)",
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "http://www.shadersallen.com/"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	HookEvent("player_spawn", Event_OnPlayerSpawn);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			RemoveDispenser(i);
		}
	}
}

public void OnConfigsExecuted()
{
	KillTimerSafe(g_hTimer_Regen);
	g_hTimer_Regen = CreateTimer(1.0, Timer_RegenTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_RegenTimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_iClass[i] == CLASS_ELF)
		{
			TF2_AddPlayerHealth(i, 3, 1.5, true, false);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public void OnClientDisconnect(int client)
{
	RemoveDispenser(client);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	bool changed;

	switch (g_iClass[victim])
	{
		case CLASS_TROLL:
		{
			damage -= 0.50 * damage;
			changed = true;
		}
		case CLASS_DWARF:
		{
			damage -= 0.25 * damage;
			changed = true;
		}
		case CLASS_ELF:
		{
			damage *= 0.25;
			changed = true;
		}
	}

	return changed ? Plugin_Changed : Plugin_Continue;
}

public Action OnPreThink(int client)
{
	int active = GetActiveWeapon(client);

	if (!IsValidEntity(active) && g_iAbility[client] == ABILITY_DECKER)
	{
		return Plugin_Continue;
	}

	char sName[32];
	GetEntityClassname(active, sName, sizeof(sName));

	if (StrEqual(sName, "tf_weapon_grapplinghook", false))
	{
		SetEntPropFloat(active, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 2.0);
	}

	return Plugin_Continue;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}

	g_iClass[client] = CLASS_NONE;
	g_iAbility[client] = ABILITY_NONE;

	CreateTimer(0.2, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsPlayerIndex(client) || !IsClientInGame(client))
	{
		return;
	}

	RemoveDispenser(client);
}

public Action Timer_DelaySpawn(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	AttachDispenser(client);

	if (TF2_GetClientTeam(client) != TFTeam_Red)
	{
		return Plugin_Stop;
	}

	OpenPickClassMenu(client);

	return Plugin_Stop;
}

void OpenPickClassMenu(int client)
{
	Menu menu = new Menu(MenuHandler_PickClass);
	menu.SetTitle("Pick a Runner class:");

	menu.AddItem("1", "Troll");
	menu.AddItem("2", "Dwarf");
	menu.AddItem("3", "Human");
	menu.AddItem("4", "Elf");

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PickClass(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			menu.GetItem(param2, sID, sizeof(sID));

			g_iClass[param1] = StringToInt(sID);
			ExecuteClassFunctions(param1);

			OpenPickAbilityMenu(param1);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void ExecuteClassFunctions(int client)
{
	switch (g_iClass[client])
	{
		case CLASS_TROLL:
		{
			TF2_ResizePlayer(client, 1.5);
			TF2Attrib_RemoveMoveSpeedBonus(client);
			TF2Attrib_ApplyMoveSpeedPenalty(client, 0.75);
			SetEntityGravity(client, 1.0);
		}
		case CLASS_DWARF:
		{
			TF2_ResizePlayer(client, 0.5);
			TF2Attrib_RemoveMoveSpeedBonus(client);
			TF2Attrib_ApplyMoveSpeedPenalty(client, 0.50);
			SetEntityGravity(client, 1.0);
		}
		case CLASS_HUMAN:
		{
			TF2Attrib_RemoveMoveSpeedBonus(client);
			TF2Attrib_ApplyMoveSpeedPenalty(client, 0.75);
		}
		case CLASS_ELF:
		{
			TF2_ResizePlayer(client, 1.0);
			TF2Attrib_RemoveMoveSpeedPenalty(client);
			TF2Attrib_ApplyMoveSpeedBonus(client, 0.15);
			SetEntityGravity(client, 0.5);
		}
	}
}

void OpenPickAbilityMenu(int client)
{
	Menu menu = new Menu(MenuHandler_PickAbility);
	menu.SetTitle("Pick a Runner ability:");

	menu.AddItem("1", "Mage");
	menu.AddItem("2", "Borg");
	menu.AddItem("3", "Decker");

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_PickAbility(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			menu.GetItem(param2, sID, sizeof(sID));

			g_iAbility[param1] = StringToInt(sID);
			ExecuteAbilityFunctions(param1);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

void ExecuteAbilityFunctions(int client)
{
	switch (g_iAbility[client])
	{
		case ABILITY_MAGE:
		{
			TF2_SetSpell(client, SPELL_FIREBALL, 2);
		}
		case ABILITY_BORG:
		{
			TF2_SetPowerup(client, POWERUP_STRENGTH);
		}
		case ABILITY_DECKER:
		{

		}
	}
}

void AttachDispenser(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	RemoveDispenser(client);

	char sModel[PLATFORM_MAX_PATH];
	GetClientModel(client, sModel, sizeof(sModel));

	int entity = CreateEntityByName("obj_dispenser");

	if (IsValidEntity(entity))
	{
		DispatchSpawn(entity);

		SetEntityModel(entity, sModel);

		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		SetEntityRenderColor(entity, 0, 0, 0, 0);

		SetEntProp(entity, Prop_Send, "m_bGlowEnabled", 1);
		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
		SetEntProp(entity, Prop_Data, "m_takedamage", 0);
		SetEntProp(entity, Prop_Data, "m_nSolidType", 0);
		SetEntProp(entity, Prop_Data, "m_CollisionGroup", 0);
		SetEntProp(entity, Prop_Send, "m_nBody", (view_as<int>(TF2_GetPlayerClass(client))) - 1);
		SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));

		int iFlags = GetEntProp(entity, Prop_Send, "m_fEffects");
		SetEntProp(entity, Prop_Send, "m_fEffects", iFlags | (1 << 0));

		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);

		g_iGlowDispenser[client] = EntIndexToEntRef(entity);
		SDKHook(entity, SDKHook_SetTransmit, OnTransmitGlow);
	}
}

void RemoveDispenser(int client)
{
	RemoveEntRef(g_iGlowDispenser[client]);
}

public Action OnTransmitGlow(int entity, int other)
{
	int client = other;

	if (IsPlayerIndex(client) && IsClientInGame(client) && IsPlayerAlive(client) && g_iAbility[client] == ABILITY_DECKER && !TF2_IsPlayerInCondition(client, TFCond_Cloaked) && !TF2_IsPlayerInCondition(client, TFCond_Stealthed))
	{
			return Plugin_Continue;
	}

	return Plugin_Handled;
}
