package packages

import (
	"encoding/json"
	"testing"
)

func TestNicGet(t *testing.T) {
	nics, err := NewNic().Get()

	if err != nil {
		t.Errorf("Error getting nics info: %v", err)
		return
	}

	// 将 c 转换为 JSON
	jsonData, err := json.Marshal(nics)
	if err != nil {
		t.Errorf("Failed to marshal nics data to JSON: %v", err)
	}

	// 输出 JSON 数据到测试日志
	t.Log(string(jsonData))
}
