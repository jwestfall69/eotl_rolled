#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <clientprefs>
#include "eotl_rolled.inc"

#define PLUGIN_AUTHOR  "ack"
#define PLUGIN_VERSION "0.10"

#define CONFIG_FILE    "configs/eotl_rolled.cfg"

public Plugin myinfo = {
	name = "eotl_rolled",
	author = PLUGIN_AUTHOR,
	description = "play a sound at the end of around if a team got rolled/stuffed",
	version = PLUGIN_VERSION,
	url = ""
};

ArrayList g_soundsRolled;
ArrayList g_soundsStuffed;
ConVar g_cvTimeRolled;
ConVar g_cvTimeStuffed;
ConVar g_cvCapStuffed;
ConVar g_cvDelay;
ConVar g_cvDebug;

int g_caps;
float g_roundStartTime;
Handle g_hClientCookies;
bool g_bPlayerEnabled[MAXPLAYERS + 1];
bool g_isPayloadMap;

GlobalForward g_OnTeamRolledForward;

public void OnPluginStart() {
    LogMessage("version %s starting", PLUGIN_VERSION);
    RegConsoleCmd("sm_rolled", CommandRolled);

    g_cvTimeRolled = CreateConVar("eotl_rolled_time_rolled", "8", "If red team loses and this many minutes haven't passed, they are considered rolled");
    g_cvTimeStuffed = CreateConVar("eotl_rolled_time_stuffed", "-1", "If blue team loses and this many minutes haven't passed, they are considered stuffed");
    g_cvCapStuffed = CreateConVar("eotl_rolled_cap_stuffed", "1", "If blue team doen't cap this many points they are considered stuffed");
    g_cvDelay = CreateConVar("eotl_rolled_delay", "5.0", "Delay seconds before playing sound at end of round");
    g_cvDebug = CreateConVar("eotl_rolled_debug", "0", "0/1 enable debug output", FCVAR_NONE, true, 0.0, true, 1.0);

    g_soundsRolled = CreateArray(PLATFORM_MAX_PATH);
    g_soundsStuffed = CreateArray(PLATFORM_MAX_PATH);
    g_hClientCookies = RegClientCookie("rolled enabled", "rolled enabled", CookieAccess_Private);

    g_OnTeamRolledForward = CreateGlobalForward("OnTeamRolled", ET_Event, Param_Cell, Param_Cell);

    HookEvent("teamplay_round_start", EventRoundStart, EventHookMode_PostNoCopy);
    HookEvent("teamplay_round_win", EventRoundWin);
    HookEvent("teamplay_point_captured", EventPointCaptured, EventHookMode_PostNoCopy);

}

public void OnMapStart() {
    char mapName[32];

    GetCurrentMap(mapName, sizeof(mapName));
    if(strncmp(mapName, "pl_", 3) == 0) {
        g_isPayloadMap = true;
    } else {
        g_isPayloadMap = false;
    }

    for(int client = 1;client <= MaxClients; client++) {
        g_bPlayerEnabled[client] = false;
    }
    LoadConfig();
}

public void OnClientCookiesCached(int client) {
   LoadClientConfig(client);
}

public void OnClientPostAdminCheck(int client) {
    LoadClientConfig(client);
}

public Action CommandRolled(int client, int args) {
    char argv[16];

    if(args > 1) {
        PrintToChat(client, "\x01[\x03rolled\x01] Invalid syntax, \"!rolled\" to enable, \"!rolled disable\" to disable");
        return Plugin_Handled;
    }

    if(args == 0) {
        if(g_bPlayerEnabled[client]) {
            PrintToChat(client, "\x01[\x03rolled\x01] is already \x03enabled\x01 for you");
            return Plugin_Handled;
        }
        g_bPlayerEnabled[client] = true;
        SaveClientConfig(client);
        PrintToChat(client, "\x01[\x03rolled\x01] sounds are now \x03enabled\x01 for you, run \"!rolled disable\" to re-disable");
        return Plugin_Handled;
    }

    GetCmdArg(1, argv, sizeof(argv));
    StringToLower(argv);

    if(!StrEqual(argv, "disable")) {
        PrintToChat(client, "\x01[\x03rolled\x01] Invalid syntax, \"!rolled\" to enable, \"!rolled disable\" to disable");
        return Plugin_Handled;
    }

    g_bPlayerEnabled[client] = false;
    SaveClientConfig(client);

    PrintToChat(client, "\x01[\x03rolled\x01] sounds are now \x03disabled\x01 for you");
    return Plugin_Handled;
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast) {
    g_roundStartTime = GetGameTime();
    g_caps = 0;
    return Plugin_Continue;
}

