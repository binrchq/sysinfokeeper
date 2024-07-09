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

#### CPU
```json
{"cpu_infos":[{"info":"","model":"Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz","bits":64,"type":"","cache":"","min_max":"","cores":16,"flags":["fpu","vme","de","pse","tsc","msr","pae","mce","cx8","apic","sep","mtrr","pge","mca","cmov","pat","pse36","clflush","dts","acpi","mmx","fxsr","sse","sse2","ss","ht","tm","pbe","syscall","nx","pdpe1gb","rdtscp","lm","constant_tsc","arch_perfmon","pebs","bts","rep_good","nopl","xtopology","nonstop_tsc","cpuid","aperfmperf","pni","pclmulqdq","dtes64","monitor","ds_cpl","vmx","smx","est","tm2","ssse3","sdbg","fma","cx16","xtpr","pdcm","pcid","dca","sse4_1","sse4_2","x2apic","movbe","popcnt","tsc_deadline_timer","aes","xsave","avx","f16c","rdrand","lahf_lm","abm","3dnowprefetch","cpuid_fault","epb","cat_l3","cdp_l3","invpcid_single","pti","intel_ppin","ssbd","ibrs","ibpb","stibp","tpr_shadow","vnmi","flexpriority","ept","vpid","ept_ad","fsgsbase","tsc_adjust","bmi1","hle","avx2","smep","bmi2","erms","invpcid","rtm","cqm","rdt_a","rdseed","adx","smap","int
el_pt","xsaveopt","cqm_llc","cqm_occup_llc","cqm_mbm_total","cqm_mbm_local","dtherm","ida","arat","pln","pts","md_clear","flush_l1d"],"avg_speed":2080.5423505604267},{"info":"","model":"Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz","bits":64,"type":"","cache":"","min_max":"","cores":16,"flags":["fpu","vme","de","pse","tsc","msr","pae","mce","cx8","apic","sep","mtrr","pge","mca","cmov","pat","pse36","clflush","dts","acpi","mmx","fxsr","sse","sse2","ss","ht","tm","pbe","syscall","nx","pdpe1gb","rdtscp","lm","constant_tsc","arch_perfmon","pebs","bts","rep_good","nopl","xtopology","nonstop_tsc","cpuid","aperfmperf","pni","pclmulqdq","dtes64","monitor","ds_cpl","vmx","smx","est","tm2","ssse3","sdbg","fma","cx16","xtpr","pdcm","pcid","dca","sse4_1","sse4_2","x2apic","movbe","popcnt","tsc_deadline_timer","aes","xsave","avx","f16c","rdrand","lahf_lm","abm","3dnowprefetch","cpuid_fault","epb","cat_l3","cdp_l3","invpcid_single","pti","intel_ppin","ssbd","ibrs","ibpb","stibp","tpr_shadow","vnmi","flexpriority","ept","vpid
","ept_ad","fsgsbase","tsc_adjust","bmi1","hle","avx2","smep","bmi2","erms","invpcid","rtm","cqm","rdt_a","rdseed","adx","smap","intel_pt","xsaveopt","cqm_llc","cqm_occup_llc","cqm_mbm_total","cqm_mbm_local","dtherm","ida","arat","pln","pts","md_clear","flush_l1d"],"avg_speed":2890.1981649286154}],"core_speed":[1200,1200,2000,3600,3300,2700,1200,1200,3600,1300,1200,1200,1200,1200,1200,1200,1200,3600,1200,3600,2300,1200,2500,2320.811,1200,1200,1200,1500,1200,1200,1200,3600,1200,1200,2700,1200,2500,1200,1200,1200,3600,3500,3600,3600,1200,3600,1200,1200,1200,3600,1300,1200,1200,1200,1300,3400,2400,1600,2300,2500,1800,2300,3600]}
```

#### 内存
```json
{"used":6313744,"total":65809292,"available":59495548,"system_ram":65809292,"active":2,"slots":16,"type":"DDR4","installed":"64GB","capacity":"1024GB","eec":"Multi-bit ECC","part_capacity":"256 GB","part_number":4,"memory_module":[{"device":"P0_Node0_Channel0_Dimm0","size":"32 GB","speed":"2133 MT/s","installed":"yes","slot":"P1-DIMMA1","manufacturer":"Samsung","model_name":"M386A4G40DM0-CPB","sn":"73003AA6"},{"device":"P0_Node0_Channel0_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMA2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel1_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMB1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel1_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMB2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel2_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMC1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel2_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMC2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel3_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMD1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P0_Node0_Channel3_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P1-DIMMD2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel0_Dimm0","size":"32 GB","speed":"2133 MT/s","installed":"yes","slot":"P2-DIMME1","manufacturer":"Samsung","model_name":"M386A4G40DM0-CPB","sn":"73003AFD"},{"device":"P1_Node1_Channel0_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMME2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel1_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMF1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel1_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMF2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel2_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMG1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel2_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMG2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel3_Dimm0","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMH1","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"},{"device":"P1_Node1_Channel3_Dimm1","size":"No Module Installed","speed":"Unknown","installed":"no","slot":"P2-DIMMH2","manufacturer":"NO DIMM","model_name":"NO DIMM","sn":"NO DIMM"}]}
```