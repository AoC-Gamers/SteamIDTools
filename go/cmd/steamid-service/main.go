package main

import (
	zlog "github.com/rs/zerolog/log"
	"steamid-service/internal/app"
)

// @title SteamIDTools API
// @version 2.1.0
// @description High-performance SteamID conversion service for game servers.
// @description All responses are plain text. Batch responses use Valve KeyValue text format.
// @BasePath /
// @schemes http
func main() {
	if err := app.Run(); err != nil {
		zlog.Fatal().Err(err).Msg("steamid-service exited")
	}
}
