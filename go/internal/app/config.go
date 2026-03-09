package app

import (
	"os"
	"strconv"
)

type appConfig struct {
	Debug         bool
	Host          string
	Port          string
	SID2Universe  string
	MaxBatchItems int
	BackendLang   string
}

var appCfg = loadConfigFromEnv()

func loadConfigFromEnv() appConfig {
	cfg := appConfig{
		Debug:         os.Getenv("DEBUG") == "1",
		Host:          envOrDefault("HOST", "0.0.0.0"),
		Port:          envOrDefault("PORT", "80"),
		SID2Universe:  envOrDefault("SID2_UNIVERSE", SID2_UNIVERSE),
		MaxBatchItems: 32,
		BackendLang:   envOrDefault("BACKEND_LANG", "en"),
	}

	if val := os.Getenv("MAX_BATCH_ITEMS"); val != "" {
		if n, err := strconv.Atoi(val); err == nil && n > 0 {
			cfg.MaxBatchItems = n
		}
	}

	return cfg
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}

	return fallback
}
