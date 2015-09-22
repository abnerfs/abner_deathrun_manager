/*Functions:
	-Prevent "kill" command.
	-Choose a random Terrorist every round.
	-Give kills to terrorists.
	-Limit number of terrorists.
	-Extra frag by kill terrorists.
	-Kill alive cts if round time ends.
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors>

#pragma semicolon 1
#define PLUGIN_VERSION "2.0"

bool jaTR[MAXPLAYERS+1] = false;
Handle roundTime = INVALID_HANDLE;

Handle g_Enabled;
Handle g_TrKills;
Handle g_RandomTR;
Handle g_killTRFrag;
Handle g_TimeLimit;
Handle g_maxTRs;

public Plugin myinfo =
{
	name = "[CSS/CS:GO] AbNeR DeathRun Manager",
	author = "AbNeR_CSS",
	description = "Deathrun manager",
	version = PLUGIN_VERSION,
	url = "www.tecnohardclan.com"
}

public void OnPluginStart()
{  
	CreateConVar("abner_deathrun_version", PLUGIN_VERSION, "Plugin Version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_REPLICATED);
	AutoExecConfig(true, "abner_deathrun");
	
	LoadTranslations("common.phrases");
	LoadTranslations("abner_deathrun.phrases");
	
	g_Enabled = CreateConVar("dr_enabled", "1", "Enable or Disable the Plugin.");
	g_TrKills = CreateConVar("dr_tr_kills", "1", "Give kills to terrorists.");
	g_RandomTR = CreateConVar("dr_random_tr", "1", "Choose a random terrorist every round.");
	g_killTRFrag = CreateConVar("dr_kill_tr_frag", "10", "Frags gives to cts who kills terrorists");
	g_TimeLimit = CreateConVar("dr_time_limit", "1", "Kill alive cts if round time ends.");
	
	AddCommandListener(JoinTeam, "jointeam");
	AddCommandListener(Suicide, "kill");
	
	SetCvar("sv_enablebunnyhopping", "1");
	SetCvar("sv_airaccelerate", "2000");
	SetCvar("mp_autoteambalance", "0");
	SetCvar("mp_limitteams", "0");

	HookEvent("round_start", RoundStart);
	HookEvent("round_end", RoundEnd);
	HookEvent("player_death", PlayerDeath);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
		{
			continue;
		}
		jaTR[i] = false;
		SDKHook(i, SDKHook_OnTakeDamageAlive, OnTakeDamage);
	}
}

public PlayerDeath(Handle event,const char[] name,bool dontBroadcast)
{
	if(GetConVarInt(g_Enabled) != 1)
		return;
		
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if(IsValidClient(attacker) && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 3)
	{
		int frags = GetClientFrags(attacker) +GetConVarInt(g_killTRFrag)-1;
		SetEntProp(attacker, Prop_Data, "m_iFrags", frags);
	}
}

public Action OnTakeDamage(int client, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(GetConVarInt(g_Enabled) != 1 || GetConVarInt(g_TrKills) != 1)
		return Plugin_Continue;
		
	int tr = FoundTR();
	if(GetClientTeam(client) == 3 && IsValidClient(tr))
	{
		attacker = tr;
	}
	return Plugin_Changed;
}


public void OnClientPutInServer(int client)
{	
	jaTR[client] = false;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public Action RoundStart(Handle event, const char[] name, bool dontBroadcast) 
{ 
	if(GetConVarInt(g_Enabled) != 1)
		return Plugin_Continue;
		
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) > 1 && !IsPlayerAlive(i))
		{
			CS_RespawnPlayer(i);
		}
	}
	
	if((GetTeamClientCount(2) == 0 ||  GetTeamClientCount(2) > 1) && GetTeamClientCount(3) + GetTeamClientCount(2) > 1 && GetConVarInt(g_RandomTR) == 1)
	{
		NewRandomTR();
	}
	
	if(GetConVarInt(g_TimeLimit) != 1)
		return Plugin_Continue;
		
	if(roundTime != INVALID_HANDLE)
	{
		KillTimer(roundTime);
	}
	Handle timeCvar = FindConVar("mp_roundtime");
	roundTime = CreateTimer(GetConVarFloat(timeCvar)*60.0, TimeKill);
	return Plugin_Continue;
	
}

public Action TimeKill(Handle timer)
{
	roundTime = INVALID_HANDLE;
	if(GetConVarInt(g_Enabled) != 1 || GetConVarInt(g_TimeLimit) != 1)
		return Plugin_Continue;
		
	for (new i = 1; i < MaxClients; i++)
	{	
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
		{
			int life = GetClientHealth(i) * 2; 
			DealDamage(i, life, 0,(1 << 1));
		}
	}
	CPrintToChatAll("{green}[AbNeR DeathRun] {default}%t", "TimeOver");
	return Plugin_Continue;
}

DealDamage(victim,damage,attacker=0,dmg_type, char[] weapon="")
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0)
	{
		char dmg_str[16];
		IntToString(damage,dmg_str,16);
		char dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		int pointHurt = CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(victim,"targetname","war3_hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","war3_hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","war3_donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

int FoundTR()
{
	for (new i = 1; i < MaxClients; i++)
	{	
		if(IsValidClient(i) && GetClientTeam(i) == 2)
		{
			return i;
		}
	}
	return 0;
}

public Action RoundEnd(Handle event, const char[] name, bool dontBroadcast) 
{ 
	if(GetConVarInt(g_Enabled) != 1 || GetConVarInt(g_RandomTR) != 1)
		return;
		
	allGod();
	int winner = GetEventInt(event, "winner");
	if (winner > 1 || GetTeamClientCount(2) == 0)
	{
		for(int i = 0;i < MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i) == 2)
			{
				CreateTimer(1.0, ChangeTeamTime, i);
			}
		}
		CreateTimer(0.1, NewTR);
	}
}

public void allGod()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			SetEntProp(i, Prop_Data, "m_takedamage", 0, 1);
		}
	}
	
}

public Action NewTR(Handle timer)
{
	NewRandomTR();
}

public Action ChangeTeamTime(Handle timer, any client)
{
	if(IsValidClient(client))
		ChangeTeam(client, 3);
}

public void ChangeTeam(int client, int index)
{
	if(GetClientTeam(client) == 3 && IsPlayerAlive(client))
	{
		ForcePlayerSuicide(client);
		int frags = GetClientFrags(client) +1;
		int deaths = GetClientDeaths(client) -1;
		SetEntProp(client, Prop_Data, "m_iFrags", frags);
		SetEntProp(client, Prop_Data, "m_iDeaths", deaths);
	}
	CS_SwitchTeam(client, index);
}

public void NewRandomTR()
{
	int client = randomTR();
	if(IsValidClient(client))
	{
		ChangeTeam(client, 2);
		CPrintToChatAll("{green}[AbNeR DeathRun]{default} %t", "RandomTR");
	}
}

int randomTR()
{
	if(GetClientCount() < 2)
		return 0;
	
	int count = 0;
	int clients[MAXPLAYERS+1];
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidClient(i) && !jaTR[i] && GetClientTeam(i) == 3)
		{
			clients[count++] = i;
		}
	}
	
	if(count > 0)
	{
		int novotr = clients[GetRandomInt(0, count-1)];
		jaTR[novotr] = true;
		return novotr;
	}
	
	count = 0;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			jaTR[i] = false;
			clients[count++] = i;
		}
	}
	
	if(count > 0)
	{
		int novotr = clients[GetRandomInt(0, count-1)];
		jaTR[novotr] = true;
		return novotr;
	}
	
	return 0;	
} 

stock SetCvar(char[] scvar, char[] svalue)
{
	Handle cvar = FindConVar(scvar);
	if(cvar != INVALID_HANDLE)
		SetConVarString(cvar, svalue, true);
}

public Action JoinTeam(int client, const char[] command, int args)
{
	char argz[32];  
	GetCmdArg(1, argz, sizeof(argz));
	int arg = StringToInt(argz);
	
	if(GetConVarInt(g_Enabled) != 1)
		return Plugin_Continue;
		
	if(arg == 1 && GetClientTeam(client) != 2)
		return Plugin_Continue;
		
	if(GetClientCount() > 1 && GetConVarInt(g_RandomTR) == 1)
	{
		if(GetClientTeam(client) == 0)
		{
			ChangeTeam(client, 3);
		}
		return Plugin_Handled;
	}
	
	if(arg == 2 && (GetTeamClientCount(2) < GetConVarInt(g_maxTRs)) )
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}	

public Action Suicide(int client, const char[] command, int args)
{
	if(GetConVarInt(g_Enabled) != 1)
		return Plugin_Continue;
		
	CPrintToChat(client, "{green}[AbNeR DeathRun] {default}%t.", "KillPrevent");
	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	return IsClientInGame(client);
}





















