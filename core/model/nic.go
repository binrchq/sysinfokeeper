package model

import (
	"strings"
	"time"

	"github.com/pterm/pterm"
)

type NicInfo struct {
	Name          string     `json:"name" gorm:"column:name"`               // Network Card Name
	Type          string     `json:"type" gorm:"column:type"`               // Network Card Type (Virtual/Physical)
	MacAddress    string     `json:"mac_address" gorm:"column:mac_address"` // MAC Address
	MaxRatedSpeed string     `json:"speed" gorm:"column:speed"`             // Maximum Rated Speed
	IPv4Addresses []string   `json:"ipv4_addresses" gorm:"-"`               // IPv4 Address Collection
	IPv6Addresses []string   `json:"ipv6_addresses" gorm:"-"`               // IPv6 Address Collection
	Vendor        string     `json:"vendor" gorm:"column:vendor"`           // Network Card Brand
	Model         string     `json:"model" gorm:"column:model"`             // Network Card Model
	Status        string     `json:"status" gorm:"column:status"`           // Current Status (up/down)
	Event         string     `json:"event"`                                 // 事件 新增，丢失，移动
	EventMsg      string     `json:"event_msg"`                             // 事件信息
	RemovedAt     *time.Time `json:"removed_at,omitempty"`                  // 移除时间
}

type NicModel struct {
	NicInfos []NicInfo `json:"nic_infos" gorm:"-"` // Ignored by both GORM and JSON
	Msg      string    `json:"msg" gorm:"-"`
}

// NewNic creates and returns a new instance of NicModel
func NewNic() *NicModel {
	return &NicModel{}
}

// ItemKey returns a unique key for identifying the NicModel
func (n *NicModel) ItemKey() string {
	return "nic"
}

func (nic *NicModel) RenderNicModel() error {
	pterm.DefaultSection.WithLevel(2).Println("Network Interface Information")
	if nic.Msg != "" {
		pterm.Info.Println(nic.Msg)
	}
	if len(nic.NicInfos) > 0 {
		rows := [][]string{
			{"Name", "Type", "MAC", "Max Speed", "Status", "Vendor", "Model", "IPv4", "IPv6", "Event", "Event Msg"},
		}

		for _, nicInfo := range nic.NicInfos {
			ipv4 := strings.Join(nicInfo.IPv4Addresses, ",")
			ipv6 := strings.Join(nicInfo.IPv6Addresses, ",")
			event := nicInfo.Event
			eventMsg := nicInfo.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}

			rows = append(rows, []string{
				nicInfo.Name,
				nicInfo.Type,
				nicInfo.MacAddress,
				nicInfo.MaxRatedSpeed,
				nicInfo.Status,
				nicInfo.Vendor,
				nicInfo.Model,
				ipv4,
				ipv6,
				event,
				eventMsg,
			})
		}

		pterm.DefaultTable.
			WithHasHeader().
			WithBoxed(true).
			WithSeparator(" │ ").
			WithData(rows).
			Render()
	}
	return nil
}
