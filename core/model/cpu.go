package model

type CpuInfo struct {
	Info      string   `json:"info" gorm:"column:info"`       // 信息
	ModelName string   `json:"model" gorm:"column:model"`     // 型号
	Bits      int      `json:"bits" gorm:"column:bits"`       // 位数
	Type      string   `json:"type" gorm:"column:type"`       // 类型
	Cache     string   `json:"cache" gorm:"column:cache"`     // 缓存
	MinMax    string   `json:"min_max" gorm:"column:min_max"` // 最小最大频率
	Cores     int      `json:"cores" gorm:"column:cores"`     // 核心数
	Flags     []string `json:"flags" gorm:"-"`                // Ignored by both GORM and JSON
	AvgSpeed  float64  `json:"avg_speed" gorm:"-"`
}

type CpuModel struct {
	CpuInfos  []CpuInfo `json:"cpu_infos" gorm:"-"`  // Ignored by both GORM and JSON
	CoreSpeed []float64 `json:"core_speed" gorm:"-"` // Ignored by both GORM and JSON
}

func NewCpu() *CpuModel {
	return &CpuModel{}
}

func (c *CpuModel) ItemKey() string {
	return "cpu"
}
