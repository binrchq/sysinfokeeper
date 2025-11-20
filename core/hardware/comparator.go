package hardware

import (
	"fmt"
	"reflect"
	"strings"
	"time"

	"binrc.com/sysinfokeeper/core/model"
)

const (
	EventAdded   = "added"
	EventRemoved = "removed"
	EventMoved   = "moved"
	EventChanged = "changed"
)

type Comparator struct {
	oldSnapshot    *HardwareSnapshot
	newSnapshot    *HardwareSnapshot
	removedDevices []RemovedDevice
}

type RemovedDevice struct {
	Type    string
	ID      string
	Name    string
	Message string
	Data    map[string]interface{} // 设备详细信息
}

func NewComparator(old, new *HardwareSnapshot) *Comparator {
	return &Comparator{
		oldSnapshot:    old,
		newSnapshot:    new,
		removedDevices: make([]RemovedDevice, 0),
	}
}

func (c *Comparator) GetRemovedDevices() []RemovedDevice {
	return c.removedDevices
}

func (c *Comparator) CompareAndMark(allInfo *model.SInfo) {
	c.compareCPU(&allInfo.Cpu)
	c.compareGPU(&allInfo.Gpu)
	c.compareDisk(&allInfo.Disk)
	c.compareMemory(&allInfo.Memory)
	c.compareNic(&allInfo.Nic)
	c.compareFan(&allInfo.Fan)
	// 将移除的设备添加到对应的硬件列表中
	now := time.Now()
	for _, rd := range c.removedDevices {
		switch rd.Type {
		case "Disk":
			if allInfo.Disk.DiskInfos == nil {
				allInfo.Disk.DiskInfos = make([]model.DiskInfo, 0)
			}
			diskInfo := model.DiskInfo{
				Device:       getString(rd.Data, "device"),
				ModelName:    getString(rd.Data, "model_name"),
				Size:         getString(rd.Data, "size"),
				SN:           getString(rd.Data, "sn"),
				Manufacturer: getString(rd.Data, "manufacturer"),
				Slot:         "/dev/" + getString(rd.Data, "device"),
				Event:        EventRemoved,
				EventMsg:     rd.Message,
				RemovedAt:    &now,
			}
			if mountPoints, ok := rd.Data["mount_point"].([]string); ok {
				diskInfo.MountPoint = mountPoints
			}
			allInfo.Disk.DiskInfos = append(allInfo.Disk.DiskInfos, diskInfo)
		case "Memory":
			if allInfo.Memory.MemoryModule == nil {
				allInfo.Memory.MemoryModule = make([]model.MemoryModule, 0)
			}
			memInfo := model.MemoryModule{
				Slot:         getString(rd.Data, "slot"),
				ModelName:    getString(rd.Data, "model_name"),
				Size:         getString(rd.Data, "size"),
				SN:           getString(rd.Data, "sn"),
				Manufacturer: getString(rd.Data, "manufacturer"),
				Event:        EventRemoved,
				EventMsg:     rd.Message,
				RemovedAt:    &now,
			}
			allInfo.Memory.MemoryModule = append(allInfo.Memory.MemoryModule, memInfo)
		case "CPU":
			if allInfo.Cpu.CpuInfos == nil {
				allInfo.Cpu.CpuInfos = make([]model.CpuInfo, 0)
			}
			cpuInfo := model.CpuInfo{
				ModelName: getString(rd.Data, "model_name"),
				Cores:     getInt(rd.Data, "cores"),
				MaxSpeed:  getFloat64(rd.Data, "max_speed"),
				MinSpeed:  getFloat64(rd.Data, "min_speed"),
				Event:     EventRemoved,
				EventMsg:  rd.Message,
				RemovedAt: &now,
			}
			allInfo.Cpu.CpuInfos = append(allInfo.Cpu.CpuInfos, cpuInfo)
		case "GPU":
			if allInfo.Gpu.GpuInfos == nil {
				allInfo.Gpu.GpuInfos = make([]model.GpuInfo, 0)
			}
			gpuInfo := model.GpuInfo{
				ModelName: getString(rd.Data, "model_name"),
				Type:      getString(rd.Data, "type"),
				Memory:    getString(rd.Data, "memory"),
				Event:     EventRemoved,
				EventMsg:  rd.Message,
				RemovedAt: &now,
			}
			allInfo.Gpu.GpuInfos = append(allInfo.Gpu.GpuInfos, gpuInfo)
		case "NIC":
			if allInfo.Nic.NicInfos == nil {
				allInfo.Nic.NicInfos = make([]model.NicInfo, 0)
			}
			nicInfo := model.NicInfo{
				Name:       getString(rd.Data, "name"),
				Vendor:     getString(rd.Data, "vendor"),
				Model:      getString(rd.Data, "model"),
				MacAddress: getString(rd.Data, "mac_address"),
				Type:       getString(rd.Data, "type"),
				Event:      EventRemoved,
				EventMsg:   rd.Message,
				RemovedAt:  &now,
			}
			allInfo.Nic.NicInfos = append(allInfo.Nic.NicInfos, nicInfo)
		case "Fan":
			if allInfo.Fan.FanInfos == nil {
				allInfo.Fan.FanInfos = make([]model.FanInfo, 0)
			}
			fanInfo := model.FanInfo{
				Name:      getString(rd.Data, "name"),
				Event:     EventRemoved,
				EventMsg:  rd.Message,
				RemovedAt: &now,
			}
			allInfo.Fan.FanInfos = append(allInfo.Fan.FanInfos, fanInfo)
		}
	}
}

