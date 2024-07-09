package utils

import (
	"encoding/json"
	"log"
)

func DebugPrintDetails(v interface{}) {
	jsonBytes, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		log.Printf("Error marshaling to JSON: %v", err)
		return
	}
	log.Printf("Detailed value: %s", string(jsonBytes))
}
