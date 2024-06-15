package utils

import (
	"testing"
)

func TestReader(t *testing.T) {
	rows, err := Reader("/proc/cpuinfo", false, nil)
	if err != nil {
		t.Error(err)
	}
	for _, row := range rows.([]string) {
		t.Log(row)
	}

	// t.Log(rows)
}
