package packages

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type Unmounted struct{}

func NewUnmounted() *Unmounted {
	return &Unmounted{}
}

type UnmountedInfo struct {
	Device     string `json:"device"`     // 设备名
	Path       string `json:"path"`       // 设备路径
	Size       string `json:"size"`       // 大小
	Type       string `json:"type"`       // 类型 (disk/part)
	Filesystem string `json:"filesystem"` // 文件系统类型
	UUID       string `json:"uuid"`       // UUID
	Label      string `json:"label"`      // 标签
	PartLabel  string `json:"partlabel"`  // 分区标签
	PartUUID   string `json:"partuuid"`   // 分区UUID
	Model      string `json:"model"`      // 型号
	Serial     string `json:"serial"`     // 序列号
	Vendor     string `json:"vendor"`     // 制造商
}

type UnmountedModel struct {
	UnmountedInfos []UnmountedInfo `json:"unmounted_infos"`
	Msg            string          `json:"msg"`
}

func NewUnmountedModel() *UnmountedModel {
	return &UnmountedModel{}
}

func (u *Unmounted) Get() (*UnmountedModel, error) {
	model := NewUnmountedModel()

	unmounted, err := u.gatherUnmountedInfo()
	if err != nil {
		model.Msg = err.Error()
		return model, err
	}

	model.UnmountedInfos = unmounted
	return model, nil
}

func (u *Unmounted) gatherUnmountedInfo() ([]UnmountedInfo, error) {
	if supportsLsblkJson() {
		return u.gatherFromLsblkJSON()
	}
	return u.gatherFromLsblkText()
}

func (u *Unmounted) gatherFromLsblkJSON() ([]UnmountedInfo, error) {
	cmd := exec.Command("lsblk", "-J", "-o", "NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,UUID,LABEL,PARTLABEL,PARTUUID,MODEL,SERIAL,VENDOR")
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

	var unmounted []UnmountedInfo
	u.extractUnmounted(lsblkData.BlockDevices, &unmounted)

	return unmounted, nil
}

func (u *Unmounted) gatherFromLsblkText() ([]UnmountedInfo, error) {
	cmd := exec.Command("lsblk", "-o", "NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE,UUID,LABEL,PARTLABEL,PARTUUID,MODEL,SERIAL,VENDOR")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run lsblk: %w", err)
	}

	lines := strings.Split(string(output), "\n")
	if len(lines) < 2 {
		return nil, fmt.Errorf("unexpected lsblk output")
	}

	header := strings.Fields(lines[0])
	var unmounted []UnmountedInfo

	for _, line := range lines[1:] {
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

		// 检查是否未挂载
		mountPoint := device["MOUNTPOINT"]
		if mountPoint == "" {
			deviceType := device["TYPE"]
			deviceName := device["NAME"]

			// 跳过虚拟设备
			if hasIgnorePrefix(deviceName) {
				continue
			}

			// 只收集磁盘和分区
			if deviceType == "disk" || deviceType == "part" {
				unmountedInfo := UnmountedInfo{
					Device:     deviceName,
					Path:       "/dev/" + deviceName,
					Size:       device["SIZE"],
					Type:       deviceType,
					Filesystem: device["FSTYPE"],
					UUID:       device["UUID"],
					Label:      device["LABEL"],
					PartLabel:  device["PARTLABEL"],
					PartUUID:   device["PARTUUID"],
					Model:      device["MODEL"],
					Serial:     device["SERIAL"],
					Vendor:     device["VENDOR"],
				}
				unmounted = append(unmounted, unmountedInfo)
			}
		}
	}

	return unmounted, nil
}

func (u *Unmounted) extractUnmounted(devices []BlockDevice, result *[]UnmountedInfo) {
	for _, device := range devices {
		// 检查是否未挂载
		if device.MountPoint == "" {
			// 跳过虚拟设备
			if hasIgnorePrefix(device.Name) {
				continue
			}

			// 只收集磁盘和分区
			if device.Type == "disk" || device.Type == "part" {
				unmountedInfo := UnmountedInfo{
					Device: device.Name,
					Path:   "/dev/" + device.Name,
					Size:   device.Size,
					Type:   device.Type,
					Model:  device.Model,
					Serial: device.Serial,
					Vendor: device.Vendor,
				}
				*result = append(*result, unmountedInfo)
			}
		}

		// 递归处理子设备
		if len(device.Children) > 0 {
			u.extractUnmounted(device.Children, result)
		}
	}
}
