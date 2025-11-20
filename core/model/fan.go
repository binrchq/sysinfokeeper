package model

import (
	"time"

	"github.com/pterm/pterm"
)

type FanInfo struct {
	Name      string     `json:"name" gorm:"column:name"`     // Type
	Speed     string     `json:"speed" gorm:"column:speed"`   // Speed (RPM)
	Status    string     `json:"status" gorm:"column:status"` // Status
	Event     string     `json:"event"`                       // 事件 新增，丢失，移动
	EventMsg  string     `json:"event_msg"`                   // 事件信息
	RemovedAt *time.Time `json:"removed_at,omitempty"`        // 移除时间
}

type FanModel struct {
	FanInfos []FanInfo `json:"fan_infos" gorm:"-"` // Ignored by both GORM and JSON
	Msg      string    `json:"msg" gorm:"-"`
}

// NewFan creates and returns a new instance of FanModel
func NewFan() *FanModel {
	return &FanModel{}
}

// ItemKey returns a unique key for identifying the FanModel
func (f *FanModel) ItemKey() string {
	return "fan"
}

func (fan *FanModel) RenderFanInfo() error {
	pterm.DefaultSection.WithLevel(2).Println("Fan Information")
	if fan.Msg != "" {
		pterm.Info.Println(fan.Msg)
	}
	if len(fan.FanInfos) > 0 {
		rows := [][]string{
			{"Name", "Speed (RPM)", "Status", "Event", "Event Msg"},
		}

		for _, f := range fan.FanInfos {
			event := f.Event
			eventMsg := f.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}
			rows = append(rows, []string{f.Name, f.Speed, f.Status, event, eventMsg})
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
