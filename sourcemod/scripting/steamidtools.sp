#include <sourcemod>
#include <steamidtools>
#include <SteamWorks>
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
	version		= "2.3.1",
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
	g_hDebugMask = CreateConVar("steamidtools_debug_mask", "0", "Debug mask for SteamIDTools. 1=general, 2=request, 4=health, 8=provider", FCVAR_NONE);

	AutoExecConfig(true, "steamidtools");
	g_iNextRequestId = 0;

	RegAdminCmd("sm_steamidtools_debug", Command_SteamIDToolsDebug, ADMFLAG_ROOT, "Show or change SteamIDTools debug mask");

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
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_GENERAL, "Plugin start. late=%d api_base_url=%s health_interval=%.2f debug_mask=%d", g_bLateLoad ? 1 : 0, szApiBaseUrl, g_hHealthCheckInterval.FloatValue, g_hDebugMask.IntValue);

	if (!g_bLateLoad)
	{
		return;
	}

	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded = LibraryExists("system2");
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "Late load provider scan. steamworks=%d system2=%d", g_bSteamWorksLoaded ? 1 : 0, g_bSystem2Loaded ? 1 : 0);
}

/**
 * Refreshes provider availability after every plugin is loaded.
 */
public void OnAllPluginsLoaded()
{
	g_bSteamWorksLoaded = LibraryExists("SteamWorks");
	g_bSystem2Loaded = LibraryExists("system2");
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "All plugins loaded. steamworks=%d system2=%d", g_bSteamWorksLoaded ? 1 : 0, g_bSystem2Loaded ? 1 : 0);
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
	SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_GENERAL, "Configs executed. steamworks=%d system2=%d api_base_url=%s health_interval=%.2f", g_bSteamWorksLoaded ? 1 : 0, g_bSystem2Loaded ? 1 : 0, szApiBaseUrl, g_hHealthCheckInterval.FloatValue);
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
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "Provider removed: SteamWorks");
		SetBackendStatus(SteamIDToolsProvider_SteamWorks, SteamIDToolsBackendStatus_Unknown, "SteamWorks extension unavailable");
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = false;
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "Provider removed: system2");
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
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "Provider added: SteamWorks");
		RequestBackendHealthCheck(SteamIDToolsProvider_SteamWorks);
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = true;
		SteamIDToolsDebug(STEAMIDTOOLS_DEBUG_PROVIDER, "Provider added: system2");
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

public Action Command_SteamIDToolsDebug(int iClient, int iArgs)
{
	if (iArgs >= 1)
	{
		char szMask[32];
		GetCmdArg(1, szMask, sizeof(szMask));
		TrimString(szMask);
		StripQuotes(szMask);
		g_hDebugMask.SetInt(StringToInt(szMask));
	}

	char szSteamWorksStatus[32], szSystem2Status[32];
	GetBackendStatusDisplay(SteamIDToolsProvider_SteamWorks, szSteamWorksStatus, sizeof(szSteamWorksStatus));
	GetBackendStatusDisplay(SteamIDToolsProvider_System2, szSystem2Status, sizeof(szSystem2Status));

	ReplySteamIDToolsDebugCommand(iClient, "debug_mask=%d categories: 1=general 2=request 4=health 8=provider", g_hDebugMask.IntValue);
	ReplySteamIDToolsDebugCommand(iClient, "steamworks: loaded=%d ready=%d status=%s message=%s", g_bSteamWorksLoaded ? 1 : 0, IsProviderReadyInternal(SteamIDToolsProvider_SteamWorks) ? 1 : 0, szSteamWorksStatus, g_szBackendStatusMessage[view_as<int>(SteamIDToolsProvider_SteamWorks)]);
	ReplySteamIDToolsDebugCommand(iClient, "system2: loaded=%d ready=%d status=%s message=%s", g_bSystem2Loaded ? 1 : 0, IsProviderReadyInternal(SteamIDToolsProvider_System2) ? 1 : 0, szSystem2Status, g_szBackendStatusMessage[view_as<int>(SteamIDToolsProvider_System2)]);
	return Plugin_Handled;
}

#include "steamidtools/steamidtools_api.sp"
#include "steamidtools/steamidtools_steamworks.sp"
#include "steamidtools/steamidtools_system2.sp"
