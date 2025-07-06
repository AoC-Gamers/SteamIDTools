package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"
)

var messages map[string]string
var backendLang = "en"
var backendMessages map[string]string

func loadMessages() {
	messages = make(map[string]string)
	langFilesByCode := map[string]string{
		"en": "lang/messages_en.json",
		"es": "lang/messages_es.json",
	}
	for lang, path := range langFilesByCode {
		data, err := ioutil.ReadFile(path)
		if err != nil {
			log.Printf("[WARN] Could not load %s: %v", path, err)
			continue
		}
		var m map[string]string
		if err := json.Unmarshal(data, &m); err != nil {
			log.Printf("[WARN] Could not parse %s: %v", path, err)
			continue
		}
		for k, v := range m {
			messages[lang+":"+k] = v
		}
	}
}

func loadBackendMessages() {
	backendMessages = make(map[string]string)
	langFiles := map[string]string{
		"en": "lang/messages_backend_en.json",
		"es": "lang/messages_backend_es.json",
	}
	path, ok := langFiles[backendLang]
	if !ok {
		path = langFiles["en"]
	}
	data, err := ioutil.ReadFile(path)
	if err != nil {
		log.Printf("[WARN] Could not load backend lang file %s: %v", path, err)
		return
	}
	var m map[string]string
	if err := json.Unmarshal(data, &m); err != nil {
		log.Printf("[WARN] Could not parse backend lang file %s: %v", path, err)
		return
	}
	for k, v := range m {
		backendMessages[k] = v
	}
}

func getLang(r *http.Request) string {
	header := r.Header.Get("Accept-Language")
	if strings.HasPrefix(header, "es") {
		return "es"
	}
	return "en"
}

func msg(key, lang string) string {
	if v, ok := messages[lang+":"+key]; ok {
		log.Printf("[DEBUG] Traducción encontrada para %s/%s: %s", lang, key, v)
		return v
	} else {
		log.Printf("[DEBUG] Clave '%s' no encontrada en idioma '%s'", key, lang)
	}
	if v, ok := messages["en:"+key]; ok {
		log.Printf("[DEBUG] Traducción EN encontrada para %s: %s", key, v)
		return v
	}
	log.Printf("[DEBUG] No se encontró traducción para clave '%s', devolviendo la clave.", key)
	return key
}

func msgBackend(key string, args ...interface{}) string {
	if v, ok := backendMessages[key]; ok {
		if len(args) > 0 {
			return fmt.Sprintf(v, args...)
		}
		return v
	}
	return key
}

func msgf(key, lang string, args ...interface{}) string {
	return fmt.Sprintf(msg(key, lang), args...)
}

func logDebug(r *http.Request, msg string, args ...interface{}) {
	if os.Getenv("DEBUG") == "1" {
		log.Printf("[DEBUG] "+msg, args...)
		log.Printf("[DEBUG] Headers for %s:", r.URL.Path)
		for k, v := range r.Header {
			log.Printf("[DEBUG]   %s: %v", k, v)
		}
	}
}

func hasNullTerm(r *http.Request) bool {
	return r.URL.Query().Get("nullterm") == "1"
}

