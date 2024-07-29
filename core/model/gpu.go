package model

type GpuInfo struct {
	Info      string   `json:"info" gorm:"column:info"`     // Information
	ModelName string   `json:"model" gorm:"column:model"`   // Model Name
	Memory    string   `json:"memory" gorm:"column:memory"` // Memory Size
	Type      string   `json:"type" gorm:"column:type"`     // Type
	Cores     int      `json:"cores" gorm:"column:cores"`   // Number of Cores
	Flags     []string `json:"flags" gorm:"-"`              // Ignored by both GORM and JSON
	AvgSpeed  float64  `json:"avg_speed" gorm:"-"`
}

type GpuModel struct {
	GpuInfos  []GpuInfo `json:"gpu_infos" gorm:"-"`  // Ignored by both GORM and JSON
	CoreSpeed []float64 `json:"core_speed" gorm:"-"` // Ignored by both GORM and JSON
}

// NewGpu creates and returns a new instance of GpuModel
func NewGpu() *GpuModel {
	return &GpuModel{}
}

// ItemKey returns a unique key for identifying the GpuModel
func (g *GpuModel) ItemKey() string {
	return "gpu"
}
