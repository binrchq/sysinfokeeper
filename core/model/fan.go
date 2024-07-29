package model

type FanInfo struct {
	Name   string `json:"name" gorm:"column:name"`     // Type
	Speed  string `json:"speed" gorm:"column:speed"`   // Speed (RPM)
	Status string `json:"status" gorm:"column:status"` // Status
}

type FanModel struct {
	FanInfos []FanInfo `json:"fan_infos" gorm:"-"` // Ignored by both GORM and JSON
}

// NewFan creates and returns a new instance of FanModel
func NewFan() *FanModel {
	return &FanModel{}
}

// ItemKey returns a unique key for identifying the FanModel
func (f *FanModel) ItemKey() string {
	return "fan"
}
