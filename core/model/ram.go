package model

import (
	"fmt"
	"time"

	"github.com/pterm/pterm"
)

type MemoryModule struct {
	Device       string     `json:"device,omitempty"`       // 设备名
	Type         string     `json:"type,omitempty"`         // 类型
	Size         string     `json:"size,omitempty"`         // 大小
	Speed        string     `json:"speed,omitempty"`        // 速度
	Installed    string     `json:"installed,omitempty"`    // 已安装信息
	Slot         string     `json:"slot,omitempty"`         // 插槽
	Rank         string     `json:"rank,omitempty"`         // 模块数
	Manufacturer string     `json:"manufacturer,omitempty"` // 制造商
	ModelName    string     `json:"model_name,omitempty"`   // 内存型号
	SN           string     `json:"sn,omitempty"`           // 序列号
	Event        string     `json:"event,omitempty"`        // 事件 新增，丢失，移动
	EventMsg     string     `json:"event_msg,omitempty"`    // 事件信息
	RemovedAt    *time.Time `json:"removed_at,omitempty"`   // 移除时间
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
	Msg          string         `json:"msg,omitempty"`           // 错误信息
}

func NewMemory() *MemoryModel {
	return &MemoryModel{}
}

func (c *MemoryModel) ItemKey() string {
	return "memory"
}

func (mem *MemoryModel) RenderMemoryInfo() error {
	pterm.DefaultSection.WithLevel(2).Println("Memory Information")
	if mem.Msg != "" {
		pterm.Info.Println(mem.Msg)
	}
	// 内存概览信息
	summary := []pterm.BulletListItem{
		{Text: fmt.Sprintf("Total: %d MB", mem.Total), Bullet: "•"},
		{Text: fmt.Sprintf("Used: %d MB", mem.Used), Bullet: "•"},
		{Text: fmt.Sprintf("Available: %d MB", mem.Available), Bullet: "•"},
		{Text: fmt.Sprintf("Slots: %d", mem.Slots), Bullet: "•"},
		{Text: fmt.Sprintf("Type: %s", mem.Type), Bullet: "•"},
		{Text: fmt.Sprintf("Installed: %s", mem.Installed), Bullet: "•"},
	}
	if mem.Eec != "" {
		summary = append(summary, pterm.BulletListItem{Text: fmt.Sprintf("EEC: %s", mem.Eec), Bullet: "•"})
	}
	pterm.DefaultBulletList.WithItems(summary).Render()
	// 内存模块表格
	if len(mem.MemoryModule) > 0 {
		rows := make([][]string, 0, len(mem.MemoryModule)+1)
		rows = append(rows, []string{"Slot", "Device", "Type", "Size", "Speed", "Rank", "Manufacturer", "ModelName", "SN", "Event", "Event Msg"})
		
		for _, module := range mem.MemoryModule {
			event := module.Event
			eventMsg := module.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}
			rows = append(rows, []string{
				module.Slot,
				module.Device,
				module.Type,
				module.Size,
				module.Speed,
				module.Rank,
				module.Manufacturer,
				module.ModelName,
				module.SN,
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
