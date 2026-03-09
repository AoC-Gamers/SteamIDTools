package app

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestHandleSteamID64ToAccountIDMissingParameterLocalized(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, EndpointSID64toAID, nil)
	req.Header.Set("Accept-Language", "es")
	rec := httptest.NewRecorder()

	HandleSteamID64ToAccountID(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}

	if body := strings.TrimSpace(rec.Body.String()); body != "se requiere el parámetro steamid" {
		t.Fatalf("unexpected body %q", body)
	}
}

func TestHandleSteamID64ToAccountIDBatchLimitMessage(t *testing.T) {
	previous := appCfg.MaxBatchItems
	appCfg.MaxBatchItems = 1
	t.Cleanup(func() {
		appCfg.MaxBatchItems = previous
	})

	req := httptest.NewRequest(http.MethodGet, EndpointSID64toAID+"?steamid=76561197960287930,76561197960287931", nil)
	rec := httptest.NewRecorder()

	HandleSteamID64ToAccountID(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}

	if body := strings.TrimSpace(rec.Body.String()); body != "batch size limit exceeded (max 1 items)" {
		t.Fatalf("unexpected body %q", body)
	}
}

func TestHandleSteamID64ToAccountIDBatchPreservesOrderAndLocalizesErrors(t *testing.T) {
	req := httptest.NewRequest(
		http.MethodGet,
		EndpointSID64toAID+"?steamid=76561197960287930,123,76561197960287931",
		nil,
	)
	req.Header.Set("Accept-Language", "en")
	rec := httptest.NewRecorder()

	HandleSteamID64ToAccountID(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	expected := "\"SteamIDTools\"\n{\n" +
		"    \"76561197960287930\" \"22202\"\n" +
		"    \"123\" \"ERROR: SteamID length is incorrect\"\n" +
		"    \"76561197960287931\" \"22203\"\n" +
		"}"

	if body := rec.Body.String(); body != expected {
		t.Fatalf("unexpected body:\n%s", body)
	}
}

func TestHandleSteamID64ToSteamID2UsesConfiguredUniverse(t *testing.T) {
	previous := appCfg.SID2Universe
	appCfg.SID2Universe = "0"
	t.Cleanup(func() {
		appCfg.SID2Universe = previous
	})

	req := httptest.NewRequest(http.MethodGet, EndpointSID64toSID2+"?steamid=76561197960287930", nil)
	rec := httptest.NewRecorder()

	HandleSteamID64ToSteamID2(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	if body := rec.Body.String(); body != "STEAM_0:0:11101" {
		t.Fatalf("unexpected body %q", body)
	}
}

func TestHandleSteamID2ToSteamID64BatchPreservesOrder(t *testing.T) {
	req := httptest.NewRequest(
		http.MethodGet,
		EndpointSID2toSID64+"?steamid=STEAM_1:0:11101,STEAM_X:0:11101",
		nil,
	)
	rec := httptest.NewRecorder()

	HandleSteamID2ToSteamID64(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d", http.StatusOK, rec.Code)
	}

	expected := "\"SteamIDTools\"\n{\n" +
		"    \"STEAM_1:0:11101\" \"76561197960287930\"\n" +
		"    \"STEAM_X:0:11101\" \"ERROR: Invalid SteamID2 format (expected STEAM_X:Y:Z)\"\n" +
		"}"

	if body := rec.Body.String(); body != expected {
		t.Fatalf("unexpected body:\n%s", body)
	}
}

func TestNewHTTPServerConfiguresTimeouts(t *testing.T) {
	server := newHTTPServer(":80", http.NewServeMux())

	if server.ReadHeaderTimeout != 5*time.Second {
		t.Fatalf("unexpected ReadHeaderTimeout: %s", server.ReadHeaderTimeout)
	}
	if server.ReadTimeout != 10*time.Second {
		t.Fatalf("unexpected ReadTimeout: %s", server.ReadTimeout)
	}
	if server.WriteTimeout != 10*time.Second {
		t.Fatalf("unexpected WriteTimeout: %s", server.WriteTimeout)
	}
	if server.IdleTimeout != 60*time.Second {
		t.Fatalf("unexpected IdleTimeout: %s", server.IdleTimeout)
	}
}
