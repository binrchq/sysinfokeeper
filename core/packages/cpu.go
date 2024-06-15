package packages

import (
	"strconv"
	"strings"

	"bitrec.ai/systemkeeper/core/model"
	"bitrec.ai/systemkeeper/core/omni"
	"bitrec.ai/systemkeeper/core/utils"
	"github.com/rs/zerolog/log"
)

type Cpu struct{}

func NewCpu() *Cpu {
	return &Cpu{}
}

func (c *Cpu) Get() (*model.CpuModel, error) {
	cpuinfo, err := c.GetCpuInfo(omni.SystemFiles["proc-cpuinfo"])
	if err != nil {
		log.Error().Err(err).Msg("Error getting CPU info")
	}
	cpuModel := model.NewCpu()
	for coreId, cpuCore := range cpuinfo {
		avgSpeed, err := strconv.ParseFloat(cpuCore["cpu mhz"], 64)
		if err != nil {
			log.Error().Err(err).Msg("Error getting CPU info")
		}
		if physical, exists := cpuCore["physical id"]; exists {
			cores, err := strconv.Atoi(cpuCore["cpu cores"])
			if err != nil {
				log.Error().Err(err).Msg("Error getting CPU info")
			}
			bits := 32
			if utils.Is64Bit(cpuCore["flags"]) {
				bits = 64
			}
			physicalId, err := strconv.Atoi(physical)
			if err != nil {
				log.Error().Err(err).Msg("Error getting CPU info")
			}
			if len(cpuModel.CpuInfos) <= physicalId {
				cpuModel.CpuInfos = append(cpuModel.CpuInfos, model.CpuInfo{ModelName: cpuCore["model name"], Cores: cores, Bits: bits, Type: "", Cache: "", MinMax: "", Flags: strings.Fields(cpuCore["flags"]), AvgSpeed: avgSpeed})
			} else {
				cpuModel.CpuInfos[physicalId].AvgSpeed = (cpuModel.CpuInfos[physicalId].AvgSpeed + avgSpeed) / 2
			}
		}
		if len(cpuModel.CoreSpeed) < coreId {
			cpuModel.CoreSpeed = append(cpuModel.CoreSpeed, avgSpeed)
		}
	}
	return cpuModel, nil
}

func (c *Cpu) GetCpuInfo(filepath string) ([]map[string]string, error) {
	raw, err := utils.Reader(filepath, false, "arr")
	if err != nil {
		return nil, err
	}

	raws := utils.EmptyLine2Strip(raw.([]string))
	if len(raws) > 0 {
		raws = append(raws, utils.EmptyLineStrip)
	}

	keyTests := []string{"firmware", "hardware", "mmu", "model", "motherboard", "platform", "system type", "timebase"}
	risc := make(map[string]bool)

	var cpuinfo []map[string]string
	cpuinfoMachine := make(map[string]string)
	blockID := 0

	for _, row := range raws {
		parts := strings.SplitN(row, ":", 2)
		if len(parts) < 2 {
			parts = append(parts, "")
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		lowerKey := strings.ToLower(key)

		bProcessor := len(risc) == 0 || !utils.Contains(keyTests, lowerKey) && (risc["ppc"] || lowerKey != "revision")

		if bProcessor {
			if key == utils.EmptyLineStrip {
				blockID++
				continue
			}

			if key == "Processor" {
				key = "model name"
			} else {
				key = lowerKey
			}

			if len(cpuinfo) <= blockID {
				cpuinfo = append(cpuinfo, make(map[string]string))
			}

			cpuinfo[blockID][key] = value
		} else {
			if _, exists := cpuinfoMachine[lowerKey]; !exists {
				cpuinfoMachine[lowerKey] = value
			}
		}
	}
	return cpuinfo, nil
}