func getString(data map[string]interface{}, key string) string {
	if val, ok := data[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

func getInt(data map[string]interface{}, key string) int {
	if val, ok := data[key]; ok {
		if i, ok := val.(int); ok {
			return i
		}
		if f, ok := val.(float64); ok {
			return int(f)
		}
	}
	return 0
}

func getFloat64(data map[string]interface{}, key string) float64 {
	if val, ok := data[key]; ok {
		if f, ok := val.(float64); ok {
			return f
		}
		if i, ok := val.(int); ok {
			return float64(i)
		}
	}
	return 0
}

func (c *Comparator) compareCPU(cpuModel *model.CpuModel) {
	oldMap := make(map[string]CpuSnapshot)
	for _, cpu := range c.oldSnapshot.CPU {
		oldMap[cpu.ID] = cpu
	}

	newMap := make(map[string]CpuSnapshot)
	for _, cpu := range c.newSnapshot.CPU {
		newMap[cpu.ID] = cpu
	}

	for i := range cpuModel.CpuInfos {
		cpuID := fmt.Sprintf("cpu_%d", i)
		newCPU := newMap[cpuID]

		if oldCPU, exists := oldMap[cpuID]; exists {
			if !reflect.DeepEqual(oldCPU, newCPU) {
				cpuModel.CpuInfos[i].Event = EventChanged
				// Detailed change information
				changes := []string{}
				if oldCPU.ModelName != newCPU.ModelName {
					changes = append(changes, fmt.Sprintf("Model: %s -> %s", oldCPU.ModelName, newCPU.ModelName))
				}
				if oldCPU.Cores != newCPU.Cores {
					changes = append(changes, fmt.Sprintf("Cores: %d -> %d", oldCPU.Cores, newCPU.Cores))
				}
				if oldCPU.MaxSpeed != newCPU.MaxSpeed {
					changes = append(changes, fmt.Sprintf("Max Speed: %.2f -> %.2f GHz", oldCPU.MaxSpeed/1000, newCPU.MaxSpeed/1000))
				}
				if oldCPU.MinSpeed != newCPU.MinSpeed {
					changes = append(changes, fmt.Sprintf("Min Speed: %.2f -> %.2f GHz", oldCPU.MinSpeed/1000, newCPU.MinSpeed/1000))
				}
				if len(changes) > 0 {
					cpuModel.CpuInfos[i].EventMsg = "Configuration changed: " + strings.Join(changes, "; ")
				} else {
					cpuModel.CpuInfos[i].EventMsg = "CPU configuration changed (details unknown)"
				}
			}
		} else {
			cpuModel.CpuInfos[i].Event = EventAdded
			cpuModel.CpuInfos[i].EventMsg = fmt.Sprintf("New CPU detected: %s (%d cores, %.2f GHz max)",
				cpuModel.CpuInfos[i].ModelName, cpuModel.CpuInfos[i].Cores, cpuModel.CpuInfos[i].MaxSpeed/1000)
		}
	}

	// Detect removed CPUs
	for oldID, oldCPU := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "CPU",
				ID:      oldID,
				Name:    oldCPU.ModelName,
				Message: fmt.Sprintf("CPU removed: %s (%d cores, %.2f GHz)", oldCPU.ModelName, oldCPU.Cores, oldCPU.MaxSpeed/1000),
				Data: map[string]interface{}{
					"model_name":  oldCPU.ModelName,
					"cores":       oldCPU.Cores,
					"max_speed":   oldCPU.MaxSpeed,
					"min_speed":   oldCPU.MinSpeed,
					"physical_id": oldCPU.PhysicalID,
				},
			})
		}
	}
}

