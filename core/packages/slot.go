package packages

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Slot struct{}

func NewSlot() *Slot {
	return &Slot{}
}

type SlotInfo struct {
	ID          string `json:"id"`           // 插槽ID
	Type        string `json:"type"`         // 类型 (PCI/PCIe/PCI-X)
	Status      string `json:"status"`       // 状态 (In Use/Available)
	BusAddress  string `json:"bus_address"`  // 总线地址
	Device      string `json:"device"`       // 设备信息
	Generation  string `json:"generation"`   // PCIe 代 (Gen1/Gen2/Gen3/Gen4/Gen5)
	Lanes       string `json:"lanes"`        // 通道数
	LanesActive string `json:"lanes_active"` // 活动通道数
	Length      string `json:"length"`       // 长度
	Voltage     string `json:"voltage"`      // 电压
	CPU         string `json:"cpu"`          // 关联的CPU
}

type SlotModel struct {
	SlotInfos []SlotInfo `json:"slot_infos"`
	Msg       string     `json:"msg"`
}

func NewSlotModel() *SlotModel {
	return &SlotModel{}
}

func (s *Slot) Get() (*SlotModel, error) {
	model := NewSlotModel()

	// 尝试从 dmidecode 获取插槽信息
	slots, err := s.gatherFromDmidecode()
	if err != nil {
		// 如果 dmidecode 失败，尝试从 sysfs 获取
		slots, err = s.gatherFromSysfs()
		if err != nil {
			model.Msg = err.Error()
			return model, err
		}
	}

	// 丰富信息（从 lspci 获取设备信息）
	s.enrichSlotInfo(slots)

	model.SlotInfos = slots
	return model, nil
}

func (s *Slot) gatherFromDmidecode() ([]SlotInfo, error) {
	cmd := exec.Command("dmidecode", "-t", "9")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("dmidecode failed: %w", err)
	}

	var slots []SlotInfo
	lines := strings.Split(string(output), "\n")

	var currentSlot *SlotInfo
	for _, line := range lines {
		line = strings.TrimSpace(line)

		if strings.HasPrefix(line, "System Slot Information") {
			if currentSlot != nil {
				slots = append(slots, *currentSlot)
			}
			currentSlot = &SlotInfo{}
			continue
		}

		if currentSlot == nil {
			continue
		}

		// 解析各种字段
		if strings.HasPrefix(line, "Designation:") {
			currentSlot.ID = strings.TrimSpace(strings.TrimPrefix(line, "Designation:"))
		} else if strings.HasPrefix(line, "Type:") {
			currentSlot.Type = strings.TrimSpace(strings.TrimPrefix(line, "Type:"))
		} else if strings.HasPrefix(line, "Current Usage:") {
			currentSlot.Status = strings.TrimSpace(strings.TrimPrefix(line, "Current Usage:"))
		} else if strings.HasPrefix(line, "Bus Address:") {
			currentSlot.BusAddress = strings.TrimSpace(strings.TrimPrefix(line, "Bus Address:"))
		} else if strings.HasPrefix(line, "Length:") {
			currentSlot.Length = strings.TrimSpace(strings.TrimPrefix(line, "Length:"))
		}
	}

	if currentSlot != nil {
		slots = append(slots, *currentSlot)
	}

	return slots, nil
}

func (s *Slot) gatherFromSysfs() ([]SlotInfo, error) {
	var slots []SlotInfo

	// 从 /sys/bus/pci/slots/ 读取插槽信息
	slotDir := "/sys/bus/pci/slots"
	entries, err := os.ReadDir(slotDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read slot directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		slotID := entry.Name()
		slotPath := filepath.Join(slotDir, slotID)

		slotInfo := SlotInfo{
			ID:     slotID,
			Type:   "PCIe",
			Status: "Available",
		}

		// 读取地址
		if addr, err := os.ReadFile(filepath.Join(slotPath, "address")); err == nil {
			slotInfo.BusAddress = strings.TrimSpace(string(addr))
		}

		// 检查是否有设备
		if _, err := os.Stat(filepath.Join(slotPath, "device")); err == nil {
			slotInfo.Status = "In Use"
		}

		slots = append(slots, slotInfo)
	}

	return slots, nil
}

func (s *Slot) enrichSlotInfo(slots []SlotInfo) {
	// 使用 lspci 获取设备信息
	cmd := exec.Command("lspci")
	output, err := cmd.Output()
	if err != nil {
		return
	}

	lspciLines := strings.Split(string(output), "\n")
	lspciMap := make(map[string]string)

	for _, line := range lspciLines {
		if len(line) < 7 {
			continue
		}
		// 提取总线地址（前7个字符，如 "00:00.0"）
		busAddr := line[:7]
		device := strings.TrimSpace(line[7:])
		lspciMap[busAddr] = device
	}

	// 匹配插槽和设备
	for i := range slots {
		if device, ok := lspciMap[slots[i].BusAddress]; ok {
			slots[i].Device = device
			slots[i].Status = "In Use"
		}

		// 尝试从 sysfs 获取 PCIe 信息
		if slots[i].BusAddress != "" {
			s.getPCIeInfo(&slots[i])
		}
	}
}

func (s *Slot) getPCIeInfo(slot *SlotInfo) {
	// 查找对应的 PCI 设备路径
	busAddr := strings.ReplaceAll(slot.BusAddress, ":", "_")
	busAddr = strings.ReplaceAll(busAddr, ".", "_")

	// 搜索 /sys/bus/pci/devices/ 目录
	devicesDir := "/sys/bus/pci/devices"
	entries, err := os.ReadDir(devicesDir)
	if err != nil {
		return
	}

	for _, entry := range entries {
		if strings.Contains(entry.Name(), busAddr) ||
			strings.Contains(entry.Name(), slot.BusAddress) {
			devicePath := filepath.Join(devicesDir, entry.Name())

			// 读取当前链接速度
			if speed, err := os.ReadFile(filepath.Join(devicePath, "current_link_speed")); err == nil {
				speedStr := strings.TrimSpace(string(speed))
				if strings.Contains(speedStr, "GT/s") {
					slot.Generation = speedStr
				}
			}

			// 读取当前链接宽度
			if width, err := os.ReadFile(filepath.Join(devicePath, "current_link_width")); err == nil {
				slot.LanesActive = strings.TrimSpace(string(width))
			}

			// 读取最大链接速度
			if maxSpeed, err := os.ReadFile(filepath.Join(devicePath, "max_link_speed")); err == nil {
				speedStr := strings.TrimSpace(string(maxSpeed))
				if strings.Contains(speedStr, "GT/s") {
					// 可以根据速度推断代
					if strings.Contains(speedStr, "2.5") {
						slot.Generation = "Gen1"
					} else if strings.Contains(speedStr, "5.0") {
						slot.Generation = "Gen2"
					} else if strings.Contains(speedStr, "8.0") {
						slot.Generation = "Gen3"
					} else if strings.Contains(speedStr, "16.0") {
						slot.Generation = "Gen4"
					} else if strings.Contains(speedStr, "32.0") {
						slot.Generation = "Gen5"
					}
				}
			}

			// 读取最大链接宽度
			if maxWidth, err := os.ReadFile(filepath.Join(devicePath, "max_link_width")); err == nil {
				slot.Lanes = strings.TrimSpace(string(maxWidth))
			}

			break
		}
	}
}
