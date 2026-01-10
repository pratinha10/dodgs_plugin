#include <sourcemod>
#include <sdktools>
#include <colors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "2.0.0"
#define MAX_CVARS 1000
#define MAX_PATH_LENGTH 256

// Structure to store CVar data
enum struct CvarData
{
    char name[MAX_PATH_LENGTH];
    char immunity[64];
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
    g_cvMaxWarnings = CreateConVar("sm_dodsg_warn", "3", "Number of warnings before punishment", FCVAR_NOTIFY, true, 0.0, true, 10.0);
    
    // Hook for changes
    g_cvCheckTimer.AddChangeHook(OnConVarChanged);
    g_cvMaxWarnings.AddChangeHook(OnConVarChanged);
    
    // Admin commands
    RegAdminCmd("sm_dodsg_test", Command_Test, ADMFLAG_ROOT, "Test plugin configuration");
    RegAdminCmd("sm_dodsg_reload", Command_Reload, ADMFLAG_ROOT, "Reload configuration");
    RegAdminCmd("sm_dodsg_check", Command_CheckPlayer, ADMFLAG_GENERIC, "Check specific player");
    
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
            kv.GetString("immunity", data.immunity, sizeof(CvarData::immunity), "");
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
    
    // Check immunity
    if (HasImmunity(client, data.immunity))
        return;
    
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
    
    // Log violation
    LogViolation(client, cvarName, cvarValue);
    
    // Notify admins
    NotifyAdmins(clientName, cvarName, cvarValue);
    
    // Warn player
    if (remainingWarnings > 0)
    {
        CPrintToChat(client, "[DODSG] {red}Warning{default}: CVar {green}%s{default} is {red}%s{default}. Fix it or be kicked! ({yellow}%d{default} warnings left)", cvarName, cvarValue, remainingWarnings);
    }
    else if (remainingWarnings == 0)
    {
        CPrintToChat(client, "[DODSG] {red}Final Warning{default}: CVar {green}%s{default} is {red}%s{default}. You will be punished in {yellow}%.0f{default} seconds!", cvarName, cvarValue, g_cvCheckTimer.FloatValue);
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
    
    switch (data.punishment)
    {
        case 1: // Kick
        {
            Format(reason, sizeof(reason), "Invalid CVar: %s = %s", cvarName, cvarValue);
            KickClient(client, "%s", reason);
            LogAction(client, -1, "Client kicked for invalid cvar: %s = %s", cvarName, cvarValue);
        }
        case 2: // Ban
        {
            Format(reason, sizeof(reason), "Invalid CVar: %s = %s", cvarName, cvarValue);
            char kickReason[512];
            Format(kickReason, sizeof(kickReason), "Banned for invalid CVar: %s = %s", cvarName, cvarValue);
            
            BanClient(client, data.banTime, BANFLAG_AUTO, reason, kickReason, "sm_dodsg");
            LogAction(client, -1, "Client banned for %d minutes for invalid cvar: %s = %s", data.banTime, cvarName, cvarValue);
        }
    }
}

void LogViolation(int client, const char[] cvarName, const char[] cvarValue)
{
    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/dodsg_cvar_checker.log");
    LogToFile(logPath, "%L CVar violation detected: %s = %s", client, cvarName, cvarValue);
}

void NotifyAdmins(const char[] clientName, const char[] cvarName, const char[] cvarValue)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsAdmin(i))
        {
            CPrintToChat(i, "[DODSG] {red}Alert{default}: Player {green}%s{default} has invalid CVar {yellow}%s{default} = {red}%s{default}", clientName, cvarName, cvarValue);
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

// ========== COMANDOS ==========

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
        
        PrintToConsole(client, "[%d] %s | Value: %s | Min: %s | Max: %s | Mode: %d | Punishment: %d | Ban: %dm | Immunity: %s",
            i + 1, data.name, data.value, 
            data.minValue[0] ? data.minValue : "N/A",
            data.maxValue[0] ? data.maxValue : "N/A",
            data.mode, data.punishment, data.banTime,
            data.immunity[0] ? data.immunity : "None");
    }
    
    PrintToChat(client, "Information sent to console.");
    return Plugin_Handled;
}

public Action Command_Reload(int client, int args)
{
    LoadConfiguration();
    
    if (client)
        PrintToChat(client, "[DODSG] Configuration reloaded successfully!");
    
    return Plugin_Handled;
}

public Action Command_CheckPlayer(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[DODSG] Usage: sm_dodsg_check <name|#userid>");
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
    ReplyToCommand(client, "[DODSG] Checking %s's CVars...", targetName);
    
    return Plugin_Handled;
}

// ========== HELPER FUNCTIONS ==========

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client));
}

bool IsAdmin(int client)
{
    return CheckCommandAccess(client, "dodsg_admin", ADMFLAG_GENERIC, true);
}

bool HasImmunity(int client, const char[] immunityFlags)
{
    if (immunityFlags[0] == '\0')
        return false;
    
    return CheckCommandAccess(client, "dodsg_immunity", ReadFlagString(immunityFlags), true);
}