func handleSteamID64ToAccountID(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "SID64toAID request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}

	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
				return
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			result := AIDFromSID64(id)
			if result.Error.IsValid() {
				batchResult.Results[id] = result.Value
			} else {
				batchResult.Errors[id] = result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion SID64->AID: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	result := AIDFromSID64(steamid)
	if !result.Error.IsValid() {
		writeErrorResponse(w, r, result.Error, "")
		return
	}
	writeSuccessResponse(w, result.Value, hasNullTerm(r))
}

func handleSteamID64ToSteamID2(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "SID64toSID2 request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}
	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
				return
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			accountResult := AIDFromSID64(id)
			if !accountResult.Error.IsValid() {
				batchResult.Errors[id] = accountResult.Error
				continue
			}
			steamid2Result := SID2FromAID(accountResult.Value)
			if steamid2Result.Error.IsValid() {
				batchResult.Results[id] = steamid2Result.Value
			} else {
				batchResult.Errors[id] = steamid2Result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion SID64->SID2: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	accountResult := AIDFromSID64(steamid)
	if !accountResult.Error.IsValid() {
		writeErrorResponse(w, r, accountResult.Error, "")
		return
	}
	steamid2Result := SID2FromAID(accountResult.Value)
	if !steamid2Result.Error.IsValid() {
		writeErrorResponse(w, r, steamid2Result.Error, msgf("accountid", lang, accountResult.Value))
		return
	}
	writeSuccessResponse(w, steamid2Result.Value, hasNullTerm(r))
}

func handleSteamID64ToSteamID3(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "SID64toSID3 request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}
	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
				return
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			accountResult := AIDFromSID64(id)
			if !accountResult.Error.IsValid() {
				batchResult.Errors[id] = accountResult.Error
				continue
			}
			steamid3Result := SID3FromAID(accountResult.Value)
			if steamid3Result.Error.IsValid() {
				batchResult.Results[id] = steamid3Result.Value
			} else {
				batchResult.Errors[id] = steamid3Result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion SID64->SID3: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	accountResult := AIDFromSID64(steamid)
	if !accountResult.Error.IsValid() {
		writeErrorResponse(w, r, accountResult.Error, "")
		return
	}
	steamid3Result := SID3FromAID(accountResult.Value)
	if !steamid3Result.Error.IsValid() {
		writeErrorResponse(w, r, steamid3Result.Error, msgf("accountid", lang, accountResult.Value))
		return
	}
	writeSuccessResponse(w, steamid3Result.Value, hasNullTerm(r))
}

func handleNotFound(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusNotFound)
	errorMsg := fmt.Sprintf("Invalid endpoint. Available endpoints: %s, %s, %s, %s, %s, %s, %s", EndpointSID64toAID, EndpointSID64toSID2, EndpointSID64toSID3, EndpointAIDtoSID64, EndpointSID2toSID64, EndpointSID3toSID64, EndpointHealth)
	fmt.Fprint(w, errorMsg+"\n")
	log.Printf("[WARNING] 404 - Invalid endpoint requested: %s [%s]", r.URL.Path, r.RemoteAddr)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	testResult := AIDFromSID64("76561198008295809")
	if !testResult.Error.IsValid() {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusServiceUnavailable)
		fmt.Fprint(w, "UNHEALTHY: Conversion test failed\n")
		log.Printf("[ERROR] Health check failed: %s [%s]", testResult.Error.Error(), r.RemoteAddr)
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "HEALTHY\n")
}

func handleAccountIDToSteamID64(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "AIDtoSID64 request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}
	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			result := SID64FromAID(id)
			if result.Error.IsValid() {
				batchResult.Results[id] = result.Value
			} else {
				batchResult.Errors[id] = result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion AID->SID64: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	result := SID64FromAID(steamid)
	if !result.Error.IsValid() {
		writeErrorResponse(w, r, result.Error, "")
		return
	}
	writeSuccessResponse(w, result.Value, hasNullTerm(r))
}

func handleSteamID2ToSteamID64(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "SID2toSID64 request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}
	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
				return
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			accountResult := AIDFromSID2(id)
			if !accountResult.Error.IsValid() {
				batchResult.Errors[id] = accountResult.Error
				continue
			}
			steamid64Result := SID64FromAID(accountResult.Value)
			if steamid64Result.Error.IsValid() {
				batchResult.Results[id] = steamid64Result.Value
			} else {
				batchResult.Errors[id] = steamid64Result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion SID2->SID64: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	accountResult := AIDFromSID2(steamid)
	if !accountResult.Error.IsValid() {
		writeErrorResponse(w, r, accountResult.Error, "")
		return
	}
	steamid64Result := SID64FromAID(accountResult.Value)
	if !steamid64Result.Error.IsValid() {
		writeErrorResponse(w, r, steamid64Result.Error, msgf("accountid", lang, accountResult.Value))
		return
	}
	writeSuccessResponse(w, steamid64Result.Value, hasNullTerm(r))
}

func handleSteamID3ToSteamID64(w http.ResponseWriter, r *http.Request) {
	lang := getLang(r)
	logDebug(r, "SID3toSID64 request: %v", r.URL.RawQuery)
	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang))
		return
	}
	if strings.Contains(steamid, ",") {
		steamids, parseErr := parseBatchInput(steamid)
		if !parseErr.IsValid() {
			if parseErr == ErrorInvalidFormat {
				writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, MaxBatchItems))
			} else {
				writeErrorResponse(w, r, parseErr, msg("batch_parse_failed", lang))
			}
			return
		}
		batchResult := BatchResult{
			Results: make(map[string]string),
			Errors:  make(map[string]SteamIDError),
		}
		for _, id := range steamids {
			if id == "" {
				continue
			}
			accountResult := AIDFromSID3(id)
			if !accountResult.Error.IsValid() {
				batchResult.Errors[id] = accountResult.Error
				continue
			}
			steamid64Result := SID64FromAID(accountResult.Value)
			if steamid64Result.Error.IsValid() {
				batchResult.Results[id] = steamid64Result.Value
			} else {
				batchResult.Errors[id] = steamid64Result.Error
			}
		}
		keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools")
		writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
		log.Printf("[INFO] Batch conversion SID3->SID64: %d items processed [%s]", len(steamids), r.RemoteAddr)
		return
	}
	accountResult := AIDFromSID3(steamid)
	if !accountResult.Error.IsValid() {
		writeErrorResponse(w, r, accountResult.Error, "")
		return
	}
	steamid64Result := SID64FromAID(accountResult.Value)
	if !steamid64Result.Error.IsValid() {
		writeErrorResponse(w, r, steamid64Result.Error, msgf("accountid", lang, accountResult.Value))
		return
	}
	writeSuccessResponse(w, steamid64Result.Value, hasNullTerm(r))
}

func HandleSteamID64ToAccountID(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToAccountID(w, r)
}

func HandleSteamID64ToSteamID2(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToSteamID2(w, r)
}

func HandleSteamID64ToSteamID3(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToSteamID3(w, r)
}

func HandleAccountIDToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleAccountIDToSteamID64(w, r)
}

func HandleSteamID2ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleSteamID2ToSteamID64(w, r)
}

func HandleSteamID3ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleSteamID3ToSteamID64(w, r)
}

func HandleHealth(w http.ResponseWriter, r *http.Request) {
	handleHealth(w, r)
}

func HandleNotFound(w http.ResponseWriter, r *http.Request) {
	handleNotFound(w, r)
}

func init() {
	loadMessages()
	loadBackendMessages()
}