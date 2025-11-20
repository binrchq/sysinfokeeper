package hardware

import (
	"encoding/json"
	"fmt"
	"time"

	"binrc.com/sysinfokeeper/core/model"
	"gorm.io/gorm"
)

type DBStorage struct {
	db *gorm.DB
}

func NewDBStorage(db *gorm.DB) *DBStorage {
	return &DBStorage{db: db}
}

// InitTables 初始化数据库表
func (d *DBStorage) InitTables() error {
	return d.db.AutoMigrate(
		&model.HardwareRecord{},
		&model.HardwareConfig{},
	)
}

// SaveHardwareInfo 保存硬件信息到数据库
func (d *DBStorage) SaveHardwareInfo(allInfo *model.SInfo) error {
	// 在保存前自动清理30天前的移除设备记录
	retentionDays, err := d.GetRetentionDays()
	if err != nil {
		retentionDays = 30
	}
	// 清理失败不影响保存，静默处理
	_, _ = d.CleanOldRecords(retentionDays)

	now := time.Now()

	// 保存CPU信息
	for i, cpu := range allInfo.Cpu.CpuInfos {
		hardwareID := fmt.Sprintf("cpu_%d", i)
		infoJSON, _ := json.Marshal(cpu)

		record := &model.HardwareRecord{
			HardwareType: "cpu",
			HardwareID:   hardwareID,
			DeviceName:   cpu.ModelName,
			HardwareInfo: string(infoJSON),
			Event:        cpu.Event,
			EventMsg:     cpu.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save CPU record: %w", err)
		}
	}

	// 保存GPU信息
	for i, gpu := range allInfo.Gpu.GpuInfos {
		hardwareID := fmt.Sprintf("gpu_%d", i)
		infoJSON, _ := json.Marshal(gpu)

		record := &model.HardwareRecord{
			HardwareType: "gpu",
			HardwareID:   hardwareID,
			DeviceName:   gpu.ModelName,
			HardwareInfo: string(infoJSON),
			Event:        gpu.Event,
			EventMsg:     gpu.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save GPU record: %w", err)
		}
	}

	// 保存磁盘信息
	for _, disk := range allInfo.Disk.DiskInfos {
		hardwareID := disk.SN
		if hardwareID == "" {
			hardwareID = disk.Device
		}
		infoJSON, _ := json.Marshal(disk)

		record := &model.HardwareRecord{
			HardwareType: "disk",
			HardwareID:   hardwareID,
			DeviceName:   disk.Device,
			HardwareInfo: string(infoJSON),
			Event:        disk.Event,
			EventMsg:     disk.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save Disk record: %w", err)
		}
	}

	// 保存内存信息
	for _, mem := range allInfo.Memory.MemoryModule {
		hardwareID := mem.SN
		if hardwareID == "" {
			hardwareID = mem.Slot + "_" + mem.ModelName
		}
		infoJSON, _ := json.Marshal(mem)

		record := &model.HardwareRecord{
			HardwareType: "memory",
			HardwareID:   hardwareID,
			DeviceName:   mem.Slot,
			HardwareInfo: string(infoJSON),
			Event:        mem.Event,
			EventMsg:     mem.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save Memory record: %w", err)
		}
	}

	// 保存网卡信息
	for _, nic := range allInfo.Nic.NicInfos {
		hardwareID := nic.MacAddress
		if hardwareID == "" {
			hardwareID = nic.Name
		}
		infoJSON, _ := json.Marshal(nic)

		record := &model.HardwareRecord{
			HardwareType: "nic",
			HardwareID:   hardwareID,
			DeviceName:   nic.Name,
			HardwareInfo: string(infoJSON),
			Event:        nic.Event,
			EventMsg:     nic.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save NIC record: %w", err)
		}
	}

	// 保存风扇信息
	for i, fan := range allInfo.Fan.FanInfos {
		hardwareID := fmt.Sprintf("fan_%d", i)
		infoJSON, _ := json.Marshal(fan)

		record := &model.HardwareRecord{
			HardwareType: "fan",
			HardwareID:   hardwareID,
			DeviceName:   fan.Name,
			HardwareInfo: string(infoJSON),
			Event:        fan.Event,
			EventMsg:     fan.EventMsg,
		}

		if err := d.saveOrUpdateRecord(record, now); err != nil {
			return fmt.Errorf("failed to save Fan record: %w", err)
		}
	}

	return nil
}

