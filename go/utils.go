package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
)

var errorMessages = map[SteamIDError]string{
	ErrorNone:               "No error - operation successful",
	ErrorInvalidFormat:      "Invalid SteamID format provided",
	ErrorInvalidLength:      "SteamID length is incorrect",
	ErrorInvalidCharacters:  "Contains invalid characters",
	ErrorInvalidSteamID2:    "Invalid SteamID2 format (expected STEAM_X:Y:Z)",
	ErrorInvalidSteamID3:    "Invalid SteamID3 format (expected [U:1:XXXXXXXX])",
	ErrorInvalidSteamID64:   "Invalid SteamID64 format or range",
	ErrorInvalidAccountID:   "Invalid AccountID (must be numeric and positive)",
	ErrorConversionFailed:   "General conversion failure",
	ErrorMissingParameter:   "Missing required parameter",
	ErrorServiceUnavailable: "SteamID conversion service is unavailable",
	ErrorDuplicateInBatch:   "Duplicate SteamID found in batch",
}

func (e SteamIDError) IsValid() bool {
	return e == ErrorNone
}

func formatAsKeyValue(results BatchResult, sectionName string) string {
	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("\"%s\"\n{\n", sectionName))
	for input, output := range results.Results {
		builder.WriteString(fmt.Sprintf("    \"%s\" \"%s\"\n", input, output))
	}
	for input, err := range results.Errors {
		builder.WriteString(fmt.Sprintf("    \"%s\" \"ERROR: %s\"\n", input, err.Error()))
	}
	builder.WriteString("}")
	return builder.String()
}

func parseBatchInput(input string) ([]string, SteamIDError) {
	if input == "" {
		return nil, ErrorMissingParameter
	}
	steamids := strings.Split(input, ",")
	if len(steamids) > MaxBatchItems {
		return nil, ErrorInvalidFormat
	}
	seen := make(map[string]struct{})
	for i, id := range steamids {
		id = strings.TrimSpace(id)
		if _, exists := seen[id]; exists {
			return nil, ErrorDuplicateInBatch
		}
		seen[id] = struct{}{}
		steamids[i] = id
	}
	return steamids, ErrorNone
}

func writeErrorResponse(w http.ResponseWriter, r *http.Request, err SteamIDError, context string) {
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	lang := getLang(r)
	var statusCode int
	var msgKey string
	switch err {
	case ErrorMissingParameter:
		statusCode = http.StatusBadRequest
		msgKey = "missing_parameter"
	case ErrorInvalidFormat:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_format"
	case ErrorInvalidLength:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_length"
	case ErrorInvalidCharacters:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_characters"
	case ErrorInvalidSteamID2:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_steamid2"
	case ErrorInvalidSteamID3:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_steamid3"
	case ErrorInvalidSteamID64:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_steamid64"
	case ErrorInvalidAccountID:
		statusCode = http.StatusBadRequest
		msgKey = "invalid_accountid"
	case ErrorConversionFailed:
		statusCode = http.StatusBadRequest
		msgKey = "conversion_failed"
	case ErrorServiceUnavailable:
		statusCode = http.StatusServiceUnavailable
		msgKey = "service_unavailable"
	case ErrorDuplicateInBatch:
		statusCode = http.StatusBadRequest
		msgKey = "duplicate_in_batch"
	default:
		statusCode = http.StatusInternalServerError
		msgKey = "conversion_failed"
	}
	w.WriteHeader(statusCode)
	log.Printf("[ERROR] %s - Context: %s [%s]", err.Error(), context, r.RemoteAddr)
	translated := msg(msgKey, lang)
	if translated == msgKey {
		// Si no hay traducción, usa el mensaje en inglés del error
		translated = err.Error()
	}
	fmt.Fprint(w, translated)
}

func writeSuccessResponse(w http.ResponseWriter, value string, nullterm bool) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if nullterm {
		value = value + "\x00"
	}
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(value)))
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(value))
}

func writeKeyValueResponse(w http.ResponseWriter, content string, nullterm bool) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if nullterm {
		content = content + "\x00"
	}
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(content)))
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(content))
}
