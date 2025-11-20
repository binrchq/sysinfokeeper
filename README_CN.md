# SysInfoKeeper

[EN](./README.md)

SysInfoKeeper 是一款面向 Linux/Unix 的硬件资产与漂移检测 CLI 工具。  
每次执行都会采集完整的硬件快照（CPU、内存、磁盘、网卡、GPU、风扇、传感器等），与存储在 SQLite 中的历史记录比对，并将设备标记为 **新增**、**移除**、**变更** 或 **位置调整**。CLI 支持渲染丰富的终端表格、输出 JSON/YAML，也可以作为守护进程持续记录硬件事件。

---
CPU
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628646256.jpg" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
MEM
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628551735.png" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
DISK
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628567628.png" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
GPU
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628559247.png" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
NETCARD
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628573878.png" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
FAN
<div style="flex: 1; text-align: center;">
  <img src="./readme_res/1763628853755.png" alt="设置界面" style="width: 100%; border-radius: 5px; box-shadow: 0 15px 40px rgba(0,0,0,0.2);">
</div>
## 功能亮点

- **精准的硬件发现**：整合 `lsblk`、`udevadm`、`dmidecode`、`smartctl`、`findmnt`、`pterm` 等工具，统一输出每个部件的规范视图。
- **磁盘基准测试**：在真实挂载点上执行校准后的 `dd` 测试（避开 tmpfs），并记录读/写吞吐与 SMART 数据。
- **事件追踪**：快照持久化在 SQLite，比较器会标记新增/移除/迁移，并保留完整时间线，便于审计。
- **留存策略**：默认保存 30 天历史（可通过 `sinfo retention` 调整），过期记录可自动或手动清理。
- **自动化友好**：支持多种输出格式（`graph`、`table`、`json`、`json-line`、`yaml`），按硬件类型筛选，分级输出 (`basic` / `advanced` / `full`)，并附带 systemd service 与 AppImage 打包脚本。

---

## 目录结构

```
.
├── cmd/sinfo/            # Cobra CLI 入口（root、clean、retention 等）
├── core/                 # 采集器、模型、数据库层、比较器
│   ├── hardware/         # 快照管理、DB 存储、调度器
│   ├── model/            # 渲染助手与 JSON 结构体
│   └── packages/         # CPU / RAM / Disk / GPU / NIC 采集逻辑
├── deployments/          # systemd 示例
├── tools/                # 调用图、构建脚本
├── LICENSE               # 双重许可策略（AGPLv3 + 商业协议）
├── LICENSE.AGPLv3        # AGPLv3 正文
└── LICENSE.COMMERCIAL    # 商业授权摘要
```

---

## 运行依赖

- Go 1.21 及以上（需启用模块模式）
- 常见 Linux 工具：`lsblk`、`dmidecode`、`smartctl`、`udevadm`、`findmnt`、`dd`、`dhclient`
- 可选：`appimagetool`、MinIO 客户端 `mc`（用于打包）、Graphviz（生成调用图）

---

## 快速开始

### 方式一 · 直接 `go run`

```bash
git clone https://github.com/binrchq/sysinfokeeper.git
cd sysinfokeeper

# 图形/表格模式
go run ./cmd/sinfo --output graph

# JSON 导出（可接入 CI/CD 或 SIEM）
go run ./cmd/sinfo --output json > snapshot.json

# 仅跟踪磁盘与网卡，输出高级信息
go run ./cmd/sinfo --target disk --target nic --level advanced
```

### 方式二 · 构建独立二进制

```bash
GO111MODULE=on go install binrc.com/sysinfokeeper/cmd/sinfo@latest
./sinfo --output table
```

默认数据库位于 `/var/lib/sysinfokeeper/hardware.db`，后续运行会自动与上一份快照对比并标记事件。

---

## 核心命令

