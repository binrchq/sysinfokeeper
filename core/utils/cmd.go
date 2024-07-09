package utils

import (
	"errors"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
)

func CmdReader(command string, strip bool, typ interface{}) (interface{}, error) {
	if command == "" {
		return nil, errors.New("command is empty")
	}

	cmd := exec.Command("bash", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("error executing command: %w", err)
	}

	var rows []string
	lines := strings.Split(string(output), "\n")
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
