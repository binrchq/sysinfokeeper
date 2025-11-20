package cli

import (
	"fmt"
	"os"
	"time"

	"binrc.com/pkg/outformat"
	"binrc.com/sysinfokeeper/core/beforehand"
	"binrc.com/sysinfokeeper/core/hardware"
	"binrc.com/sysinfokeeper/core/initialize"
	"binrc.com/sysinfokeeper/core/model"
	"binrc.com/sysinfokeeper/core/packages"

	"github.com/spf13/cobra"
)

var (
	cfgFile    string
	dbPath     string
	showEvents bool
	targets    []string
	level      string
)

func init() {
	if len(os.Args) > 1 && (os.Args[1] == "version" || os.Args[1] == "completion") {
		return
	}

	// 输出格式参数
	rootCmd.PersistentFlags().BoolP("json", "j", false, "Output format json (等同于 --output json)")
	rootCmd.PersistentFlags().
		StringP("output", "o", "graph", "Output format: 'graph', 'table', 'toml', 'json', 'json-line' or 'yaml'")

	// 目标硬件类型参数
	rootCmd.PersistentFlags().StringArrayP("target", "t", []string{},
		"Target hardware types to display. Empty for all. Options: 'cpu', 'gpu', 'memory', 'disk', 'nic', 'fan'")

	// 数据库相关参数
	rootCmd.PersistentFlags().StringVarP(&dbPath, "db", "d", "",
		"Database file path (default: /var/lib/sysinfokeeper/hardware.db)")

	// 硬件变化检测参数（已移除，默认总是启用）

	// 显示事件信息参数
	rootCmd.PersistentFlags().BoolVarP(&showEvents, "events", "e", true,
		"Show hardware change events (default: true)")

	// 显示等级参数
	rootCmd.PersistentFlags().StringVarP(&level, "level", "l", "basic",
		"Display level: 'basic' (default, minimal info), 'advanced' (detailed info), 'full' (all info including flags)")

	// 配置文件参数
	rootCmd.PersistentFlags().StringVarP(&cfgFile, "config", "c", "",
		"Config file path")

	rootCmd.PersistentPreRun = func(cmd *cobra.Command, args []string) {
		jsonFlag, _ := cmd.Flags().GetBool("json")
		if jsonFlag {
			cmd.Flags().Set("output", "json")
		}

		// 获取 targets 参数
		targets, _ = cmd.Flags().GetStringArray("target")
	}
	rootCmd.Flags().SortFlags = false
}

