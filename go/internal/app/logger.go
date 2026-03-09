package app

import (
	"net/http"
	"os"
	"time"

	"github.com/rs/zerolog"
	zlog "github.com/rs/zerolog/log"
)

type responseRecorder struct {
	http.ResponseWriter
	status int
	size   int
}

func (r *responseRecorder) WriteHeader(statusCode int) {
	r.status = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

func (r *responseRecorder) Write(p []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}

	n, err := r.ResponseWriter.Write(p)
	r.size += n
	return n, err
}

func configureLogger(debugMode bool) {
	zerolog.TimeFieldFormat = time.RFC3339

	level := zerolog.InfoLevel
	if debugMode {
		level = zerolog.DebugLevel
	}

	zerolog.SetGlobalLevel(level)

	logger := zerolog.New(os.Stdout).
		With().
		Timestamp().
		Str("service", "steamid-service").
		Logger()

	if debugMode {
		logger = logger.With().Caller().Logger()
	}

	zlog.Logger = logger
}

func shouldSkipAccessLog(r *http.Request, status int) bool {
	return r.URL.Path == EndpointHealth && status < http.StatusBadRequest
}

func accessLogMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startedAt := time.Now()
		recorder := &responseRecorder{
			ResponseWriter: w,
			status:         http.StatusOK,
		}

		next.ServeHTTP(recorder, r)

		if shouldSkipAccessLog(r, recorder.status) {
			return
		}

		event := zlog.Info()
		switch {
		case recorder.status >= http.StatusInternalServerError:
			event = zlog.Error()
		case recorder.status >= http.StatusBadRequest:
			event = zlog.Warn()
		}

		event.
			Str("method", r.Method).
			Str("path", r.URL.Path).
			Str("query", r.URL.RawQuery).
			Int("status", recorder.status).
			Int("bytes", recorder.size).
			Int64("duration_ms", time.Since(startedAt).Milliseconds()).
			Str("remote_addr", r.RemoteAddr).
			Str("user_agent", r.UserAgent()).
			Msg("http request completed")
	})
}

func appDebugf(format string, args ...interface{}) {
	zlog.Debug().Msgf(format, args...)
}

func appDebugEvent() *zerolog.Event {
	return zlog.Debug()
}

func appInfof(format string, args ...interface{}) {
	zlog.Info().Msgf(format, args...)
}

func appInfoEvent() *zerolog.Event {
	return zlog.Info()
}

func appWarnf(format string, args ...interface{}) {
	zlog.Warn().Msgf(format, args...)
}

func appErrorf(format string, args ...interface{}) {
	zlog.Error().Msgf(format, args...)
}
