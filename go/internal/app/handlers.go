package app

import (
	"fmt"
	"net/http"
	"strings"
)

func getLang(r *http.Request) string {
	header := r.Header.Get("Accept-Language")
	if strings.HasPrefix(header, "es") {
		return "es"
	}
	return "en"
}

func logDebug(r *http.Request, msg string, args ...interface{}) {
	if debugEnabled() {
		appDebugf(msg, args...)
		appDebugf("headers for %s:", r.URL.Path)
		for k, v := range r.Header {
			appDebugf("header %s=%v", k, v)
		}
	}
}

func hasNullTerm(r *http.Request) bool {
	return r.URL.Query().Get("nullterm") == "1"
}

type conversionStep struct {
	convert      func(string) ConversionResult
	errorContext func(lang, value string) string
}

type conversionExecutionResult struct {
	Value        string
	Error        SteamIDError
	ErrorContext string
}

type conversionHandlerConfig struct {
	RequestLabel string
	BatchLabel   string
	Steps        []conversionStep
}

var (
	accountIDErrorContext = func(lang, value string) string {
		return msgf("accountid", lang, value)
	}

	sid64ToAIDConfig = conversionHandlerConfig{
		RequestLabel: "SID64toAID",
		BatchLabel:   "SID64->AID",
		Steps: []conversionStep{
			{convert: AIDFromSID64},
		},
	}

	sid64ToSID2Config = conversionHandlerConfig{
		RequestLabel: "SID64toSID2",
		BatchLabel:   "SID64->SID2",
		Steps: []conversionStep{
			{convert: AIDFromSID64},
			{convert: SID2FromAID, errorContext: accountIDErrorContext},
		},
	}

	sid64ToSID3Config = conversionHandlerConfig{
		RequestLabel: "SID64toSID3",
		BatchLabel:   "SID64->SID3",
		Steps: []conversionStep{
			{convert: AIDFromSID64},
			{convert: SID3FromAID, errorContext: accountIDErrorContext},
		},
	}

	aidToSID64Config = conversionHandlerConfig{
		RequestLabel: "AIDtoSID64",
		BatchLabel:   "AID->SID64",
		Steps: []conversionStep{
			{convert: SID64FromAID},
		},
	}

	sid2ToSID64Config = conversionHandlerConfig{
		RequestLabel: "SID2toSID64",
		BatchLabel:   "SID2->SID64",
		Steps: []conversionStep{
			{convert: AIDFromSID2},
			{convert: SID64FromAID, errorContext: accountIDErrorContext},
		},
	}

	sid3ToSID64Config = conversionHandlerConfig{
		RequestLabel: "SID3toSID64",
		BatchLabel:   "SID3->SID64",
		Steps: []conversionStep{
			{convert: AIDFromSID3},
			{convert: SID64FromAID, errorContext: accountIDErrorContext},
		},
	}
)

func runConversionSteps(input, lang string, steps []conversionStep) conversionExecutionResult {
	current := input

	for _, step := range steps {
		result := step.convert(current)
		if !result.Error.IsValid() {
			context := current
			if step.errorContext != nil {
				context = step.errorContext(lang, current)
			}

			return conversionExecutionResult{
				Error:        result.Error,
				ErrorContext: context,
			}
		}

		current = result.Value
	}

	return conversionExecutionResult{
		Value: current,
		Error: ErrorNone,
	}
}

func newBatchResult(size int) BatchResult {
	return BatchResult{
		Items: make([]BatchItemResult, 0, size),
	}
}

func writeBatchParseError(w http.ResponseWriter, r *http.Request, lang, rawInput string, parseErr SteamIDError) {
	if parseErr == ErrorInvalidFormat {
		writeErrorResponse(w, r, parseErr, msgf("batch_limit", lang, appCfg.MaxBatchItems), rawInput)
		return
	}

	writeErrorResponse(w, r, parseErr, "", rawInput)
}

func handleBatchConversion(w http.ResponseWriter, r *http.Request, lang, rawInput string, cfg conversionHandlerConfig) {
	steamids, parseErr := parseBatchInput(rawInput)
	if !parseErr.IsValid() {
		writeBatchParseError(w, r, lang, rawInput, parseErr)
		return
	}

	batchResult := newBatchResult(len(steamids))
	for _, id := range steamids {
		if id == "" {
			continue
		}

		result := runConversionSteps(id, lang, cfg.Steps)
		batchResult.Items = append(batchResult.Items, BatchItemResult{
			Input: id,
			Value: result.Value,
			Error: result.Error,
		})
	}

	keyValueOutput := formatAsKeyValue(batchResult, "SteamIDTools", lang)
	writeKeyValueResponse(w, keyValueOutput, hasNullTerm(r))
	appInfof("batch conversion processed: conversion=%s items=%d remote_addr=%s", cfg.BatchLabel, len(steamids), r.RemoteAddr)
}

