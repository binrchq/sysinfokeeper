package constants

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
)

const (
	DOMAIN = "http://brc.local"
)

var (
	BASE_DIR        = "/usr/local/dialmainer/"
	DEV_CONFIG_FILE = fmt.Sprintf("%s/configs/config.toml", BASE_DIR)
	DEV_DB_FILE     = fmt.Sprintf("%s/dialer.db", BASE_DIR)
)

func init() {
	root := os.Getenv("DIALER_BASE_ROOT")
	if root != "" {
		BASE_DIR = root
	} else {
		// 执行`go list -m -f "{{.Dir}}"`命令来获取当前模块的根目录
		cmd := exec.Command("go", "list", "-m", "-f", "{{.Dir}}")
		output, err := cmd.Output()
		if err != nil {
			//日志
			log.Println("获取当前模块的根目录失败:", err)
			return
		}
		// 将输出转换为字符串并去除可能的空白字符
		BASE_DIR = strings.TrimSpace(string(output))
	}
	// 设置默认的配置文件路径
	DEV_CONFIG_FILE = fmt.Sprintf("%s/configs/config.toml", BASE_DIR)
	DEV_DB_FILE = fmt.Sprintf("%s/dialer.db", BASE_DIR)
}
