#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

// Tempo em segundos para bloquear o sprint após spawn
#define SPRINT_BLOCK_TIME 0.2

// Array para guardar o tempo de spawn de cada jogador
float g_flSpawnTime[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "DoD:S Sprint Block on Spawn",
    author = "pratinha",
    description = "Impede jogadores de usar sprint imediatamente após renascer",
    version = PLUGIN_VERSION,
    url = "https://github.com/pratinha10/dodgs_plugin"
};

public void OnPluginStart()
{
    // Hook do evento de spawn
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // Hook para todos os clientes já conectados
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
    g_flSpawnTime[client] = 0.0;
    SDKHook(client, SDKHook_PreThink, Hook_PreThink);
}

public void OnClientDisconnect(int client)
{
    g_flSpawnTime[client] = 0.0;
    SDKUnhook(client, SDKHook_PreThink, Hook_PreThink);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client > 0 && IsClientInGame(client))
    {
        // Guarda o tempo atual como tempo de spawn
        g_flSpawnTime[client] = GetGameTime();
    }
    
    return Plugin_Continue;
}

public void Hook_PreThink(int client)
{
    if (!IsPlayerAlive(client))
        return;
    
    // Verifica se está dentro do período de bloqueio
    float currentTime = GetGameTime();
    if (g_flSpawnTime[client] > 0.0 && 
        (currentTime - g_flSpawnTime[client]) < SPRINT_BLOCK_TIME)
    {
        // Remove o botão de sprint dos botões pressionados
        int buttons = GetClientButtons(client);
        if (buttons & IN_SPEED)
        {
            buttons &= ~IN_SPEED;
            SetEntProp(client, Prop_Data, "m_nButtons", buttons);
        }
    }
}