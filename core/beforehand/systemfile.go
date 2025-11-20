package beforehand

import (
	"os"
	"strings"

	"binrc.com/sysinfokeeper/core/omni"
)

var (
	OMNISystemFiles = map[string]string{}
)

func SetSystemFiles() {
	systemFiles := map[string]string{
		"asound-cards":       "/proc/asound/cards",
		"asound-modules":     "/proc/asound/modules",
		"asound-version":     "/proc/asound/version",
		"dmesg-boot":         "/var/run/dmesg.boot",
		"proc-cmdline":       "/proc/cmdline",
		"proc-cpuinfo":       "/proc/cpuinfo",
		"device-cpufreq0max": "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_max_freq",
		"device-cpufreq0min": "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_min_freq",
		"proc-mdstat":        "/proc/mdstat",
		"proc-meminfo":       "/proc/meminfo",
		"proc-modules":       "/proc/modules", // not used
		"proc-mounts":        "/proc/mounts",  // not used
		"proc-partitions":    "/proc/partitions",
		"proc-scsi":          "/proc/scsi/scsi",
		"proc-version":       "/proc/version",
		// note: 'xorg-log' is set in set_xorg_log() only if -G is triggered
	}

	for key, value := range systemFiles {
		_, err := os.Stat(value)
		if err == nil || strings.Contains(value, "%s") {
			OMNISystemFiles[key] = value
		} else {
			OMNISystemFiles[key] = "" // 或者你可以选择忽略不存在的文件
		}
	}

	omni.SystemFiles = OMNISystemFiles
}