func handleConversion(w http.ResponseWriter, r *http.Request, cfg conversionHandlerConfig) {
	lang := getLang(r)
	logDebug(r, "%s request: %v", cfg.RequestLabel, r.URL.RawQuery)

	steamid := r.URL.Query().Get("steamid")
	if steamid == "" {
		writeErrorResponse(w, r, ErrorMissingParameter, msg("steamid_param_required", lang), "steamid query parameter missing")
		return
	}

	if strings.Contains(steamid, ",") {
		handleBatchConversion(w, r, lang, steamid, cfg)
		return
	}

	result := runConversionSteps(steamid, lang, cfg.Steps)
	if !result.Error.IsValid() {
		writeErrorResponse(w, r, result.Error, "", result.ErrorContext)
		return
	}

	writeSuccessResponse(w, result.Value, hasNullTerm(r))
}

func handleSteamID64ToAccountID(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, sid64ToAIDConfig)
}

func handleSteamID64ToSteamID2(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, sid64ToSID2Config)
}

func handleSteamID64ToSteamID3(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, sid64ToSID3Config)
}

func handleNotFound(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusNotFound)
	errorMsg := fmt.Sprintf("Invalid endpoint. Available endpoints: %s, %s, %s, %s, %s, %s, %s", EndpointSID64toAID, EndpointSID64toSID2, EndpointSID64toSID3, EndpointAIDtoSID64, EndpointSID2toSID64, EndpointSID3toSID64, EndpointHealth)
	writePlainTextBody(w, errorMsg+"\n")
	appWarnf("invalid endpoint requested: path=%s remote_addr=%s", r.URL.Path, r.RemoteAddr)
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	testResult := AIDFromSID64("76561198008295809")
	if !testResult.Error.IsValid() {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusServiceUnavailable)
		writePlainTextBody(w, "UNHEALTHY: Conversion test failed\n")
		appErrorf("health check failed: code=%s remote_addr=%s", testResult.Error.Key(), r.RemoteAddr)
		return
	}
	w.Header().Set("Content-Type", "text/plain")
	w.WriteHeader(http.StatusOK)
	writePlainTextBody(w, "HEALTHY\n")
}

func handleAccountIDToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, aidToSID64Config)
}

func handleSteamID2ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, sid2ToSID64Config)
}

func handleSteamID3ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleConversion(w, r, sid3ToSID64Config)
}

// HandleSteamID64ToAccountID godoc
// @Summary Convert SteamID64 to AccountID
// @Description Converts one SteamID64 value to AccountID. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "SteamID64 value or comma-separated SteamID64 batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted AccountID or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /SID64toAID [get]
func HandleSteamID64ToAccountID(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToAccountID(w, r)
}

// HandleSteamID64ToSteamID2 godoc
// @Summary Convert SteamID64 to SteamID2
// @Description Converts one SteamID64 value to SteamID2. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "SteamID64 value or comma-separated SteamID64 batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted SteamID2 or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /SID64toSID2 [get]
func HandleSteamID64ToSteamID2(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToSteamID2(w, r)
}

// HandleSteamID64ToSteamID3 godoc
// @Summary Convert SteamID64 to SteamID3
// @Description Converts one SteamID64 value to SteamID3. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "SteamID64 value or comma-separated SteamID64 batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted SteamID3 or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /SID64toSID3 [get]
func HandleSteamID64ToSteamID3(w http.ResponseWriter, r *http.Request) {
	handleSteamID64ToSteamID3(w, r)
}

// HandleAccountIDToSteamID64 godoc
// @Summary Convert AccountID to SteamID64
// @Description Converts one AccountID value to SteamID64. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "AccountID value or comma-separated AccountID batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted SteamID64 or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /AIDtoSID64 [get]
func HandleAccountIDToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleAccountIDToSteamID64(w, r)
}

// HandleSteamID2ToSteamID64 godoc
// @Summary Convert SteamID2 to SteamID64
// @Description Converts one SteamID2 value to SteamID64. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "SteamID2 value or comma-separated SteamID2 batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted SteamID64 or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /SID2toSID64 [get]
func HandleSteamID2ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleSteamID2ToSteamID64(w, r)
}

// HandleSteamID3ToSteamID64 godoc
// @Summary Convert SteamID3 to SteamID64
// @Description Converts one SteamID3 value to SteamID64. Supports comma-separated batch input via the steamid query parameter.
// @Tags conversion
// @Produce plain
// @Param steamid query string true "SteamID3 value or comma-separated SteamID3 batch"
// @Param nullterm query int false "Append a NUL terminator to the plain-text response"
// @Success 200 {string} string "Converted SteamID64 or Valve KeyValue batch response"
// @Failure 400 {string} string "Validation error"
// @Failure 503 {string} string "Service unavailable"
// @Router /SID3toSID64 [get]
func HandleSteamID3ToSteamID64(w http.ResponseWriter, r *http.Request) {
	handleSteamID3ToSteamID64(w, r)
}

// HandleHealth godoc
// @Summary Health check
// @Description Returns the backend health status after a self-check conversion.
// @Tags health
// @Produce plain
// @Success 200 {string} string "HEALTHY"
// @Failure 503 {string} string "UNHEALTHY"
// @Router /health [get]
func HandleHealth(w http.ResponseWriter, r *http.Request) {
	handleHealth(w, r)
}

func HandleNotFound(w http.ResponseWriter, r *http.Request) {
	handleNotFound(w, r)
}
