#include <sourcemod>
#include <steamidtools>
#include <steamworks>
#include <system2>

#define MAX_API_BASE_URL_LENGTH 192
#define MAX_API_URL_LENGTH 1024
#define STEAMIDTOOLS_PROVIDER_SLOT_COUNT 3
#define STEAMIDTOOLS_BACKEND_STATUS_TEXT_LENGTH 128
#define STEAMIDTOOLS_DEBUG_GENERAL 1
#define STEAMIDTOOLS_DEBUG_REQUEST 2
#define STEAMIDTOOLS_DEBUG_HEALTH 4
#define STEAMIDTOOLS_DEBUG_PROVIDER 8
ConVar g_hApiBaseUrl;
ConVar g_hHealthCheckInterval;
ConVar g_hDebugMask;
Handle g_hRequestFinishedForward = INVALID_HANDLE;
Handle g_hBackendStatusChangedForward = INVALID_HANDLE;
Handle g_hHealthCheckTimer = INVALID_HANDLE;

bool
	g_bLateLoad,
	g_bSteamWorksLoaded,
	g_bSystem2Loaded;

bool g_bBackendStatusKnown[STEAMIDTOOLS_PROVIDER_SLOT_COUNT];
bool g_bBackendOnline[STEAMIDTOOLS_PROVIDER_SLOT_COUNT];
bool g_bHealthCheckInFlight[STEAMIDTOOLS_PROVIDER_SLOT_COUNT];
char g_szBackendStatusMessage[STEAMIDTOOLS_PROVIDER_SLOT_COUNT][STEAMIDTOOLS_BACKEND_STATUS_TEXT_LENGTH];

int g_iNextRequestId;

public Plugin myinfo =
{
	name		= "SteamID Tools",
	author		= "lechuga",
	description = "SteamIDTools API plugin supporting SteamWorks and system2",
	version		= STEAMIDTOOLS_VERSION,
	url			= "https://github.com/AoC-Gamers/SteamIDTools"
};

void SteamIDToolsDebug(int iMask, const char[] szMessage, any ...)
{
	if (g_hDebugMask == null || (g_hDebugMask.IntValue & iMask) == 0)
	{
		return;
	}

	char szBuffer[512];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
	LogMessage("[STEAMIDTOOLS][debug] %s", szBuffer);
}

void ReplySteamIDToolsDebugCommand(int iClient, const char[] szMessage, any ...)
{
	char szBuffer[256];
	VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
	ReplyToCommand(iClient, "[STEAMIDTOOLS] %s", szBuffer);
}