func (c *Comparator) compareGPU(gpuModel *model.GpuModel) {
	oldMap := make(map[string]GpuSnapshot)
	for _, gpu := range c.oldSnapshot.GPU {
		oldMap[gpu.ID] = gpu
	}

	newMap := make(map[string]GpuSnapshot)
	for _, gpu := range c.newSnapshot.GPU {
		newMap[gpu.ID] = gpu
	}

	for i := range gpuModel.GpuInfos {
		gpuID := fmt.Sprintf("gpu_%d", i)
		newGPU := newMap[gpuID]

		if oldGPU, exists := oldMap[gpuID]; exists {
			if oldGPU.ModelName != newGPU.ModelName || oldGPU.Memory != newGPU.Memory || oldGPU.Type != newGPU.Type {
				gpuModel.GpuInfos[i].Event = EventChanged
				changes := []string{}
				if oldGPU.ModelName != newGPU.ModelName {
					changes = append(changes, fmt.Sprintf("Model: %s -> %s", oldGPU.ModelName, newGPU.ModelName))
				}
				if oldGPU.Memory != newGPU.Memory {
					changes = append(changes, fmt.Sprintf("Memory: %s -> %s", oldGPU.Memory, newGPU.Memory))
				}
				if oldGPU.Type != newGPU.Type {
					changes = append(changes, fmt.Sprintf("Type: %s -> %s", oldGPU.Type, newGPU.Type))
				}
				if len(changes) > 0 {
					gpuModel.GpuInfos[i].EventMsg = "Configuration changed: " + strings.Join(changes, "; ")
				} else {
					gpuModel.GpuInfos[i].EventMsg = "GPU configuration changed (details unknown)"
				}
			}
		} else {
			gpuModel.GpuInfos[i].Event = EventAdded
			gpuModel.GpuInfos[i].EventMsg = fmt.Sprintf("New GPU detected: %s (%s, %s)",
				gpuModel.GpuInfos[i].ModelName, gpuModel.GpuInfos[i].Type, gpuModel.GpuInfos[i].Memory)
		}
	}

	// Detect removed GPUs
	for oldID, oldGPU := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "GPU",
				ID:      oldID,
				Name:    oldGPU.ModelName,
				Message: fmt.Sprintf("GPU removed: %s (%s, %s)", oldGPU.ModelName, oldGPU.Type, oldGPU.Memory),
				Data: map[string]interface{}{
					"model_name": oldGPU.ModelName,
					"type":       oldGPU.Type,
					"memory":     oldGPU.Memory,
				},
			})
		}
	}
}

func (c *Comparator) compareDisk(diskModel *model.DiskModel) {
	oldMap := make(map[string]DiskSnapshot)
	for _, disk := range c.oldSnapshot.Disk {
		oldMap[disk.ID] = disk
	}

	newMap := make(map[string]DiskSnapshot)
	for _, disk := range c.newSnapshot.Disk {
		newMap[disk.ID] = disk
	}

	for i := range diskModel.DiskInfos {
		diskID := diskModel.DiskInfos[i].SN
		if diskID == "" {
			diskID = diskModel.DiskInfos[i].Device
		}

		newDisk := newMap[diskID]

		if oldDisk, exists := oldMap[diskID]; exists {
			if !reflect.DeepEqual(oldDisk.MountPoint, newDisk.MountPoint) {
				diskModel.DiskInfos[i].Event = EventMoved
				oldMP := strings.Join(oldDisk.MountPoint, ",")
				newMP := strings.Join(newDisk.MountPoint, ",")
				if oldMP == "" {
					oldMP = "unmounted"
				}
				if newMP == "" {
					newMP = "unmounted"
				}
				diskModel.DiskInfos[i].EventMsg = fmt.Sprintf("Mount point changed: %s -> %s", oldMP, newMP)
			} else if oldDisk.Device != newDisk.Device || oldDisk.Size != newDisk.Size || oldDisk.ModelName != newDisk.ModelName {
				diskModel.DiskInfos[i].Event = EventChanged
				changes := []string{}
				if oldDisk.Device != newDisk.Device {
					changes = append(changes, fmt.Sprintf("Device: %s -> %s", oldDisk.Device, newDisk.Device))
				}
				if oldDisk.Size != newDisk.Size {
					changes = append(changes, fmt.Sprintf("Size: %s -> %s", oldDisk.Size, newDisk.Size))
				}
				if oldDisk.ModelName != newDisk.ModelName {
					changes = append(changes, fmt.Sprintf("Model: %s -> %s", oldDisk.ModelName, newDisk.ModelName))
				}
				if oldDisk.Manufacturer != newDisk.Manufacturer {
					changes = append(changes, fmt.Sprintf("Manufacturer: %s -> %s", oldDisk.Manufacturer, newDisk.Manufacturer))
				}
				if len(changes) > 0 {
					diskModel.DiskInfos[i].EventMsg = "Configuration changed: " + strings.Join(changes, "; ")
				} else {
					diskModel.DiskInfos[i].EventMsg = "Disk configuration changed (details unknown)"
				}
			}
		} else {
			diskModel.DiskInfos[i].Event = EventAdded
			diskModel.DiskInfos[i].EventMsg = fmt.Sprintf("New disk detected: %s (%s, %s)",
				diskModel.DiskInfos[i].Device, diskModel.DiskInfos[i].ModelName, diskModel.DiskInfos[i].Size)
		}
	}

	// Detect removed disks
	for oldID, oldDisk := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "Disk",
				ID:      oldID,
				Name:    oldDisk.Device,
				Message: fmt.Sprintf("Disk removed: %s (%s, %s)", oldDisk.Device, oldDisk.ModelName, oldDisk.Size),
				Data: map[string]interface{}{
					"device":       oldDisk.Device,
					"model_name":   oldDisk.ModelName,
					"size":         oldDisk.Size,
					"sn":           oldDisk.SN,
					"manufacturer": oldDisk.Manufacturer,
					"mount_point":  oldDisk.MountPoint,
				},
			})
		}
	}
}

