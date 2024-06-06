# sysinfokeeper

`sysinfokeeper` 是一个用于收集和报告系统信息的工具，支持多种 Linux 发行版。该工具可以自动配置网络，并将系统信息存储到 SQLite 数据库中。

## 功能

- 自动配置网络（使用 DHCP 获取 IP 地址）
- 收集内存、硬盘、CPU、主板、GPU、网卡等硬件信息
- 将系统信息存储到 SQLite 数据库
- 支持信息变动上报
- 提供命令行接口和交互模式
- 支持多种 CPU 架构（默认 `amd64`，支持 `arm64` 等）
- 构建生成的 AppImage 文件，并推送到 MinIO 存储桶

## 目录结构
```
├── build-appimage.sh # 构建 AppImage 的脚本
├── syskeeper.service # systemd 服务文件
├── Makefile # 构建和推送的 Makefile
├── README.md # 本文档
├── path/to/your/config/file # 配置文件路径（示例路径，需要替换）
└── src # 项目源代码目录
```

## 依赖

- Go 编程语言
- `appimagetool` 工具
- MinIO 客户端 `mc`

## 使用方法

### 克隆项目

```bash
git clone https://git.c.bitrec.ai/bitrec/sysinfokeeper.git
cd sysinfokeeper
```
### 构建和推送
通过 Makefile 你可以轻松地构建和推送 AppImage 文件到 MinIO。

### 构建和推送 amd64 架构的默认版本
```bash
make all
```

### 构建和推送指定版本和架构
```bash
make VERSION=1.0.0 ARCH=arm64
```

### 构建和推送指定版本的 amd64 架构
```bash
make VERSION=1.0.0
```

### 清理构建输出
```bash
make clean
```
### 推送到 MinIO
在 Makefile 中配置了推送逻辑，将生成的 AppImage 文件推送到指定的 MinIO 存储桶的 app 目录中：

```makefile
push:
	@echo "Pushing $(APP_NAME)-$(VERSION)-$(ARCH).AppImage to MinIO..."
	mc alias set minio $(MINIO_ENDPOINT) $(MINIO_ACCESS_KEY) $(MINIO_SECRET_KEY)
	mc mb minio/$(MINIO_BUCKET)
	mc cp $(OUTPUT_DIR)/$(APP_NAME)-$(VERSION)-$(ARCH).AppImage minio/$(MINIO_BUCKET)/app/
```