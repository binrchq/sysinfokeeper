package packages

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type Swap struct{}

func NewSwap() *Swap {
	return &Swap{}
}

type SwapInfo struct {
	Device     string `json:"device"`     // 设备路径
	Type       string `json:"type"`       // 类型 (partition/file)
	Size       string `json:"size"`       // 大小
	Used       string `json:"used"`       // 已使用
	Priority   int    `json:"priority"`   // 优先级
	UUID       string `json:"uuid"`       // UUID
	Label      string `json:"label"`      // 标签
	Filesystem string `json:"filesystem"` // 文件系统类型
}

type SwapModel struct {
	SwapInfos []SwapInfo `json:"swap_infos"`
	Total     string     `json:"total"` // 总交换空间
	Used      string     `json:"used"`  // 已使用
	Free      string     `json:"free"`  // 可用
	Msg       string     `json:"msg"`   // 错误信息
}

func NewSwapModel() *SwapModel {
	return &SwapModel{}
}

func (s *Swap) Get() (*SwapModel, error) {
	model := NewSwapModel()

	// 从 /proc/swaps 读取交换分区信息
	swapInfos, err := s.readProcSwaps()
	if err != nil {
		model.Msg = err.Error()
		return model, err
	}

	// 获取 UUID 和 Label
	for i := range swapInfos {
		s.enrichSwapInfo(&swapInfos[i])
	}

	model.SwapInfos = swapInfos

	// 计算总计
	var totalSize, usedSize float64
	for _, swap := range swapInfos {
		if size, err := parseSize(swap.Size); err == nil {
			totalSize += size
		}
		if used, err := parseSize(swap.Used); err == nil {
			usedSize += used
		}
	}

	model.Total = formatSize(totalSize)
	model.Used = formatSize(usedSize)
	model.Free = formatSize(totalSize - usedSize)

	return model, nil
}

func (s *Swap) readProcSwaps() ([]SwapInfo, error) {
	file, err := os.Open("/proc/swaps")
	if err != nil {
		return nil, fmt.Errorf("failed to open /proc/swaps: %w", err)
	}
	defer file.Close()

	var swaps []SwapInfo
	scanner := bufio.NewScanner(file)
	lineNum := 0

	for scanner.Scan() {
		lineNum++
		line := strings.TrimSpace(scanner.Text())

		// 跳过标题行
		if lineNum == 1 || line == "" {
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}

		swapInfo := SwapInfo{
			Device: fields[0],
		}

		// 判断类型
		if strings.HasPrefix(swapInfo.Device, "/") {
			if strings.Contains(swapInfo.Device, "swap") ||
				strings.Contains(swapInfo.Device, "SWAP") {
				swapInfo.Type = "partition"
			} else {
				swapInfo.Type = "file"
			}
		} else {
			swapInfo.Type = "partition"
		}

		// 解析大小（KB）
		if sizeKB, err := strconv.ParseFloat(fields[1], 64); err == nil {
			swapInfo.Size = formatSize(sizeKB * 1024)
		}

		// 解析已使用（KB）
		if usedKB, err := strconv.ParseFloat(fields[2], 64); err == nil {
			swapInfo.Used = formatSize(usedKB * 1024)
		}

		// 解析优先级
		if len(fields) >= 4 {
			if priority, err := strconv.Atoi(fields[3]); err == nil {
				swapInfo.Priority = priority
			}
		}

		swaps = append(swaps, swapInfo)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading /proc/swaps: %w", err)
	}

	return swaps, nil
}

func (s *Swap) enrichSwapInfo(swap *SwapInfo) {
	// 尝试获取 UUID 和 Label
	if swap.Type == "partition" {
		// 使用 blkid 获取 UUID 和 LABEL
		cmd := exec.Command("blkid", swap.Device)
		output, err := cmd.Output()
		if err == nil {
			outputStr := string(output)
			// 解析 UUID=xxx LABEL=xxx TYPE=xxx
			if strings.Contains(outputStr, "UUID=") {
				parts := strings.Fields(outputStr)
				for _, part := range parts {
					if strings.HasPrefix(part, "UUID=") {
						swap.UUID = strings.Trim(strings.TrimPrefix(part, "UUID="), "\"")
					} else if strings.HasPrefix(part, "LABEL=") {
						swap.Label = strings.Trim(strings.TrimPrefix(part, "LABEL="), "\"")
					} else if strings.HasPrefix(part, "TYPE=") {
						swap.Filesystem = strings.Trim(strings.TrimPrefix(part, "TYPE="), "\"")
					}
				}
			}
		}
	}
}
