package packages

import (
	"os/exec"
	"strings"

	"binrc.com/sysinfokeeper/core/model"
)

type Gpu struct{}

func NewGpu() *Gpu {
	return &Gpu{}
}

func (g *Gpu) Get() (*model.GpuModel, error) {
	gpuModel := model.NewGpu()

	// 1. 优先 NVIDIA
	if out, err := exec.Command("nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader,nounits").Output(); err == nil {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			if strings.TrimSpace(line) == "" {
				continue
			}
			parts := strings.Split(line, ",")
			if len(parts) < 2 {
				continue
			}
			gpuModel.GpuInfos = append(gpuModel.GpuInfos, model.GpuInfo{
				ModelName: strings.TrimSpace(parts[0]),
				Memory:    strings.TrimSpace(parts[1]) + " MiB",
				Type:      "NVIDIA",
			})
		}
		return gpuModel, nil
	}

	// 2. 尝试 ROCm (AMD)
	if out, err := exec.Command("rocm-smi").Output(); err == nil {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			if strings.Contains(line, "GPU") && strings.Contains(line, "MiB") {
				gpuModel.GpuInfos = append(gpuModel.GpuInfos, model.GpuInfo{
					Info:      strings.TrimSpace(line),
					ModelName: "AMD GPU",
					Memory:    g.extractMemoryFromLine(line),
					Type:      "AMD",
				})
			}
		}
		if len(gpuModel.GpuInfos) > 0 {
			return gpuModel, nil
		}
	}

	// 3. 通用 Fallback：lspci
	if out, err := exec.Command("lspci").Output(); err == nil {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines {
			lower := strings.ToLower(line)
			if strings.Contains(lower, "vga") || strings.Contains(lower, "3d") {
				gpuModel.GpuInfos = append(gpuModel.GpuInfos, model.GpuInfo{
					Info:      strings.TrimSpace(line),
					ModelName: g.extractModelName(line),
					Type:      g.detectGpuType(line),
				})
			}
		}
	}

	return gpuModel, nil
}

func (g *Gpu) extractModelName(info string) string {
	if idx := strings.Index(info, ":"); idx != -1 {
		return strings.TrimSpace(info[idx+1:])
	}
	return strings.TrimSpace(info)
}

func (g *Gpu) extractMemoryFromLine(line string) string {
	// 简单抓取 "xxxx MiB" 作为显存
	parts := strings.Fields(line)
	for _, p := range parts {
		if strings.HasSuffix(p, "MiB") {
			return p
		}
	}
	return ""
}

func (g *Gpu) detectGpuType(info string) string {
	l := strings.ToLower(info)
	switch {
	case strings.Contains(l, "nvidia"):
		return "NVIDIA"
	case strings.Contains(l, "amd"), strings.Contains(l, "advanced micro"):
		return "AMD"
	case strings.Contains(l, "intel"):
		return "Intel"
	default:
		return "Unknown"
	}
}
