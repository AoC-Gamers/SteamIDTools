/*
	steamidtools.inc
	Copyright (C) 2025 lechuga

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#if defined _steamidtools_included
	#endinput
#endif
#define _steamidtools_included

#include <clients>

#define ACCOUNTID_LENGTH	   16
#define STEAMID64_EXACT_LENGTH 17
#define STEAMID2_MIN_LENGTH	   11
#define STEAMID3_MIN_LENGTH	   8
#define STEAMID64_BASE		   76561197960265728

#define API_SID64toAID    "/SID64toAID"
#define API_SID64toSID2   "/SID64toSID2"
#define API_SID64toSID3   "/SID64toSID3"
#define API_AIDtoSID64    "/AIDtoSID64"
#define API_SID2toSID64   "/SID2toSID64"
#define API_SID3toSID64   "/SID3toSID64"
#define API_Health        "/health"

/**
 * Enum for different SteamID formats
 */
enum SteamIDFormat
{
	STEAMID_FORMAT_UNKNOWN = 0,
	STEAMID_FORMAT_STEAMID2,
	STEAMID_FORMAT_STEAMID3,
	STEAMID_FORMAT_STEAMID64,
	STEAMID_FORMAT_ACCOUNTID,
	STEAMID_FORMAT_SPECIAL
}

/**
 * Validates if a SteamID2 has valid format
 * Expected format: STEAM_X:Y:Z where X=0|1, Y=0|1, Z=number
 *
 * @param szSteamId2    SteamID2 string to validate
 * @return              true if valid format, false otherwise
 */
stock bool IsValidSteamID2(const char[] szSteamId2)
{
	if (strlen(szSteamId2) < 11)
	{
		return false;
	}

	if (StrContains(szSteamId2, "STEAM_", false) != 0)
	{
		return false;
	}

	int iColonCount = 0;
	for (int i = 0; szSteamId2[i] != '\0'; i++)
	{
		if (szSteamId2[i] == ':')
		{
			iColonCount++;
		}
	}

	return (iColonCount == 2);
}

/**
 * Converts SteamID2 to AccountID
 * Format: STEAM_X:Y:Z -> AccountID = Z * 2 + Y
 *
 * @param szSteamId2    SteamID2 string (STEAM_X:Y:Z)
 * @return              AccountID, or 0 if invalid
 */
stock int SteamID2ToAccountID(const char[] szSteamId2)
{
	if (!IsValidSteamID2(szSteamId2))
	{
		return 0;
	}

	char szParts[3][16];
	if (ExplodeString(szSteamId2, ":", szParts, sizeof(szParts), sizeof(szParts[])) != 3)
	{
		return 0;
	}

	int iY = StringToInt(szParts[1]);
	int iZ = StringToInt(szParts[2]);

	return iZ * 2 + iY;
}

/**
 * Converts AccountID to SteamID2
 *
 * @param iAccountId    AccountID to convert
 * @param szBuffer      Buffer to store the result
 * @param iMaxlen       Maximum buffer length
 * @return              true on success, false on failure
 */
stock bool AccountIDToSteamID2(int iAccountId, char[] szBuffer, int iMaxlen)
{
	if (iAccountId <= 0)
	{
		return false;
	}

	int iY = iAccountId & 1;
	int iZ = iAccountId >> 1;

	Format(szBuffer, iMaxlen, "STEAM_0:%d:%d", iY, iZ);
	return true;
}

/**
 * Validates if a SteamID64 is valid
 *
 * @param szSteamId64   SteamID64 string to validate
 * @return              true if valid, false otherwise
 */
stock bool IsValidSteamID64(const char[] szSteamId64)
{
	if (strlen(szSteamId64) < 17 || strlen(szSteamId64) > 17)
	{
		return false;
	}

	for (int i = 0; szSteamId64[i] != '\0'; i++)
	{
		if (!IsCharNumeric(szSteamId64[i]))
		{
			return false;
		}
	}

	return (StrContains(szSteamId64, "76561197", false) == 0 || StrContains(szSteamId64, "76561198", false) == 0);
}

/**
 * Validates if a SteamID3 is valid
 * Format: [U:1:XXXXXXXX]
 *
 * @param szSteamId3    SteamID3 string to validate
 * @return              true if valid, false otherwise
 */
stock bool IsValidSteamID3(const char[] szSteamId3)
{
	if (strlen(szSteamId3) < 8)
	{
		return false;
	}

	if (StrContains(szSteamId3, "[U:1:", false) != 0)
	{
		return false;
	}

	if (szSteamId3[strlen(szSteamId3) - 1] != ']')
	{
		return false;
	}

	return true;
}

/**
 * Converts SteamID3 to AccountID
 * Format: [U:1:XXXXXXXX] -> XXXXXXXX
 *
 * @param szSteamId3    SteamID3 string
 * @return              AccountID, or 0 if invalid
 */
stock int SteamID3ToAccountID(const char[] szSteamId3)
{
	if (!IsValidSteamID3(szSteamId3))
	{
		return 0;
	}

	char szTemp[32];
	strcopy(szTemp, sizeof(szTemp), szSteamId3[5]);

	int iLen = strlen(szTemp);
	if (iLen > 0 && szTemp[iLen - 1] == ']')
	{
		szTemp[iLen - 1] = '\0';
	}

	return StringToInt(szTemp);
}

/**
 * Converts AccountID to SteamID3
 *
 * @param iAccountId    AccountID to convert
 * @param szBuffer      Buffer to store the result
 * @param iMaxlen       Maximum buffer length
 * @return              true on success, false on failure
 */
