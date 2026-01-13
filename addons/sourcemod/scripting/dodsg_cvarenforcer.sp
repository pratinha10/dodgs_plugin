/*
 * DoD:S ConVar Enforcer
 * 
 * Description:
 *   Monitors and enforces client console variable (CVar) values in Day of Defeat: Source.
 *   Automatically checks player CVars at regular intervals and applies warnings/punishments
 *   for invalid values. Supports multiple checking modes including exact match, range validation,
 *   and min/max limits.
 * 
 * Features:
 *   - Periodic CVar checking with configurable intervals
 *   - Multiple validation modes (equal, not equal, range, min, max)
 *   - Warning system with configurable attempts before punishment
 *   - Public violation alerts visible to all players
 *   - Kick or temporary ban punishments
 *   - Easy configuration via KeyValues file
 * 
 * Commands:
 *   sm_dodsg_check     - Check specific player's CVars (ADMIN)
 * 
 * ConVars:
 *   sm_dodsg_timer     - CVar check interval in seconds (default: 10.0)
 *   sm_dodsg_warn      - Number of warnings before punishment (default: 5)
 * 
 * Configuration:
 *   File: addons/sourcemod/configs/dodsg_cvar_checker.cfg
 * 
 * Author: pratinha
 * Version: 2.0.0
 * URL: https://github.com/pratinha10/dodsg_plugins
 */

#include <sourcemod>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "2.0.0"
#define MAX_CVARS 1000
#define MAX_PATH_LENGTH 256

// Structure to store CVar data
enum struct CvarData
{
    char name[MAX_PATH_LENGTH];
    char value[MAX_PATH_LENGTH];
    char minValue[MAX_PATH_LENGTH];
    char maxValue[MAX_PATH_LENGTH];
    int mode;
    int punishment;
    int banTime;
}

// Global variables
ArrayList g_CvarList;
int g_iPlayerWarnings[MAXPLAYERS + 1];
bool g_bPlayerJustJoined[MAXPLAYERS + 1];
Handle g_hCheckTimer;

// ConVars
ConVar g_cvCheckTimer;
ConVar g_cvMaxWarnings;

public Plugin myinfo =
{
    name = "DoD:S ConVar Enforcer",
    author = "pratinha",
    version = PLUGIN_VERSION,
    description = "Check and enforce client console variable rules",
    url = "https://github.com/pratinha10/dodsg_plugins"
};

public void OnPluginStart()
{
    // Create ConVars
    g_cvCheckTimer = CreateConVar("sm_dodsg_timer", "10.0", "CVar check interval (seconds)", FCVAR_NOTIFY, true, 5.0, true, 60.0);
    g_cvMaxWarnings = CreateConVar("sm_dodsg_warn", "5", "Number of warnings before punishment", FCVAR_NOTIFY, true, 0.0, true, 10.0);
    
    // Hook for changes
    g_cvCheckTimer.AddChangeHook(OnConVarChanged);
    g_cvMaxWarnings.AddChangeHook(OnConVarChanged);
    
    // Admin commands
    RegAdminCmd("sm_dodsg_check", Command_CheckPlayer, ADMFLAG_GENERIC, "Check specific player");
    
    // Auto-execute config
    AutoExecConfig(true, "dodsg_cvar_checker");
    
    // Initialize ArrayList
    g_CvarList = new ArrayList(sizeof(CvarData));
    
    // Load configuration immediately on plugin start
    LoadConfiguration();
}

public void OnConfigsExecuted()
{
    LoadConfiguration();
    StartCheckTimer();
}

public void OnMapStart()
{
    StartCheckTimer();
}

public void OnMapEnd()
{
    StopCheckTimer();
}

void StartCheckTimer()
{
    StopCheckTimer();
    float interval = g_cvCheckTimer.FloatValue;
    g_hCheckTimer = CreateTimer(interval, Timer_CheckCvars, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void StopCheckTimer()
{
    delete g_hCheckTimer;
}

void LoadConfiguration()
{
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/dodsg_cvar_checker.cfg");
    
    PrintToServer("[DODSG] Looking for config file at: %s", configPath);
    
    if (!FileExists(configPath))
    {
        LogError("Configuration file not found: %s", configPath);
        PrintToServer("[DODSG] ERROR: Configuration file not found!");
        return;
    }
    
    PrintToServer("[DODSG] Config file exists, loading...");
    
    // Clear existing list
    g_CvarList.Clear();
    
    KeyValues kv = new KeyValues("cvar");
    
    if (!kv.ImportFromFile(configPath))
    {
        LogError("Failed to load configuration file");
        PrintToServer("[DODSG] ERROR: Failed to import KeyValues from file!");
        delete kv;
        return;
    }
    
    PrintToServer("[DODSG] KeyValues imported successfully");
    
    if (kv.GotoFirstSubKey())
    {
        PrintToServer("[DODSG] Found first subkey, reading CVars...");
        
        do
        {
            CvarData data;
            
            kv.GetSectionName(data.name, sizeof(CvarData::name));
            kv.GetString("value", data.value, sizeof(CvarData::value), "");
            kv.GetString("min", data.minValue, sizeof(CvarData::minValue), "");
            kv.GetString("max", data.maxValue, sizeof(CvarData::maxValue), "");
            data.mode = kv.GetNum("mode", 0);
            data.punishment = kv.GetNum("punishment", 1);
            data.banTime = kv.GetNum("bantime", 0);
            
            g_CvarList.PushArray(data);
            
            PrintToServer("[DODSG] Loaded CVar: %s (mode=%d, value=%s, punishment=%d)", 
                data.name, data.mode, data.value, data.punishment);
        }
        while (kv.GotoNextKey());
    }
    else
    {
        PrintToServer("[DODSG] ERROR: No subkeys found in config file!");
    }
    
    delete kv;
    
    // Reset warnings
    ResetAllWarnings();
    
    LogMessage("Configuration loaded: %d cvars monitored", g_CvarList.Length);
    PrintToServer("[DODSG] Configuration loaded successfully: %d CVars monitored", g_CvarList.Length);
}

void ResetAllWarnings()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iPlayerWarnings[i] = 0;
    }
}

