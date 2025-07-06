package main

type SteamIDError string

const (
	ErrorNone               SteamIDError = "none"
	ErrorInvalidFormat      SteamIDError = "invalid_format"
	ErrorInvalidLength      SteamIDError = "invalid_length"
	ErrorInvalidCharacters  SteamIDError = "invalid_characters"
	ErrorInvalidSteamID2    SteamIDError = "invalid_steamid2"
	ErrorInvalidSteamID3    SteamIDError = "invalid_steamid3"
	ErrorInvalidSteamID64   SteamIDError = "invalid_steamid64"
	ErrorInvalidAccountID   SteamIDError = "invalid_accountid"
	ErrorConversionFailed   SteamIDError = "conversion_failed"
	ErrorMissingParameter   SteamIDError = "missing_parameter"
	ErrorServiceUnavailable SteamIDError = "service_unavailable"
	ErrorDuplicateInBatch   SteamIDError = "duplicate_in_batch"
)

func (e SteamIDError) Error() string { return string(e) }
func (e SteamIDError) Key() string   { return string(e) }

const (
	STEAMID64_BASE = 76561197960265728
	SID2_UNIVERSE  = "1"
)

const (
	EndpointSID64toAID   = "/SID64toAID"
	EndpointSID64toSID2  = "/SID64toSID2"
	EndpointSID64toSID3  = "/SID64toSID3"
	EndpointAIDtoSID64   = "/AIDtoSID64"
	EndpointSID2toSID64  = "/SID2toSID64"
	EndpointSID3toSID64  = "/SID3toSID64"
	EndpointHealth       = "/health"
)

type ConversionResult struct {
	Value string
	Error SteamIDError
}

type BatchResult struct {
	Results map[string]string
	Errors  map[string]SteamIDError
}
