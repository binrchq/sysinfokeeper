package packages

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"bitrec.ai/systemkeeper/core/model"
)

type Disk struct{}

func NewDisk() *Disk {
	return &Disk{}
}

func (d *Disk) Get() (diskModel *model.DiskModel, err error) {
	diskModel = model.NewDiskModel()
	err = populateDiskInfo(diskModel)
	if err != nil {
		return nil, err
	}
	return diskModel, nil
}

func populateDiskInfo(dm *model.DiskModel) error {
	err := gatherLsblkInfo(dm)
	if err != nil {
		return err
	}

	err = gatherDDInfo(dm)
	if err != nil {
		return err
	}

	err = gatherUdevadmInfo(dm)
	if err != nil {
		return err
	}

	err = gatherSmartctlInfo(dm)
	if err != nil {
		return err
	}

	return nil
}

type BlockDevice struct {
	Name       string        `json:"name"`
	Type       string        `json:"type"`
	Size       string        `json:"size"`
	FSUsed     string        `json:"fsused"`
	MountPoint string        `json:"mountpoint"`
	Model      string        `json:"model"`
	Serial     string        `json:"serial"`
	Vendor     string        `json:"vendor"`
	Rev        string        `json:"rev"`
	Rota       bool          `json:"rota"`
	Children   []BlockDevice `json:"children"`
}

func gatherLsblkInfo(dm *model.DiskModel) error {
	lsblkCmd := exec.Command("lsblk", "-J", "-o", "NAME,TYPE,SIZE,FSUSED,MOUNTPOINT,MODEL,SERIAL,VENDOR,REV,ROTA")
	lsblkOutput, err := lsblkCmd.Output()
	if err != nil {
		return err
	}

	var lsblkData struct {
		BlockDevices []BlockDevice `json:"blockdevices"`
	}

	err = json.Unmarshal(lsblkOutput, &lsblkData)
	if err != nil {
		return err
	}

	for _, device := range lsblkData.BlockDevices {
		if device.Type == "disk" {
			diskInfo := parseBlockDevice(device)
			dm.DiskInfos = append(dm.DiskInfos, diskInfo)
		}
	}

	// 计算总使用量和总空间
	totalSize := float64(0)
	usedSize := float64(0)
	// availableSize := float64(0)

	for _, disk := range dm.DiskInfos {
		if disk.Size != "" {
			size, err := parseSize(disk.Size)
			if err == nil {
				totalSize += size
			}
		}
		if disk.Usage != "" {
			used := parseUsage(disk.Usage)
			usedSize += used
			// availableSize += avail
		}
	}

	dm.Total = formatSize(totalSize)
	dm.Used = formatSize(usedSize)
	dm.Available = formatSize(totalSize - usedSize)

	return nil
}

func parseBlockDevice(device BlockDevice) model.DiskInfo {
	mountPoints := gatherMountPoints(device)
	sysSymbol := "no"
	for _, mp := range mountPoints {
		if strings.Contains(mp, "/boot") || strings.Contains(mp, "/") {
			sysSymbol = "yes"
			break
		}
	}

	usage := gatherUsage(device)

	diskInfo := model.DiskInfo{
		Device:       device.Name,
		Size:         device.Size,
		Usage:        usage,
		Slot:         "/dev/" + device.Name,
		SysSymbol:    sysSymbol,
		Manufacturer: device.Vendor,
		ModelName:    device.Model,
		SN:           device.Serial,
		FwVersion:    device.Rev,
		MountPoint:   mountPoints,
	}

	return diskInfo
}

func gatherMountPoints(device BlockDevice) []string {
	var mountPoints []string
	if device.MountPoint != "" {
		mountPoints = append(mountPoints, device.MountPoint)
	}
	for _, child := range device.Children {
		mountPoints = append(mountPoints, gatherMountPoints(child)...)
	}
	return mountPoints
}

func gatherUsage(device BlockDevice) string {
	totalUsed := float64(0)
	// totalAvail := int64(0)

	if device.FSUsed != "" {
		used := parseUsage(device.FSUsed)
		totalUsed += used
	}
	for _, child := range device.Children {
		childUsage := gatherUsage(child)
		if childUsage != "" {
			used := parseUsage(childUsage)
			totalUsed += used
		}
	}

	return formatSize(totalUsed)
}

func parseUsage(usage string) float64 {
	// 假设使用值以逗号分隔
	used, err1 := parseSize(usage)
	if err1 == nil {
		return used
	}
	return 0
}

func parseSize(sizeStr string) (float64, error) {
	unitMultipliers := map[string]float64{
		"B": 1,
		"K": 1024,
		"M": 1024 * 1024,
		"G": 1024 * 1024 * 1024,
		"T": 1024 * 1024 * 1024 * 1024,
		"P": 1024 * 1024 * 1024 * 1024 * 1024,
	}
	var size float64
	var unit string
	_, err := fmt.Sscanf(sizeStr, "%f%s", &size, &unit)
	if err != nil {
		return 0, err
	}
	multiplier, exists := unitMultipliers[unit]
	if !exists {
		return 0, fmt.Errorf("unknown size unit: %s", unit)
	}
	return size * multiplier, nil
}

