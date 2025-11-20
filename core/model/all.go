package model

import (
	"encoding/json"

	"github.com/bitly/go-simplejson"
)

type SInfo struct {
	Cpu    CpuModel
	Disk   DiskModel
	Memory MemoryModel
	Gpu    GpuModel
	Nic    NicModel
	Fan    FanModel
}

func NewSInfo() *SInfo {
	return &SInfo{}
}

// 自定义序列化
func (a *SInfo) MarshalJSON() ([]byte, error) {
	// 构造一个动态 key 的 map
	m := map[string]interface{}{
		a.Cpu.ItemKey():    a.Cpu,
		a.Disk.ItemKey():   a.Disk,
		a.Memory.ItemKey(): a.Memory,
		a.Gpu.ItemKey():    a.Gpu,
		a.Nic.ItemKey():    a.Nic,
		a.Fan.ItemKey():    a.Fan,
	}
	return json.Marshal(m)
}

func (a *SInfo) ToSimpleJson() *simplejson.Json {
	js := simplejson.New()

	// 只设置非空的硬件信息（包括有移除设备的）
	if len(a.Cpu.CpuInfos) > 0 || a.Cpu.Msg != "" {
		js.Set(a.Cpu.ItemKey(), a.Cpu)
	}
	if len(a.Disk.DiskInfos) > 0 || a.Disk.Msg != "" {
		js.Set("disk", a.Disk)
	}
	if len(a.Memory.MemoryModule) > 0 || a.Memory.Msg != "" {
		js.Set("memory", a.Memory)
	}
	if len(a.Gpu.GpuInfos) > 0 || a.Gpu.Msg != "" {
		js.Set("gpu", a.Gpu)
	}
	if len(a.Nic.NicInfos) > 0 || a.Nic.Msg != "" {
		js.Set("nic", a.Nic)
	}
	if len(a.Fan.FanInfos) > 0 || a.Fan.Msg != "" {
		js.Set("fan", a.Fan)
	}

	return js
}
