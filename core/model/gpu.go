package model

import (
	"fmt"
	"strings"
	"time"

	"github.com/pterm/pterm"
)

type GpuInfo struct {
	Info      string     `json:"info" gorm:"column:info"`     // Information
	ModelName string     `json:"model" gorm:"column:model"`   // Model Name
	Memory    string     `json:"memory" gorm:"column:memory"` // Memory Size
	Type      string     `json:"type" gorm:"column:type"`     // Type
	Cores     int        `json:"cores" gorm:"column:cores"`   // Number of Cores
	Flags     []string   `json:"flags" gorm:"-"`              // Ignored by both GORM and JSON
	AvgSpeed  float64    `json:"avg_speed" gorm:"-"`
	Event     string     `json:"event"`     // 事件 新增，丢失，移动
	EventMsg  string     `json:"event_msg"` // 事件信息
	RemovedAt *time.Time `json:"removed_at,omitempty"` // 移除时间
}

type GpuModel struct {
	GpuInfos  []GpuInfo `json:"gpu_infos" gorm:"-"`  // Ignored by both GORM and JSON
	CoreSpeed []float64 `json:"core_speed" gorm:"-"` // Ignored by both GORM and JSON
	Msg       string    `json:"msg" gorm:"-"`
	Info      string    `json:"info"`
	Type      string    `json:"type"` // NVIDIA, AMD, Intel, Unknown
}

// NewGpu creates and returns a new instance of GpuModel
func NewGpu() *GpuModel {
	return &GpuModel{}
}

// ItemKey returns a unique key for identifying the GpuModel
func (g *GpuModel) ItemKey() string {
	return "gpu"
}

func (gpu *GpuModel) RenderGpuInfo() error {
	pterm.DefaultSection.WithLevel(2).Println("GPU Information")
	if gpu.Msg != "" {
		pterm.Info.Println(gpu.Msg)
	}
	// GPU 概览
	summary := []pterm.BulletListItem{
		{Text: fmt.Sprintf("Total GPUs: %d", len(gpu.GpuInfos)), Bullet: "•"},
		{Text: fmt.Sprintf("Type: %s", gpu.Type), Bullet: "•"},
	}
	if gpu.Info != "" {
		summary = append(summary, pterm.BulletListItem{Text: fmt.Sprintf("Info: %s", gpu.Info), Bullet: "•"})
	}
	pterm.DefaultBulletList.WithItems(summary).Render()
	// GPU 详情表格
	if len(gpu.GpuInfos) > 0 {
		rows := make([][]string, 0, len(gpu.GpuInfos)+1)
		rows = append(rows, []string{
			"Index", "Type", "Model", "Memory", "Cores", "Avg Speed (MHz)", "Flags", "Info", "Event", "Event Msg",
		})

		for i, g := range gpu.GpuInfos {
			event := g.Event
			eventMsg := g.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}
			rows = append(rows, []string{
				fmt.Sprintf("%d", i),
				g.Type,
				g.ModelName,
				g.Memory,
				fmt.Sprintf("%d", g.Cores),
				fmt.Sprintf("%.2f", g.AvgSpeed),
				strings.Join(g.Flags, ", "),
				strings.ReplaceAll(g.Info, "\n", " "),
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