func formatSize(size float64) string {
	units := []string{"B", "K", "M", "G", "T", "P"}
	unit := 0
	for size >= 1024 && unit < len(units)-1 {
		size /= 1024
		unit++
	}
	return strconv.FormatFloat(size, 'f', 2, 64) + units[unit]
}

func gatherSmartctlInfo(dm *model.DiskModel) error {
	for i, disk := range dm.DiskInfos {
		smartctlCmd := exec.Command("smartctl", "-a", "/dev/"+disk.Device)
		smartctlOutput, err := smartctlCmd.Output()
		if err != nil {
			return err
		}

		lines := strings.Split(string(smartctlOutput), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Model Family:") {
				fields := strings.FieldsFunc(line, func(r rune) bool {
					return r == ':'
				})
				dm.DiskInfos[i].Manufacturer = strings.TrimSpace(fields[len(fields)-1])
			}
		}
		// Parse smartctlOutput to find health status and bad sectors
		healthStatus, badBlocksCount := parseSmartctlOutput(string(smartctlOutput))
		dm.DiskInfos[i].Health = healthStatus
		dm.DiskInfos[i].BadBlocks = badBlocksCount
	}

	return nil
}

func gatherUdevadmInfo(dm *model.DiskModel) error {
	for i, disk := range dm.DiskInfos {
		udevadmCmd := exec.Command("udevadm", "info", "--query=all", "--name=/dev/"+disk.Device)
		udevadmOutput, err := udevadmCmd.Output()
		if err != nil {
			return err
		}

		udevadmInfo := string(udevadmOutput)
		if strings.Contains(udevadmInfo, "ID_BUS=scsi") && strings.Contains(udevadmInfo, "ID_SCSI_TYPE=disk") {
			dm.DiskInfos[i].Type = "sas"
		} else if strings.Contains(udevadmInfo, "ID_ATA_ROTATION_RATE_RPM=0") {
			dm.DiskInfos[i].Type = "ssd"
		} else if strings.Contains(disk.Device, "nvme") {
			dm.DiskInfos[i].Type = "nvme"
		} else {
			dm.DiskInfos[i].Type = "hdd"
		}
	}

	return nil
}

func parseSmartctlOutput(output string) (string, int) {
	lines := strings.Split(output, "\n")
	healthStatus := "unknown"
	badBlocksCount := 0

	for _, line := range lines {
		if strings.Contains(line, "SMART overall-health self-assessment test result:") {
			if strings.Contains(line, "PASSED") {
				healthStatus = "Good"
			} else {
				healthStatus = "Fail"
			}
		}
		if strings.Contains(line, "Reallocated_Sector_Ct") {
			fields := strings.Fields(line)
			if len(fields) > 9 {
				count, err := strconv.Atoi(fields[9])
				if err == nil {
					badBlocksCount = count
				}
			}
		}
	}

	return healthStatus, badBlocksCount
}
func gatherDDInfo(dm *model.DiskModel) error {
	for i := range dm.DiskInfos {
		disk := &dm.DiskInfos[i]
		filePath := fmt.Sprintf("/dev/%s", disk.Device)
		blockSize := "1M"
		count := 300
		duration := 1 * time.Second

		writeSpeed, readSpeed, err := DiskSpeedTest(filePath, blockSize, count, duration)
		if err != nil {
			return err
		}

		disk.ReadSpeed = readSpeed
		disk.WriteSpeed = writeSpeed
	}
	return nil
}

// DiskSpeedTest executes dd commands to test read and write speeds
func DiskSpeedTest(disk string, blockSize string, count int, duration time.Duration) (writeSpeed, readSpeed string, err error) {
	// Measure write speed
	writeCmd := exec.Command("dd", "if=/dev/zero", fmt.Sprintf("of=%s", disk), fmt.Sprintf("bs=%s", blockSize), fmt.Sprintf("count=%d", count), "oflag=direct", "status=progress")
	writeOutput, err := writeCmd.CombinedOutput()
	if err != nil {
		return "", "", fmt.Errorf("failed to execute write test: %w\nOutput: %s", err, writeOutput)
	}
	writeSpeed = parseDDOutput(string(writeOutput))

	// Measure read speed
	readCmd := exec.Command("dd", fmt.Sprintf("if=%s", disk), "of=/dev/null", fmt.Sprintf("bs=%s", blockSize), fmt.Sprintf("count=%d", count), "iflag=direct", "status=progress")
	readOutput, err := readCmd.CombinedOutput()
	if err != nil {
		return "", "", fmt.Errorf("failed to execute read test: %w\nOutput: %s", err, readOutput)
	}
	readSpeed = parseDDOutput(string(readOutput))
	return writeSpeed, readSpeed, nil
}

// parseDDOutput parses the dd command output to extract the speed
func parseDDOutput(output string) string {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(line, "MB/s") || strings.Contains(line, "kB/s") || strings.Contains(line, "GB/s") {
			fields := strings.Fields(line)
			if len(fields) > 1 {
				return fields[len(fields)-2] + " " + fields[len(fields)-1]
			}
		}
	}
	return "unknown"
}
