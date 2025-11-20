package hardware

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"binrc.com/sysinfokeeper/core/model"
)

const (
	SnapshotDir  = "/var/lib/sysinfokeeper"
	SnapshotFile = "hardware_snapshot.json"
)

type HardwareSnapshot struct {
	Timestamp time.Time              `json:"timestamp"`
	CPU       []CpuSnapshot          `json:"cpu"`
	GPU       []GpuSnapshot          `json:"gpu"`
	Disk      []DiskSnapshot         `json:"disk"`
	Memory    []MemoryModuleSnapshot `json:"memory"`
	Nic       []NicSnapshot          `json:"nic"`
	Fan       []FanSnapshot          `json:"fan"`
}

type CpuSnapshot struct {
	ID         string  `json:"id"`
	ModelName  string  `json:"model_name"`
	Cores      int     `json:"cores"`
	MaxSpeed   float64 `json:"max_speed"`
	MinSpeed   float64 `json:"min_speed"`
	PhysicalID string  `json:"physical_id"`
}

type GpuSnapshot struct {
	ID        string `json:"id"`
	ModelName string `json:"model_name"`
	Memory    string `json:"memory"`
	Type      string `json:"type"`
}

type DiskSnapshot struct {
	ID           string   `json:"id"`
	Device       string   `json:"device"`
	SN           string   `json:"sn"`
	ModelName    string   `json:"model_name"`
	Size         string   `json:"size"`
	Manufacturer string   `json:"manufacturer"`
	MountPoint   []string `json:"mount_point"`
}

type MemoryModuleSnapshot struct {
	ID           string `json:"id"`
	Slot         string `json:"slot"`
	SN           string `json:"sn"`
	ModelName    string `json:"model_name"`
	Size         string `json:"size"`
	Manufacturer string `json:"manufacturer"`
}

type NicSnapshot struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	MacAddress string `json:"mac_address"`
	Type       string `json:"type"`
	Vendor     string `json:"vendor"`
	Model      string `json:"model"`
}

type FanSnapshot struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type SnapshotManager struct {
	snapshotPath string
}

func NewSnapshotManager() *SnapshotManager {
	return &SnapshotManager{
		snapshotPath: filepath.Join(SnapshotDir, SnapshotFile),
	}
}

func (sm *SnapshotManager) EnsureDir() error {
	return os.MkdirAll(SnapshotDir, 0755)
}

func (sm *SnapshotManager) Save(snapshot *HardwareSnapshot) error {
	if err := sm.EnsureDir(); err != nil {
		return fmt.Errorf("failed to create snapshot directory: %w", err)
	}

	snapshot.Timestamp = time.Now()
	data, err := json.MarshalIndent(snapshot, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal snapshot: %w", err)
	}

	if err := os.WriteFile(sm.snapshotPath, data, 0644); err != nil {
		return fmt.Errorf("failed to write snapshot file: %w", err)
	}

	return nil
}

func (sm *SnapshotManager) Load() (*HardwareSnapshot, error) {
	data, err := os.ReadFile(sm.snapshotPath)
	if err != nil {
		if os.IsNotExist(err) {
			return &HardwareSnapshot{
				Timestamp: time.Now(),
				CPU:       []CpuSnapshot{},
				GPU:       []GpuSnapshot{},
				Disk:      []DiskSnapshot{},
				Memory:    []MemoryModuleSnapshot{},
				Nic:       []NicSnapshot{},
				Fan:       []FanSnapshot{},
			}, nil
		}
		return nil, fmt.Errorf("failed to read snapshot file: %w", err)
	}

	var snapshot HardwareSnapshot
	if err := json.Unmarshal(data, &snapshot); err != nil {
		return nil, fmt.Errorf("failed to unmarshal snapshot: %w", err)
	}

	return &snapshot, nil
}

func (sm *SnapshotManager) CreateFromCurrent(allInfo *model.SInfo) *HardwareSnapshot {
	snapshot := &HardwareSnapshot{
		Timestamp: time.Now(),
		CPU:       make([]CpuSnapshot, 0),
		GPU:       make([]GpuSnapshot, 0),
		Disk:      make([]DiskSnapshot, 0),
		Memory:    make([]MemoryModuleSnapshot, 0),
		Nic:       make([]NicSnapshot, 0),
		Fan:       make([]FanSnapshot, 0),
	}

	for i, cpu := range allInfo.Cpu.CpuInfos {
		snapshot.CPU = append(snapshot.CPU, CpuSnapshot{
			ID:         fmt.Sprintf("cpu_%d", i),
			ModelName:  cpu.ModelName,
			Cores:      cpu.Cores,
			MaxSpeed:   cpu.MaxSpeed,
			MinSpeed:   cpu.MinSpeed,
			PhysicalID: fmt.Sprintf("%d", i),
		})
	}

	for i, gpu := range allInfo.Gpu.GpuInfos {
		snapshot.GPU = append(snapshot.GPU, GpuSnapshot{
			ID:        fmt.Sprintf("gpu_%d", i),
			ModelName: gpu.ModelName,
			Memory:    gpu.Memory,
			Type:      gpu.Type,
		})
	}

	for _, disk := range allInfo.Disk.DiskInfos {
		id := disk.SN
		if id == "" {
			id = disk.Device
		}
		snapshot.Disk = append(snapshot.Disk, DiskSnapshot{
			ID:           id,
			Device:       disk.Device,
			SN:           disk.SN,
			ModelName:    disk.ModelName,
			Size:         disk.Size,
			Manufacturer: disk.Manufacturer,
			MountPoint:   disk.MountPoint,
		})
	}

	for _, mem := range allInfo.Memory.MemoryModule {
		id := mem.SN
		if id == "" {
			id = mem.Slot + "_" + mem.ModelName
		}
		snapshot.Memory = append(snapshot.Memory, MemoryModuleSnapshot{
			ID:           id,
			Slot:         mem.Slot,
			SN:           mem.SN,
			ModelName:    mem.ModelName,
			Size:         mem.Size,
			Manufacturer: mem.Manufacturer,
		})
	}

	for _, nic := range allInfo.Nic.NicInfos {
		id := nic.MacAddress
		if id == "" {
			id = nic.Name
		}
		snapshot.Nic = append(snapshot.Nic, NicSnapshot{
			ID:         id,
			Name:       nic.Name,
			MacAddress: nic.MacAddress,
			Type:       nic.Type,
			Vendor:     nic.Vendor,
			Model:      nic.Model,
		})
	}

	for i, fan := range allInfo.Fan.FanInfos {
		snapshot.Fan = append(snapshot.Fan, FanSnapshot{
			ID:   fmt.Sprintf("fan_%d", i),
			Name: fan.Name,
		})
	}

	return snapshot
}
