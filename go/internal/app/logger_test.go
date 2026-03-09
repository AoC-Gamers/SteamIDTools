package app

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/rs/zerolog"
	zlog "github.com/rs/zerolog/log"
)

func TestAccessLogMiddlewareEmitsStructuredJSON(t *testing.T) {
	var output strings.Builder
	previousLogger := zlog.Logger
	zlog.Logger = zerolog.New(&output)
	t.Cleanup(func() {
		zlog.Logger = previousLogger
	})

	handler := accessLogMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte("ok"))
	}))

	req := httptest.NewRequest(http.MethodGet, "/SID64toAID?full=1", nil)
	req.RemoteAddr = "127.0.0.1:12345"
	req.Header.Set("User-Agent", "steamidtools-test")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	var entry map[string]any
	if err := json.Unmarshal([]byte(output.String()), &entry); err != nil {
		t.Fatalf("expected valid JSON log entry, got error: %v", err)
	}

	if got := entry["message"]; got != "http request completed" {
		t.Fatalf("unexpected log message %v", got)
	}
	if got := entry["method"]; got != http.MethodGet {
		t.Fatalf("unexpected method %v", got)
	}
	if got := entry["path"]; got != "/SID64toAID" {
		t.Fatalf("unexpected path %v", got)
	}
	if got := entry["query"]; got != "full=1" {
		t.Fatalf("unexpected query %v", got)
	}
	if got := entry["status"]; got != float64(http.StatusCreated) {
		t.Fatalf("unexpected status %v", got)
	}
	if got := entry["bytes"]; got != float64(2) {
		t.Fatalf("unexpected bytes %v", got)
	}
	if got := entry["remote_addr"]; got != "127.0.0.1:12345" {
		t.Fatalf("unexpected remote_addr %v", got)
	}
	if got := entry["user_agent"]; got != "steamidtools-test" {
		t.Fatalf("unexpected user_agent %v", got)
	}
}

func TestAccessLogMiddlewareSkipsHealthyHealthChecks(t *testing.T) {
	var output strings.Builder
	previousLogger := zlog.Logger
	zlog.Logger = zerolog.New(&output)
	t.Cleanup(func() {
		zlog.Logger = previousLogger
	})

	handler := accessLogMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("HEALTHY\n"))
	}))

	req := httptest.NewRequest(http.MethodGet, EndpointHealth, nil)
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if got := strings.TrimSpace(output.String()); got != "" {
		t.Fatalf("expected no access log output for healthy health check, got %q", got)
	}
}

func TestLogStartupEmitsStructuredEvents(t *testing.T) {
	var output strings.Builder
	previousLogger := zlog.Logger
	zlog.Logger = zerolog.New(&output)
	t.Cleanup(func() {
		zlog.Logger = previousLogger
	})

	logStartup("http://localhost:80", "0.0.0.0", "80", "en", "1", false)

	lines := strings.Split(strings.TrimSpace(output.String()), "\n")
	if len(lines) != 4 {
		t.Fatalf("expected 4 startup log entries, got %d", len(lines))
	}

	var first map[string]any
	if err := json.Unmarshal([]byte(lines[0]), &first); err != nil {
		t.Fatalf("expected valid JSON startup log entry, got error: %v", err)
	}

	if got := first["message"]; got != "service starting" {
		t.Fatalf("unexpected first startup message %v", got)
	}
	if got := first["host"]; got != "0.0.0.0" {
		t.Fatalf("unexpected host %v", got)
	}
	if got := first["port"]; got != "80" {
		t.Fatalf("unexpected port %v", got)
	}
	if got := first["public_base_url"]; got != "http://localhost:80" {
		t.Fatalf("unexpected public_base_url %v", got)
	}

	foundEndpoints := false
	foundReady := false
	for _, line := range lines[1:] {
		var entry map[string]any
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			t.Fatalf("expected valid JSON startup log entry, got error: %v", err)
		}

		if entry["message"] == "endpoints registered" {
			if got := entry["endpoint_count"]; got != float64(8) {
				t.Fatalf("unexpected endpoint_count %v", got)
			}

			endpoints, ok := entry["endpoints"].([]any)
			if !ok {
				t.Fatalf("expected endpoints array, got %T", entry["endpoints"])
			}

			if len(endpoints) != 8 {
				t.Fatalf("unexpected endpoints length %d", len(endpoints))
			}

			healthFound := false
			for _, rawEndpoint := range endpoints {
				endpoint, ok := rawEndpoint.(map[string]any)
				if !ok {
					t.Fatalf("expected endpoint object, got %T", rawEndpoint)
				}
				if endpoint["Name"] == "health" && endpoint["Path"] == "/health" {
					healthFound = true
					break
				}
			}

			if !healthFound {
				t.Fatal("expected health endpoint in endpoints array")
			}

			foundEndpoints = true
		}
		if entry["message"] == "service ready" {
			foundReady = true
		}
	}

	if !foundEndpoints {
		t.Fatal("expected endpoints registered log entry")
	}
	if !foundReady {
		t.Fatal("expected service ready log entry")
	}
}
