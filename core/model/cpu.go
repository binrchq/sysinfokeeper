package model

import (
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/pterm/pterm"
)

type CpuInfo struct {
	Info      string     `json:"info"                 gorm:"column:info"`      // 信息
	ModelName string     `json:"model"                gorm:"column:model"`     // 型号
	Bits      int        `json:"bits"                 gorm:"column:bits"`      // 位数
	Type      string     `json:"type"                 gorm:"column:type"`      // 类型
	Cache     string     `json:"cache"                gorm:"column:cache"`     // 缓存
	MinSpeed  float64    `json:"min_speed"            gorm:"column:min_speed"` // 最大基准频率
	MaxSpeed  float64    `json:"max_speed"            gorm:"column:max_speed"` // 最小基准频率
	Cores     int        `json:"cores"                gorm:"column:cores"`     // 核心数
	Flags     []string   `json:"flags"                gorm:"-"`                // Ignored by both GORM and JSON
	AvgSpeed  float64    `json:"avg_speed"            gorm:"-"`
	Event     string     `json:"event"`                // 事件 新增，丢失，移动
	EventMsg  string     `json:"event_msg"`            // 事件信息
	RemovedAt *time.Time `json:"removed_at,omitempty"` // 移除时间
}

type CpuModel struct {
	CpuInfos  []CpuInfo `json:"cpu_infos"  gorm:"-"` // Ignored by both GORM and JSON
	CoreSpeed []float64 `json:"core_speed" gorm:"-"` // Ignored by both GORM and JSON
	Msg       string    `json:"msg"        gorm:"-"`
}

func NewCpu() *CpuModel {
	return &CpuModel{}
}

func (c *CpuModel) ItemKey() string {
	return "cpu"
}

func (c *CpuModel) RenderCPUInfo() {
	c.RenderCPUInfoWithLevel("basic")
}

func (c *CpuModel) RenderCPUInfoWithLevel(level string) {
	pterm.DefaultSection.WithLevel(2).Println("CPU Information")
	if c.Msg != "" {
		pterm.Info.Println(c.Msg)
	}
	c.DrawCpuHeatmap()
	renderCPUTable(c.CpuInfos, level)
}

func renderCPUTable(cpus []CpuInfo, level string) {
	// 根据等级决定显示哪些列
	header := []string{
		"CPU", "Model", "Cores/Threads", "Base Clock", "Freq Range",
		"Avg Speed",
	}

	// advanced 和 full 级别显示更多信息
	if level == "advanced" || level == "full" {
		header = append(header, "Type", "Cache")
	}

	// 如果有事件，显示事件信息
	hasEvent := false
	for _, cpu := range cpus {
		if cpu.Event != "" {
			hasEvent = true
			break
		}
	}
	if hasEvent {
		header = append(header, "Event", "Event Msg")
	}

	data := [][]string{header}

	flags := make([][]string, len(cpus))
	for i, cpu := range cpus {
		coreThread := fmt.Sprintf("%dC/%dT", cpu.Cores, cpu.Cores*2)
		baseClock := fmt.Sprintf("%.2f GHz", cpu.MaxSpeed/1000/1000)
		freqRange := fmt.Sprintf("%.2f - %.2f GHz", cpu.MinSpeed/1000/1000, cpu.MaxSpeed/1000/1000)
		avgSpeed := fmt.Sprintf("%.2f GHz", cpu.AvgSpeed/1000)

		flags[i] = cpu.Flags

		row := []string{
			fmt.Sprintf("CPU%d", i+1),
			cpu.ModelName,
			coreThread,
			baseClock,
			freqRange,
			avgSpeed,
		}

		// advanced 和 full 级别添加更多信息
		if level == "advanced" || level == "full" {
			row = append(row, cpu.Type, cpu.Cache)
		}

		// 如果有事件，添加事件信息
		if hasEvent {
			event := cpu.Event
			eventMsg := cpu.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}
			row = append(row, event, eventMsg)
		}

		data = append(data, row)
	}

	// 渲染表格
	pterm.DefaultTable.
		WithHasHeader().
		WithSeparator(" │ ").
		WithBoxed(true).
		WithData(data).
		Render()

	// 只在 full 级别显示 flags
	if level == "full" {
		for i, flag := range flags {
			if len(flag) > 0 {
				pterm.Println(fmt.Sprintf("CPU%d", i+1) + ": " + strings.Join(flag, " "))
			}
		}
	}
}

func calcColsRows(total int) (cols, rows int) {
	termWidth := pterm.GetTerminalWidth() / 2

	maxLabel := fmt.Sprintf("C%d", total-1)
	cellWidth := len(maxLabel) + 6

	idealCols := termWidth / cellWidth
	if idealCols < 1 {
		idealCols = 1
	}
	if idealCols > total {
		idealCols = total
	}

	// 找最大因子，使其 <= idealCols 且能整除 total
	cols = 1
	for c := idealCols; c >= 1; c-- {
		if total%c == 0 {
			cols = c
			break
		}
	}

	rows = total / cols
	return
}

func (cpu *CpuModel) DrawCpuHeatmap() {
	// 获取CPU核心数量
	total := len(cpu.CoreSpeed)
	// 如果没有核心数据，则输出警告信息
	if total == 0 {
		pterm.Warning.Println("No core speed data to display.")
		return
	}
	// 设置热力图样式
	// 计算热力图行列数
	cols, rows := calcColsRows(total)

	// 6. 构造热力图数据与坐标轴
	data := make([][]float32, rows)
	axis := pterm.HeatmapAxis{XAxis: make([]string, cols),
		YAxis: make([]string, rows)}

	for r := 0; r < rows; r++ {
		//如果是最后一个元素
		data[r] = make([]float32, cols)
		axis.YAxis[r] = fmt.Sprintf("R%d", r)
		for c := 0; c < cols; c++ {
			idx := r*cols + c
			if idx < len(cpu.CoreSpeed) {
				// 计算热力图数据
				// value := (cpu.CoreSpeed[idx] - cpu.CpuInfos[0].MinSpeed/1000) / cpu.CpuInfos[0].MaxSpeed * 100 * 1000
				rounded := math.Round(float64(cpu.CoreSpeed[idx])*100) / 100
				data[r][c] = float32(rounded)
			}
			if r == 0 {
				axis.XAxis[c] = fmt.Sprintf("%d", c)
			}
		}
	}
	// 7. 渲染热力图
	pterm.DefaultHeatmap.WithData(data).WithBoxed(false).WithAxisData(axis).WithColors(
		// pterm.BgBlack,
		pterm.BgBlue,
		pterm.BgCyan,
		pterm.BgGreen,
		pterm.BgYellow,
		pterm.BgLightRed,
		pterm.BgRed,
		pterm.BgMagenta,
		pterm.BgWhite,
	).WithLegend(false).WithGrid(false).Render()

}
