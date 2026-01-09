//
// SourceMod Script
//
// Originally developed by <eVa>Dog
// Modernized and fixed - 2026
//
// DESCRIPTION:
// For Day of Defeat: Source only
// This plugin implements the "Fade to Black" effect when players die
//
// CHANGELOG:
// - 2026.01 Version 2.0.0 - Complete modernization and bug fixes

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "2.0.0"
#define FADE_IN  0x0001
#define FADE_OUT 0x0002
#define FADE_MODULATE 0x0004
#define FADE_STAYOUT 0x0008
#define FADE_PURGE 0x0010

ConVar g_cvFtbDelay;
ConVar g_cvFtbEnabled;
ConVar g_cvFtbSpeed;
ConVar g_cvFtbRed;
ConVar g_cvFtbGreen;
ConVar g_cvFtbBlue;
ConVar g_cvFtbAlpha;

bool g_bEventHooked = false;

public Plugin myinfo = 
{
	name = "DoDS Fade to Black",
	author = "pratinha",
	description = "Fade to Black for Day of Defeat: Source",
	version = PLUGIN_VERSION,
	url = "https://github.com/pratinha10/dodgs_plugin"
}

public void OnPluginStart()
{
	// Plugin version
	CreateConVar("dodsg_ftb_version", PLUGIN_VERSION, "Version of dodsg_ftb", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Configurable ConVars - enabled by default
	g_cvFtbEnabled = CreateConVar("dodsg_ftb_enabled", "1", "Enable/disable Fade to Black (0 = disabled, 1 = enabled)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_cvFtbSpeed = CreateConVar("dodsg_ftb_speed", "0.5", "Speed of fade transition in seconds (0.1 = instant, 2.0 = slow)", FCVAR_NOTIFY, true, 0.1, true, 5.0);
	g_cvFtbDelay = CreateConVar("dodsg_ftb_delay", "3.0", "Duration to stay black in seconds", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	g_cvFtbRed = CreateConVar("dodsg_ftb_red", "0", "Red value of fade color (0-255)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	g_cvFtbGreen = CreateConVar("dodsg_ftb_green", "0", "Green value of fade color (0-255)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	g_cvFtbBlue = CreateConVar("dodsg_ftb_blue", "0", "Blue value of fade color (0-255)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	g_cvFtbAlpha = CreateConVar("dodsg_ftb_alpha", "255", "Fade transparency (0-255, 255 = opaque)", FCVAR_NOTIFY, true, 0.0, true, 255.0);
	
	// Generate configuration file
	AutoExecConfig(true, "dodsg_ftb");
	
	// Hook ConVar change to manage event hooking
	g_cvFtbEnabled.AddChangeHook(OnEnabledChanged);
	
	// Hook death event if enabled
	if (g_cvFtbEnabled.BoolValue)
	{
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		g_bEventHooked = true;
	}
}

public void OnEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bool enabled = convar.BoolValue;
	
	// Hook event when enabled
	if (enabled && !g_bEventHooked)
	{
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		g_bEventHooked = true;
	}
	// Unhook event when disabled
	else if (!enabled && g_bEventHooked)
	{
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		g_bEventHooked = false;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Safety validations
	if (!IsValidClient(client))
		return;
	
	// Get ConVar values
	int red = g_cvFtbRed.IntValue;
	int green = g_cvFtbGreen.IntValue;
	int blue = g_cvFtbBlue.IntValue;
	int alpha = g_cvFtbAlpha.IntValue;
	float speed = g_cvFtbSpeed.FloatValue;
	float delay = g_cvFtbDelay.FloatValue;
	
	// Apply fade effect
	ApplyScreenFade(client, red, green, blue, alpha, speed, delay);
}

void ApplyScreenFade(int client, int red, int green, int blue, int alpha, float speed, float delay)
{
	// Additional validation
	if (!IsValidClient(client))
		return;
	
	int duration = RoundToNearest(speed * 1000.0); // Fade transition speed (how fast it goes black)
	int holdTime = RoundToNearest(delay * 1000.0); // How long it stays black
	int fadeFlags = FADE_OUT | FADE_STAYOUT;
	
	// Apply the fade to black
	Handle userMessage = StartMessageOne("Fade", client, USERMSG_RELIABLE);
	
	if (userMessage != INVALID_HANDLE)
	{
		BfWriteShort(userMessage, duration);
		BfWriteShort(userMessage, holdTime);
		BfWriteShort(userMessage, fadeFlags);
		BfWriteByte(userMessage, red);
		BfWriteByte(userMessage, green);
		BfWriteByte(userMessage, blue);
		BfWriteByte(userMessage, alpha);
		EndMessage();
	}
	
	// Create timer to fade back to normal after delay
	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(client));
	data.WriteCell(duration);
	CreateTimer(delay, Timer_FadeIn, data);
}

public Action Timer_FadeIn(Handle timer, DataPack data)
{
	data.Reset();
	int userId = data.ReadCell();
	int duration = data.ReadCell();
	delete data;
	
	int client = GetClientOfUserId(userId);
	
	// Check if client is still valid
	if (!IsValidClient(client))
		return Plugin_Stop;
	
	// Fade back to normal (transparent)
	int fadeFlags = FADE_IN | FADE_PURGE;
	
	Handle userMessage = StartMessageOne("Fade", client, USERMSG_RELIABLE);
	
	if (userMessage != INVALID_HANDLE)
	{
		BfWriteShort(userMessage, duration);
		BfWriteShort(userMessage, 0);
		BfWriteShort(userMessage, fadeFlags);
		BfWriteByte(userMessage, 0);
		BfWriteByte(userMessage, 0);
		BfWriteByte(userMessage, 0);
		BfWriteByte(userMessage, 0);
		EndMessage();
	}
	
	return Plugin_Stop;
}

// Helper function to validate clients
bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
	
	if (!IsClientInGame(client))
		return false;
	
	if (IsFakeClient(client))
		return false;
	
	return true;
}