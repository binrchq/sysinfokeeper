package packages

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"binrc.com/sysinfokeeper/core/model"
)

type Disk struct {
	speedTestMode string
}

type SpeedTestMode string

const (
	SpeedTestNone SpeedTestMode = "none"
	SpeedTestLow  SpeedTestMode = "low"
	SpeedTestHigh SpeedTestMode = "high"
)

func NewDisk() *Disk {
	return &Disk{
		speedTestMode: string(SpeedTestLow),
	}
}

func (d *Disk) SetSpeedTestMode(mode string) {
	d.speedTestMode = mode
}

func (d *Disk) Get() (diskModel *model.DiskModel, err error) {
	diskModel = model.NewDiskModel()
	err = populateDiskInfo(diskModel, d.speedTestMode)
	if err != nil {
		return nil, err
	}
	return diskModel, nil
}

func populateDiskInfo(dm *model.DiskModel, speedTestMode string) error {
	err := gatherLsblkInfo(dm)
	if err != nil {
		return err
	}

	err = gatherDDInfo(dm, speedTestMode)
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
	if supportsLsblkJson() {
		return gatherFromLsblkJSON(dm)
	}
	return gatherFromLsblkText(dm)
}

func supportsLsblkJson() bool {
	out, err := exec.Command("lsblk", "--help").CombinedOutput()
	if err != nil {
		return false
	}
	return strings.Contains(string(out), "-J")
}

