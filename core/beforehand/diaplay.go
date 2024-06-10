package beforehand

import (
	"os/exec"
	"strconv"
	"strings"

	"bitrec.ai/systemkeeper/core/utils"
)

var (
	size = map[string]int{
		"console":        0,
		"no-display":     0,
		"irc":            0,
		"max-cols":       0,
		"max-cols-basic": 0,
		"term-lines":     24, // Default value
		"term-cols":      80, // Default value
	}
	b_irc     = false
	b_display = false
)

func SetDisplaySize() {
	if !b_irc {
		if program := utils.CheckProgram("tput"); program != false {
			colsOutput, colsErr := exec.Command("tput", "cols").Output()
			if colsErr == nil {
				colsStr := strings.TrimSpace(string(colsOutput))
				if cols, err := strconv.Atoi(colsStr); err == nil {
					size["term-cols"] = cols
				}
			}

			linesOutput, linesErr := exec.Command("tput", "lines").Output()
			if linesErr == nil {
				linesStr := strings.TrimSpace(string(linesOutput))
				if lines, err := strconv.Atoi(linesStr); err == nil {
					size["term-lines"] = lines
				}
			}
		}

		if size["term-cols"] == 0 {
			size["term-cols"] = 80
		}
		if size["term-lines"] == 0 {
			size["term-lines"] = 24
		}
	}

	if !b_display && size["no-display"] != 0 {
		size["console"] = size["no-display"]
	}

	if size["term-cols"] < size["console"] {
		size["console"] = size["term-cols"]
	}

	size["console"]--

	if !b_irc {
		size["max-cols"] = size["console"]
	} else {
		size["max-cols"] = size["irc"]
	}

	size["max-cols-basic"] = size["max-cols"]
}
