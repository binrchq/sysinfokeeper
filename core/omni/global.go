package omni

import (
	operationsys "os"

	"binrc.com/sysinfokeeper/configs"

	"github.com/shirou/gopsutil/process"
	"gorm.io/gorm"
)

var (
	Config  *configs.Config  // 全局配置
	Process *process.Process //进程号
	DB      *gorm.DB         // 数据库
	Mode    string           // 运行模式
)

func init() {
	p, err := process.NewProcess(int32(operationsys.Getpid()))
	if err != nil {
		panic(err)
	}
	Process = p
}

func GetDB() *gorm.DB {
	return DB
}
