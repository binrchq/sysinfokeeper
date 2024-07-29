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
```json
./sinfo --json
{
   "cpu": {
      "core_speed": [
         2300,
         1200,
         2200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         2300,
         1200,
         1200,
         2400,
         1200,
         1200,
         1833.722,
         1200,
         1200,
         1200,
         1914.99,
         1200,
         1200,
         3200,
         1400,
         2300,
         1200,
         1200,
         2300,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1200,
         1800,
         1200,
         3000,
         2200,
         2500,
         2300,
         1400,
         1200,
         2300,
         2300,
         1200,
         2100,
         2100,
         1200,
         2200,
         2200
      ],
      "cpu_infos": [
         {
            "avg_speed": 1200.067141605541,
            "bits": 64,
            "cache": "",
            "cores": 16,
            "flags": [
               "fpu",
               "vme",
               "de",
               "pse",
               "tsc",
               "msr",
               "pae",
               "mce",
               "cx8",
               "apic",
               "sep",
               "mtrr",
               "pge",
               "mca",
               "cmov",
               "pat",
               "pse36",
               "clflush",
               "dts",
               "acpi",
               "mmx",
               "fxsr",
               "sse",
               "sse2",
               "ss",
               "ht",
               "tm",
               "pbe",
               "syscall",
               "nx",
               "pdpe1gb",
               "rdtscp",
               "lm",
               "constant_tsc",
               "arch_perfmon",
               "pebs",
               "bts",
               "rep_good",
               "nopl",
               "xtopology",
               "nonstop_tsc",
               "cpuid",
               "aperfmperf",
               "pni",
               "pclmulqdq",
               "dtes64",
               "monitor",
               "ds_cpl",
               "vmx",
               "smx",
               "est",
               "tm2",
               "ssse3",
               "sdbg",
               "fma",
               "cx16",
               "xtpr",
               "pdcm",
               "pcid",
               "dca",
               "sse4_1",
               "sse4_2",
               "x2apic",
               "movbe",
               "popcnt",
               "tsc_deadline_timer",
               "aes",
               "xsave",
               "avx",
               "f16c",
               "rdrand",
               "lahf_lm",
               "abm",
               "3dnowprefetch",
               "cpuid_fault",
               "epb",
               "cat_l3",
               "cdp_l3",
               "invpcid_single",
               "pti",
               "intel_ppin",
               "ssbd",
               "ibrs",
               "ibpb",
               "stibp",
               "tpr_shadow",
               "vnmi",
               "flexpriority",
               "ept",
               "vpid",
               "ept_ad",
               "fsgsbase",
               "tsc_adjust",
               "bmi1",
               "hle",
               "avx2",
               "smep",
               "bmi2",
               "erms",
               "invpcid",
               "rtm",
               "cqm",
               "rdt_a",
               "rdseed",
               "adx",
               "smap",
               "intel_pt",
               "xsaveopt",
               "cqm_llc",
               "cqm_occup_llc",
               "cqm_mbm_total",
               "cqm_mbm_local",
               "dtherm",
               "ida",
               "arat",
               "pln",
               "pts",
               "md_clear",
               "flush_l1d"
            ],
            "info": "",
            "min_max": "",
            "model": "Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz",
            "type": ""
         },
         {
            "avg_speed": 2048.569671182886,
            "bits": 64,
            "cache": "",
            "cores": 16,
            "flags": [
               "fpu",
               "vme",
               "de",
               "pse",
               "tsc",
               "msr",
               "pae",
               "mce",
               "cx8",
               "apic",
               "sep",
               "mtrr",
               "pge",
               "mca",
               "cmov",
               "pat",
               "pse36",
               "clflush",
               "dts",
               "acpi",
               "mmx",
               "fxsr",
               "sse",
               "sse2",
               "ss",
               "ht",
               "tm",
               "pbe",
               "syscall",
               "nx",
               "pdpe1gb",
               "rdtscp",
               "lm",
               "constant_tsc",
               "arch_perfmon",
               "pebs",
               "bts",
               "rep_good",
               "nopl",
               "xtopology",
               "nonstop_tsc",
               "cpuid",
               "aperfmperf",
               "pni",
               "pclmulqdq",
               "dtes64",
               "monitor",
               "ds_cpl",
               "vmx",
               "smx",
               "est",
               "tm2",
               "ssse3",
               "sdbg",
               "fma",
               "cx16",
               "xtpr",
               "pdcm",
               "pcid",
               "dca",
               "sse4_1",
               "sse4_2",
               "x2apic",
               "movbe",
               "popcnt",
               "tsc_deadline_timer",
               "aes",
               "xsave",
               "avx",
               "f16c",
               "rdrand",
               "lahf_lm",
               "abm",
               "3dnowprefetch",
               "cpuid_fault",
               "epb",
               "cat_l3",
               "cdp_l3",
               "invpcid_single",
               "pti",
               "intel_ppin",
               "ssbd",
               "ibrs",
               "ibpb",
               "stibp",
               "tpr_shadow",
               "vnmi",
               "flexpriority",
               "ept",
               "vpid",
               "ept_ad",
               "fsgsbase",
               "tsc_adjust",
               "bmi1",
               "hle",
               "avx2",
               "smep",
               "bmi2",
               "erms",
               "invpcid",
               "rtm",
               "cqm",
               "rdt_a",
               "rdseed",
               "adx",
               "smap",
               "intel_pt",
               "xsaveopt",
               "cqm_llc",
               "cqm_occup_llc",
               "cqm_mbm_total",
               "cqm_mbm_local",
               "dtherm",
               "ida",
               "arat",
               "pln",
               "pts",
               "md_clear",
               "flush_l1d"
            ],
            "info": "",
            "min_max": "",
            "model": "Intel(R) Xeon(R) CPU E5-2697A v4 @ 2.60GHz",
            "type": ""
         }
      ]
   },
   "disk": {
      "available": "1.78T",
      "disk_infos": [
         {
            "bad_blocks": 0,
            "device": "sda",
            "fw_version": "MU03",
            "health": "Good",
            "manufacturer": "Crucial/Micron Client SSDs",
            "model_name": "Micron_M600_MTFD",
            "mount_point": [
               "/boot",
               "/"
            ],
            "size": "953.9G",
            "slot": "/dev/sda",
            "sn": "160511B083F6",
            "speed": "468 MB/s",
            "sys_symbol": "yes",
            "type": "hdd",
            "usage": "59.35G",
            "write_speed": "444 MB/s"
         },
         {
            "bad_blocks": 0,
            "device": "sdb",
            "fw_version": "1A01",
            "health": "Good",
            "manufacturer": "Western Digital Blue Mobile (SMR)",
            "model_name": "WDC WD10SPZX-00Z",
            "mount_point": null,
            "size": "931.5G",
            "slot": "/dev/sdb",
            "sn": "WD-WX32A32J71TL",
            "speed": "111 MB/s",
            "sys_symbol": "no",
            "type": "hdd",
            "usage": "0.00B",
            "write_speed": "113 MB/s"
         }
      ],
      "total": "1.84T",
      "used": "59.35G"
   },
   "fan": {
      "fan_infos": [
         {
            "name": "FAN1",
            "speed": "7900 RPM",
            "status": "ok"
         },
         {
            "name": "FAN2",
            "speed": "7600 RPM",
            "status": "ok"
         },
         {
            "name": "FAN3",
            "speed": "No Reading",
            "status": "ns"
         }
      ]
   },
   "memory": {
      "active": 2,
      "available": 61303296,
      "capacity": "1024GB",
      "eec": "Multi-bit ECC",
      "installed": "64GB",
      "memory_module": [
         {
            "device": "P0_Node0_Channel0_Dimm0",
            "installed": "yes",
            "manufacturer": "Samsung",
            "model_name": "M386A4G40DM0-CPB",
            "size": "32 GB",
            "slot": "P1-DIMMA1",
            "sn": "73003AA6",
            "speed": "2133 MT/s"
         },
         {
            "device": "P0_Node0_Channel0_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMA2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel1_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMB1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel1_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMB2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel2_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMC1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel2_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMC2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel3_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMD1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P0_Node0_Channel3_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P1-DIMMD2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel0_Dimm0",
            "installed": "yes",
            "manufacturer": "Samsung",
            "model_name": "M386A4G40DM0-CPB",
            "size": "32 GB",
            "slot": "P2-DIMME1",
            "sn": "73003AFD",
            "speed": "2133 MT/s"
         },
         {
            "device": "P1_Node1_Channel0_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMME2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel1_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMF1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel1_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMF2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel2_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMG1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel2_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMG2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel3_Dimm0",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMH1",
            "sn": "NO DIMM",
            "speed": "Unknown"
         },
         {
            "device": "P1_Node1_Channel3_Dimm1",
            "installed": "no",
            "manufacturer": "NO DIMM",
            "model_name": "NO DIMM",
            "size": "No Module Installed",
            "slot": "P2-DIMMH2",
            "sn": "NO DIMM",
            "speed": "Unknown"
         }
      ],
      "part_capacity": "256 GB",
      "part_number": 4,
      "slots": 16,
      "system_ram": 65809252,
      "total": 65809252,
      "type": "DDR4",
      "used": 4505956
   },
   "nic": {
      "nic_infos": [
         {
            "ipv4_addresses": [
               "192.168.6.21"
            ],
            "ipv6_addresses": [
               "2409:8a6a:b074:34d0:ae1f:6bff:fe0d:ff9a",
               "fe80::ae1f:6bff:fe0d:ff9a"
            ],
            "mac_address": "ac:1f:6b:0d:ff:9a",
            "model": "82599ES 10-Gigabit SFI/SFP+ Network Connection",
            "name": "ens5f0",
            "speed": "10Gbit/s",
            "status": "up",
            "type": "physical",
            "vendor": "Intel Corporation"
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": null,
            "mac_address": "ac:1f:6b:0d:ff:9b",
            "model": "82599ES 10-Gigabit SFI/SFP+ Network Connection",
            "name": "ens5f1",
            "speed": "10Gbit/s",
            "status": "down",
            "type": "physical",
            "vendor": "Intel Corporation"
         },
         {
            "ipv4_addresses": [
               "10.2.0.15"
            ],
            "ipv6_addresses": [
               "fd7a:115c:a1e0::f",
               "fe80::6dc0:aaf4:bef1:5424"
            ],
            "mac_address": "",
            "model": "",
            "name": "tailscale0",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "172.19.0.1"
            ],
            "ipv6_addresses": [
               "fe80::42:44ff:fe5b:9cab"
            ],
            "mac_address": "02:42:44:5b:9c:ab",
            "model": "",
            "name": "br-151966ad26e7",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "172.30.0.1"
            ],
            "ipv6_addresses": [
               "fe80::42:3aff:fe6d:61fb"
            ],
            "mac_address": "02:42:3a:6d:61:fb",
            "model": "",
            "name": "br-1efdd8280084",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "172.17.0.1"
            ],
            "ipv6_addresses": null,
            "mac_address": "02:42:61:41:7d:99",
            "model": "",
            "name": "docker0",
            "speed": "unknown",
            "status": "down",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "172.18.0.1"
            ],
            "ipv6_addresses": [
               "fe80::42:26ff:fe36:fab1"
            ],
            "mac_address": "02:42:26:36:fa:b1",
            "model": "",
            "name": "br-3c7f245c5575",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "172.20.0.1"
            ],
            "ipv6_addresses": null,
            "mac_address": "02:42:0e:fa:f7:3e",
            "model": "",
            "name": "br-683e3ba0b156",
            "speed": "unknown",
            "status": "down",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": [
               "192.168.0.1"
            ],
            "ipv6_addresses": [
               "fe80::42:aaff:fe99:e770"
            ],
            "mac_address": "02:42:aa:99:e7:70",
            "model": "",
            "name": "br-c72299eb3afd",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::e476:ceff:fe80:8dd6"
            ],
            "mac_address": "e6:76:ce:80:8d:d6",
            "model": "",
            "name": "vethfb43897",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::c43d:24ff:fe4e:b77e"
            ],
            "mac_address": "c6:3d:24:4e:b7:7e",
            "model": "",
            "name": "vethbd552e4",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::2c0c:e5ff:fec7:8fd0"
            ],
            "mac_address": "2e:0c:e5:c7:8f:d0",
            "model": "",
            "name": "veth0fb6411",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::46d:87ff:fe0e:5532"
            ],
            "mac_address": "06:6d:87:0e:55:32",
            "model": "",
            "name": "veth6d8fc2a",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::e8a0:ffff:fe1a:4757"
            ],
            "mac_address": "ea:a0:ff:1a:47:57",
            "model": "",
            "name": "veth85db72d",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::2882:feff:fe9f:48e4"
            ],
            "mac_address": "2a:82:fe:9f:48:e4",
            "model": "",
            "name": "vetha75accf",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::2029:55ff:fe97:d4f0"
            ],
            "mac_address": "22:29:55:97:d4:f0",
            "model": "",
            "name": "veth0d6cffa",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::a0e5:1bff:fe59:1d61"
            ],
            "mac_address": "a2:e5:1b:59:1d:61",
            "model": "",
            "name": "veth5083a5b",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         },
         {
            "ipv4_addresses": null,
            "ipv6_addresses": [
               "fe80::20e7:e9ff:fefe:c9ca"
            ],
            "mac_address": "22:e7:e9:fe:c9:ca",
            "model": "",
            "name": "veth0a151c3",
            "speed": "unknown",
            "status": "up",
            "type": "virtual",
            "vendor": ""
         }
      ]
   }
}
```