public Action Timer_CheckCvars(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client))
        {
            CheckClientCvars(client);
        }
    }
    
    return Plugin_Continue;
}

void CheckClientCvars(int client)
{
    int length = g_CvarList.Length;
    
    PrintToServer("[DODSG] Checking %d CVars for client %N", length, client);
    
    for (int i = 0; i < length; i++)
    {
        CvarData data;
        g_CvarList.GetArray(i, data);
        
        PrintToServer("[DODSG] Querying CVar: %s for client %N", data.name, client);
        QueryClientConVar(client, data.name, OnCvarQueried, i);
    }
}

public void OnCvarQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, int cvarIndex)
{
    PrintToServer("[DODSG] Query result for %s: result=%d, value=%s, client=%N", cvarName, result, cvarValue, client);
    
    if (!IsValidClient(client))
    {
        PrintToServer("[DODSG] Client %d is not valid, skipping", client);
        return;
    }
    
    if (result != ConVarQuery_Okay)
    {
        HandleQueryError(result, cvarName);
        return;
    }
    
    CvarData data;
    g_CvarList.GetArray(cvarIndex, data);
    
    PrintToServer("[DODSG] Checking %s: current=%s, expected=%s, mode=%d", cvarName, cvarValue, data.value, data.mode);
    
    // Check if value is incorrect
    bool isViolation = false;
    
    switch (data.mode)
    {
        case 0: // Must be equal
        {
            isViolation = !StrEqual(cvarValue, data.value);
        }
        case 1: // Must be different
        {
            isViolation = StrEqual(cvarValue, data.value);
        }
        case 2: // Must be within range (min-max)
        {
            if (data.minValue[0] != '\0' && data.maxValue[0] != '\0')
            {
                float currentValue = StringToFloat(cvarValue);
                float minVal = StringToFloat(data.minValue);
                float maxVal = StringToFloat(data.maxValue);
                
                isViolation = (currentValue < minVal || currentValue > maxVal);
            }
        }
        case 3: // Must be less than or equal
        {
            if (data.value[0] != '\0')
            {
                float currentValue = StringToFloat(cvarValue);
                float maxVal = StringToFloat(data.value);
                
                isViolation = (currentValue > maxVal);
            }
        }
        case 4: // Must be greater than or equal
        {
            if (data.value[0] != '\0')
            {
                float currentValue = StringToFloat(cvarValue);
                float minVal = StringToFloat(data.value);
                
                isViolation = (currentValue < minVal);
            }
        }
    }
    
    if (isViolation)
    {
        PrintToServer("[DODSG] VIOLATION DETECTED! %s = %s for client %N", cvarName, cvarValue, client);
        HandleViolation(client, cvarName, cvarValue, data);
    }
    else
    {
        PrintToServer("[DODSG] CVar %s is correct for client %N", cvarName, client);
    }
}

void HandleViolation(int client, const char[] cvarName, const char[] cvarValue, CvarData data)
{
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
    // If player just joined with wrong values, kick immediately without warnings
    if (g_bPlayerJustJoined[client])
    {
        PrintToServer("[DODSG] Player %N joined with invalid CVar %s = %s - IMMEDIATE KICK", client, cvarName, cvarValue);
        
        // Notify everyone
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidClient(i))
            {
                PrintToChat(i, "\x07FF0000[DODSG]\x01 \x05%s\x01 was kicked for joining with invalid CVar \x04%s\x01 = \x03%s\x01", 
                    clientName, cvarName, cvarValue);
            }
        }
        
        // Apply immediate punishment
        ApplyPunishment(client, cvarName, cvarValue, data);
        return;
    }
    
    // Normal warning system for players already in server
    g_iPlayerWarnings[client]++;
    
    int maxWarnings = g_cvMaxWarnings.IntValue;
    int remainingWarnings = maxWarnings - g_iPlayerWarnings[client];
    
    // Warn player privately
    if (remainingWarnings > 0)
    {
        PrintToChat(client, "\x07FF0000[DODSG]\x01 \x03Warning:\x01 CVar \x04%s\x01 is \x03%s\x01. Fix it or be kicked! (\x05%d\x01 warnings left)", 
            cvarName, cvarValue, remainingWarnings);
    }
    else if (remainingWarnings == 0)
    {
        PrintToChat(client, "\x07FF0000[DODSG]\x01 \x03Final Warning:\x01 CVar \x04%s\x01 is \x03%s\x01. You will be punished in \x05%.0f\x01 seconds!", 
            cvarName, cvarValue, g_cvCheckTimer.FloatValue);
    }
    
    // Notify everyone in the server with eye-catching colors
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            PrintToChat(i, "\x07FF0000[DODSG]\x01 \x05%s\x01 has invalid CVar \x04%s\x01 = \x03%s\x01 (\x05%d\x01 warnings left)", 
                clientName, cvarName, cvarValue, remainingWarnings);
        }
    }
    
    // Apply punishment if needed
    if (g_iPlayerWarnings[client] > maxWarnings)
    {
        ApplyPunishment(client, cvarName, cvarValue, data);
    }
}