public Action EventRoundWin(Handle event, const char[] name, bool dontBroadcast) {

    if(!g_isPayloadMap) {
        LogDebug("Skipping rolled check, not a payload map");
        return Plugin_Continue;
    }

    float roundTime = (GetGameTime() - g_roundStartTime) / 60.0;
    TFTeam winTeam = view_as<TFTeam>(GetEventInt(event, "team"));
    bool isMiniRound = !GetEventInt(event, "full_round");
    int rollType = ROLL_TYPE_NONE;

    float timeRolled = g_cvTimeRolled.FloatValue;
    float timeStuffed = g_cvTimeStuffed.FloatValue;
    int capStuffed = g_cvCapStuffed.IntValue;
    float delay = g_cvDelay.FloatValue;

    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, PLATFORM_MAX_PATH);

    if(delay <= 0.0) {
        delay = 0.1;
    }

    LogMessage("Map: %s, Round Time: %.2f minutes, Winning Team: %s, Caps: %d (Rolled Time: %.1f, Stuffed Time: %.1f, Stuffed Cap: %d)", mapName, roundTime, winTeam == TFTeam_Blue ? "blue" : "red", g_caps, timeRolled, timeStuffed, capStuffed);

    // blue team won, check for a roll
    if(winTeam == TFTeam_Blue) {
        if(timeRolled <= 0.0) {
            return Plugin_Continue;
        }

        if(roundTime > timeRolled) {
            return Plugin_Continue;
        }

        PrintToChatAll("\x01Red got \x03Rolled\x01!");

        if(g_soundsRolled.Length <= 0) {
            LogMessage("No Rolled sounds to play!");
            return Plugin_Continue;
        }

        // doing this in one lines seems to be less random?
        int rand = GetURandomInt();
        int index = rand % g_soundsRolled.Length;

        if(index < g_soundsRolled.Length) {
            CreateTimer(delay, PlaySoundRolled, index, TIMER_FLAG_NO_MAPCHANGE);
        }
        rollType = ROLL_TYPE_ROLLED;

    // red time won, check for stuffed
    } else if(winTeam == TFTeam_Red) {

        bool isStuffed = false;
        // time based
        if(timeStuffed > 0.0 && (roundTime < timeStuffed)) {
            isStuffed = true;
        }

        // didn't cap enough points
        if(capStuffed >= 0 && g_caps <= capStuffed) {
            isStuffed = true;
        }

        if(!isStuffed) {
            return Plugin_Continue;
        }

        PrintToChatAll("\x01Blue got \x03Stuffed\x01!");

        if(g_soundsStuffed.Length <= 0) {
            LogMessage("No Stuffed sounds to play!");
            return Plugin_Continue;
        }

        int rand = GetURandomInt();
        int index = rand % g_soundsStuffed.Length;
        if(index < g_soundsStuffed.Length) {
            CreateTimer(delay, PlaySoundStuffed, index, TIMER_FLAG_NO_MAPCHANGE);
        }
        rollType = ROLL_TYPE_STUFFED;
    }

    Call_StartForward(g_OnTeamRolledForward);
    Call_PushCell(rollType);
    Call_PushCell(isMiniRound);
    Call_Finish();

    return Plugin_Continue;
}

public Action EventPointCaptured(Handle event, const char[] name, bool dontBroadcast) {
    g_caps++;
    return Plugin_Continue;
}