/**
 * Registers the SteamIDTools library and its public natives.
 */
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	g_bLateLoad = bLate;

	RegPluginLibrary(STEAMIDTOOLS_LIBRARY);
	CreateNative("SteamIDTools_IsProviderAvailable", Native_IsProviderAvailable);
	CreateNative("SteamIDTools_GetBackendStatus", Native_GetBackendStatus);
	CreateNative("SteamIDTools_IsProviderReady", Native_IsProviderReady);
	CreateNative("SteamIDTools_RequestHealthCheck", Native_RequestHealthCheck);
	CreateNative("SteamIDTools_GetBackendStatusMessage", Native_GetBackendStatusMessage);
	CreateNative("SteamIDTools_GetApiBaseUrl", Native_GetApiBaseUrl);
	CreateNative("SteamIDTools_RequestConversion", Native_RequestConversion);
	CreateNative("SteamIDTools_RequestBatch", Native_RequestBatch);
	g_hRequestFinishedForward = CreateGlobalForward("SteamIDTools_OnRequestFinished", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	g_hBackendStatusChangedForward = CreateGlobalForward("SteamIDTools_OnBackendStatusChanged", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	return APLRes_Success;
}

/**
 * Creates plugin state and generates the plugin autoexec config.
 */
public void OnPluginStart()
{
	g_hApiBaseUrl = CreateConVar("steamidtools_api_base_url", "http://localhost:80", "Base URL for SteamIDTools HTTP requests", FCVAR_NONE);
	g_hHealthCheckInterval = CreateConVar("steamidtools_health_check_interval", "60.0", "Interval in seconds between backend health checks. Set to 0 to disable periodic checks.", FCVAR_NONE);
	g_hDebugMask = CreateConVar("steamidtools_debug_mask", "0", "Debug mask for SteamIDTools. 1=general, 2=request, 4=health, 8=provider (all=15)", FCVAR_NONE);

	AutoExecConfig(true, "steamidtools");
	g_iNextRequestId = 0;

	RegAdminCmd("sm_steamidtools_health", Command_SteamIDToolsHealth, ADMFLAG_ROOT, "Queue an immediate SteamIDTools backend health check for loaded providers");

	for (int i = 0; i < STEAMIDTOOLS_PROVIDER_SLOT_COUNT; i++)
	{
		g_bBackendStatusKnown[i] = false;
		g_bBackendOnline[i] = false;
		g_bHealthCheckInFlight[i] = false;
		strcopy(g_szBackendStatusMessage[i], sizeof(g_szBackendStatusMessage[]), "Not checked");
	}

	HookConVarChange(g_hApiBaseUrl, OnSteamIDToolsSettingsChanged);
	HookConVarChange(g_hHealthCheckInterval, OnSteamIDToolsSettingsChanged);
	HookConVarChange(g_hDebugMask, OnSteamIDToolsSettingsChanged);

	char szApiBaseUrl[MAX_API_BASE_URL_LENGTH];
	g_hApiBaseUrl.GetString(szApiBaseUrl, sizeof(szApiBaseUrl));

	if (!g_bLateLoad)
	{
		return;
	}

	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded = LibraryExists("system2");
}

/**
 * Refreshes provider availability after every plugin is loaded.
 */
public void OnAllPluginsLoaded()
{
	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded = LibraryExists("system2");
}

/**
 * Applies autoexec values after config execution and refreshes backend state.
 *
 * This runs on every map change, which keeps the status aligned with runtime
 * cvar values without depending only on the periodic timer.
 */
public void OnConfigsExecuted()
{
	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded = LibraryExists("system2");
	char szApiBaseUrl[MAX_API_BASE_URL_LENGTH];
	g_hApiBaseUrl.GetString(szApiBaseUrl, sizeof(szApiBaseUrl));
	RestartHealthCheckTimer();
	RequestAllBackendHealthChecks();
}

/**
 * Tracks when an HTTP provider extension becomes unavailable.
 */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
	{
		g_bSteamWorksLoaded = false;
		SetBackendStatus(SteamIDToolsProvider_SteamWorks, SteamIDToolsBackendStatus_Unknown, "SteamWorks extension unavailable");
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = false;
		SetBackendStatus(SteamIDToolsProvider_System2, SteamIDToolsBackendStatus_Unknown, "system2 extension unavailable");
	}
}

/**
 * Tracks when an HTTP provider extension becomes available again.
 */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
	{
		g_bSteamWorksLoaded = true;
		RequestBackendHealthCheck(SteamIDToolsProvider_SteamWorks);
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = true;
		RequestBackendHealthCheck(SteamIDToolsProvider_System2);
	}
}

public void OnPluginEnd()
{
	if (g_hHealthCheckTimer != INVALID_HANDLE)
	{
		delete g_hHealthCheckTimer;
		g_hHealthCheckTimer = INVALID_HANDLE;
	}
}

public Action Command_SteamIDToolsHealth(int iClient, int iArgs)
{
	if (iArgs != 0)
	{
		ReplySteamIDToolsDebugCommand(iClient, "usage: sm_steamidtools_health");
		return Plugin_Handled;
	}

	bool bSteamWorksQueued = RequestBackendHealthCheck(SteamIDToolsProvider_SteamWorks);
	bool bSystem2Queued = RequestBackendHealthCheck(SteamIDToolsProvider_System2);
	ReplySteamIDToolsDebugCommand(iClient, "health queued: steamworks=%d system2=%d", bSteamWorksQueued ? 1 : 0, bSystem2Queued ? 1 : 0);
	return Plugin_Stop;
}

#include "steamidtools/steamidtools_api.sp"
#include "steamidtools/steamidtools_steamworks.sp"
#include "steamidtools/steamidtools_system2.sp"