func (c *Comparator) compareMemory(memModel *model.MemoryModel) {
	oldMap := make(map[string]MemoryModuleSnapshot)
	for _, mem := range c.oldSnapshot.Memory {
		oldMap[mem.ID] = mem
	}

	newMap := make(map[string]MemoryModuleSnapshot)
	for _, mem := range c.newSnapshot.Memory {
		newMap[mem.ID] = mem
	}

	for i := range memModel.MemoryModule {
		memID := memModel.MemoryModule[i].SN
		if memID == "" {
			memID = memModel.MemoryModule[i].Slot + "_" + memModel.MemoryModule[i].ModelName
		}

		newMem := newMap[memID]

		if oldMem, exists := oldMap[memID]; exists {
			if oldMem.Slot != newMem.Slot {
				memModel.MemoryModule[i].Event = EventMoved
				memModel.MemoryModule[i].EventMsg = fmt.Sprintf("Slot position changed: %s -> %s", oldMem.Slot, newMem.Slot)
			} else if oldMem.Size != newMem.Size || oldMem.ModelName != newMem.ModelName || oldMem.Manufacturer != newMem.Manufacturer {
				memModel.MemoryModule[i].Event = EventChanged
				changes := []string{}
				if oldMem.Size != newMem.Size {
					changes = append(changes, fmt.Sprintf("Size: %s -> %s", oldMem.Size, newMem.Size))
				}
				if oldMem.ModelName != newMem.ModelName {
					changes = append(changes, fmt.Sprintf("Model: %s -> %s", oldMem.ModelName, newMem.ModelName))
				}
				if oldMem.Manufacturer != newMem.Manufacturer {
					changes = append(changes, fmt.Sprintf("Manufacturer: %s -> %s", oldMem.Manufacturer, newMem.Manufacturer))
				}
				if len(changes) > 0 {
					memModel.MemoryModule[i].EventMsg = "Configuration changed: " + strings.Join(changes, "; ")
				} else {
					memModel.MemoryModule[i].EventMsg = "Memory configuration changed (details unknown)"
				}
			}
		} else {
			memModel.MemoryModule[i].Event = EventAdded
			memModel.MemoryModule[i].EventMsg = fmt.Sprintf("New memory module detected: %s (%s, %s)",
				memModel.MemoryModule[i].Slot, memModel.MemoryModule[i].ModelName, memModel.MemoryModule[i].Size)
		}
	}

	// Detect removed memory modules
	for oldID, oldMem := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "Memory",
				ID:      oldID,
				Name:    oldMem.Slot,
				Message: fmt.Sprintf("Memory module removed: %s (%s, %s)", oldMem.Slot, oldMem.ModelName, oldMem.Size),
				Data: map[string]interface{}{
					"slot":         oldMem.Slot,
					"model_name":   oldMem.ModelName,
					"size":         oldMem.Size,
					"sn":           oldMem.SN,
					"manufacturer": oldMem.Manufacturer,
				},
			})
		}
	}
}