| 命令 | 说明 |
|------|------|
| `sinfo` | 采集硬件信息、输出结果并写入快照。 |
| `sinfo clean` | 清理历史记录（支持 `--all`、`--inactive`、`--days`、`--type`、`--dry-run` 等）。 |
| `sinfo retention` | 查看或修改留存天数（默认 30 天）。 |
| `sinfo --output json` | 机器可读输出。 |
| `sinfo --target cpu --target memory` | 仅采集指定硬件类型。 |

无人值守场景可结合 cron/systemd，或使用 `core/hardware/scheduler.go` 中的调度器。

---

## 输出示例（JSON 摘要）

```json
{
  "cpu": {
    "cpu_infos": [
      {
        "model": "Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz",
        "cores": 16,
        "avg_speed": "2.05 GHz",
        "event": "changed",
        "event_msg": "Configuration changed: Max Speed: 2.30 -> 2.60 GHz"
      }
    ]
  },
  "disk": {
    "disk_infos": [
      {
        "device": "sda",
        "size": "953.9G",
        "read_speed": "468 MB/s",
        "write_speed": "444 MB/s",
        "mount_point": ["/", "/boot"],
        "event": "-",
        "removed_at": null
      },
      {
        "device": "loop0",
        "event": "removed",
        "event_msg": "Disk removed: loop0 (50.8M)",
        "removed_at": "2024-01-01T12:00:00Z"
      }
    ]
  }
}
```

---

## 构建与部署

```bash
# 标准 Go 二进制（模块路径方式）
go build binrc.com/sysinfokeeper/cmd/sinfo -o sinfo

# 生成 AppImage（需要 appimagetool 与 MinIO 凭据）
make appimage

# systemd 服务部署
sudo install -m644 deployments/sinfo.service /etc/systemd/system/sinfo.service
sudo systemctl enable --now sinfo
```

`build-appimage.sh` 与 `Makefile` 展示了项目的发行流程。

---

## 使用 `serve` 以 systemd 服务方式运行

仓库中已经提供了参考配置 `deployments/sinfo.service`。可将其复制到 `/etc/systemd/system/` 并按需修改，用于长时间运行 `sinfo serve` 调度任务：

```ini
[Unit]
Description=SysInfoKeeper Hardware Monitoring Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=sysinfokeeper
Group=sysinfokeeper
WorkingDirectory=/var/lib/sysinfokeeper
Environment=SINFO_INTERVAL=3600
Environment=SINFO_RETENTION=30
Environment=SINFO_SPEED_TEST=low
EnvironmentFile=-/etc/sysinfokeeper.env
ExecStart=/usr/local/bin/sinfo serve \
  --interval $SINFO_INTERVAL \
  --retention $SINFO_RETENTION \
  --speed-test $SINFO_SPEED_TEST
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

可以通过环境变量或 `/etc/sysinfokeeper.env` 覆盖 `interval`、`retention`、`speed-test` 等参数。`sinfo serve` 将常驻运行，不断采集并写入快照直至服务停止。

---

## 参与贡献

1. Fork & Clone 仓库。  
2. 开启 Go Modules（`GO111MODULE=on`）。  
3. 提交前请 `gofmt`/`goimports`，并运行 lint / test。  
4. 提交 Issue 时请尽量描述硬件环境（内核、发行版、存储拓扑、RAID 等）。

贡献默认遵循本项目的双重许可方案（见下文）。

---

## 许可证

SysInfoKeeper 采用双许可证模式：

- **开源方案**：基于 [GNU AGPLv3](LICENSE.AGPLv3)，适用于开源与可开源部署场景。
- **商业方案**：参考 [LICENSE.COMMERCIAL](LICENSE.COMMERCIAL)，适用于闭源、OEM 或 SaaS 等无需遵守 copyleft 的商业项目。

请阅读 [LICENSE](LICENSE) 以了解如何选择合适的许可并获取商业授权。如未签署商业协议，贡献与使用默认受 AGPLv3 约束。

如需商业授权，请按 `LICENSE.COMMERCIAL` 中的方式联系 BinRC。

---