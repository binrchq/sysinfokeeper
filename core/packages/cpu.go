package packages

import (
	"fmt"
	"strconv"
	"strings"

	"binrc.com/sysinfokeeper/core/model"
	"binrc.com/sysinfokeeper/core/omni"
	"binrc.com/sysinfokeeper/core/utils"
	"github.com/rs/zerolog/log"
)

type Cpu struct{}

// 创建一个新的Cpu实例
func NewCpu() *Cpu {
	// 返回一个指向Cpu实例的指针
	return &Cpu{}
}

func (c *Cpu) Get() (*model.CpuModel, error) {
	cpuinfo, err := c.GetCpuInfo(omni.SystemFiles["proc-cpuinfo"])
	if err != nil {
		log.Warn().Err(err).Msg("Error getting CPU info")
	}
	cpuModel := model.NewCpu()
	for coreId, cpuCore := range cpuinfo {
		avgSpeed, err := strconv.ParseFloat(cpuCore["cpu mhz"], 64)
		if err != nil {
			log.Warn().Err(err).Msg("Error getting CPU info")
		}
		if physical, exists := cpuCore["physical id"]; exists {
			cores, err := strconv.Atoi(cpuCore["cpu cores"])
			if err != nil {
				log.Warn().Err(err).Msg("Error getting CPU info")
			}
			bits := 32
			if utils.Is64Bit(cpuCore["flags"]) {
				bits = 64
			}
			physicalId, err := strconv.Atoi(physical)
			if err != nil {
				log.Warn().Err(err).Msg("Error getting CPU info")
			}
			if len(cpuModel.CpuInfos) <= physicalId {
				MaxSpeed, _ := c.GetBaseSpeed(fmt.Sprintf(omni.SystemFiles["device-cpufreq0max"], cpuCore["processor"]))
				MinSpeed, _ := c.GetBaseSpeed(fmt.Sprintf(omni.SystemFiles["device-cpufreq0min"], cpuCore["processor"]))
				cpuModel.CpuInfos = append(cpuModel.CpuInfos, model.CpuInfo{ModelName: cpuCore["model name"], Cores: cores, Bits: bits, Type: "", Cache: "", MaxSpeed: MaxSpeed, MinSpeed: MinSpeed, Flags: strings.Fields(cpuCore["flags"]), AvgSpeed: avgSpeed})
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

// 读取cpu的基础睿频信息
func (c *Cpu) GetBaseSpeed(filepath string) (float64, error) {
	raw, err := utils.Reader(filepath, false, nil)
	if err != nil {
		return -1, err
	}
	line := raw.([]string)[0]
	Speed, err := strconv.ParseFloat(strings.TrimSpace(line), 64)

	if err != nil {
		return -1, err
	}
	return Speed, nil
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
