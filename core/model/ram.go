package model

type MemoryModule struct {
	Device       string `json:"device,omitempty"`       // 设备名
	Type         string `json:"type,omitempty"`         // 类型
	Size         string `json:"size,omitempty"`         // 大小
	Speed        string `json:"speed,omitempty"`        // 速度
	Installed    string `json:"installed,omitempty"`    // 已安装信息
	Slot         string `json:"slot,omitempty"`         // 插槽
	Rank         string `json:"rank,omitempty"`         // 模块数
	Manufacturer string `json:"manufacturer,omitempty"` // 制造商
	ModelName    string `json:"model_name,omitempty"`   // 内存型号
	SN           string `json:"sn,omitempty"`           // 序列号
}
type MemoryModel struct {
	Used         int            `json:"used,omitempty"`          // 使用的内存
	Total        int            `json:"total,omitempty"`         // 总内存
	Available    int            `json:"available,omitempty"`     // 可用内存
	SystemRam    int            `json:"system_ram,omitempty"`    // 系统内存
	Active       int            `json:"active,omitempty"`        // 活跃内存
	Slots        int            `json:"slots,omitempty"`         // 插槽数量
	Type         string         `json:"type,omitempty"`          // 内存类型
	Installed    string         `json:"installed,omitempty"`     // 已安装内存
	Capacity     string         `json:"capacity,omitempty"`      // 总容量
	Eec          string         `json:"eec,omitempty"`           // 错误校验码
	PartCapacity string         `json:"part_capacity,omitempty"` // 部分容量
	PartNumber   int            `json:"part_number,omitempty"`   // 部分编号
	MemoryModule []MemoryModule `json:"memory_module,omitempty"` // 内存模块列表
}

func NewMemory() *MemoryModel {
	return &MemoryModel{}
}

func (c *MemoryModel) ItemKey() string {
	return "memory"
}
