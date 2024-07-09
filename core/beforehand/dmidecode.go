package beforehand

import (
	"bitrec.ai/systemkeeper/core/omni"
)

var (
	OMNIDmidecodeCmd = map[string]string{}
)

func SetDmidecodeCmd() {
	dmidecodeCmd := map[string]string{
		"dmidecode-memory": "dmidecode -t memory",
	}

	for key, value := range dmidecodeCmd {
		OMNIDmidecodeCmd[key] = value
	}

	omni.DmidecodeCmd = OMNIDmidecodeCmd
}
