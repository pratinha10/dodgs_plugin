/**
* DoD:S Block Class Respawn by pratinha
*
* Description:
*   Prevents immediately re-spawning after changing player class within a spawn area (always blocks).
*
* Version 1.0
* Changelog & more info at https://github.com/pratinha10/dodgs_plugin
*/

// ====[ CONSTANTS ]======================================================================
#define PLUGIN_NAME    "DoD:S Block Class Respawn"
#define PLUGIN_VERSION "1.0"

#define CLASS_INIT     0
#define MAX_CLASS      6
#define DOD_MAXPLAYERS 33

// Define the GetEntProp condition for m_iDesiredPlayerClass netprop
#define m_iDesiredPlayerClass(%1) (GetEntProp(%1, Prop_Send, "m_iDesiredPlayerClass"))

enum
{
	TEAM_UNASSIGNED,
	TEAM_SPECTATOR,
	TEAM_ALLIES,
	TEAM_AXIS,
	TEAM_SIZE
};

// ====[ VARIABLES ]======================================================================
static const String:block_cmds[][] = { "cls_random", "joinclass" },
	String:allies_cmds[][]  = { "cls_garand", "cls_tommy", "cls_bar",  "cls_spring", "cls_30cal", "cls_bazooka"  },
	String:axis_cmds[][]    = { "cls_k98",    "cls_mp40",  "cls_mp44", "cls_k98s",   "cls_mg42",  "cls_pschreck" },
	String:allies_cvars[][] =
{
	"mp_limit_allies_rifleman",
	"mp_limit_allies_assault",
	"mp_limit_allies_support",
	"mp_limit_allies_sniper",
	"mp_limit_allies_mg",
	"mp_limit_allies_rocket"
},
	String:axis_cvars[][] =
{
	"mp_limit_axis_rifleman",
	"mp_limit_axis_assault",
	"mp_limit_axis_support",
	"mp_limit_axis_sniper",
	"mp_limit_axis_mg",
	"mp_limit_axis_rocket"
};

new	classlimit[TEAM_SIZE][MAX_CLASS], Handle:blockchange_enabled = INVALID_HANDLE;

// ====[ PLUGIN ]=========================================================================
public Plugin:myinfo =
{
	name        = PLUGIN_NAME,
	author      = "pratinha",
	description = "Prevents immediately re-spawning after changing player class within a spawn area (always blocks)",
	version     = PLUGIN_VERSION,
	url         = "https://github.com/pratinha10/dodgs_plugin"
}


/* OnPluginStart()
 *
 * When the plugin starts up.
 * --------------------------------------------------------------------------------------- */