stock bool AccountIDToSteamID3(int iAccountId, char[] szBuffer, int iMaxlen)
{
	if (iAccountId <= 0)
	{
		return false;
	}

	Format(szBuffer, iMaxlen, "[U:1:%d]", iAccountId);
	return true;
}

/**
 * Converts SteamID2 to SteamID3
 *
 * @param szSteamId2    SteamID2 string
 * @param szBuffer      Buffer to store the result
 * @param iMaxlen       Maximum buffer length
 * @return              true on success, false on failure
 */
stock bool SteamID2ToSteamID3(const char[] szSteamId2, char[] szBuffer, int iMaxlen)
{
	int iAccountId = SteamID2ToAccountID(szSteamId2);
	if (iAccountId == 0)
	{
		return false;
	}

	return AccountIDToSteamID3(iAccountId, szBuffer, iMaxlen);
}

/**
 * Converts SteamID3 to SteamID2
 *
 * @param szSteamId3    SteamID3 string
 * @param szBuffer      Buffer to store the result
 * @param iMaxlen       Maximum buffer length
 * @return              true on success, false on failure
 */
stock bool SteamID3ToSteamID2(const char[] szSteamId3, char[] szBuffer, int iMaxlen)
{
	int iAccountId = SteamID3ToAccountID(szSteamId3);
	if (iAccountId == 0)
	{
		return false;
	}

	return AccountIDToSteamID2(iAccountId, szBuffer, iMaxlen);
}

/**
 * Gets the AccountID of a connected client
 *
 * @param iClient       Client index
 * @return              AccountID, or 0 if invalid
 */
stock int GetClientAccountID(int iClient)
{
	if (!IsValidClientIndex(iClient) || !IsClientInGame(iClient))
	{
		return 0;
	}

	return GetSteamAccountID(iClient);
}


/**
 * Finds the client index by their Steam Account ID.
 *
 * Iterates through all connected clients and returns the client index
 * whose Steam Account ID matches the specified value.
 *
 * @param iAccountId	Steam Account ID to search for.
 * @return				Client index (1-based) if found,
 *                      0 if the provided Account ID is invalid,
 *                      or -1 if no matching client is found.
 */
stock int FindClientByAccountID(int iAccountId)
{
	if (iAccountId <= 0)
	{
		return 0;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClientIndex(i) || !IsClientInGame(i))
		{
			continue;
		}

		if (GetSteamAccountID(i) != iAccountId)
		{
			continue;
		}

		return i;
	}

	return -1;
}

/**
 * Finds a client by SteamID2
 *
 * @param szSteamId2    SteamID2 to search for
 * @return              Client index, or 0 if not found
 */
stock int FindClientBySteamID2(const char[] szSteamId2)
{
	int iAccountId = SteamID2ToAccountID(szSteamId2);
	return FindClientByAccountID(iAccountId);
}

/**
 * Finds a client by SteamID3
 *
 * @param szSteamId3    SteamID3 to search for
 * @return              Client index, or 0 if not found
 */
stock int FindClientBySteamID3(const char[] szSteamId3)
{
	int iAccountId = SteamID3ToAccountID(szSteamId3);
	return FindClientByAccountID(iAccountId);
}

/**
 * Validates if a client index is valid (internal helper)
 *
 * @param iClient       Client index
 * @return              true if valid, false otherwise
 */
stock bool IsValidClientIndex(int iClient)
{
	return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Checks if a SteamID is a special case (BOT, PENDING, LAN)
 *
 * @param szSteamId     SteamID string to check
 * @return              true if it's a special case, false otherwise
 */
stock bool IsSteamIDSpecialCase(const char[] szSteamId)
{
	return (StrEqual(szSteamId, "BOT", false) || StrEqual(szSteamId, "STEAM_ID_PENDING", false) || StrEqual(szSteamId, "STEAM_ID_LAN", false));
}

/**
 * Automatically detects the format of a SteamID
 *
 * @param szSteamId     SteamID string to analyze
 * @return              SteamIDFormat enum value
 */
stock SteamIDFormat DetectSteamIDFormat(const char[] szSteamId)
{
	if (strlen(szSteamId) == 0)
	{
		return STEAMID_FORMAT_UNKNOWN;
	}

	if (IsSteamIDSpecialCase(szSteamId))
	{
		return STEAMID_FORMAT_SPECIAL;
	}

	if (StrContains(szSteamId, "STEAM_", false) == 0 && IsValidSteamID2(szSteamId))
	{
		return STEAMID_FORMAT_STEAMID2;
	}

	if (StrContains(szSteamId, "[U:1:", false) == 0 && IsValidSteamID3(szSteamId))
	{
		return STEAMID_FORMAT_STEAMID3;
	}

	if (strlen(szSteamId) == STEAMID64_EXACT_LENGTH && IsValidSteamID64(szSteamId))
	{
		return STEAMID_FORMAT_STEAMID64;
	}

	if (strlen(szSteamId) <= ACCOUNTID_LENGTH)
	{
		bool bIsNumeric = true;
		for (int i = 0; szSteamId[i] != '\0'; i++)
		{
			if (!IsCharNumeric(szSteamId[i]))
			{
				bIsNumeric = false;
				break;
			}
		}

		if (bIsNumeric)
		{
			int iAccountId = StringToInt(szSteamId);
			if (iAccountId > 0)
			{
				return STEAMID_FORMAT_ACCOUNTID;
			}
		}
	}

	return STEAMID_FORMAT_UNKNOWN;
}