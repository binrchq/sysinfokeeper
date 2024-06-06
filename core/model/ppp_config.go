package model

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"bitrec.ai/dialmainer/core/constants"
	"bitrec.ai/dialmainer/core/utils"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	TablePPPConfigExtend  = "PPPConfigExtend"
	DefaultConnectTimeout = 60
	DefaultMTU            = 1480
	DefaultMRU            = 1480
	DefaultLcpInterval    = 20
	DefaultLcpFailure     = 3
)

type PPPConfigExtend struct {
	ID          uint64 `gorm:"primaryKey;autoIncrement"`
	Device      string `gorm:"column:device;uniqueIndex;not null"`
	PPPConfigID int
}

func (c PPPConfigExtend) ToRtTableItem() []int {
	return []int{int(c.ID), c.PPPConfigID}
}

type PPPConfigExtends []PPPConfigExtend

func (l PPPConfigExtends) ToRtTableItems() (items [][]int) {
	for _, i := range l {
		items = append(items, i.ToRtTableItem())
	}
	return
}

func (PPPConfigExtend) TableName() string {
	return TablePPPConfigExtend
}

func (PPPConfigExtend) BeforeCreate(tx *gorm.DB) error {
	tx.Statement.AddClause(clause.OnConflict{
		Columns:   []clause.Column{{Name: "device"}},
		DoNothing: false,
		UpdateAll: true,
	})
	return nil
}

func NewPPPConfigExtend(device string) PPPConfigExtend {
	return PPPConfigExtend{
		Device: device,
	}
}

type PPPConfig struct {
	PPPConfigExtend PPPConfigExtend
	ID              int            `gorm:"column:id;primaryKey;not null"`
	CreatedAt       *time.Time     `gorm:"column:created_at"`
	UpdatedAt       *time.Time     `gorm:"column:updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index"`
	Device          string         `gorm:"column:device;type:varchar(32);primaryKey;not null"`
	User            string         `gorm:"column:user;type:varchar(32);not null"`
	Password        string         `gorm:"column:password;type:varchar(32);not null"`
	ETH             string         `gorm:"column:eth;type:varchar(32);not null"`
	MTU             uint16         `gorm:"column:mtu;default:1480"`
	MRU             uint16         `gorm:"column:mru;default:1480"`
	LcpInterval     uint8          `gorm:"column:lcp_interval;default:20"`
	LcpFailure      uint8          `gorm:"column:lcp_failure;default:3"`
	ConnectTimeout  uint8          `gorm:"column:connect_timeout;default:60"`
	LogFile         string         `gorm:"column:log_file;type:varchar(128);not null"`
	PIDFile         string         `gorm:"column:pid_file;type:varchar(128);not null"`
	IsIPv6          bool           `gorm:"column:is_ipv6;default:false"`
	MainETH         string         `gorm:"column:main_eth;type:varchar(32);not null"`
	Checksum        string         `gorm:"column:checksum;type:varchar(32);not null"`
	Uptime          time.Time      `gorm:"column:uptime"` // 拨上号的时间
	BSCVlanID       int            `gorm:"column:bsc_vlan_id;default:0"`
	BSCNetType      string         `gorm:"column:bsc_net_type;type:varchar(32);default:''"`
	BSCBWLimit      int            `gorm:"column:bsc_bw_limit;default:0"`
	BSCMainMAC      string         `gorm:"column:bsc_main_mac;type:varchar(32);default:''"`
	MacVlanMAC      string         `gorm:"column:macvlan_mac;type:varchar(32);default:''"` // macvlan网卡的mac地址
	PlatStatus      int            `gorm:"column:plat_status;default:0"`                   // 平台标记的网卡状态, 1 正常, 2 异常
	IP              string         `gorm:"column:ip"`
	IPv6            string         `gorm:"column:ipv6"`
	IPv6NetType     int            `gorm:"column:ipv6_net_type"` // 平台的标记: 0-未初始化 4800-无 4801-外网，4802-内网
	PPPServiceName  string         `gorm:"column:ppp_servicename;type:varchar(32);default:''"`
	PPPAcName       string         `gorm:"column:ppp_acname;type:varchar(32);default:''"`
	IsManualStop    bool           `gorm:"column:is_manual_stop;default:false"` // 是否是手动停止
}

