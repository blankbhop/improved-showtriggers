#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <output_info_plugin>

#define PLUGIN_NAME "Show Triggers (Brushes) Redux"
#define PLUGIN_AUTHOR "JoinedSenses, edited by Blank"
#define PLUGIN_DESCRIPTION "Toggle brush visibility"
#define PLUGIN_VERSION "0.2.2"
#define PLUGIN_URL "http://github.com/JoinedSenses"

#define EF_NODRAW 32

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

#define ENABLE_ALL                -2
#define DISABLE_ALL               -1
#define TRIGGER_MULTIPLE           0
#define TRIGGER_PUSH               1
#define TRIGGER_TELEPORT           2
#define TRIGGER_TELEPORT_RELATIVE  3
#define MAX_TYPES                  4

static const char g_NAMES[][] =
{
	"trigger_multiple",
	"trigger_push",
	"trigger_teleport",
	"trigger_teleport_relative"
};


// Which brush types does the player have enabled?
bool g_bTypeEnabled[MAXPLAYERS+1][MAX_TYPES];
// Offset for brush effects
int g_iOffsetMFEffects = -1;

// Main menu
Menu g_Menu;

public void OnPluginStart()
{
	g_iOffsetMFEffects = FindSendPropInfo("CBaseEntity", "m_fEffects");
	if (g_iOffsetMFEffects == -1)
	{
		SetFailState("[Show Triggers] Could not find CBaseEntity:m_fEffects");
	}

	CreateConVar("sm_showtriggers_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD).SetString(PLUGIN_VERSION);

	RegConsoleCmd("sm_showtriggerssettings", cmdShowTriggersSettings, "Toggle trigger settings menu");
	RegConsoleCmd("sm_stsettings", cmdShowTriggersSettings, "Toggle trigger settings menu");
	RegConsoleCmd("sm_sts", cmdShowTriggersSettings, "Toggle trigger settings menu");
	RegConsoleCmd("sm_showtriggers", cmdShowTriggers, "Toggles brush visibility");
	RegConsoleCmd("sm_st", cmdShowTriggers, "Toggles brush visibility");

	Menu menu = new Menu(menuHandler_Main, MenuAction_DrawItem|MenuAction_DisplayItem);
	menu.SetTitle("Toggle Visibility");
	menu.AddItem("-2", "Enable All Triggers");
	menu.AddItem("-1", "Disable All Triggers\n\n");
	for (int i = 0; i < MAX_TYPES; i++)
	{
		menu.AddItem(IntToStringEx(i), g_NAMES[i]);
	}
	g_Menu = menu;
}

public Action cmdShowTriggersHelp(int client, int args)
{
	if (IsValidClient(client))
	{
		PrintToChat(client, "!showtriggers (!st) -> Toggles visibility for trigger_teleport triggers.");
		PrintToChat(client, "!showtriggerssettings (!stsettings, !sts) -> Displays menu to toggle certain trigger visibility.");
	}
	
	return Plugin_Handled;
}

public Action cmdShowTriggers(int client, int args)
{
	if (IsValidClient(client))
	{
		for (int i = 0; i < MAX_TYPES; i++)
		{
			continue;
		}
		if (!g_bTypeEnabled[client][2])
		{
			for (int j = 0; j < MAX_TYPES; j++)
			{
				g_bTypeEnabled[client][2] = true;
			}
			CheckBrushes(ShouldRender());
			PrintToChat(client, "Showtriggers toggled: ON");
			PrintToChat(client, "Consider using !stsettings(!sts) for more options.");
		}
		else
		{
			for (int k = 0; k < MAX_TYPES; k++)
			{
				g_bTypeEnabled[client][2] = false;
			}
			CheckBrushes(ShouldRender());
			PrintToChat(client, "Showtriggers toggled: OFF");
		}
	}

	return Plugin_Handled;
}

// Display trigger menu
public Action cmdShowTriggersSettings(int client, int args)
{
	if (IsValidClient(client))
	{
		if (client)
		{
			g_Menu.Display(client, MENU_TIME_FOREVER);
		}
	}

	return Plugin_Handled;
}

public int menuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[8];
			menu.GetItem(param2, info, sizeof info);

			int type = StringToInt(info);
			switch (type)
			{
				case ENABLE_ALL:
				{
					// Loop through all types and enable
					for (int i = 0; i < MAX_TYPES; i++)
					{
						g_bTypeEnabled[param1][i] = true;
					}
				}
				case DISABLE_ALL:
				{
					// Loop through all types and disable
					for (int i = 0; i < MAX_TYPES; i++)
					{
						g_bTypeEnabled[param1][i] = false;
					}
				}
				default:
				{
					// Toggle selected type
					g_bTypeEnabled[param1][type] = !g_bTypeEnabled[param1][type];
				}
			}
			
			CheckBrushes(ShouldRender());

			menu.DisplayAt(param1, menu.Selection, MENU_TIME_FOREVER);
		}
		// Check *_ALL items to see if they should be disabled
		case MenuAction_DrawItem:
		{
			char info[8];
			menu.GetItem(param2, info, sizeof info);
			switch (StringToInt(info))
			{
				case ENABLE_ALL:
				{
					for (int i = 0; i < MAX_TYPES; i++)
					{
						if (!g_bTypeEnabled[param1][i])
						{
							return ITEMDRAW_DEFAULT;
						}
					}

					return ITEMDRAW_DISABLED;
				}
				case DISABLE_ALL:
				{
					for (int i = 0; i < MAX_TYPES; i++)
					{
						if (g_bTypeEnabled[param1][i])
						{
							return ITEMDRAW_DEFAULT;
						}
					}

					return ITEMDRAW_DISABLED;
				}
			}

			return ITEMDRAW_DEFAULT;
		}
		// Check which items are enabled.
		case MenuAction_DisplayItem:
		{
			char info[8];
			char text[64];
			menu.GetItem(param2, info, sizeof info, _, text, sizeof text);

			int type = StringToInt(info);
			if (type >= 0)
			{
				if (g_bTypeEnabled[param1][type])
				{
					StrCat(text, sizeof text, ": [ON]");
					return RedrawMenuItem(text);
				}
				else
				{
					StrCat(text, sizeof text, ": [OFF]");
				}
			}
		}
	}

	return 0;
}

