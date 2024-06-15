package utils

import (
	"fmt"
	"regexp"
	"strings"
)

func Readkv(line string, delimiter string) (map[string]string, error) {
	// Set default delimiter if not provided
	if delimiter == "" {
		delimiter = ":"
	}

	// Split the line into key and value
	kvMap := make(map[string]string)
	parts := strings.SplitN(line, delimiter, 2)
	if len(parts) == 2 {
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		kvMap[key] = value
	} else {
		return nil, fmt.Errorf("invalid key-value format(delimiter:'%s'):%s", delimiter, line)
	}
	return kvMap, nil
}

var (
	EmptyLineStrip = "~~~"
)

func EmptyLine2Strip(raw []string) []string {
	re := regexp.MustCompile(`^\s*$`)
	for i, line := range raw {
		if re.MatchString(line) {
			raw[i] = EmptyLineStrip
		}
	}
	return raw
}
