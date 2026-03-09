package app

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
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

func localizedErrorMessage(err SteamIDError, lang string) string {
	if err == ErrorNone {
		return ""
	}

	translated := msg(err.Key(), lang)
	if translated != err.Key() {
		return translated
	}

	if fallback, ok := errorMessages[err]; ok {
		return fallback
	}

	return err.Error()
}

func writePlainTextBody(w io.Writer, body string) {
	// #nosec G705 -- this service intentionally returns text/plain content, including converted identifiers.
	_, _ = io.WriteString(w, body)
}

func appendKeyValueLine(builder *strings.Builder, input, value string) {
	// #nosec G705 -- batch responses are emitted as Valve KeyValue text, not HTML.
	_, _ = fmt.Fprintf(builder, "    \"%s\" \"%s\"\n", input, value)
}

func formatAsKeyValue(results BatchResult, sectionName string, lang string) string {
	var builder strings.Builder
	_, _ = fmt.Fprintf(&builder, "\"%s\"\n{\n", sectionName)

	for _, item := range results.Items {
		if item.Error.IsValid() {
			appendKeyValueLine(&builder, item.Input, item.Value)
			continue
		}

		appendKeyValueLine(&builder, item.Input, "ERROR: "+localizedErrorMessage(item.Error, lang))
	}

	builder.WriteString("}")
	return builder.String()
}

func parseBatchInput(input string) ([]string, SteamIDError) {
	if input == "" {
		return nil, ErrorMissingParameter
	}

	steamids := strings.Split(input, ",")
	if len(steamids) > appCfg.MaxBatchItems {
		return nil, ErrorInvalidFormat
	}

	seen := make(map[string]struct{}, len(steamids))
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

func writeErrorResponse(w http.ResponseWriter, r *http.Request, err SteamIDError, responseOverride string, logContext string) {
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

	appErrorf("request failed: code=%s context=%s remote_addr=%s", err.Key(), logContext, r.RemoteAddr)

	if responseOverride != "" {
		writePlainTextBody(w, responseOverride)
		return
	}

	translated := msg(msgKey, lang)
	if translated == msgKey {
		translated = localizedErrorMessage(err, lang)
	}

	writePlainTextBody(w, translated)
}

func writeSuccessResponse(w http.ResponseWriter, value string, nullterm bool) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if nullterm {
		value = value + "\x00"
	}
	w.Header().Set("Content-Length", strconv.Itoa(len(value)))
	w.WriteHeader(http.StatusOK)
	writePlainTextBody(w, value)
}

func writeKeyValueResponse(w http.ResponseWriter, content string, nullterm bool) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	if nullterm {
		content = content + "\x00"
	}
	w.Header().Set("Content-Length", strconv.Itoa(len(content)))
	w.WriteHeader(http.StatusOK)
	writePlainTextBody(w, content)
}
