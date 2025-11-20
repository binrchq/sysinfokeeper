package model

import (
	"time"

	"gorm.io/gorm"
)

// HardwareRecord 硬件信息记录表
type HardwareRecord struct {
	ID          uint           `gorm:"primarykey" json:"id"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	DeletedAt   gorm.DeletedAt `gorm:"index" json:"deleted_at,omitempty"`
	
	// 硬件类型
	HardwareType string `gorm:"type:varchar(50);index" json:"hardware_type"` // cpu, gpu, disk, memory, nic, fan
	
	// 硬件标识
	HardwareID   string `gorm:"type:varchar(255);index" json:"hardware_id"`   // 唯一标识（序列号、MAC地址等）
	DeviceName   string `gorm:"type:varchar(255)" json:"device_name"`         // 设备名称
	
	// 硬件信息（JSON格式存储详细信息）
	HardwareInfo string `gorm:"type:text" json:"hardware_info"`
	
	// 事件相关
	Event        string    `gorm:"type:varchar(50)" json:"event"`         // added, removed, moved, changed
	EventMsg     string    `gorm:"type:text" json:"event_msg"`           // 事件描述
	FirstSeenAt  time.Time `gorm:"index" json:"first_seen_at"`            // 首次发现时间
	LastSeenAt   time.Time `gorm:"index" json:"last_seen_at"`              // 最后发现时间
	RemovedAt    *time.Time `gorm:"index" json:"removed_at,omitempty"`     // 移除时间（如果设备被移除）
	ChangedAt    *time.Time `gorm:"index" json:"changed_at,omitempty"`     // 变动时间（如果设备配置变化）
	
	// 状态
	IsActive     bool      `gorm:"default:true;index" json:"is_active"`    // 是否活跃（未被移除）
}

func (HardwareRecord) TableName() string {
	return "hardware_records"
}

// HardwareConfig 硬件监控配置表
type HardwareConfig struct {
	ID        uint      `gorm:"primarykey" json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	
	// 配置键值对
	ConfigKey   string `gorm:"type:varchar(100);uniqueIndex" json:"config_key"`
	ConfigValue string `gorm:"type:text" json:"config_value"`
	Description string `gorm:"type:varchar(255)" json:"description"`
}

func (HardwareConfig) TableName() string {
	return "hardware_configs"
}

// 配置键常量
const (
	ConfigKeyRetentionDays = "retention_days" // 数据保留天数，默认30天
	ConfigKeyCheckInterval = "check_interval" // 检查间隔（秒），默认3600秒（1小时）
)

