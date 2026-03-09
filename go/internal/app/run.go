package app

import (
	"flag"
	"fmt"
	"net/http"
	"time"

	httpSwagger "github.com/swaggo/http-swagger/v2"
	docs "steamid-service/internal/app/docs"
)

func newHandlerMux(debugMode bool) *http.ServeMux {
	mux := http.NewServeMux()

	if debugMode {
		mux.HandleFunc("/debug", func(w http.ResponseWriter, r *http.Request) {
			_, _ = fmt.Fprintf(w, "Debug mode: %v\n", debugMode)
		})
	}

	mux.Handle("/swagger/", httpSwagger.Handler(
		httpSwagger.URL("/swagger/doc.json"),
	))
	mux.Handle(EndpointSID64toAID, http.HandlerFunc(HandleSteamID64ToAccountID))
	mux.Handle(EndpointSID64toSID2, http.HandlerFunc(HandleSteamID64ToSteamID2))
	mux.Handle(EndpointSID64toSID3, http.HandlerFunc(HandleSteamID64ToSteamID3))
	mux.Handle(EndpointAIDtoSID64, http.HandlerFunc(HandleAccountIDToSteamID64))
	mux.Handle(EndpointSID2toSID64, http.HandlerFunc(HandleSteamID2ToSteamID64))
	mux.Handle(EndpointSID3toSID64, http.HandlerFunc(HandleSteamID3ToSteamID64))
	mux.Handle(EndpointHealth, http.HandlerFunc(HandleHealth))
	mux.Handle("/", http.HandlerFunc(HandleNotFound))

	return mux
}

func newHTTPServer(addr string, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
}

type endpointRegistration struct {
	Name       string
	Path       string
	ExampleURL string
}

func publicHost(host string) string {
	if host == "0.0.0.0" || host == "" {
		return "localhost"
	}
	return host
}

func startupEndpoints(baseURL, sid2Example string) []endpointRegistration {
	return []endpointRegistration{
		{
			Name:       "swagger",
			Path:       "/swagger/index.html",
			ExampleURL: baseURL + "/swagger/index.html",
		},
		{
			Name:       "sid64_to_aid",
			Path:       EndpointSID64toAID,
			ExampleURL: fmt.Sprintf("%s%s?steamid=76561197960287930", baseURL, EndpointSID64toAID),
		},
		{
			Name:       "sid64_to_sid2",
			Path:       EndpointSID64toSID2,
			ExampleURL: fmt.Sprintf("%s%s?steamid=76561197960287930", baseURL, EndpointSID64toSID2),
		},
		{
			Name:       "sid64_to_sid3",
			Path:       EndpointSID64toSID3,
			ExampleURL: fmt.Sprintf("%s%s?steamid=76561197960287930", baseURL, EndpointSID64toSID3),
		},
		{
			Name:       "aid_to_sid64",
			Path:       EndpointAIDtoSID64,
			ExampleURL: fmt.Sprintf("%s%s?steamid=22202", baseURL, EndpointAIDtoSID64),
		},
		{
			Name:       "sid2_to_sid64",
			Path:       EndpointSID2toSID64,
			ExampleURL: fmt.Sprintf("%s%s?steamid=%s", baseURL, EndpointSID2toSID64, sid2Example),
		},
		{
			Name:       "sid3_to_sid64",
			Path:       EndpointSID3toSID64,
			ExampleURL: fmt.Sprintf("%s%s?steamid=[U:1:22202]", baseURL, EndpointSID3toSID64),
		},
		{
			Name:       "health",
			Path:       EndpointHealth,
			ExampleURL: baseURL + EndpointHealth,
		},
	}
}

func logStartup(baseURL, host, port, backendLang, sid2Universe string, debugMode bool) {
	endpoints := startupEndpoints(baseURL, fmt.Sprintf("STEAM_%s:0:11101", sid2Universe))

	appInfoEvent().
		Str("host", host).
		Str("port", port).
		Str("listen_addr", fmt.Sprintf("%s:%s", host, port)).
		Str("public_base_url", baseURL).
		Bool("debug", debugMode).
		Str("backend_lang", backendLang).
		Str("sid2_universe", sid2Universe).
		Int("max_batch_items", appCfg.MaxBatchItems).
		Msg("service starting")

	appInfoEvent().
		Bool("error_handling", true).
		Bool("request_logging", true).
		Bool("batch_processing", true).
		Bool("keyvalue_output", true).
		Bool("swagger_enabled", true).
		Str("batch_output_format", "valve-keyvalue").
		Str("swagger_url", baseURL+"/swagger/index.html").
		Msg("service features enabled")

	appInfoEvent().
		Int("endpoint_count", len(endpoints)).
		Interface("endpoints", endpoints).
		Msg("endpoints registered")

	if debugMode {
		appDebugEvent().
			Bool("debug", true).
			Msg("debug mode enabled")
	}

	appInfoEvent().
		Str("shutdown_signal", "ctrl+c").
		Msg("service ready")
}

func Run() error {
	backendLangFlag := flag.String("backend-lang", appCfg.BackendLang, "Backend language (en/es)")
	flag.Parse()
	appCfg.BackendLang = *backendLangFlag
	configureLogger(appCfg.Debug)
	loadBackendMessages(appCfg.BackendLang)

	debugMode := appCfg.Debug
	port := appCfg.Port
	host := appCfg.Host

	addr := fmt.Sprintf("%s:%s", host, port)
	server := newHTTPServer(addr, accessLogMiddleware(newHandlerMux(debugMode)))
	docs.SwaggerInfo.BasePath = "/"
	docs.SwaggerInfo.Schemes = []string{"http"}
	docs.SwaggerInfo.Host = fmt.Sprintf("%s:%s", publicHost(host), port)

	sid2Universe := appCfg.SID2Universe
	baseURL := fmt.Sprintf("http://%s:%s", publicHost(host), port)
	logStartup(baseURL, host, port, appCfg.BackendLang, sid2Universe, debugMode)
	if err := server.ListenAndServe(); err != nil {
		return fmt.Errorf(msgBackend("server_failed"), err)
	}

	return nil
}
