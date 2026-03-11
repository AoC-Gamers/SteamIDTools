#include <sourcemod>
#include <steamidtools>
#include <SteamWorks>
#include <system2>

#define MAX_API_BASE_URL_LENGTH 192
#define MAX_API_URL_LENGTH 1024

ConVar g_hApiBaseUrl;
Handle g_hRequestFinishedForward = INVALID_HANDLE;

bool
	g_bLateLoad,
	g_bSteamWorksLoaded,
	g_bSystem2Loaded;

int g_iNextRequestId;

public Plugin myinfo =
{
	name		= "SteamID Tools",
	author		= "lechuga",
	description = "SteamIDTools API plugin supporting SteamWorks and system2",
	version		= "2.2.0",
	url			= "https://github.com/AoC-Gamers/SteamIDTools"
};

/**
 * Registers the SteamIDTools library and its public natives.
 */
public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax)
{
	g_bLateLoad = bLate;

	RegPluginLibrary(STEAMIDTOOLS_LIBRARY);
	CreateNative("SteamIDTools_IsProviderAvailable", Native_IsProviderAvailable);
	CreateNative("SteamIDTools_GetApiBaseUrl", Native_GetApiBaseUrl);
	CreateNative("SteamIDTools_RequestConversion", Native_RequestConversion);
	CreateNative("SteamIDTools_RequestBatch", Native_RequestBatch);
	g_hRequestFinishedForward = CreateGlobalForward("SteamIDTools_OnRequestFinished", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_String);

	return APLRes_Success;
}

/**
 * Creates plugin state and generates the plugin autoexec config.
 */
public void OnPluginStart()
{
	g_hApiBaseUrl = CreateConVar("steamidtools_api_base_url", "http://localhost:80", "Base URL for SteamIDTools HTTP requests", FCVAR_NONE);
	AutoExecConfig(true, "steamidtools");
	g_iNextRequestId = 0;

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
 * Tracks when an HTTP provider extension becomes unavailable.
 */
public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "SteamWorks"))
	{
		g_bSteamWorksLoaded = false;
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = false;
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
	}
	else if (StrEqual(sName, "system2"))
	{
		g_bSystem2Loaded = true;
	}
}

#include "steamidtools/steamidtools_api.sp"
#include "steamidtools/steamidtools_steamworks.sp"
#include "steamidtools/steamidtools_system2.sp"
