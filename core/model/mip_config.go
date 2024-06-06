package model

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const TableMipConfigExtend = "MipConfigExtend"

type MipConfigExtend struct {
	ID          uint64 `gorm:"primaryKey;autoIncrement"`
	Device      string `gorm:"column:device;uniqueIndex;type:varchar(64);not null"`
	MipConfigID int
}

func (c MipConfigExtend) ToRtTableItem() []int {
	return []int{int(c.ID), c.MipConfigID}
}

type MipConfigExtends []MipConfigExtend

func (l MipConfigExtends) ToRtTableItems() (items [][]int) {
	for _, i := range l {
		items = append(items, i.ToRtTableItem())
	}
	return
}

func (MipConfigExtend) TableName() string {
	return TableMipConfigExtend
}

func (MipConfigExtend) BeforeCreate(tx *gorm.DB) error {
	tx.Statement.AddClause(clause.OnConflict{
		Columns:   []clause.Column{{Name: "device"}},
		DoNothing: false,
		UpdateAll: true,
	})
	return nil
}

func NewMipConfigExtend(device string) MipConfigExtend {
	return MipConfigExtend{
		Device: device,
	}
}

type MipConfig struct {
	MipConfigExtend MipConfigExtend
	MipKeyConfig
	CreatedAt    *time.Time     `gorm:"column:created_at"`
	UpdatedAt    *time.Time     `gorm:"column:updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index"`
	Checksum     string         `gorm:"column:checksum;type:varchar(32);not null"`
	BSCBWLimit   int            `gorm:"column:bsc_bw_limit;default:0"`
	BSCMainMAC   string         `gorm:"column:bsc_main_mac;type:varchar(32);default:''"`
	PlatStatus   int            `gorm:"column:plat_status;default:0"` // 平台标记的网卡状态, 1 正常, 2 异常
	IsIPv6       bool           `gorm:"column:is_ipv6;default:false"`
	IsManageIP   bool           `gorm:"column:is_manage_ip;default:false"`   // 是否是管理IP
	IsManualStop bool           `gorm:"column:is_manual_stop;default:false"` // 是否是手动停止
}

type MipKeyConfig struct {
	ID         int    `gorm:"column:id;primaryKey;not null"`
	Device     string `gorm:"column:device;type:varchar(64);primaryKey;not null"`
	ETH        string `gorm:"column:eth;type:varchar(32);not null"` // 子网卡名
	MainETH    string `gorm:"column:main_eth;type:varchar(32);not null"`
	BSCVlanID  int    `gorm:"column:bsc_vlan_id;default:0"`
	BSCNetType string `gorm:"column:bsc_net_type;type:varchar(32);default:''"`
	MAC        string `gorm:"column:mac;type:varchar(32);default:''"` // 网卡的mac地址
	IP         string `gorm:"column:ip"`
	Gateway    string `gorm:"column:gateway;type:varchar(32);not null"`
	NetMask    string `gorm:"column:netmask;type:varchar(32);not null"`

	IPv6        string `gorm:"column:ipv6;type:varchar(128)"`
	IPv6Gateway string `gorm:"column:ipv6_gateway;type:varchar(128)"`
	IPv6NetMask string `gorm:"column:ipv6_netmask;type:varchar(128)"`
	IPv6NetType int    `gorm:"column:ipv6_net_type"` // 平台的标记: 0-未初始化 4800-无 4801-外网，4802-内网
}

func (c MipKeyConfig) GenChecksum() string {
	data, _ := json.Marshal(c)
	return fmt.Sprintf("%x", md5.Sum(data))
}

func (c MipConfig) IsVlanType() bool {
	return c.BSCNetType == "vlan"
}

func (c MipConfig) IsPhysicalNetCard() bool {
	return c.ETH == c.MainETH
}

func (c MipConfig) TableName() string {
	return "mip_config"
}

func NewMipConfig(id int, eth, mainEth string, vlanID int, netType string, mainMac string, limit int, mac string, status int, ip, gateway, netmask string, ipv6, ipv6Gateway, ipv6Netmask string, isManageIP bool) *MipConfig {
	c := MipConfig{
		BSCMainMAC: mainMac,
		BSCBWLimit: limit,
	}
	c.ID = id
	c.Device = eth
	c.ETH = eth
	c.MainETH = mainEth
	c.BSCVlanID = vlanID
	c.BSCNetType = netType
	c.MAC = mac
	c.PlatStatus = status
	c.IP = ip
	c.Gateway = gateway
	c.NetMask = netmask
	c.IPv6 = ipv6
	c.IPv6Gateway = ipv6Gateway
	c.IPv6NetMask = ipv6Netmask
	c.IsManageIP = isManageIP
	c.Checksum = c.GenChecksum()
	device := c.Device
	if c.IsPhysicalNetCard() {
		device = fmt.Sprintf("%s.%d", eth, id)
	}
	c.MipConfigExtend = NewMipConfigExtend(device)
	return &c
}

type MipConfigs []MipConfig

func (c MipConfigs) IDs() []int {
	var ids []int
	for _, v := range c {
		ids = append(ids, v.ID)
	}
	return ids
}

func (l MipConfigs) Devices() []string {
	var devices []string
	for _, mipConfig := range l {
		devices = append(devices, mipConfig.Device)
	}
	return devices
}

func (c MipConfigs) Get(unit int) *MipConfig {
	for _, v := range c {
		if v.ID == unit {
			return &v
		}
	}
	return nil
}

func (c MipConfigs) MacvlanMacs() map[string]bool {
	macs := make(map[string]bool)
	for _, v := range c {
		if v.MAC != "" {
			macs[v.MAC] = true
		}
	}
	return macs
}

type MipConfigMap map[int]MipConfig

func (c MipConfigMap) ToSlice() MipConfigs {
	configs := MipConfigs{}
	for _, v := range c {
		configs = append(configs, v)
	}
	return configs
}

func (c MipConfigMap) Devices() []string {
	var devices []string
	for _, v := range c {
		devices = append(devices, v.Device)
	}
	return devices
}

func (c MipConfigs) VlanCountMap() map[int]int {
	vlanCountMap := make(map[int]int)
	for _, config := range c {
		vlanCountMap[config.BSCVlanID]++
	}
	return vlanCountMap
}

// 平台规划为外网IPv6的
func (c MipConfigs) HasPlanIPv6() bool {
	for _, config := range c {
		if config.IPv6NetType == 4801 {
			return true
		}
	}
	return false
}

func (c MipConfigs) HasIPv6() bool {
	for _, config := range c {
		if config.IPv6 != "" {
			return true
		}
	}
	return false
}