public Action PlaySoundRolled(Handle timer, int index) {
    char file[PLATFORM_MAX_PATH];
    g_soundsRolled.GetString(index, file, sizeof(file));
    LogMessage("Rolled! Playing %s", file);
    PlaySound(file);
    return Plugin_Continue;
}

public Action PlaySoundStuffed(Handle timer, int index) {
    char file[PLATFORM_MAX_PATH];
    g_soundsStuffed.GetString(index, file, sizeof(file));
    LogMessage("Stuffed! Playing %s", file);
    PlaySound(file);
    return Plugin_Continue;
}

// play the sound for the clients that have rolled enabled
void PlaySound(const char [] soundFile) {
    int client;

    for(client = 1; client <= MaxClients; client++) {

        if(!IsClientInGame(client)) {
            continue;
        }

        if(IsFakeClient(client)) {
            continue;
        }

        if(!g_bPlayerEnabled[client]) {
            continue;
        }

        EmitSoundToClient(client, soundFile);
    }
}

void LoadConfig() {

    g_soundsRolled.Clear();
    g_soundsStuffed.Clear();

    KeyValues cfg = CreateKeyValues("rolls");

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), CONFIG_FILE);

    LogMessage("loading config file: %s", configFile);
    if(!FileToKeyValues(cfg, configFile)) {
        SetFailState("unable to load config file!");
        return;
    }

    char name[PLATFORM_MAX_PATH];
    char file[PLATFORM_MAX_PATH];
    char downloadFile[PLATFORM_MAX_PATH];

    if(cfg.JumpToKey("Rolled")) {
        KvGotoFirstSubKey(cfg);
        do {
            cfg.GetSectionName(name, sizeof(name));
            cfg.GetString("file", file, sizeof(file));
            g_soundsRolled.PushString(file);

            Format(downloadFile, sizeof(downloadFile), "sound/%s", file);
            AddFileToDownloadsTable(downloadFile);
            PrecacheSound(file, true);

            LogMessage("loaded rolled %s as file %s", name, file);
        } while(KvGotoNextKey(cfg));
    }

    cfg.Rewind();

    if(cfg.JumpToKey("Stuffed")) {
        KvGotoFirstSubKey(cfg);
        do {
            cfg.GetSectionName(name, sizeof(name));
            cfg.GetString("file", file, sizeof(file));
            g_soundsStuffed.PushString(file);

            Format(downloadFile, sizeof(downloadFile), "sound/%s", file);
            AddFileToDownloadsTable(downloadFile);
            PrecacheSound(file, true);

            LogMessage("loaded stuffed %s as file %s", name, file);
        } while(KvGotoNextKey(cfg));
    }
    CloseHandle(cfg);
}

void LoadClientConfig(int client) {

    if(IsFakeClient(client)) {
        return;
    }

    if(!IsClientInGame(client)) {
        return;
	}

    char enableState[6];
    GetClientCookie(client, g_hClientCookies, enableState, 6);
    if(StrEqual(enableState, "false")) {
        g_bPlayerEnabled[client] = false;
    } else {
        g_bPlayerEnabled[client] = true;
    }

    LogDebug("client: %N has rolled %s", client, g_bPlayerEnabled[client] ? "enabled" : "disabled");
}

void SaveClientConfig(int client) {
    char enableState[6];
    if(g_bPlayerEnabled[client]) {
        Format(enableState, 6, "true");
    } else {
        Format(enableState, 6, "false");
    }

    LogMessage("client: %N saving rolled as %s", client, g_bPlayerEnabled[client] ? "enabled" : "disabled");
    SetClientCookie(client, g_hClientCookies, enableState);
}

void StringToLower(char[] string) {
    int len = strlen(string);
    int i;

    for(i = 0;i < len;i++) {
        string[i] = CharToLower(string[i]);
    }
}

void LogDebug(char []fmt, any...) {

    if(!g_cvDebug.BoolValue) {
        return;
    }

    char message[128];
    VFormat(message, sizeof(message), fmt, 2);
    LogMessage(message);
}