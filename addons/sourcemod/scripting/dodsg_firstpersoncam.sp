/**
* Forces First Person POV while dead by pratinha
*
* Description:
*   Forces first person camera when observing teammates after death
*
* Version 1.0.1
* Changelog & more info at https://github.com/pratinha10/dodsg_plugins
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define DELAY_TIME 5.0
#define OBS_MODE_IN_EYE 4
#define OBS_MODE_CHASE 5
#define OBS_MODE_ROAMING 6

public Plugin myinfo = {
    name = "Forces First Person POV while dead",
    author = "pratinha",
    description = "Forces first person camera when observing teammates after death",
    version = "1.0.1",
    url = "https://github.com/pratinha10/dodsg_plugins"
};

public void OnPluginStart() {
    HookEvent("player_death", Event_PlayerDeath);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (victim > 0 && IsClientInGame(victim)) {
        // Fixed 5 seconds delay before forcing first person camera
        CreateTimer(DELAY_TIME, Timer_SetFirstPerson, GetClientUserId(victim));
    }
    
    return Plugin_Continue;
}

public Action Timer_SetFirstPerson(Handle timer, int userid) {
    int client = GetClientOfUserId(userid);
    
    // Validate client before setting observer mode
    if (client > 0 && IsClientInGame(client) && !IsPlayerAlive(client)) {
        // Set observer mode to first person (OBS_MODE_IN_EYE)
        SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);
    }
    
    return Plugin_Stop;
}

public void OnClientPutInServer(int client) {
    // Hook for when client changes observer mode
    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnClientDisconnect(int client) {
    // Unhook when client disconnects to prevent memory leaks
    SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnPostThinkPost(int client) {
    // Only enforce first person for dead players who are observing
    if (IsClientInGame(client) && !IsPlayerAlive(client)) {
        int observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
        
        // If not in first person (mode 4), force to first person
        // Mode 5 is third person, mode 6 is freelook
        if (observerMode == OBS_MODE_CHASE || observerMode == OBS_MODE_ROAMING) {
            SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);
        }
    }
}