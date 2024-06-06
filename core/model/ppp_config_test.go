package model

import (
	"testing"
)

func TestPPPConfig_GenCommand(t *testing.T) {
	PPPConfig := NewPPPConfig(16729296, "VJTsz51235754343165", "123321", "ens7f0.1000", false, "ppp0", 100, "00:11:22:33:44:55", "", "")
	command := PPPConfig.GenCommand()
	t.Log(command)
}

func TestPPPConfig_GenCommandWithOpt(t *testing.T) {
	PPPConfig := NewPPPConfig(16729296, "VJTsz51235754343165", "123321", "ens7f0.1000", false, "ppp0", 100, "00:11:22:33:44:55", "servername", "acname")
	command := PPPConfig.GenCommand()
	t.Log(command)
}
