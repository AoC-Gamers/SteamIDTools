package app

import (
	"strconv"
	"strings"
)

func isValidAccountID(accountID uint64) bool {
	return accountID > 0 && accountID <= MaxAccountID
}

func isASCIIUnsignedDecimal(value string) bool {
	for i := 0; i < len(value); i++ {
		if value[i] < '0' || value[i] > '9' {
			return false
		}
	}

	return true
}

func AIDFromSID64(steamid64Str string) ConversionResult {
	if len(steamid64Str) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if len(steamid64Str) != 17 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !isASCIIUnsignedDecimal(steamid64Str) {
		return ConversionResult{"", ErrorInvalidCharacters}
	}
	steamid64, err := strconv.ParseUint(steamid64Str, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidSteamID64}
	}
	if steamid64 <= STEAMID64_BASE || steamid64 > MaxSteamID64 {
		return ConversionResult{"", ErrorInvalidSteamID64}
	}
	accountID := steamid64 - STEAMID64_BASE
	if !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidSteamID64}
	}
	return ConversionResult{strconv.FormatUint(accountID, 10), ErrorNone}
}

func SID64FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !isASCIIUnsignedDecimal(accountIDStr) {
		return ConversionResult{"", ErrorInvalidCharacters}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	steamid64 := accountID + STEAMID64_BASE
	return ConversionResult{strconv.FormatUint(steamid64, 10), ErrorNone}
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
	if z > (MaxAccountID-y)/2 {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	accountID := z*2 + y
	if !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidSteamID2}
	}
	return ConversionResult{strconv.FormatUint(accountID, 10), ErrorNone}
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
	if !isASCIIUnsignedDecimal(accountIDStr) {
		return ConversionResult{"", ErrorInvalidCharacters}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil || !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidSteamID3}
	}
	return ConversionResult{accountIDStr, ErrorNone}
}

func SID2FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !isASCIIUnsignedDecimal(accountIDStr) {
		return ConversionResult{"", ErrorInvalidCharacters}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	y := accountID & 1
	z := accountID >> 1
	steamid2 := "STEAM_" + appCfg.SID2Universe + ":" + strconv.FormatUint(y, 10) + ":" + strconv.FormatUint(z, 10)
	return ConversionResult{steamid2, ErrorNone}
}

func SID3FromAID(accountIDStr string) ConversionResult {
	if len(accountIDStr) == 0 {
		return ConversionResult{"", ErrorInvalidLength}
	}
	if !isASCIIUnsignedDecimal(accountIDStr) {
		return ConversionResult{"", ErrorInvalidCharacters}
	}
	accountID, err := strconv.ParseUint(accountIDStr, 10, 64)
	if err != nil {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	if !isValidAccountID(accountID) {
		return ConversionResult{"", ErrorInvalidAccountID}
	}
	steamid3 := "[U:1:" + strconv.FormatUint(accountID, 10) + "]"
	return ConversionResult{steamid3, ErrorNone}
}