// gatherLsblkInfo 函数用于获取磁盘信息
func gatherFromLsblkJSON(dm *model.DiskModel) error {
	lsblkCmd := exec.Command("lsblk", "-J", "-o", "NAME,TYPE,SIZE,FSUSED,MOUNTPOINT,MODEL,SERIAL,VENDOR,REV,ROTA")
	lsblkOutput, err := lsblkCmd.Output()
	if err != nil {
		return fmt.Errorf("failed to run lsblk -J: %v", err)
	}

	var lsblkData struct {
		BlockDevices []BlockDevice `json:"blockdevices"`
	}

	err = json.Unmarshal(lsblkOutput, &lsblkData)
	if err != nil {
		return fmt.Errorf("failed to parse lsblk output: %v", err)
	}

	for _, device := range lsblkData.BlockDevices {
		// Only process real disks, skip loop devices and other virtual devices
		if device.Type == "disk" && isValidDisk(device.Name) {
			if size, err := parseSize(device.Size); err != nil || size == 0 {
				continue
			}
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
func gatherFromLsblkText(dm *model.DiskModel) error {
	fields := "NAME,TYPE,SIZE,MOUNTPOINT,MODEL,SERIAL,VENDOR,REV,ROTA"
	cmd := exec.Command("lsblk", "-o", fields)
	output, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to run lsblk -o: %v", err)
	}

	lines := strings.Split(string(output), "\n")
	if len(lines) < 2 {
		return fmt.Errorf("unexpected lsblk output")
	}
	// 获取字段位置索引
	header := parseColumns(lines[0])
	for _, line := range lines[1:] {
		cols := parseColumns(line)
		if len(cols) < len(header) {
			continue
		}

		device := mapColumnsToValues(header, cols)
		if device["TYPE"] != "disk" || !isValidDisk(device["NAME"]) {
			continue
		}

		if size, err := parseSize(device["SIZE"]); err != nil || size == 0 {
			continue
		}
		rota := device["ROTA"] == "1"

		disk := BlockDevice{
			Name:       device["NAME"],
			Type:       device["TYPE"],
			Size:       device["SIZE"],
			MountPoint: device["MOUNTPOINT"],
			Model:      device["MODEL"],
			Serial:     device["SERIAL"],
			Vendor:     device["VENDOR"],
			Rev:        device["REV"],
			Rota:       rota,
		}
		diskInfo := parseBlockDevice(disk)
		dm.DiskInfos = append(dm.DiskInfos, diskInfo)

	}

	// 总量计算
	var totalSize, usedSize float64
	for _, disk := range dm.DiskInfos {
		if disk.Size != "" {
			if size, err := parseSize(disk.Size); err == nil {
				totalSize += size
			}
		}
		if disk.Usage != "" {
			usedSize += parseUsage(disk.Usage)
		}
	}
	dm.Total = formatSize(totalSize)
	dm.Used = formatSize(usedSize)
	dm.Available = formatSize(totalSize - usedSize)

	return nil
}
func parseColumns(line string) []string {
	return strings.Fields(line)
}

func mapColumnsToValues(headers, values []string) map[string]string {
	result := make(map[string]string)
	for i := 0; i < len(headers) && i < len(values); i++ {
		result[headers[i]] = values[i]
	}
	return result
}

var ignorePrefixes = []string{
	"loop", "ram", "nbd", "dm-", "fd", "sr", "zd", "rbd", "md",
}

func hasIgnorePrefix(dev string) bool {
	for _, prefix := range ignorePrefixes {
		if strings.HasPrefix(dev, prefix) {
			return true
		}
	}
	return false
}
func hasDeviceEntry(dev string) bool {
	_, err := os.Stat("/sys/block/" + dev + "/device")
	return err == nil
}
func isValidDisk(dev string) bool {
	if hasIgnorePrefix(dev) {
		return false
	}
	if !hasDeviceEntry(dev) {
		return false
	}
	return true
}

func parseBlockDevice(device BlockDevice) model.DiskInfo {
	mountPoints := gatherMountPoints(device)
	sysSymbol := "no"
	for _, mp := range mountPoints {
		if mp == "/" || strings.Contains(mp, "/boot") {
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
			// smartctl 可能因为权限问题或设备不支持而失败，继续处理其他磁盘
			// 设置默认值，不中断整个流程
			dm.DiskInfos[i].Health = "unknown"
			dm.DiskInfos[i].BadBlocks = 0
			continue
		}

		lines := strings.Split(string(smartctlOutput), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Model Family:") {
				fields := strings.FieldsFunc(line, func(r rune) bool {
					return r == ':'
				})
				if len(fields) > 1 {
					dm.DiskInfos[i].Manufacturer = strings.TrimSpace(fields[len(fields)-1])
				}
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
			// If udevadm fails, try to determine type from other sources
			dm.DiskInfos[i].Type = determineDiskTypeFromModel(disk.ModelName, disk.Device)
			continue
		}

		udevadmInfo := string(udevadmOutput)

		// Check for NVMe first
		if strings.Contains(disk.Device, "nvme") || strings.Contains(udevadmInfo, "ID_BUS=nvme") {
			dm.DiskInfos[i].Type = "nvme"
		} else if strings.Contains(udevadmInfo, "ID_BUS=scsi") && strings.Contains(udevadmInfo, "ID_SCSI_TYPE=disk") {
			// Check rotation rate for SAS disks
			if strings.Contains(udevadmInfo, "ID_ATA_ROTATION_RATE_RPM=0") {
				dm.DiskInfos[i].Type = "ssd"
			} else {
				dm.DiskInfos[i].Type = "sas"
			}
		} else if strings.Contains(udevadmInfo, "ID_ATA_ROTATION_RATE_RPM=0") {
			dm.DiskInfos[i].Type = "ssd"
		} else if strings.Contains(udevadmInfo, "ID_ATA_ROTATION_RATE_RPM") {
			// Has rotation rate, it's an HDD
			dm.DiskInfos[i].Type = "hdd"
		} else {
			// Fallback: try to determine from model name
			dm.DiskInfos[i].Type = determineDiskTypeFromModel(disk.ModelName, disk.Device)
		}
	}

	return nil
}

// determineDiskTypeFromModel tries to determine disk type from model name
func determineDiskTypeFromModel(modelName, device string) string {
	modelLower := strings.ToLower(modelName)
	deviceLower := strings.ToLower(device)

	// Check for NVMe
	if strings.Contains(deviceLower, "nvme") {
		return "nvme"
	}

	// Check for SSD indicators in model name
	ssdIndicators := []string{"ssd", "m.2", "nvme", "solid state", "flash", "micron", "samsung", "crucial"}
	for _, indicator := range ssdIndicators {
		if strings.Contains(modelLower, indicator) {
			return "ssd"
		}
	}

	// Check for HDD indicators
	hddIndicators := []string{"hdd", "hard disk", "wd", "seagate", "toshiba", "hitachi"}
	for _, indicator := range hddIndicators {
		if strings.Contains(modelLower, indicator) {
			return "hdd"
		}
	}

	// Default to hdd if uncertain
	return "hdd"
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

func gatherDDInfo(dm *model.DiskModel, speedTestMode string) error {
	if speedTestMode == string(SpeedTestNone) {
		for i := range dm.DiskInfos {
			dm.DiskInfos[i].ReadSpeed = "N/A"
			dm.DiskInfos[i].WriteSpeed = "N/A"
		}
		return nil
	}

	var blockSize string
	var count int

	switch speedTestMode {
	case string(SpeedTestHigh):
		blockSize = "1M"
		count = 1024
	case string(SpeedTestLow):
		fallthrough
	default:
		blockSize = "512K"
		count = 20
	}

	for i := range dm.DiskInfos {
		disk := &dm.DiskInfos[i]

		if len(disk.MountPoint) == 0 {
			disk.ReadSpeed = "N/A"
			disk.WriteSpeed = "N/A"
			continue
		}

		testMountPoint := findValidTestMountPoint(disk.MountPoint)
		if testMountPoint == "" {
			disk.ReadSpeed = "N/A"
			disk.WriteSpeed = "N/A"
			continue
		}

		testDir := fmt.Sprintf("%s/sinfo-tmp", testMountPoint)
		if err := os.MkdirAll(testDir, 0755); err != nil {
			disk.ReadSpeed = "N/A"
			disk.WriteSpeed = "N/A"
			continue
		}

		testFile := fmt.Sprintf("%s/.sinfo_dd.test-%s", testDir, disk.Device)

		writeSpeed, readSpeed, err := DiskSpeedTest(testFile, blockSize, count)
		if err != nil {
			disk.ReadSpeed = "N/A"
			disk.WriteSpeed = "N/A"
			_ = os.RemoveAll(testDir)
			continue
		}

		disk.ReadSpeed = readSpeed
		disk.WriteSpeed = writeSpeed

		_ = os.RemoveAll(testDir)
	}
	return nil
}

func findValidTestMountPoint(mountPoints []string) string {
	for _, mp := range mountPoints {
		if mp == "" {
			continue
		}
		if isTmpfs(mp) {
			continue
		}
		if info, err := os.Stat(mp); err == nil && info.IsDir() {
			return mp
		}
	}
	return ""
}

func isTmpfs(mountPoint string) bool {
	cmd := exec.Command("findmnt", "-n", "-o", "FSTYPE", mountPoint)
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	fsType := strings.TrimSpace(string(output))
	return fsType == "tmpfs" || fsType == "devtmpfs"
}

func DiskSpeedTest(filePath, blockSize string, count int) (writeSpeed, readSpeed string, err error) {
	writeCmd := exec.Command("dd", "if=/dev/zero", fmt.Sprintf("of=%s", filePath),
		fmt.Sprintf("bs=%s", blockSize), fmt.Sprintf("count=%d", count),
		"oflag=direct", "status=progress")
	writeOutput, err := writeCmd.CombinedOutput()
	if err != nil {
		return "", "", fmt.Errorf("write test failed: %w\nOutput: %s", err, writeOutput)
	}
	writeSpeed = parseDDOutput(string(writeOutput))

	readCmd := exec.Command("dd", fmt.Sprintf("if=%s", filePath), "of=/dev/null",
		fmt.Sprintf("bs=%s", blockSize), fmt.Sprintf("count=%d", count),
		"iflag=direct", "status=progress")
	readOutput, err := readCmd.CombinedOutput()
	if err != nil {
		return "", "", fmt.Errorf("read test failed: %w\nOutput: %s", err, readOutput)
	}
	readSpeed = parseDDOutput(string(readOutput))

	return writeSpeed, readSpeed, nil
}

// parseDDOutput 提取 dd 输出中的速度信息
func parseDDOutput(output string) string {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(line, "MB/s") || strings.Contains(line, "MiB/s") ||
			strings.Contains(line, "kB/s") || strings.Contains(line, "KiB/s") ||
			strings.Contains(line, "GB/s") || strings.Contains(line, "GiB/s") {
			fields := strings.Fields(line)
			if len(fields) > 1 {
				return fields[len(fields)-2] + " " + fields[len(fields)-1]
			}
		}
	}
	return "unknown"
}