void ApplyPunishment(int client, const char[] cvarName, const char[] cvarValue, CvarData data)
{
    char reason[512];
    char expectedValue[256];
    
    // Build expected value message based on mode
    switch (data.mode)
    {
        case 0: // Must be equal
            Format(expectedValue, sizeof(expectedValue), "%s", data.value);
        case 1: // Must be different
            Format(expectedValue, sizeof(expectedValue), "anything except %s", data.value);
        case 2: // Range
            Format(expectedValue, sizeof(expectedValue), "between %s and %s", data.minValue, data.maxValue);
        case 3: // Max
            Format(expectedValue, sizeof(expectedValue), "%s or less", data.value);
        case 4: // Min
            Format(expectedValue, sizeof(expectedValue), "%s or more", data.value);
    }
    
    switch (data.punishment)
    {
        case 1: // Kick
        {
            Format(reason, sizeof(reason), "[DODSG Enforcer] %s %s | Change it to %s", cvarName, cvarValue, expectedValue);
            KickClient(client, "%s", reason);
        }
        case 2: // Ban
        {
            Format(reason, sizeof(reason), "[DODSG Enforcer] %s %s | Change it to %s", cvarName, cvarValue, expectedValue);
            char kickReason[512];
            Format(kickReason, sizeof(kickReason), "[DODSG Enforcer] Banned for invalid CVar: %s %s | Required: %s", cvarName, cvarValue, expectedValue);
            
            BanClient(client, data.banTime, BANFLAG_AUTO, reason, kickReason, "sm_dodsg");
        }
    }
}

void HandleQueryError(ConVarQueryResult result, const char[] cvarName)
{
    switch (result)
    {
        case ConVarQuery_NotFound:
            LogError("Client CVar not found: %s", cvarName);
        case ConVarQuery_NotValid:
            LogError("Console command found but not a CVar: %s", cvarName);
        case ConVarQuery_Protected:
            LogError("CVar is protected, cannot retrieve value: %s", cvarName);
    }
}

public void OnClientPutInServer(int client)
{
    g_iPlayerWarnings[client] = 0;
    g_bPlayerJustJoined[client] = true;
    
    // Check CVars immediately when player joins (after a small delay to let them fully connect)
    if (IsValidClient(client))
    {
        CreateTimer(5.0, Timer_CheckNewPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_CheckNewPlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if (client && IsValidClient(client))
    {
        PrintToServer("[DODSG] Checking CVars for newly connected player: %N", client);
        PrintToServer("[DODSG] Client index: %d, IsInGame: %d, IsFakeClient: %d", client, IsClientInGame(client), IsFakeClient(client));
        CheckClientCvars(client);
        
        // Clear the flag immediately after first check
        // This ensures only the INITIAL join check kicks immediately
        CreateTimer(1.0, Timer_ClearJoinedFlag, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        PrintToServer("[DODSG] Client validation failed for userid %d", userid);
    }
    
    return Plugin_Stop;
}

public Action Timer_ClearJoinedFlag(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    if (client && IsValidClient(client))
    {
        g_bPlayerJustJoined[client] = false;
        PrintToServer("[DODSG] Player %N is now past initial grace period - warnings will apply", client);
    }
    
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    g_iPlayerWarnings[client] = 0;
    g_bPlayerJustJoined[client] = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvCheckTimer)
    {
        StartCheckTimer();
    }
    else if (convar == g_cvMaxWarnings)
    {
        ResetAllWarnings();
    }
}

// ========== COMMANDS ==========

public Action Command_CheckPlayer(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "\x07FF0000[DODSG]\x01 Usage: sm_dodsg_check <name|#userid>");
        return Plugin_Handled;
    }
    
    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if (target == -1)
        return Plugin_Handled;
    
    CheckClientCvars(target);
    
    char targetName[MAX_NAME_LENGTH];
    GetClientName(target, targetName, sizeof(targetName));
    ReplyToCommand(client, "\x07FF0000[DODSG]\x01 Checking %s's CVars...", targetName);
    
    return Plugin_Handled;
}

// ========== HELPER FUNCTIONS ==========

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client));
}