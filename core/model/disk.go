package model

type DiskInfo struct {
	Device       string   `json:"device"`       // 设备名
	Type         string   `json:"type"`         // 磁盘类型 (ssd/hdd/sas)
	Size         string   `json:"size"`         // 大小
	ReadSpeed    string   `json:"speed"`        // 读速度
	WriteSpeed   string   `json:"write_speed"`  // 写速度
	Usage        string   `json:"usage"`        // 使用空间
	Slot         string   `json:"slot"`         // 插槽
	SysSymbol    string   `json:"sys_symbol"`   // 是否系统盘
	Manufacturer string   `json:"manufacturer"` // 制造商
	ModelName    string   `json:"model_name"`   // 内存型号
	SN           string   `json:"sn"`           // 序列号
	FwVersion    string   `json:"fw_version"`   // 固件版本
	Health       string   `json:"health"`       // 状态
	BadBlocks    int      `json:"bad_blocks"`   // 坏道数量
	MountPoint   []string `json:"mount_point"`  // 挂载点
}

type DiskModel struct {
	DiskInfos []DiskInfo `json:"disk_infos" gorm:"-"` // Ignored by both GORM and JSON
	Used      string     `json:"used"`                // 使用的磁盘空间
	Total     string     `json:"total"`               // 总空间
	Available string     `json:"available"`           // 可用空间
}

func NewDiskModel() *DiskModel {
	return &DiskModel{}
}

func (c *DiskModel) ItemKey() string {
	return "disk"
}
