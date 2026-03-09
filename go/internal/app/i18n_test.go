package app

import (
	"os"
	"testing"
)

func TestEmbeddedLanguageFilesDoNotDependOnWorkingDirectory(t *testing.T) {
	previousDir, err := os.Getwd()
	if err != nil {
		t.Fatalf("failed to get working directory: %v", err)
	}

	tempDir := t.TempDir()
	if err := os.Chdir(tempDir); err != nil {
		t.Fatalf("failed to change working directory: %v", err)
	}

	t.Cleanup(func() {
		if err := os.Chdir(previousDir); err != nil {
			t.Fatalf("failed to restore working directory: %v", err)
		}
		loadMessages()
		loadBackendMessages(appCfg.BackendLang)
	})

	loadMessages()
	loadBackendMessages("es")

	if got := msg("invalid_length", "es"); got != "La longitud del SteamID es incorrecta" {
		t.Fatalf("unexpected translated message %q", got)
	}

	if got := msgBackend("service_ready"); got == "service_ready" {
		t.Fatalf("expected embedded backend message, got key fallback")
	}
}
