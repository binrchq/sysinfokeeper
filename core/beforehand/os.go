package beforehand

import (
	sysos "os"
	"strings"
	"syscall"

	"bitrec.ai/systemkeeper/core/utils"
)

var (
	risc = map[string]interface{}{
		"arm":   false,
		"mips":  false,
		"ppc":   false,
		"riscv": false,
		"sparc": false,
		"id":    "",
	}
	windows = map[string]bool{
		"cygwin": false,
		"wsl":    false,
	}
	bitsSys  = 0
	bsdType  = ""
	cpuArch  = ""
	bAndroid = false
)

func SetOS() {
	var uname syscall.Utsname
	if err := syscall.Uname(&uname); err != nil { //这里取代了POSIX的uname
		// 处理获取系统信息失败的情况
	}

	// Convert Sysname and Machine to strings
	os := strings.ToLower(utils.ByteSliceToString(uname.Sysname[:]))
	cpuArch := strings.ToLower(utils.ByteSliceToString(uname.Machine[:]))

	switch {
	case strings.Contains(cpuArch, "arm") || strings.Contains(cpuArch, "aarch"):
		risc["arm"] = true
		risc["id"] = "arm"
	case strings.Contains(cpuArch, "mips"):
		risc["mips"] = true
		risc["id"] = "mips"
	case strings.Contains(cpuArch, "power") || strings.Contains(cpuArch, "ppc"):
		risc["ppc"] = true
		risc["id"] = "ppc"
	case strings.Contains(cpuArch, "riscv"):
		risc["riscv"] = true
		risc["id"] = "riscv"
	case strings.Contains(cpuArch, "sparc") || strings.Contains(cpuArch, "sun4uv"):
		risc["sparc"] = true
		risc["id"] = "sparc"
	}

	if strings.Contains(cpuArch, "armv") || strings.Contains(cpuArch, "32") || strings.Contains(cpuArch, "i386") {
		bitsSys = 32
	} else if strings.Contains(cpuArch, "alpha") || strings.Contains(cpuArch, "64") || strings.Contains(cpuArch, "e2k") || strings.Contains(cpuArch, "sparc_v9") || strings.Contains(cpuArch, "sun4uv") || strings.Contains(cpuArch, "ultrasparc") {
		bitsSys = 64
		if strings.Contains(cpuArch, "e2k") || strings.Contains(cpuArch, "elbrus") {
			cpuArch = "elbrus"
		}
	}

	if strings.Contains(os, "cygwin") {
		windows["cygwin"] = true
	} else if _, err := sysos.Stat("/usr/lib/wsl/drivers"); err == nil {
		windows["wsl"] = true
	} else if _, err := sysos.Stat("/system/build.prop"); err == nil {
		bAndroid = true
	}

	switch {
	case strings.Contains(os, "aix") || strings.Contains(os, "bsd") || strings.Contains(os, "cosix") || strings.Contains(os, "dragonfly") || strings.Contains(os, "darwin") || strings.Contains(os, "hp-ux") || strings.Contains(os, "indiana") || strings.Contains(os, "illumos") || strings.Contains(os, "irix") || strings.Contains(os, "sunos") || strings.Contains(os, "solaris") || strings.Contains(os, "ultrix") || strings.Contains(os, "unix"):
		if strings.Contains(os, "openbsd") {
			os = "openbsd"
		} else if strings.Contains(os, "darwin") {
			os = "darwin"
		}

		if strings.Contains(os, "kfreebsd") {
			bsdType = "debian-bsd"
		} else {
			bsdType = os
		}
	}
}
