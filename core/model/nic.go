package model

type NicInfo struct {
	Name          string   `json:"name" gorm:"column:name"`               // Network Card Name
	Type          string   `json:"type" gorm:"column:type"`               // Network Card Type (Virtual/Physical)
	MacAddress    string   `json:"mac_address" gorm:"column:mac_address"` // MAC Address
	MaxRatedSpeed string   `json:"speed" gorm:"column:speed"`             // Maximum Rated Speed
	IPv4Addresses []string `json:"ipv4_addresses" gorm:"-"`               // IPv4 Address Collection
	IPv6Addresses []string `json:"ipv6_addresses" gorm:"-"`               // IPv6 Address Collection
	Vendor        string   `json:"vendor" gorm:"column:vendor"`           // Network Card Brand
	Model         string   `json:"model" gorm:"column:model"`             // Network Card Model
	Status        string   `json:"status" gorm:"column:status"`           // Current Status (up/down)
}

type NicModel struct {
	NicInfos []NicInfo `json:"nic_infos" gorm:"-"` // Ignored by both GORM and JSON
}

// NewNic creates and returns a new instance of NicModel
func NewNic() *NicModel {
	return &NicModel{}
}

// ItemKey returns a unique key for identifying the NicModel
func (n *NicModel) ItemKey() string {
	return "nic"
}
