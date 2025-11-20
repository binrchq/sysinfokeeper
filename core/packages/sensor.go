package packages

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"

	"binrc.com/sysinfokeeper/core/model"
)

type Sensor struct{} // TODO

func NewSensor() *Sensor {
	return &Sensor{}
}

// FanGet collects fan information using ipmitool
func (s *Sensor) FanGet() (*model.FanModel, error) {
	// Execute ipmitool command to get fan sensor data
	cmd := exec.Command("ipmitool", "sdr", "type", "fan")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return nil, fmt.Errorf("failed to execute ipmitool command: %w", err)
	}

	// Parse ipmitool output
	lines := strings.Split(out.String(), "\n")
	var fanInfos []model.FanInfo

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		parts := strings.FieldsFunc(line, func(r rune) bool {
			return r == '|'
		})
		if len(parts) < 5 {
			continue
		}

		name := strings.TrimSpace(parts[0])
		status := strings.TrimSpace(parts[2])
		speedStr := strings.TrimSpace(parts[4])

		fanInfos = append(fanInfos, model.FanInfo{
			Name:   name,
			Speed:  speedStr,
			Status: status,
		})
	}

	return &model.FanModel{FanInfos: fanInfos}, nil
}
