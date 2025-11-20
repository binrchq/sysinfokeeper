package packages

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type Partition struct{}

func NewPartition() *Partition {
	return &Partition{}
}

type PartitionInfo struct {
	Device     string   `json:"device"`      // 设备名 (如 sda1)
	Path       string   `json:"path"`        // 设备路径 (如 /dev/sda1)
	Size       string   `json:"size"`        // 大小
	Type       string   `json:"type"`        // 类型 (part/lvm/raid等)
	Filesystem string   `json:"filesystem"`  // 文件系统类型
	MountPoint string   `json:"mountpoint"`  // 挂载点
	UUID       string   `json:"uuid"`        // UUID
	Label      string   `json:"label"`       // 标签
	PartLabel  string   `json:"partlabel"`   // 分区标签
	PartUUID   string   `json:"partuuid"`    // 分区UUID
	Parent     string   `json:"parent"`      // 父设备
}

type PartitionModel struct {
	PartitionInfos []PartitionInfo `json:"partition_infos"`
	Msg            string           `json:"msg"`
}

func NewPartitionModel() *PartitionModel {
	return &PartitionModel{}
}

func (p *Partition) Get() (*PartitionModel, error) {
	model := NewPartitionModel()

	// 使用 lsblk 获取分区信息
	partitions, err := p.gatherPartitionInfo()
	if err != nil {
		model.Msg = err.Error()
		return model, err
	}

	model.PartitionInfos = partitions
	return model, nil
}

func (p *Partition) gatherPartitionInfo() ([]PartitionInfo, error) {
	if supportsLsblkJson() {
		return p.gatherFromLsblkJSON()
	}
	return p.gatherFromLsblkText()
}

func (p *Partition) gatherFromLsblkJSON() ([]PartitionInfo, error) {
	cmd := exec.Command("lsblk", "-J", "-o", "NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,UUID,LABEL,PARTLABEL,PARTUUID")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run lsblk: %w", err)
	}

	var lsblkData struct {
		BlockDevices []BlockDevice `json:"blockdevices"`
	}

	if err := json.Unmarshal(output, &lsblkData); err != nil {
		return nil, fmt.Errorf("failed to parse lsblk output: %w", err)
	}

	var partitions []PartitionInfo
	p.extractPartitions(lsblkData.BlockDevices, "", &partitions)

	return partitions, nil
}

func (p *Partition) gatherFromLsblkText() ([]PartitionInfo, error) {
	cmd := exec.Command("lsblk", "-o", "NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,UUID,LABEL,PARTLABEL,PARTUUID")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run lsblk: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	if len(lines) < 2 {
		return nil, fmt.Errorf("unexpected lsblk output")
	}

	header := strings.Fields(lines[0])
	var partitions []PartitionInfo
	parentMap := make(map[string]string)

	for i, line := range lines[1:] {
		if strings.TrimSpace(line) == "" {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < len(header) {
			continue
		}

		device := map[string]string{}
		for j, field := range fields {
			if j < len(header) {
				device[header[j]] = field
			}
		}

		// 确定父设备
		deviceName := device["NAME"]
		parent := ""
		if i > 0 {
			// 查找最近的父设备
			for prevName, prevType := range parentMap {
				if strings.HasPrefix(deviceName, prevName) && prevType == "disk" {
					parent = prevName
					break
				}
			}
		}

		deviceType := device["TYPE"]
		parentMap[deviceName] = deviceType

		// 只收集分区，跳过磁盘本身
		if deviceType == "part" || deviceType == "lvm" || deviceType == "raid" {
			partInfo := PartitionInfo{
				Device:     deviceName,
				Path:       "/dev/" + deviceName,
				Size:       device["SIZE"],
				Type:       deviceType,
				Filesystem: device["FSTYPE"],
				MountPoint: device["MOUNTPOINT"],
				UUID:       device["UUID"],
				Label:      device["LABEL"],
				PartLabel:  device["PARTLABEL"],
				PartUUID:   device["PARTUUID"],
				Parent:     parent,
			}
			partitions = append(partitions, partInfo)
		}
	}

	return partitions, nil
}

func (p *Partition) extractPartitions(devices []BlockDevice, parent string, result *[]PartitionInfo) {
	for _, device := range devices {
		// 如果是分区类型，添加到结果
		if device.Type == "part" || device.Type == "lvm" || device.Type == "raid" {
			partInfo := PartitionInfo{
				Device:     device.Name,
				Path:       "/dev/" + device.Name,
				Size:       device.Size,
				Type:       device.Type,
				MountPoint: device.MountPoint,
				Parent:     parent,
			}
			*result = append(*result, partInfo)
		}

		// 递归处理子设备
		if len(device.Children) > 0 {
			currentParent := device.Name
			if device.Type == "disk" {
				currentParent = device.Name
			}
			p.extractPartitions(device.Children, currentParent, result)
		}
	}
}

