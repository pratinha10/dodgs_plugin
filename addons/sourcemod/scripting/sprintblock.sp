#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// Offset para stamina no DoD:S
int g_iStaminaOffset = -1;

// Guarda a última stamina para detectar quando recuperou
float g_flLastStamina[MAXPLAYERS + 1];
bool g_bJustRecovered[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "Sprint Exploit Fix",
    author = "pratinha",
    description = "Fix for stamina exploit - forces consumption to 100%",
    version = "1.7",
    url = ""
};

public void OnPluginStart()
{
    // Tenta encontrar o offset da stamina
    g_iStaminaOffset = FindSendPropInfo("CDODPlayer", "m_flStamina");
    
    if (g_iStaminaOffset == -1)
    {
        SetFailState("Não foi possível encontrar m_flStamina offset!");
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
    SDKHook(client, SDKHook_PreThink, Hook_PreThink);
    
    // Timer para mostrar stamina a cada 3 segundos
    CreateTimer(3.0, Timer_ShowStamina, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientDisconnect(int client)
{
    g_flLastStamina[client] = 100.0;
    g_bJustRecovered[client] = false;
    SDKUnhook(client, SDKHook_PreThink, Hook_PreThink);
}

public void Hook_PreThink(int client)
{
    if (!IsPlayerAlive(client))
        return;
    
    int buttons = GetClientButtons(client);
    
    // Obtém stamina atual
    float stamina = GetEntDataFloat(client, g_iStaminaOffset);
    
    // Verifica se está a mover-se
    bool isMoving = (buttons & IN_FORWARD) || (buttons & IN_BACK) || 
                    (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT);
    
    // Detecta quando stamina chega a 100% (recuperou completamente)
    if (stamina >= 99.5 && g_flLastStamina[client] < 99.5)
    {
        g_bJustRecovered[client] = true;
    }
    
    // Se está a pressionar sprint E em movimento E acabou de recuperar
    if ((buttons & IN_SPEED) && isMoving && g_bJustRecovered[client])
    {
        // FORÇA o gasto de 15% no primeiro movimento após recuperar
        SetEntDataFloat(client, g_iStaminaOffset, 85.0, true);
        g_bJustRecovered[client] = false;
    }
    
    // Guarda stamina atual para próximo tick
    g_flLastStamina[client] = stamina;
}

public Action Timer_ShowStamina(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    
    // Se o cliente desconectou, para o timer
    if (client == 0 || !IsClientInGame(client))
        return Plugin_Stop;
    
    // Se não está vivo, não mostra
    if (!IsPlayerAlive(client))
        return Plugin_Continue;
    
    // Obtém stamina atual
    float stamina = GetEntDataFloat(client, g_iStaminaOffset);
    
    // Mostra no chat
    char name[64];
    GetClientName(client, name, sizeof(name));
    PrintToChatAll("%s - Stamina: %.1f%%", name, stamina);
    
    return Plugin_Continue;
}