public void OnClientDisconnect(int client)
{
	for (int i = 0; i < MAX_TYPES; i++)
	{
		g_bTypeEnabled[client][i] = false;
	}

	CheckBrushes(ShouldRender());
}

public void OnPluginEnd()
{
	CheckBrushes(false);
}


// ======================== Normal Functions ========================


/**
 * If transmit state has changed, iterates through each brush type
 * to modify entity flags and to (un)hook as needed.
 * 
 * @param transmit    Should we attempt to transmit these brushes?
 */
void CheckBrushes(bool transmit)
{
	static bool hooked = false;

	// If transmit state has not changed, do nothing
	if (hooked == transmit)
	{
		return;
	}

	hooked = !hooked;

	char className[32];
	for (int ent = MaxClients + 1; ent <= 2048; ent++)
	{
		if (!IsValidEntity(ent))
		{
			continue;
		}

		GetEntityClassname(ent, className, sizeof className);
		if (StrContains(className, "func_") != 0 && StrContains(className, "trigger_") != 0)
		{
			continue;
		}

		for (int i = 0; i < MAX_TYPES; i++)
		{
			if (!StrEqual(className, g_NAMES[i]))
			{
				continue;
			}

			SDKHookCB f = INVALID_FUNCTION;
			switch (i)
			{
				case TRIGGER_MULTIPLE:          f = hookST_triggerMultiple;
				case TRIGGER_PUSH:              f = hookST_triggerPush;
				case TRIGGER_TELEPORT:          f = hookST_triggerTeleport;
				case TRIGGER_TELEPORT_RELATIVE: f = hookST_triggerTeleportRelative;
				// somehow got an invalid index. this shouldnt happen unless someone modifies this plugin and fucks up.
				default: break;
			}

			if (hooked)
			{
				SetEntData(ent, g_iOffsetMFEffects, GetEntData(ent, g_iOffsetMFEffects) & ~EF_NODRAW);
				ChangeEdictState(ent, g_iOffsetMFEffects);
				SetEdictFlags(ent, GetEdictFlags(ent) & ~FL_EDICT_DONTSEND);
				SDKHook(ent, SDKHook_SetTransmit, f);
			}
			else
			{
				SetEntData(ent, g_iOffsetMFEffects, GetEntData(ent, g_iOffsetMFEffects) | EF_NODRAW);
				ChangeEdictState(ent, g_iOffsetMFEffects);
				SetEdictFlags(ent, GetEdictFlags(ent) | FL_EDICT_DONTSEND);
				SDKUnhook(ent, SDKHook_SetTransmit, f);
			}

			break;
		}
	}
}

/**
 * Function to return the int value as a string directly.
 * 
 * @param value    The integer value to convert to string
 * @return         String value of passed integer
 */
char[] IntToStringEx(int value)
{
	char result[11];
	IntToString(value, result, sizeof result);
	return result;
}

/**
 * Function to check if we should be attempting to render any of the brush types.
 * Meant to be passed to CheckTriggers() and used for optimizing SetTransmit hooking.
 * 
 * @return        True if any client has any brush types enabled, else false
 */
bool ShouldRender()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			for (int i = 0; i < MAX_TYPES; i++)
			{
				if (g_bTypeEnabled[client][i])
				{
					return true;
				}
			}
		}
	}

	return false;
}

// ======================== SetTransmit Hooks ========================

public Action hookST_triggerMultiple(int entity, int client)
{
	if (g_bTypeEnabled[client][TRIGGER_MULTIPLE])
	{
		char buffer[32];
		GetEntityClassname(entity, buffer, sizeof(buffer));
		int count = GetOutputCount(entity, "m_OnStartTouch");
		for(int i = 0; i < count; i++)
		{
			GetOutputParameter(entity, "m_OnStartTouch", i, buffer);
			if(StrEqual(buffer, "gravity 40"))
			{
				SetEntityRenderColor(entity, 255, 100, 0, 255);
			}
		}
		count = GetOutputCount(entity, "m_OnEndTouch");
		for(int i = 0; i < count; i++)
		{
			GetOutputParameter(entity, "m_OnEndTouch", i, buffer);
			if(StrContains(buffer, "gravity -") != -1)
			{
				SetEntityRenderColor(entity, 0, 255, 185, 255);
			}
			if(StrContains(buffer, "basevelocity") != -1)
			{
				SetEntityRenderColor(entity, 0, 255, 0, 255);
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action hookST_triggerPush(int entity, int client)
{
	if (g_bTypeEnabled[client][TRIGGER_PUSH])
	{
		SetEntityRenderColor(entity, 0, 255, 0, 255);
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action hookST_triggerTeleport(int entity, int client)
{
	if (g_bTypeEnabled[client][TRIGGER_TELEPORT])
	{
		SetEntityRenderColor(entity, 255, 0, 0, 255);
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action hookST_triggerTeleportRelative(int entity, int client)
{
	if (g_bTypeEnabled[client][TRIGGER_TELEPORT_RELATIVE])
	{
		SetEntityRenderColor(entity, 255, 0, 0, 255);
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

stock bool IsValidClient(int client, bool nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client); 
} 