func NewPPPConfig(id int, user, password, eth string, isIPv6 bool, mainEth string, vlanID int, macVlanMAC, PPPServiceName, PPPAcName string) *PPPConfig {
	device := fmt.Sprintf("ppp%d", id)
	c := PPPConfig{
		ID:             id,
		User:           strings.TrimSpace(user),
		Password:       strings.TrimSpace(password),
		ETH:            eth,
		Device:         device,
		MTU:            DefaultMTU,
		MRU:            DefaultMRU,
		LcpInterval:    DefaultLcpInterval,
		LcpFailure:     DefaultLcpFailure,
		LogFile:        fmt.Sprintf(constants.PPPD_LOG_PATH, device),
		PIDFile:        fmt.Sprintf(constants.PPPD_PID_PATH, device),
		IsIPv6:         isIPv6,
		MainETH:        mainEth,
		BSCVlanID:      vlanID,
		MacVlanMAC:     macVlanMAC,
		PPPServiceName: PPPServiceName,
		PPPAcName:      PPPAcName,
	}
	c.Checksum = c.GenChecksum()
	c.ConnectTimeout = DefaultConnectTimeout
	c.PPPConfigExtend = NewPPPConfigExtend(device)
	return &c
}

func (c PPPConfig) IsVlanType() bool {
	return c.BSCNetType == "vlan"
}

func (c PPPConfig) GenChecksum() string {
	data, _ := json.Marshal(c)
	return fmt.Sprintf("%x", md5.Sum(data))
}

func (c *PPPConfig) TableName() string {
	return "ppp_config"
}

func (c *PPPConfig) GenCommand() []string {
	args := []string{constants.PPPD_BIN_PATH,
		"ipparam", c.Device,
		"linkname", c.Device,
		"plugin", "rp-pppoe.so", fmt.Sprintf("nic-%s", c.ETH),
		"noipdefault", "noauth", "default-asyncmap", "hide-password", "nodetach",
		"mtu", fmt.Sprintf("%d", c.MTU), "mru", fmt.Sprintf("%d", c.MRU),
		"noaccomp", "nodeflate", "nopcomp", "novj", "novjccomp",
		"user", c.User,
		"password", c.Password,
		"lcp-echo-interval", fmt.Sprintf("%d", c.LcpInterval),
		"lcp-echo-failure", fmt.Sprintf("%d", c.LcpFailure),
		"unit", strconv.Itoa(c.ID),
		"logfile", c.LogFile,
	}
	if c.IsIPv6 {
		args = append(args, "+ipv6")
	}
	if c.PPPServiceName != "" {
		args = append(args, "rp_pppoe_service", c.PPPServiceName)
	}
	if c.PPPAcName != "" {
		args = append(args, "rp_pppoe_ac", c.PPPAcName)
	}
	return args
}

type PPPConfigs []PPPConfig

func (c PPPConfigs) IDs() []int {
	var ids []int
	for _, v := range c {
		ids = append(ids, v.ID)
	}
	return ids
}

func (c PPPConfigs) MainETHs() []string {
	var mainETHs []string
	for _, v := range c {
		mainETHs = append(mainETHs, v.MainETH)
	}
	return utils.Uniq(mainETHs)
}

func (c PPPConfigs) Devices() []string {
	var devices []string
	for _, v := range c {
		devices = append(devices, v.Device)
	}
	return devices
}

func (c PPPConfigs) MacvlanMacs() map[string]bool {
	macs := make(map[string]bool)
	for _, v := range c {
		if v.MacVlanMAC != "" {
			macs[v.MacVlanMAC] = true
		}
	}
	return macs
}

func (c PPPConfigs) Get(unit int) *PPPConfig {
	for _, v := range c {
		if v.ID == unit {
			return &v
		}
	}
	return nil
}

type PPPConfigMap map[int]PPPConfig

func (c PPPConfigMap) ToSlice() PPPConfigs {
	configs := PPPConfigs{}
	for _, v := range c {
		configs = append(configs, v)
	}
	return configs
}

func (c PPPConfigMap) Devices() []string {
	var devices []string
	for _, v := range c {
		devices = append(devices, v.Device)
	}
	return devices
}

func (c PPPConfigs) VlanCountMap() map[int]int {
	vlanCountMap := make(map[int]int)
	for _, config := range c {
		vlanCountMap[config.BSCVlanID]++
	}
	return vlanCountMap
}

func (c PPPConfigs) HasIPv6() bool {
	for _, config := range c {
		if config.IsIPv6 {
			return true
		}
	}
	return false
}

// 平台规划为外网IPv6的
func (c PPPConfigs) HasPlanIPv6() bool {
	for _, config := range c {
		if config.IPv6NetType == 4801 {
			return true
		}
	}
	return false
}
