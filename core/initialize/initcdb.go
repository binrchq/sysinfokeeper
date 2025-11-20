package initialize

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"

	"binrc.com/sysinfokeeper/core/model"

	"github.com/rs/zerolog/log"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	cdb    *gorm.DB
	db_url = "/var/lib/sysinfokeeper/hardware.db" // 默认数据库路径
)

func InitCDB() (*gorm.DB, error) {
	var db *gorm.DB
	var err error

	// 使用 SQLite
	db, err = initSQLite()
	if err != nil {
		return nil, err
	}

	// 初始化硬件相关表
	if err := migrateTables(db,
		&model.HardwareRecord{},
		&model.HardwareConfig{},
	); err != nil {
		return nil, err
	}

	cdb = db
	return cdb, nil
}

func initSQLite() (*gorm.DB, error) {
	if _, err := os.Stat(db_url); os.IsNotExist(err) {
		directory := filepath.Dir(db_url)
		if err := os.MkdirAll(directory, 0755); err != nil {
			// 创建目录失败，输出错误信息并退出程序
			log.Fatal().Caller().Err(err).Msgf(fmt.Sprintf("无法创建目录：%s", directory))
		}
		if _, err := os.Create(db_url); err != nil {
			return nil, fmt.Errorf("failed to create SQLite database: %s", err)
		}
	}
	db, err := gorm.Open(sqlite.Open(db_url), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to open SQLite database: %s", err)
	}
	return db, nil
}

func getTableName(model interface{}) string {
	// 通过反射获取结构体的类型
	t := reflect.TypeOf(model)
	// 如果是指针类型，取其指向的类型
	if t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	// 返回结构体类型的名称作为表名
	return t.Name()
}

func migrateTables(db *gorm.DB, models ...interface{}) error {
	for _, model := range models {
		tableName := getTableName(model)
		if err := db.AutoMigrate(model); err != nil {
			return fmt.Errorf("failed to migrate table[%s]: %s", tableName, err)
		}
	}
	return nil
}