public OnPluginStart()
{
	CreateConVar("dod_blockrespawn_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	blockchange_enabled = CreateConVar("dod_blockrespawn", "1", "Enable/disable blocking player respawning after changing class (0 = disabled, 1 = enabled)", FCVAR_PLUGIN, true, 0.0, true, 1.0);

	for (new i; i < sizeof(block_cmds); i++)
	{
		// Using AddCommandListener to intercept existing commands
		AddCommandListener(OtherClass, block_cmds[i]);
	}

	// Get all commands and classlimit ConVars for both teams
	for (new i; i < MAX_CLASS; i++)
	{
		AddCommandListener(OnAlliesClass, allies_cmds[i]);
		AddCommandListener(OnAxisClass,   axis_cmds[i]);

		// Initialize team-specified classlimits
		classlimit[TEAM_ALLIES][i] = GetConVarInt(FindConVar(allies_cvars[i]));
		classlimit[TEAM_AXIS][i]   = GetConVarInt(FindConVar(axis_cvars[i]));

		// Hook any changes for classlimit cvars
		HookConVarChange(FindConVar(allies_cvars[i]), UpdateClassLimits);
		HookConVarChange(FindConVar(axis_cvars[i]),   UpdateClassLimits);
	}
}

/* UpdateClasslimits()
 *
 * Called when value of classlimit convar is changed.
 * --------------------------------------------------------------------------------------- */
public UpdateClassLimits(Handle:convar, const String:oldValue[], const String:newValue[])
{
	for (new i; i < MAX_CLASS; i++)
	{
		// When classlimit value is changed (for any team/any class), just re-init variables again
		classlimit[TEAM_ALLIES][i] = GetConVarInt(FindConVar(allies_cvars[i]));
		classlimit[TEAM_AXIS][i]   = GetConVarInt(FindConVar(axis_cvars[i]));
	}
}

/* OnAlliesClass()
 *
 * Called when a player has executed a join class command for Allies team.
 * --------------------------------------------------------------------------------------- */
public Action:OnAlliesClass(client, const String:command[], argc)
{
	new team = GetClientTeam(client);

	// Make sure plugin is enabled and player is alive
	if (IsPlayerAlive(client) && GetConVarBool(blockchange_enabled) && team == TEAM_ALLIES)
	{
		new class = CLASS_INIT;
		new cvar  = CLASS_INIT;

		// Loop through available allies class commands
		for (new i; i < sizeof(allies_cmds); i++)
		{
			if (StrEqual(command, allies_cmds[i]))
			{
				class = cvar = i;
				break;
			}
		}

		// Make sure desired player class is available in allies team
		if (IsClassAvailable(client, team, class, cvar))
		{
			// Always block respawn - only change the desired class for next spawn
			PrintUserMessage(client, class, command);
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/* OnAxisClass()
 *
 * Called when a player has executed a join class command for Axis team.
 * --------------------------------------------------------------------------------------- */
public Action:OnAxisClass(client, const String:command[], argc)
{
	new team = GetClientTeam(client);

	if (IsPlayerAlive(client) && GetConVarBool(blockchange_enabled) && team == TEAM_AXIS)
	{
		// Initialize class and cvar numbers
		new class = CLASS_INIT;
		new cvar  = CLASS_INIT;

		for (new i; i < sizeof(axis_cmds); i++)
		{
			// Now assign a class and a convar numbers as same than command
			if (StrEqual(command, axis_cmds[i]))
			{
				class = cvar = i;
				break;
			}
		}

		if (IsClassAvailable(client, team, class, cvar))
		{
			// Always block respawn - only change the desired class for next spawn
			PrintUserMessage(client, class, command);
			SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

/* OtherClass()
 *
 * Called when a player has executed a random or other command to change class.
 * --------------------------------------------------------------------------------------- */
public Action:OtherClass(client, const String:command[], argc)
{
	// Block "joinclass/cls_random" commands if plugin is enabled
	return GetConVarBool(blockchange_enabled) ? Plugin_Handled : Plugin_Continue;
}

/* IsClassAvailable()
 *
 * Checks whether or not desired class is available via limit cvars.
 * --------------------------------------------------------------------------------------- */
bool:IsClassAvailable(client, team, desiredclass, cvarnumber)
{
	// Initialize amount of classes
	new class = CLASS_INIT;

	// Lets loop through all clients from same team
	for (new i = 1; i <= MaxClients; i++)
	{
		// Make sure all clients is in game!
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			// If any classes which teammates are playing right now and matches with desired, increase amount of classes on every match
			if (m_iDesiredPlayerClass(i) == desiredclass) class++;
		}
	}

	if ((class >= classlimit[team][cvarnumber])         // Amount of classes in client's team is more OR same than value of appropriate ConVar
	&& (classlimit[team][cvarnumber] > -1)              // if ConVar value limit is obviously initialized (more than -1)
	|| (m_iDesiredPlayerClass(client)) == desiredclass) // or if current player's class is not a desired one
	{
		return false;
	}

	// Otherwise player may select/play as desired class
	return true;
}

/* PrintUserMessage()
 *
 * Prints default TextMsg usermessage with phrase.
 * --------------------------------------------------------------------------------------- */
PrintUserMessage(client, desiredclass, const String:command[])
{
	// Don't print message if player selected desired class more than once
	if (m_iDesiredPlayerClass(client) != desiredclass)
	{
		// Start a simpler TextMsg usermessage for one client
		new Handle:TextMsg = StartMessageOne("TextMsg", client);

		// Just to be safer
		if (TextMsg != INVALID_HANDLE)
		{
			// Write into a bitbuffer the stock 'You will respawn as' phrase
			decl String:buffer[128];
			Format(buffer, sizeof(buffer), "\x03#Game_respawn_as");
			BfWriteString(TextMsg, buffer);

			// Also write class string to properly show as which class you will respawn
			Format(buffer, sizeof(buffer), "#%s", command);

			// VALVe just called class names same as command names (check dod_english.txt or w/e), it makes name defines way easier
			BfWriteString(TextMsg, buffer);

			// End the TextMsg message. If message will not be sent, memory leak may occur - and PrintToChat* natives will not work
			EndMessage();
		}
	}
}