// saveOrUpdateRecord 保存或更新记录
func (d *DBStorage) saveOrUpdateRecord(record *model.HardwareRecord, now time.Time) error {
	var existing model.HardwareRecord
	err := d.db.Where("hardware_type = ? AND hardware_id = ?", record.HardwareType, record.HardwareID).
		First(&existing).Error

	if err == gorm.ErrRecordNotFound {
		// 新设备
		record.FirstSeenAt = now
		record.LastSeenAt = now
		record.IsActive = true
		if record.Event == "" {
			record.Event = EventAdded
			record.EventMsg = "Device first detected"
		}
		return d.db.Create(record).Error
	} else if err != nil {
		return err
	}

	// 如果设备已被移除且未过期，不应该更新（除非设备重新出现）
	if !existing.IsActive && existing.RemovedAt != nil {
		// 检查是否过期（30天）
		retentionDays, _ := d.GetRetentionDays()
		cutoffDate := time.Now().AddDate(0, 0, -retentionDays)

		// 如果移除时间在保留期内，且当前记录不是重新添加，则不更新
		if existing.RemovedAt.After(cutoffDate) && record.Event != EventAdded {
			// 移除的设备在保留期内，不更新记录
			return nil
		}
	}

	// 更新现有记录
	existing.LastSeenAt = now
	existing.HardwareInfo = record.HardwareInfo
	existing.DeviceName = record.DeviceName

	// 处理事件
	if record.Event != "" {
		existing.Event = record.Event
		existing.EventMsg = record.EventMsg

		switch record.Event {
		case EventRemoved:
			existing.IsActive = false
			if existing.RemovedAt == nil {
				t := now
				existing.RemovedAt = &t
			}
		case EventChanged, EventMoved:
			if existing.ChangedAt == nil || existing.Event != record.Event {
				t := now
				existing.ChangedAt = &t
			}
		case EventAdded:
			// 如果之前被标记为移除，现在又出现了
			if !existing.IsActive {
				existing.IsActive = true
				existing.RemovedAt = nil
			}
		}
	} else {
		// 如果没有事件，说明设备正常存在
		existing.IsActive = true
	}

	return d.db.Save(&existing).Error
}

// GetLatestSnapshot 获取最新的硬件快照（用于对比）
func (d *DBStorage) GetLatestSnapshot() (*HardwareSnapshot, error) {
	snapshot := &HardwareSnapshot{
		Timestamp: time.Now(),
		CPU:       []CpuSnapshot{},
		GPU:       []GpuSnapshot{},
		Disk:      []DiskSnapshot{},
		Memory:    []MemoryModuleSnapshot{},
		Nic:       []NicSnapshot{},
		Fan:       []FanSnapshot{},
	}

	// 获取所有活跃的硬件记录
	var records []model.HardwareRecord
	if err := d.db.Where("is_active = ?", true).Find(&records).Error; err != nil {
		return nil, err
	}

	for _, record := range records {
		switch record.HardwareType {
		case "cpu":
			var cpuInfo model.CpuInfo
			if err := json.Unmarshal([]byte(record.HardwareInfo), &cpuInfo); err == nil {
				snapshot.CPU = append(snapshot.CPU, CpuSnapshot{
					ID:         record.HardwareID,
					ModelName:  cpuInfo.ModelName,
					Cores:      cpuInfo.Cores,
					MaxSpeed:   cpuInfo.MaxSpeed,
					MinSpeed:   cpuInfo.MinSpeed,
					PhysicalID: record.HardwareID,
				})
			}
		case "gpu":
			var gpuInfo model.GpuInfo
			if err := json.Unmarshal([]byte(record.HardwareInfo), &gpuInfo); err == nil {
				snapshot.GPU = append(snapshot.GPU, GpuSnapshot{
					ID:        record.HardwareID,
					ModelName: gpuInfo.ModelName,
					Memory:    gpuInfo.Memory,
					Type:      gpuInfo.Type,
				})
			}
		case "disk":
			var diskInfo model.DiskInfo
			if err := json.Unmarshal([]byte(record.HardwareInfo), &diskInfo); err == nil {
				snapshot.Disk = append(snapshot.Disk, DiskSnapshot{
					ID:           record.HardwareID,
					Device:       diskInfo.Device,
					SN:           diskInfo.SN,
					ModelName:    diskInfo.ModelName,
					Size:         diskInfo.Size,
					Manufacturer: diskInfo.Manufacturer,
					MountPoint:   diskInfo.MountPoint,
				})
			}
		case "memory":
			var memInfo model.MemoryModule
			if err := json.Unmarshal([]byte(record.HardwareInfo), &memInfo); err == nil {
				snapshot.Memory = append(snapshot.Memory, MemoryModuleSnapshot{
					ID:           record.HardwareID,
					Slot:         memInfo.Slot,
					SN:           memInfo.SN,
					ModelName:    memInfo.ModelName,
					Size:         memInfo.Size,
					Manufacturer: memInfo.Manufacturer,
				})
			}
		case "nic":
			var nicInfo model.NicInfo
			if err := json.Unmarshal([]byte(record.HardwareInfo), &nicInfo); err == nil {
				snapshot.Nic = append(snapshot.Nic, NicSnapshot{
					ID:         record.HardwareID,
					Name:       nicInfo.Name,
					MacAddress: nicInfo.MacAddress,
					Type:       nicInfo.Type,
					Vendor:     nicInfo.Vendor,
					Model:      nicInfo.Model,
				})
			}
		case "fan":
			var fanInfo model.FanInfo
			if err := json.Unmarshal([]byte(record.HardwareInfo), &fanInfo); err == nil {
				snapshot.Fan = append(snapshot.Fan, FanSnapshot{
					ID:   record.HardwareID,
					Name: fanInfo.Name,
				})
			}
		}
	}

	return snapshot, nil
}

