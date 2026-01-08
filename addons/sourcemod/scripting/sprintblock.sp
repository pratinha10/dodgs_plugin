/**
* DoD:S Sprint Exploit Fix by pratinha
*
* Description:
*   Fixes the stamina sprint exploit - add penalty to who sprint+forward.
*
* Version 2.0 - Updated for SourceMod 1.11+
* Changelog & more info at https://github.com/pratinha10/dodgs_plugin
*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// Offset for stamina in DoD:S
int g_iStaminaOffset = -1;

// Stores last stamina to detect when it recovered
float g_flLastStamina[MAXPLAYERS + 1];
bool g_bJustRecovered[MAXPLAYERS + 1];
bool g_bSprintFirstDetected[MAXPLAYERS + 1]; // Track if pressed sprint first

// Track previous button state to detect order
int g_iPreviousButtons[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "DoD:S Sprint Exploit Fix",
    author = "pratinha",
    description = "Fixes the stamina sprint exploit - add penalty to who sprint+forward",
    version = "2.0",
    url = ""
};

public void OnPluginStart()
{
    // Try to find stamina offset
    g_iStaminaOffset = FindSendPropInfo("CDODPlayer", "m_flStamina");
    
    if (g_iStaminaOffset == -1)
    {
        SetFailState("Could not find m_flStamina offset!");
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_PreThink, Hook_PreThink);
        }
    }
}

public void OnClientPutInServer(int client)
{
    g_flLastStamina[client] = 100.0;
    g_bJustRecovered[client] = false;
    g_bSprintFirstDetected[client] = false;
    g_iPreviousButtons[client] = 0;
    SDKHook(client, SDKHook_PreThink, Hook_PreThink);
    
    // Timer to show stamina every 3 seconds
    CreateTimer(3.0, Timer_ShowStamina, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
    g_flLastStamina[client] = 100.0;
    g_bJustRecovered[client] = false;
    g_bSprintFirstDetected[client] = false;
    g_iPreviousButtons[client] = 0;
    SDKUnhook(client, SDKHook_PreThink, Hook_PreThink);
}

public void Hook_PreThink(int client)
{
    if (!IsPlayerAlive(client))
        return;
    
    int buttons = GetClientButtons(client);
    int prevButtons = g_iPreviousButtons[client];
    
    // Get current stamina
    float stamina = GetEntDataFloat(client, g_iStaminaOffset);
    
    // Check if player is moving
    bool isMoving = (buttons & IN_FORWARD) || (buttons & IN_BACK) || 
                    (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT);
    
    // Detect button press order
    bool justPressedForward = (buttons & IN_FORWARD) && !(prevButtons & IN_FORWARD);
    bool justPressedSprint = (buttons & IN_SPEED) && !(prevButtons & IN_SPEED);
    bool hadForward = (prevButtons & IN_FORWARD);
    bool hadSprint = (prevButtons & IN_SPEED);
    
    // Detect if player pressed SPRINT FIRST, then FORWARD (exploit pattern)
    if (justPressedForward && hadSprint)
    {
        g_bSprintFirstDetected[client] = true;
        PrintToChatAll("[DEBUG] %N pressed: SPRINT first, then FORWARD - WILL BE PENALIZED", client);
    }
    else if (justPressedSprint && hadForward)
    {
        g_bSprintFirstDetected[client] = false;
        PrintToChatAll("[DEBUG] %N pressed: FORWARD first, then SPRINT - NORMAL", client);
    }
    
    // Reset sprint-first flag when both keys are released
    if (!(buttons & IN_SPEED) && !(buttons & IN_FORWARD))
    {
        g_bSprintFirstDetected[client] = false;
    }
    
    // Check if actively sprinting (sprint + FORWARD only)
    bool isActivelySprinting = (buttons & IN_SPEED) && (buttons & IN_FORWARD);
    
    // Detect when stamina reaches 100% (fully recovered)
    if (stamina >= 99.5 && g_flLastStamina[client] < 99.5)
    {
        g_bJustRecovered[client] = true;
        PrintToChatAll("[DEBUG] %N stamina recovered to 100%%", client);
    }
    
    // Apply 15% penalty ONLY if:
    // 1. Pressing sprint AND moving
    // 2. Just recovered stamina
    // 3. Pressed SPRINT FIRST (exploit pattern)
    if (isActivelySprinting && g_bJustRecovered[client] && g_bSprintFirstDetected[client])
    {
        // FORCE 15% stamina cost on first movement after recovery
        SetEntDataFloat(client, g_iStaminaOffset, 85.0, true);
        g_bJustRecovered[client] = false;
        PrintToChatAll("[DEBUG] %N PENALIZED - stamina forced to 85%%", client);
    }
    else if (isActivelySprinting && g_bJustRecovered[client] && !g_bSprintFirstDetected[client])
    {
        // Normal sprint (forward first) - no penalty
        g_bJustRecovered[client] = false;
        PrintToChatAll("[DEBUG] %N started sprint normally - NO PENALTY", client);
    }
    
    // Store current stamina for next tick
    g_flLastStamina[client] = stamina;
    
    // Store current buttons for next tick
    g_iPreviousButtons[client] = buttons;
}

public Action Timer_ShowStamina(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    // If client disconnected, stop timer
    if (client == 0 || !IsClientInGame(client))
        return Plugin_Stop;
    
    // If not alive, don't show
    if (!IsPlayerAlive(client))
        return Plugin_Continue;
    
    // Get current stamina
    float stamina = GetEntDataFloat(client, g_iStaminaOffset);
    
    // Show in chat
    char name[64];
    GetClientName(client, name, sizeof(name));
    PrintToChatAll("%s - Stamina: %.1f%%", name, stamina);
    
    return Plugin_Continue;
}