package app

import (
	"fmt"
	"testing"
)

func TestAIDFromSID64RejectsOutOfRangeValues(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		input   string
		wantErr SteamIDError
		wantVal string
	}{
		{
			name:    "valid steamid64",
			input:   "76561197960287930",
			wantErr: ErrorNone,
			wantVal: "22202",
		},
		{
			name:    "base value maps to invalid account id",
			input:   fmt.Sprintf("%d", STEAMID64_BASE),
			wantErr: ErrorInvalidSteamID64,
		},
		{
			name:    "value above max account range",
			input:   fmt.Sprintf("%d", MaxSteamID64+1),
			wantErr: ErrorInvalidSteamID64,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := AIDFromSID64(tc.input)
			if got.Error != tc.wantErr {
				t.Fatalf("expected error %q, got %q", tc.wantErr, got.Error)
			}
			if got.Value != tc.wantVal {
				t.Fatalf("expected value %q, got %q", tc.wantVal, got.Value)
			}
		})
	}
}

func TestSID64FromAIDRejectsOutOfRangeValues(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		input   string
		wantErr SteamIDError
		wantVal string
	}{
		{
			name:    "valid account id",
			input:   "22202",
			wantErr: ErrorNone,
			wantVal: "76561197960287930",
		},
		{
			name:    "zero account id",
			input:   "0",
			wantErr: ErrorInvalidAccountID,
		},
		{
			name:    "account id above uint32 max",
			input:   fmt.Sprintf("%d", MaxAccountID+1),
			wantErr: ErrorInvalidAccountID,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := SID64FromAID(tc.input)
			if got.Error != tc.wantErr {
				t.Fatalf("expected error %q, got %q", tc.wantErr, got.Error)
			}
			if got.Value != tc.wantVal {
				t.Fatalf("expected value %q, got %q", tc.wantVal, got.Value)
			}
		})
	}
}

func TestAIDFromSID2RejectsInvalidAccountRange(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name    string
		input   string
		wantErr SteamIDError
	}{
		{
			name:    "zero account id",
			input:   "STEAM_1:0:0",
			wantErr: ErrorInvalidSteamID2,
		},
		{
			name:    "account id above uint32 max",
			input:   "STEAM_1:1:2147483648",
			wantErr: ErrorInvalidSteamID2,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			got := AIDFromSID2(tc.input)
			if got.Error != tc.wantErr {
				t.Fatalf("expected error %q, got %q", tc.wantErr, got.Error)
			}
		})
	}
}
