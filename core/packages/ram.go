package packages

import (
	"fmt"
	"strings"

	"bitrec.ai/systemkeeper/core/model"
	"bitrec.ai/systemkeeper/core/omni"
	"bitrec.ai/systemkeeper/core/utils"
	"github.com/rs/zerolog/log"
)

type Ram struct{}

func NewRam() *Ram {
	return &Ram{}
}

func (c *Ram) Get() (memoryModel *model.MemoryModel, err error) {
	meminfo, err := c.GetRamInfo(omni.SystemFiles["proc-meminfo"])
	if err != nil {
		log.Warn().Err(err).Msg("Error getting Memory info")
	}
	memoryModel = model.NewMemory()
	memoryModel.Total = meminfo["memtotal"]
	memoryModel.Used = meminfo["memtotal"] - meminfo["memavailable"]
	memoryModel.Available = meminfo["memavailable"]
	memoryModel.SystemRam = meminfo["memtotal"] + meminfo["swaptotal"]
	memModule, err := c.GetRamModuleInfo(omni.DmidecodeCmd["dmidecode-memory"])
	if err != nil {
		log.Warn().Err(err).Msg("Error getting Memory info")
		return

	}
	keyTestsPart := []string{"maximum capacity"}
	keyTestsModule := []string{"size", "locator", "type", "part number", "manufacturer", "serial number"}
	Installed := 0
	for _, sonPart := range memModule {
		isPart := utils.ContainsAll(sonPart.keys(), keyTestsPart)
		isModule := utils.ContainsAll(sonPart.keys(), keyTestsModule)
		if isPart {
			memoryModel.PartNumber++
			memoryModel.PartCapacity = sonPart["maximum capacity"]
			memoryModel.Eec = sonPart["error correction type"]
		} else if isModule {
			memoryModule := &model.MemoryModule{}
			memoryModel.Slots++

			// 判断是否安装了
			isInstalled, err := utils.ExtractInt(sonPart["size"])
			if err == nil && isInstalled > 0 {
				memoryModel.Active++
				Installed += isInstalled
				memoryModule.Installed = "yes"
			} else {
				memoryModule.Installed = "no"
			}

			memoryModel.Type = sonPart["type"]
			memoryModule.Device = sonPart["bank locator"]
			memoryModule.Size = sonPart["size"]
			memoryModule.Speed = sonPart["speed"]
			memoryModule.Slot = sonPart["locator"]
			memoryModule.ModelName = sonPart["part number"]
			memoryModule.SN = sonPart["serial number"]
			memoryModule.Manufacturer = sonPart["manufacturer"]
			memoryModel.MemoryModule = append(memoryModel.MemoryModule, *memoryModule)
		}
	}
	gb, err := utils.ExtractInt(memoryModel.PartCapacity)
	if err != nil {
		log.Warn().Err(err).Msg("Error getting Memory info")
		return
	}
	memoryModel.Capacity = fmt.Sprintf("%dGB", gb*memoryModel.PartNumber)
	memoryModel.Installed = fmt.Sprintf("%dGB", Installed)
	return
}

func (c *Ram) GetRamInfo(filepath string) (map[string]int, error) {
	raws, err := utils.Reader(filepath, false, "arr")
	if err != nil {
		return nil, err
	}

	meminfo := map[string]int{}
	keyTests := []string{"memtotal", "memfree", "memavailable", "swaptotal"}
	for _, row := range raws.([]string) {
		parts := strings.SplitN(row, ":", 2)
		if len(parts) < 2 {
			parts = append(parts, "0")
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		valueInt, err := utils.ExtractInt(value)
		if err != nil {
			return nil, err

		}
		lowerKey := strings.ToLower(key)
		if utils.Contains(keyTests, lowerKey) {
			if _, exists := meminfo[lowerKey]; !exists {
				meminfo[lowerKey] = valueInt
			}
		}
	}
	return meminfo, nil
}

// 模拟的 MemModuleInfo 类型
type MemModuleInfo map[string]string

// 获取键的切片
func (m MemModuleInfo) keys() []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	return keys
}

func (c *Ram) GetRamModuleInfo(cmd string) ([]MemModuleInfo, error) {
	raw, err := utils.CmdReader(cmd, false, "arr")
	if err != nil {
		log.Warn().Err(err).Msg("Error getting Memory infos")
		return nil, err
	}

	raws := utils.EmptyLine2Strip(raw.([]string))
	if len(raws) > 0 {
		raws = append(raws, utils.EmptyLineStrip)
	}
	memModule := []MemModuleInfo{}
	blockID := 0

	for _, row := range raws {
		if !strings.Contains(row, ":") && !strings.Contains(row, utils.EmptyLineStrip) {
			continue
		}
		parts := strings.SplitN(row, ":", 2)
		if len(parts) < 2 {
			parts = append(parts, "")
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		lowerKey := strings.ToLower(key)
		if key == utils.EmptyLineStrip {
			blockID++
			continue
		}
		if len(memModule) <= blockID {
			memModule = append(memModule, MemModuleInfo{lowerKey: value})
		} else {
			memModule[blockID][lowerKey] = value
		}
	}
	return memModule, nil
}
