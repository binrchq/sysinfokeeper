package packages

import (
	"encoding/json"
	"testing"
)

func TestDiskGet(t *testing.T) {
	disks, err := NewDisk().Get()
	if err != nil {
		t.Errorf("Error getting disk info: %v", err)
		return
	}

	// 将 c 转换为 JSON
	jsonData, err := json.Marshal(disks)
	if err != nil {
		t.Errorf("Failed to marshal CPU data to JSON: %v", err)
	}

	// 输出 JSON 数据到测试日志
	t.Log(string(jsonData))
}