var rootCmd = &cobra.Command{
	Use:   "sinfo",
	Short: "sinfo - a system information tool and keeper",
	Long: `
sinfo - a system information tool and keeper for Linux/Unix systems.
Can view hardware, process, network information, and track hardware changes over time.

https://dl.binrc.com/bin/sinfo`,
	Run: masterCmd,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

// shouldCollect 判断是否应该收集指定类型的硬件信息
func shouldCollect(hwType string) bool {
	if len(targets) == 0 {
		return true // 如果没有指定 targets，收集所有
	}
	for _, t := range targets {
		if t == hwType {
			return true
		}
	}
	return false
}

// filterSInfoByTargets 根据 targets 过滤硬件信息
func filterSInfoByTargets(allInfo *model.SInfo) *model.SInfo {
	filtered := model.NewSInfo()

	if shouldCollect("cpu") {
		filtered.Cpu = allInfo.Cpu
	}
	if shouldCollect("gpu") {
		filtered.Gpu = allInfo.Gpu
	}
	if shouldCollect("memory") {
		filtered.Memory = allInfo.Memory
	}
	if shouldCollect("disk") {
		filtered.Disk = allInfo.Disk
	}
	if shouldCollect("nic") {
		filtered.Nic = allInfo.Nic
	}
	if shouldCollect("fan") {
		filtered.Fan = allInfo.Fan
	}

	return filtered
}

// filterRemovedDevicesByTargets 根据 targets 过滤移除的设备事件
func filterRemovedDevicesByTargets(removedDevices []hardware.RemovedDevice) []hardware.RemovedDevice {
	if len(targets) == 0 {
		return removedDevices // 如果没有指定 targets，显示所有
	}

	filtered := []hardware.RemovedDevice{}
	typeMap := map[string]string{
		"CPU":    "cpu",
		"GPU":    "gpu",
		"Memory": "memory",
		"Disk":   "disk",
		"NIC":    "nic",
		"Fan":    "fan",
	}

	for _, device := range removedDevices {
		hwType := typeMap[device.Type]
		if hwType != "" && shouldCollect(hwType) {
			filtered = append(filtered, device)
		}
	}

	return filtered
}

func masterCmd(cmd *cobra.Command, args []string) {
	output, _ := cmd.Flags().GetString("output")
	beforeRun()

	allInfo := model.NewSInfo()

	// CPU
	if shouldCollect("cpu") {
		if c, err := packages.NewCpu().Get(); err != nil {
			allInfo.Cpu = model.CpuModel{Msg: err.Error()}
		} else {
			allInfo.Cpu = *c
		}
	}

	// RAM
	if shouldCollect("memory") {
		if m, err := packages.NewRam().Get(); err != nil {
			allInfo.Memory = model.MemoryModel{Msg: err.Error()}
		} else {
			allInfo.Memory = *m
		}
	}

	// Disk
	if shouldCollect("disk") {
		if d, err := packages.NewDisk().Get(); err != nil {
			allInfo.Disk = model.DiskModel{Msg: err.Error()}
		} else {
			allInfo.Disk = *d
		}
	}

	// NIC
	if shouldCollect("nic") {
		if n, err := packages.NewNic().Get(); err != nil {
			allInfo.Nic = model.NicModel{Msg: err.Error()}
		} else {
			allInfo.Nic = *n
		}
	}

	// Fan
	if shouldCollect("fan") {
		if f, err := packages.NewSensor().FanGet(); err != nil {
			allInfo.Fan = model.FanModel{Msg: err.Error()}
		} else {
			allInfo.Fan = *f
		}
	}

	// GPU
	if shouldCollect("gpu") {
		if g, err := packages.NewGpu().Get(); err != nil {
			allInfo.Gpu = model.GpuModel{Msg: err.Error()}
		} else {
			allInfo.Gpu = *g
		}
	}

	// 硬件变化检测（默认总是启用）
	// 设置数据库路径（如果指定）
	if dbPath != "" {
		// 这里需要修改 initialize 包以支持自定义路径
		// 暂时先使用默认路径
	}

	db, err := initialize.InitCDB()
	if err == nil {
		storage := hardware.NewDBStorage(db)

		// Initialize tables if not exist
		if err := storage.InitTables(); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Failed to initialize database tables: %v\n", err)
		} else {
			// 获取历史快照进行对比
			oldSnapshot, err := storage.GetLatestSnapshot()
			if err != nil {
				oldSnapshot = &hardware.HardwareSnapshot{
					Timestamp: time.Now(),
				}
			}

			newSnapshot := hardware.NewSnapshotManager().CreateFromCurrent(allInfo)
			comparator := hardware.NewComparator(oldSnapshot, newSnapshot)
			comparator.CompareAndMark(allInfo)

			// Save to database (only save collected hardware info)
			if err := storage.SaveHardwareInfo(allInfo); err != nil {
				fmt.Fprintf(os.Stderr, "Warning: Failed to save hardware info to database: %v\n", err)
			}
		}
	} else {
		fmt.Fprintf(os.Stderr, "Warning: Failed to connect to database, using file snapshot: %v\n", err)
		// Fallback to file snapshot
		sm := hardware.NewSnapshotManager()
		oldSnapshot, err := sm.Load()
		if err != nil {
			oldSnapshot = &hardware.HardwareSnapshot{}
		}

		newSnapshot := sm.CreateFromCurrent(allInfo)
		comparator := hardware.NewComparator(oldSnapshot, newSnapshot)
		comparator.CompareAndMark(allInfo)

		if err := sm.Save(newSnapshot); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Failed to save hardware snapshot: %v\n", err)
		}
	}

	if output == "graph" {
		// 根据 targets 参数决定显示哪些硬件信息
		if shouldCollect("cpu") {
			allInfo.Cpu.RenderCPUInfoWithLevel(level)
		}

		if shouldCollect("memory") {
			allInfo.Memory.RenderMemoryInfo()
		}

		if shouldCollect("gpu") {
			allInfo.Gpu.RenderGpuInfo()
		}

		if shouldCollect("disk") {
			allInfo.Disk.RenderDiskInfo()
		}

		if shouldCollect("nic") {
			allInfo.Nic.RenderNicModel()
		}

		if shouldCollect("fan") {
			allInfo.Fan.RenderFanInfo()
		}

	} else {
		// ToSimpleJson 已经会自动过滤空数据，直接使用 allInfo
		outformat.SuccessOutput(allInfo.ToSimpleJson(), "", output)
	}
}

func beforeRun() {
	beforehand.SetSystemFiles()
	beforehand.SetDmidecodeCmd()
}
