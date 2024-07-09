package packages

import (
	"encoding/json"
	"testing"

	"bitrec.ai/systemkeeper/core/beforehand"
)

func TestGetM(t *testing.T) {
	beforehand.SetSystemFiles()
	beforehand.SetDmidecodeCmd()
	c, _ := NewRam().Get()

	// 将 c 转换为 JSON
	jsonData, err := json.Marshal(c)
	if err != nil {
		t.Errorf("Failed to marshal Mem data to JSON: %v", err)
	}

	// 输出 JSON 数据到测试日志
	t.Log(string(jsonData))
}
