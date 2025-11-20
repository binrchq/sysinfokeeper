package model

import (
	"fmt"
	"strings"
	"time"

	"github.com/pterm/pterm"
)

type DiskInfo struct {
	Device       string     `json:"device"`               // 设备名
	Type         string     `json:"type"`                 // 磁盘类型 (ssd/hdd/sas)
	Size         string     `json:"size"`                 // 大小
	ReadSpeed    string     `json:"speed"`                // 读速度
	WriteSpeed   string     `json:"write_speed"`          // 写速度
	Usage        string     `json:"usage"`                // 使用空间
	Slot         string     `json:"slot"`                 // 插槽
	SysSymbol    string     `json:"sys_symbol"`           // 是否系统盘
	Manufacturer string     `json:"manufacturer"`         // 制造商
	ModelName    string     `json:"model_name"`           // 内存型号
	SN           string     `json:"sn"`                   // 序列号
	FwVersion    string     `json:"fw_version"`           // 固件版本
	Health       string     `json:"health"`               // 状态
	BadBlocks    int        `json:"bad_blocks"`           // 坏道数量
	MountPoint   []string   `json:"mount_point"`          // 挂载点
	Event        string     `json:"event"`                // 事件 新增，丢失，移动
	EventMsg     string     `json:"event_msg"`            // 事件信息
	RemovedAt    *time.Time `json:"removed_at,omitempty"` // 移除时间
}

type DiskModel struct {
	DiskInfos []DiskInfo `json:"disk_infos" gorm:"-"` // Ignored by both GORM and JSON
	Used      string     `json:"used"`                // 使用的磁盘空间
	Total     string     `json:"total"`               // 总空间
	Available string     `json:"available"`           // 可用空间
	Msg       string     `json:"msg"`                 // 消息
}

func NewDiskModel() *DiskModel {
	return &DiskModel{}
}

func (c *DiskModel) ItemKey() string {
	return "disk"
}

func (disk *DiskModel) RenderDiskInfo() error {
	pterm.DefaultSection.WithLevel(2).Println("Disk Information")
	if disk.Msg != "" {
		pterm.Info.Println(disk.Msg)
	}
	// 磁盘概览
	summary := []pterm.BulletListItem{
		{Text: fmt.Sprintf("Total: %s", disk.Total), Bullet: "•"},
		{Text: fmt.Sprintf("Used: %s", disk.Used), Bullet: "•"},
		{Text: fmt.Sprintf("Available: %s", disk.Available), Bullet: "•"},
	}
	pterm.DefaultBulletList.WithItems(summary).Render()
	// 磁盘详情表格
	if len(disk.DiskInfos) > 0 {
		rows := make([][]string, 0, len(disk.DiskInfos)+1)
		rows = append(rows, []string{
			"Slot", "Device", "Type", "Size", "Read Speed", "Write Speed", "Usage", "Sys Disk", "Manufacturer", "Model", "SN", "FW Version", "Health", "Bad Blocks", "Mount Points", "Event", "Event Msg",
		})

		for _, d := range disk.DiskInfos {
			mountPoints := strings.Join(d.MountPoint, ",")
			event := d.Event
			eventMsg := d.EventMsg
			if event == "" {
				event = "-"
				eventMsg = "-"
			}
			rows = append(rows, []string{
				d.Slot,
				d.Device,
				d.Type,
				d.Size,
				d.ReadSpeed,
				d.WriteSpeed,
				d.Usage,
				d.SysSymbol,
				d.Manufacturer,
				d.ModelName,
				d.SN,
				d.FwVersion,
				d.Health,
				fmt.Sprintf("%d", d.BadBlocks),
				mountPoints,
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
