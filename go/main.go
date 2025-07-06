package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
)

var MaxBatchItems = 32

func init() {
	if val := os.Getenv("MAX_BATCH_ITEMS"); val != "" {
		if n, err := strconv.Atoi(val); err == nil && n > 0 {
			MaxBatchItems = n
		}
	}
}

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	debugMode := os.Getenv("DEBUG") == "1"

	port := os.Getenv("PORT")
	if port == "" {
		port = "80"
	}

	host := os.Getenv("HOST")
	if host == "" {
		host = "0.0.0.0"
	}

	http.HandleFunc("/debug", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Debug mode: %v\n", debugMode)
	})

	http.Handle(EndpointSID64toAID, http.HandlerFunc(HandleSteamID64ToAccountID))
	http.Handle(EndpointSID64toSID2, http.HandlerFunc(HandleSteamID64ToSteamID2))
	http.Handle(EndpointSID64toSID3, http.HandlerFunc(HandleSteamID64ToSteamID3))
	http.Handle(EndpointAIDtoSID64, http.HandlerFunc(HandleAccountIDToSteamID64))
	http.Handle(EndpointSID2toSID64, http.HandlerFunc(HandleSteamID2ToSteamID64))
	http.Handle(EndpointSID3toSID64, http.HandlerFunc(HandleSteamID3ToSteamID64))
	http.Handle(EndpointHealth, http.HandlerFunc(HandleHealth))
	http.Handle("/", http.HandlerFunc(HandleNotFound))

	addr := fmt.Sprintf("%s:%s", host, port)

	sid2Universe := os.Getenv("SID2_UNIVERSE")
	if sid2Universe == "" {
		sid2Universe = SID2_UNIVERSE
	}

	fmt.Println("Available endpoints:")
	baseURL := fmt.Sprintf("http://%s:%s", func() string {
		if host == "0.0.0.0" || host == "" {
			return "localhost"
		}
		return host
	}(), port)
	fmt.Printf("  %s%s?steamid=76561197960287930\n", baseURL, EndpointSID64toAID)
	fmt.Printf("  %s%s?steamid=76561197960287930\n", baseURL, EndpointSID64toSID2)
	fmt.Printf("  %s%s?steamid=76561197960287930\n", baseURL, EndpointSID64toSID3)
	fmt.Printf("  %s%s?steamid=22202\n", baseURL, EndpointAIDtoSID64)
	fmt.Printf("  %s%s?steamid=STEAM_1:0:11101\n", baseURL, EndpointSID2toSID64)
	fmt.Printf("  %s%s?steamid=[U:1:22202]\n", baseURL, EndpointSID3toSID64)
	fmt.Printf("  %s%s (Health check endpoint)\n", baseURL, EndpointHealth)
	fmt.Println("\n📦 BATCH PROCESSING:")
	fmt.Printf("  %s%s?steamid=76561197960287930,76561197960287931,76561197960287932\n", baseURL, EndpointSID64toAID)
	fmt.Printf("  🔹 Use comma-separated values for batch processing (max %d items)\n", MaxBatchItems)
	fmt.Println("  🔹 Batch responses are formatted as Valve KeyValue format")
	fmt.Println("\n✨ Enhanced features:")
	fmt.Println("  🔍 Detailed error reporting")
	fmt.Println("  📊 Request logging")
	fmt.Println("  🛡️ Input validation")
	fmt.Println("  ❤️  Health check endpoint")
	fmt.Println("  📦 Batch processing support (KeyValue format)")
	fmt.Printf("  🌍 SteamID2 format: STEAM_%s:Y:Z\n", sid2Universe)

	backendLangEnv := os.Getenv("BACKEND_LANG")
	backendLangFlag := flag.String("backend-lang", "", "Backend language (en/es)")
	flag.Parse()
	if backendLangEnv != "" {
		backendLang = backendLangEnv
	} else if *backendLangFlag != "" {
		backendLang = *backendLangFlag
	}
	loadBackendMessages()

	log.Println(msgBackend("service_ready"))
	log.Println(msgBackend("debug_enabled"))
	log.Println(msgBackend("starting_on", host, port))
	log.Println(msgBackend("error_handling"))
	log.Println(msgBackend("detailed_logging"))
	log.Println(msgBackend("batch_processing", MaxBatchItems))
	log.Println(msgBackend("keyvalue_output"))
	log.Println(msgBackend("steamid2_universe", sid2Universe))
	log.Println(msgBackend("press_ctrlc_hint"))
	log.Println(msgBackend("service_ready_log"))
	if debugMode {
		log.Println(msgBackend("debug_enabled_log"))
	}
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf(msgBackend("server_failed"), err)
	}
}
