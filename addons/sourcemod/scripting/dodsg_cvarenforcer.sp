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
 *   sm_dodsg_test      - Display plugin configuration (ROOT)
 *   sm_dodsg_reload    - Reload configuration file (ROOT)
 *   sm_dodsg_check     - Check specific player's CVars (ADMIN)
 *   sm_dodsg_testmsg   - Test violation message in chat (SERVER CONSOLE)
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
    RegAdminCmd("sm_dodsg_test", Command_Test, ADMFLAG_ROOT, "Test plugin configuration");
    RegAdminCmd("sm_dodsg_reload", Command_Reload, ADMFLAG_ROOT, "Reload configuration");
    RegAdminCmd("sm_dodsg_check", Command_CheckPlayer, ADMFLAG_GENERIC, "Check specific player");
    RegServerCmd("sm_dodsg_testmsg", Command_TestMessage, "Test violation message in chat");
    RegServerCmd("sm_dodsg_testkick", Command_TestKick, "Test kick punishment on all players");
    
    // Auto-execute config
    AutoExecConfig(true, "dodsg_cvar_checker");
    
    // Initialize ArrayList
    g_CvarList = new ArrayList(sizeof(CvarData));
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
    
    if (!FileExists(configPath))
    {
        LogError("Configuration file not found: %s", configPath);
        return;
    }
    
    // Clear existing list
    g_CvarList.Clear();
    
    KeyValues kv = new KeyValues("cvar");
    
    if (!kv.ImportFromFile(configPath))
    {
        LogError("Failed to load configuration file");
        delete kv;
        return;
    }
    
    if (kv.GotoFirstSubKey())
    {
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
        }
        while (kv.GotoNextKey());
    }
    
    delete kv;
    
    // Reset warnings
    ResetAllWarnings();
    
    LogMessage("Configuration loaded: %d cvars monitored", g_CvarList.Length);
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
    
    for (int i = 0; i < length; i++)
    {
        CvarData data;
        g_CvarList.GetArray(i, data);
        
        QueryClientConVar(client, data.name, OnCvarQueried, i);
    }
}

public void OnCvarQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, int cvarIndex)
{
    if (!IsValidClient(client))
        return;
    
    if (result != ConVarQuery_Okay)
    {
        HandleQueryError(result, cvarName);
        return;
    }
    
    CvarData data;
    g_CvarList.GetArray(cvarIndex, data);
    
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
        HandleViolation(client, cvarName, cvarValue, data);
    }
}

void HandleViolation(int client, const char[] cvarName, const char[] cvarValue, CvarData data)
{
    g_iPlayerWarnings[client]++;
    
    int maxWarnings = g_cvMaxWarnings.IntValue;
    int remainingWarnings = maxWarnings - g_iPlayerWarnings[client];
    
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
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
}

public void OnClientDisconnect(int client)
{
    g_iPlayerWarnings[client] = 0;
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

public Action Command_Test(int client, int args)
{
    if (!client || IsFakeClient(client))
        return Plugin_Handled;
    
    int length = g_CvarList.Length;
    PrintToConsole(client, "=== Client ConVar Checker Configuration ===");
    PrintToConsole(client, "Total monitored CVars: %d", length);
    
    for (int i = 0; i < length; i++)
    {
        CvarData data;
        g_CvarList.GetArray(i, data);
        
        PrintToConsole(client, "[%d] %s | Value: %s | Min: %s | Max: %s | Mode: %d | Punishment: %d | Ban: %dm",
            i + 1, data.name, data.value, 
            data.minValue[0] ? data.minValue : "N/A",
            data.maxValue[0] ? data.maxValue : "N/A",
            data.mode, data.punishment, data.banTime);
    }
    
    PrintToChat(client, "Information sent to console.");
    return Plugin_Handled;
}

public Action Command_Reload(int client, int args)
{
    LoadConfiguration();
    
    if (client)
        PrintToChat(client, "\x07FF0000[DODSG]\x01 Configuration reloaded successfully!");
    
    return Plugin_Handled;
}

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

public Action Command_TestMessage(int args)
{
    // Send test violation message to all players in the server
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            PrintToChat(i, "\x07FF0000[DODSG]\x01 \x05TestPlayer\x01 has invalid CVar \x04r_shadows\x01 = \x031\x01 (\x052\x01 warnings left)");
        }
    }
    
    PrintToServer("[DODSG] Test violation message sent to all players in chat!");
    
    return Plugin_Handled;
}

public Action Command_TestKick(int args)
{
    int kickedCount = 0;
    
    // Kick all players in the server with proper expected value message
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            KickClient(i, "[DODSG Enforcer] r_shadows 1 | Change it to 0");
            kickedCount++;
        }
    }
    
    PrintToServer("[DODSG] Test kick executed! %d players kicked from server.", kickedCount);
    
    return Plugin_Handled;
}

// ========== HELPER FUNCTIONS ==========

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client));
}