package utils

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Reader reads the content of a file and processes it based on the parameters.
func Reader(file string, strip bool, typ interface{}) (interface{}, error) {
	if file == "" {
		return nil, errors.New("file name is empty")
	}
	if _, err := os.Stat(file); os.IsNotExist(err) {
		return nil, fmt.Errorf("file %s does not exist or is not readable", file)
	}

	content, err := os.ReadFile(file)
	if err != nil {
		return nil, fmt.Errorf("error opening file: %w", err)
	}
	var rows []string
	lines := strings.Split(string(content), "\n")
	for _, line := range lines {
		if strip {
			line = strings.TrimSpace(line)
			// Skip empty lines or lines starting with '#' or empty lines
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
		}
		rows = append(rows, line)
	}

	switch v := typ.(type) {
	case string:
		switch v {
		case "arr":
			return rows, nil
		case "ref":
			return &rows, nil
		default:
			index, err := strconv.Atoi(v)
			if err != nil || index < 0 || index >= len(rows) {
				return nil, nil
			}
			return rows[index], nil
		}
	case int:
		if v < 0 || v >= len(rows) {
			return nil, fmt.Errorf("index out of range: %d", v)
		}
		return rows[v], nil
	default:
		return rows, nil
	}
}
