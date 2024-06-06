package main

import (
	"os"
	"strings"
	"time"

	"bitrec.ai/dialmainer/cmd/dialer/cli"

	"bitrec.ai/dialmainer/core/global"
	"github.com/jagottsicher/termcolor"
	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

func main() {
	var colors bool
	switch l := termcolor.SupportLevel(os.Stderr); l {
	case termcolor.Level16M:
		colors = true
	case termcolor.Level256:
		colors = true
	case termcolor.LevelBasic:
		colors = true
	case termcolor.LevelNone:
		colors = false
	default:
		colors = false
	}

	global.Mode = "release"
	if len(os.Args) > 1 && strings.Contains(os.Args[0], "go") {
		global.Mode = "dev"
	}

	if _, noColorIsSet := os.LookupEnv("NO_COLOR"); noColorIsSet {
		colors = false
	}

	zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
	log.Logger = log.Output(zerolog.ConsoleWriter{
		Out:        os.Stderr,
		TimeFormat: time.RFC3339,
		NoColor:    !colors,
	})

	cli.Execute()
}
