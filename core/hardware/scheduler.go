package hardware

import (
	"fmt"
	"time"

	"binrc.com/sysinfokeeper/core/model"
	"binrc.com/sysinfokeeper/core/packages"
	"gorm.io/gorm"
)

type Scheduler struct {
	db            *gorm.DB
	storage       *DBStorage
	stopChan      chan bool
	isRunning     bool
	interval      time.Duration
	speedTestMode string
}

func NewScheduler(db *gorm.DB) *Scheduler {
	storage := NewDBStorage(db)
	return &Scheduler{
		db:            db,
		storage:       storage,
		stopChan:      make(chan bool),
		isRunning:     false,
		interval:      time.Hour, // 默认1小时
		speedTestMode: "low",     // 默认低消耗模式
	}
}

// Start 启动定时任务
func (s *Scheduler) Start() error {
	if s.isRunning {
		return fmt.Errorf("scheduler is already running")
	}
	
	// 初始化数据库表
	if err := s.storage.InitTables(); err != nil {
		return fmt.Errorf("failed to init tables: %w", err)
	}
	
	// 获取检查间隔
	intervalStr, err := s.storage.GetConfig(model.ConfigKeyCheckInterval, "3600")
	if err == nil {
		var seconds int
		if _, err := fmt.Sscanf(intervalStr, "%d", &seconds); err == nil && seconds > 0 {
			s.interval = time.Duration(seconds) * time.Second
		}
	}
	
	s.isRunning = true
	
	// 立即执行一次
	go s.runOnce()
	
	// 启动定时任务
	go s.run()
	
	return nil
}

// Stop 停止定时任务
func (s *Scheduler) Stop() {
	if !s.isRunning {
		return
	}
	
	s.isRunning = false
	close(s.stopChan)
}

// run 定时执行任务
func (s *Scheduler) run() {
	ticker := time.NewTicker(s.interval)
	defer ticker.Stop()
	
	for {
		select {
		case <-ticker.C:
			s.runOnce()
		case <-s.stopChan:
			return
		}
	}
}

// runOnce 执行一次硬件信息收集和对比
func (s *Scheduler) runOnce() {
	// 收集当前硬件信息
	allInfo := model.NewSInfo()
	
	// CPU
	if c, err := packages.NewCpu().Get(); err == nil {
		allInfo.Cpu = *c
	}
	
	// RAM
	if m, err := packages.NewRam().Get(); err == nil {
		allInfo.Memory = *m
	}
	
	// Disk
	disk := packages.NewDisk()
	disk.SetSpeedTestMode(s.speedTestMode)
	if d, err := disk.Get(); err == nil {
		allInfo.Disk = *d
	}
	
	// NIC
	if n, err := packages.NewNic().Get(); err == nil {
		allInfo.Nic = *n
	}
	
	// Fan
	if f, err := packages.NewSensor().FanGet(); err == nil {
		allInfo.Fan = *f
	}
	
	// GPU
	if g, err := packages.NewGpu().Get(); err == nil {
		allInfo.Gpu = *g
	}
	
	// 获取历史快照进行对比
	oldSnapshot, err := s.storage.GetLatestSnapshot()
	if err != nil {
		// 如果获取失败，使用空快照
		oldSnapshot = &HardwareSnapshot{
			Timestamp: time.Now(),
			CPU:       []CpuSnapshot{},
			GPU:       []GpuSnapshot{},
			Disk:      []DiskSnapshot{},
			Memory:    []MemoryModuleSnapshot{},
			Nic:       []NicSnapshot{},
			Fan:       []FanSnapshot{},
		}
	}
	
	// 创建新快照
	sm := NewSnapshotManager()
	newSnapshot := sm.CreateFromCurrent(allInfo)
	
	// 对比并标记变化
	comparator := NewComparator(oldSnapshot, newSnapshot)
	comparator.CompareAndMark(allInfo)
	
	// 保存到数据库
	if err := s.storage.SaveHardwareInfo(allInfo); err != nil {
		fmt.Printf("Error saving hardware info: %v\n", err)
		return
	}
	
	// 清理过期数据
	retentionDays, err := s.storage.GetRetentionDays()
	if err == nil {
		if _, err := s.storage.CleanOldRecords(retentionDays); err != nil {
			fmt.Printf("Error cleaning old records: %v\n", err)
		}
	}
}

// SetInterval 设置检查间隔
func (s *Scheduler) SetInterval(interval time.Duration) {
	s.interval = interval
}

// SetSpeedTestMode 设置磁盘测速模式: "none", "low", "high"
func (s *Scheduler) SetSpeedTestMode(mode string) {
	s.speedTestMode = mode
}

