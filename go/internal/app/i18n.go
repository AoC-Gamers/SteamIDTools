package app

import (
	"embed"
	"encoding/json"
	"fmt"
)

//go:embed lang/*.json
var langFiles embed.FS

var messages map[string]string
var backendMessages map[string]string

func loadMessages() {
	messages = make(map[string]string)
	langFilesByCode := map[string]string{
		"en": "lang/messages_en.json",
		"es": "lang/messages_es.json",
	}

	for lang, path := range langFilesByCode {
		data, err := langFiles.ReadFile(path)
		if err != nil {
			appWarnf("could not load language file %s: %v", path, err)
			continue
		}

		var translated map[string]string
		if err := json.Unmarshal(data, &translated); err != nil {
			appWarnf("could not parse language file %s: %v", path, err)
			continue
		}

		for key, value := range translated {
			messages[lang+":"+key] = value
		}
	}
}

func loadBackendMessages(lang string) {
	backendMessages = make(map[string]string)
	langFilesByCode := map[string]string{
		"en": "lang/messages_backend_en.json",
		"es": "lang/messages_backend_es.json",
	}

	path, ok := langFilesByCode[lang]
	if !ok {
		path = langFilesByCode["en"]
	}

	data, err := langFiles.ReadFile(path)
	if err != nil {
		appWarnf("could not load backend language file %s: %v", path, err)
		return
	}

	var translated map[string]string
	if err := json.Unmarshal(data, &translated); err != nil {
		appWarnf("could not parse backend language file %s: %v", path, err)
		return
	}

	for key, value := range translated {
		backendMessages[key] = value
	}
}

func debugEnabled() bool {
	return appCfg.Debug
}

func debugLog(format string, args ...interface{}) {
	if debugEnabled() {
		appDebugf(format, args...)
	}
}

func msg(key, lang string) string {
	if value, ok := messages[lang+":"+key]; ok {
		debugLog("Translation found for %s/%s: %s", lang, key, value)
		return value
	}

	debugLog("Translation key %q not found in language %q", key, lang)
	if value, ok := messages["en:"+key]; ok {
		debugLog("Fallback translation found for %s: %s", key, value)
		return value
	}

	debugLog("No translation found for key %q, returning the key", key)
	return key
}

func msgBackend(key string, args ...interface{}) string {
	if value, ok := backendMessages[key]; ok {
		if len(args) > 0 {
			return fmt.Sprintf(value, args...)
		}
		return value
	}

	return key
}

func msgf(key, lang string, args ...interface{}) string {
	return fmt.Sprintf(msg(key, lang), args...)
}

func init() {
	loadMessages()
	loadBackendMessages(appCfg.BackendLang)
}