// CleanOldRecords 清理过期记录，返回清理的记录数
func (d *DBStorage) CleanOldRecords(retentionDays int) (int64, error) {
	cutoffDate := time.Now().AddDate(0, 0, -retentionDays)

	// Delete expired removed device records
	result := d.db.Where("is_active = ? AND removed_at < ?", false, cutoffDate).
		Delete(&model.HardwareRecord{})

	return result.RowsAffected, result.Error
}

// CleanAllRecords 清理所有记录
func (d *DBStorage) CleanAllRecords() (int64, error) {
	result := d.db.Where("1 = 1").Delete(&model.HardwareRecord{})
	return result.RowsAffected, result.Error
}

// CleanRecordsByType 按硬件类型清理记录
func (d *DBStorage) CleanRecordsByType(hardwareType string) (int64, error) {
	result := d.db.Where("hardware_type = ?", hardwareType).Delete(&model.HardwareRecord{})
	return result.RowsAffected, result.Error
}

// CleanInactiveRecords 清理所有非活跃记录
func (d *DBStorage) CleanInactiveRecords() (int64, error) {
	result := d.db.Where("is_active = ?", false).Delete(&model.HardwareRecord{})
	return result.RowsAffected, result.Error
}

// CleanRecordsBeforeDate 清理指定日期之前的记录
func (d *DBStorage) CleanRecordsBeforeDate(beforeDate time.Time) (int64, error) {
	result := d.db.Where("last_seen_at < ?", beforeDate).Delete(&model.HardwareRecord{})
	return result.RowsAffected, result.Error
}

// GetRecordCount 获取记录数量
func (d *DBStorage) GetRecordCount() (int64, error) {
	var count int64
	err := d.db.Model(&model.HardwareRecord{}).Count(&count).Error
	return count, err
}

// GetRecordCountByType 按类型获取记录数量
func (d *DBStorage) GetRecordCountByType(hardwareType string) (int64, error) {
	var count int64
	err := d.db.Model(&model.HardwareRecord{}).Where("hardware_type = ?", hardwareType).Count(&count).Error
	return count, err
}

// GetInactiveRecordCount 获取非活跃记录数量
func (d *DBStorage) GetInactiveRecordCount() (int64, error) {
	var count int64
	err := d.db.Model(&model.HardwareRecord{}).Where("is_active = ?", false).Count(&count).Error
	return count, err
}

// GetRecordCountBeforeDate 获取指定日期之前的记录数量
func (d *DBStorage) GetRecordCountBeforeDate(beforeDate time.Time) (int64, error) {
	var count int64
	err := d.db.Model(&model.HardwareRecord{}).Where("last_seen_at < ?", beforeDate).Count(&count).Error
	return count, err
}

// GetExpiredRemovedRecordCount 获取过期的已移除记录数量
func (d *DBStorage) GetExpiredRemovedRecordCount(retentionDays int) (int64, error) {
	cutoffDate := time.Now().AddDate(0, 0, -retentionDays)
	var count int64
	err := d.db.Model(&model.HardwareRecord{}).Where("is_active = ? AND removed_at < ?", false, cutoffDate).Count(&count).Error
	return count, err
}

// GetConfig 获取配置
func (d *DBStorage) GetConfig(key string, defaultValue string) (string, error) {
	var config model.HardwareConfig
	err := d.db.Where("config_key = ?", key).First(&config).Error

	if err == gorm.ErrRecordNotFound {
		// 如果不存在，创建默认配置
		config = model.HardwareConfig{
			ConfigKey:   key,
			ConfigValue: defaultValue,
		}
		if err := d.db.Create(&config).Error; err != nil {
			return defaultValue, err
		}
		return defaultValue, nil
	}

	if err != nil {
		return defaultValue, err
	}

	return config.ConfigValue, nil
}

// SetConfig 设置配置
func (d *DBStorage) SetConfig(key, value, description string) error {
	var config model.HardwareConfig
	err := d.db.Where("config_key = ?", key).First(&config).Error

	if err == gorm.ErrRecordNotFound {
		config = model.HardwareConfig{
			ConfigKey:   key,
			ConfigValue: value,
			Description: description,
		}
		return d.db.Create(&config).Error
	}

	if err != nil {
		return err
	}

	config.ConfigValue = value
	if description != "" {
		config.Description = description
	}
	return d.db.Save(&config).Error
}

// GetRetentionDays 获取保留天数
func (d *DBStorage) GetRetentionDays() (int, error) {
	value, err := d.GetConfig(model.ConfigKeyRetentionDays, "30")
	if err != nil {
		return 30, err
	}

	var days int
	if _, err := fmt.Sscanf(value, "%d", &days); err != nil {
		return 30, nil
	}

	return days, nil
}

// SetRetentionDays 设置保留天数
func (d *DBStorage) SetRetentionDays(days int) error {
	return d.SetConfig(model.ConfigKeyRetentionDays, fmt.Sprintf("%d", days), "数据保留天数")
}
