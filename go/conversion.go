package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func AIDFromSID64(steamid64Str string) ConversionResult {
	if len(steamid64Str) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if len(steamid64Str) != 17 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	for _, char := range steamid64Str {
		if char < '0' || char > '9' {
			return ConversionResult{"", ErrorInvalidCharacters}
		}
	}
	steamid64, err := strconv.ParseUint(steamid64Str, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidSteamID64}
	}
	if steamid64 < STEAMID64_BASE {
		return ConversionResult{"", ErrorInvalidSteamID64}
	}
	accountID := steamid64 - STEAMID64_BASE
	return ConversionResult{fmt.Sprintf("%d", accountID), ErrorNone}
}

func SID64FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	for _, char := range accountIDStr {
		if char < '0' || char > '9' {
			return ConversionResult{"", ErrorInvalidCharacters}
		}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if accountID == 0 {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	steamid64 := accountID + STEAMID64_BASE
	return ConversionResult{fmt.Sprintf("%d", steamid64), ErrorNone}
}

func AIDFromSID2(steamid2 string) ConversionResult {
	if len(steamid2) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if len(steamid2) < 11 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !strings.HasPrefix(steamid2, "STEAM_") {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	parts := strings.Split(steamid2, ":")
	if len(parts) != 3 {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	universe, err := strconv.ParseUint(parts[0][6:], 10, 64)
	if err != nil || (universe != 0 && universe != 1) {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	y, err := strconv.ParseUint(parts[1], 10, 64)
	if err != nil || (y != 0 && y != 1) {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	z, err := strconv.ParseUint(parts[2], 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	accountID := z*2 + y
	return ConversionResult{fmt.Sprintf("%d", accountID), ErrorNone}
}

func AIDFromSID3(steamid3 string) ConversionResult {
	if len(steamid3) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if len(steamid3) < 8 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !strings.HasPrefix(steamid3, "[U:1:") || !strings.HasSuffix(steamid3, "]") {
		return ConversionResult{"", ErrorInvalidSteamID3}
	}
	accountIDStr := steamid3[5 : len(steamid3)-1]
	for _, char := range accountIDStr {
		if char < '0' || char > '9' {
			return ConversionResult{"", ErrorInvalidCharacters}
		}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil || accountID == 0 {
		return ConversionResult{"", ErrorInvalidSteamID3}
	}
	return ConversionResult{accountIDStr, ErrorNone}
}

func SID2FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	for _, char := range accountIDStr {
		if char < '0' || char > '9' {
			return ConversionResult{"", ErrorInvalidCharacters}
		}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if accountID == 0 {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	y := accountID & 1
	z := accountID >> 1
	universe := os.Getenv("SID2_UNIVERSE")
	if universe == "" {
		universe = SID2_UNIVERSE
	}
	steamid2 := fmt.Sprintf("STEAM_%s:%d:%d", universe, y, z)
	return ConversionResult{steamid2, ErrorNone}
}

func SID3FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	for _, char := range accountIDStr {
		if char < '0' || char > '9' {
			return ConversionResult{"", ErrorInvalidCharacters}
		}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if accountID == 0 {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	steamid3 := fmt.Sprintf("[U:1:%d]", accountID)
	return ConversionResult{steamid3, ErrorNone}
}