func (c *Comparator) compareNic(nicModel *model.NicModel) {
	oldMap := make(map[string]NicSnapshot)
	for _, nic := range c.oldSnapshot.Nic {
		oldMap[nic.ID] = nic
	}

	newMap := make(map[string]NicSnapshot)
	for _, nic := range c.newSnapshot.Nic {
		newMap[nic.ID] = nic
	}

	for i := range nicModel.NicInfos {
		nicID := nicModel.NicInfos[i].MacAddress
		if nicID == "" {
			nicID = nicModel.NicInfos[i].Name
		}

		newNic := newMap[nicID]

		if oldNic, exists := oldMap[nicID]; exists {
			if oldNic.Name != newNic.Name {
				nicModel.NicInfos[i].Event = EventMoved
				nicModel.NicInfos[i].EventMsg = fmt.Sprintf("Interface name changed: %s -> %s (MAC: %s)", oldNic.Name, newNic.Name, newNic.MacAddress)
			} else if oldNic.Vendor != newNic.Vendor || oldNic.Model != newNic.Model || oldNic.Type != newNic.Type {
				nicModel.NicInfos[i].Event = EventChanged
				changes := []string{}
				if oldNic.Vendor != newNic.Vendor {
					changes = append(changes, fmt.Sprintf("Vendor: %s -> %s", oldNic.Vendor, newNic.Vendor))
				}
				if oldNic.Model != newNic.Model {
					changes = append(changes, fmt.Sprintf("Model: %s -> %s", oldNic.Model, newNic.Model))
				}
				if oldNic.Type != newNic.Type {
					changes = append(changes, fmt.Sprintf("Type: %s -> %s", oldNic.Type, newNic.Type))
				}
				if len(changes) > 0 {
					nicModel.NicInfos[i].EventMsg = "Configuration changed: " + strings.Join(changes, "; ")
				} else {
					nicModel.NicInfos[i].EventMsg = "NIC configuration changed (details unknown)"
				}
			}
		} else {
			nicModel.NicInfos[i].Event = EventAdded
			nicModel.NicInfos[i].EventMsg = fmt.Sprintf("New NIC detected: %s (%s, MAC: %s)",
				nicModel.NicInfos[i].Name, nicModel.NicInfos[i].Vendor, nicModel.NicInfos[i].MacAddress)
		}
	}

	// Detect removed NICs
	for oldID, oldNic := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "NIC",
				ID:      oldID,
				Name:    oldNic.Name,
				Message: fmt.Sprintf("NIC removed: %s (%s, MAC: %s)", oldNic.Name, oldNic.Vendor, oldNic.MacAddress),
				Data: map[string]interface{}{
					"name":        oldNic.Name,
					"vendor":      oldNic.Vendor,
					"model":       oldNic.Model,
					"mac_address": oldNic.MacAddress,
					"type":        oldNic.Type,
				},
			})
		}
	}
}

func (c *Comparator) compareFan(fanModel *model.FanModel) {
	oldMap := make(map[string]FanSnapshot)
	for _, fan := range c.oldSnapshot.Fan {
		oldMap[fan.ID] = fan
	}

	newMap := make(map[string]FanSnapshot)
	for _, fan := range c.newSnapshot.Fan {
		newMap[fan.ID] = fan
	}

	for i := range fanModel.FanInfos {
		fanID := fmt.Sprintf("fan_%d", i)
		newFan := newMap[fanID]

		if oldFan, exists := oldMap[fanID]; exists {
			if oldFan.Name != newFan.Name {
				fanModel.FanInfos[i].Event = EventChanged
				fanModel.FanInfos[i].EventMsg = fmt.Sprintf("Fan name changed: %s -> %s", oldFan.Name, newFan.Name)
			}
		} else {
			fanModel.FanInfos[i].Event = EventAdded
			fanModel.FanInfos[i].EventMsg = fmt.Sprintf("New fan detected: %s", fanModel.FanInfos[i].Name)
		}
	}

	// Detect removed fans
	for oldID, oldFan := range oldMap {
		if _, exists := newMap[oldID]; !exists {
			c.removedDevices = append(c.removedDevices, RemovedDevice{
				Type:    "Fan",
				ID:      oldID,
				Name:    oldFan.Name,
				Message: fmt.Sprintf("Fan removed: %s", oldFan.Name),
				Data: map[string]interface{}{
					"name": oldFan.Name,
				},
			})
		}
	}
}
