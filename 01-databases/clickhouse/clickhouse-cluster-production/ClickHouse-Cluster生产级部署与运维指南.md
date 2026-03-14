---
title: ClickHouse-Cluster 生产级部署与运维指南
author: devinyan
updated: 2026-03-14
version: v1.0
middleware_version: 25.8.18.1
cluster_mode: ReplicatedMergeTree + ClickHouse Keeper
verified: true
changelog:
  - version: v1.0
    date: 2026-03-14
    changes: "初始版本，基于 ClickHouse 25.8.18.1 Docker 伪集群验证"
---

> [TOC]

# ClickHouse-Cluster 生产级部署与运维指南

> 📋 **适用范围**：本文档适用于 Rocky Linux 9.x / Ubuntu 22.04 LTS、ClickHouse 25.8.18.1（LTS）、
> ReplicatedMergeTree + ClickHouse Keeper 集群模式。最后验证日期：2026-03-14。

---

## 1. 简介

### 1.1 服务介绍与核心特性

ClickHouse 是 Yandex 开源的列式 OLAP 数据库，专为海量数据的实时分析查询设计。

**核心特性**：

- **列式存储**：同列数据连续存储，压缩率高（通常 5~10 倍），聚合查询性能极强
- **向量化执行**：SIMD 指令并行处理列数据，单节点亿级数据秒级响应
- **水平分片**：Distributed 引擎 + ReplicatedMergeTree 实现数据分片与多副本高可用
- **ClickHouse Keeper**：内置 Raft 协调服务，替代 ZooKeeper，简化运维依赖
- **丰富的表引擎**：MergeTree 家族（ReplicatedMergeTree / SummingMergeTree / AggregatingMergeTree 等）满足不同场景
- **内置 Prometheus 端点**：25.x 原生暴露 `/metrics`（端口 9363），无需外部 Exporter

### 1.2 适用场景

| 场景 | 说明 |
|------|------|
| 日志/事件分析 | 应用日志、用户行为、埋点事件的实时聚合与查询 |
| 实时报表 | 业务指标大盘、多维分析，替代传统 OLAP 数仓 |
| 时序数据存储 | 监控指标、IoT 传感器数据，配合 TTL 自动过期 |
| 用户画像 | 亿级用户属性的多维筛选与漏斗分析 |
| 广告/风控 | 高并发写入 + 实时聚合统计 |

### 1.3 架构原理图

```mermaid
graph TB
    subgraph Client["客户端层"]
        style Client fill:#e1f5fe,stroke:#0288d1
        APP["应用程序 / BI 工具"]
        LB["负载均衡（Nginx/HAProxy）"]
        APP --> LB
    end

    subgraph Keeper["ClickHouse Keeper 集群（3 节点 · Raft）"]
        style Keeper fill:#fff3e0,stroke:#f57c00
        K1["Keeper-01<br/>9181 / 9234"]
        K2["Keeper-02<br/>9181 / 9234"]
        K3["Keeper-03<br/>9181 / 9234"]
        K1 <-->|"Raft"| K2
        K2 <-->|"Raft"| K3
        K3 <-->|"Raft"| K1
    end

    subgraph Shard1["分片 01（1 主 1 副本）"]
        style Shard1 fill:#e8f5e9,stroke:#4caf50
        CH1["ch-01  192.168.1.101"]
        CH4["ch-04  192.168.1.104"]
        CH1 <-->|"副本同步 9009"| CH4
    end

    subgraph Shard2["分片 02（1 主 1 副本）"]
        style Shard2 fill:#e3f2fd,stroke:#2196f3
        CH2["ch-02  192.168.1.102"]
        CH5["ch-05  192.168.1.105"]
        CH2 <-->|"副本同步 9009"| CH5
    end

    subgraph Shard3["分片 03（1 主 1 副本）"]
        style Shard3 fill:#fce4ec,stroke:#e91e63
        CH3["ch-03  192.168.1.103"]
        CH6["ch-06  192.168.1.106"]
        CH3 <-->|"副本同步 9009"| CH6
    end

    LB --> CH1 & CH2 & CH3
    Keeper -->|"元数据协调"| Shard1 & Shard2 & Shard3
```

> ⚠️ **架构说明**：
> - **ClickHouse Keeper** 负责副本间元数据协调（DDL、副本状态、分布式锁），不存储业务数据
> - **ReplicatedMergeTree** 是本地表引擎，副本间数据通过 9009 端口直接同步
> - **Distributed 表** 是逻辑视图，查询时路由到各分片，写入时按分片键分发
> - 生产推荐：3 分片 × 2 副本 = 6 个 ClickHouse 节点 + 3 个独立 Keeper 节点

### 1.4 版本说明

> 以下版本号通过 Docker Hub API 实际查询确认（2026-03-14）。

| 组件 | 版本 | 兼容性 |
|------|------|--------|
| **ClickHouse Server** | 25.8.18.1（LTS） | Linux x86_64 / ARM64，内核 ≥ 5.4 |
| **ClickHouse Keeper** | 25.8.18.1（与 Server 同版本） | 同上 |
| **操作系统** | Rocky Linux 9.x / Ubuntu 22.04 LTS | — |
| **Prometheus metrics** | 内置端口 9363 | 25.x 原生支持，无需外部 Exporter |

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| 版本系列 | 类型 | 关键特性 | 是否需改业务代码 |
|---------|------|---------|----------------|
| **25.8.x**（本文档） | LTS | Keeper 成熟、内置 Prometheus、JSON 类型增强 | 否（兼容 24.x 客户端） |
| 25.3.x / 25.6.x | 稳定版 | 功能更新，非 LTS | 否 |
| 24.8.x | 上一 LTS | 稳定，部分企业仍在使用 | 否 |

### 2.2 版本决策建议

| 场景 | 建议 |
|------|------|
| **新建集群** | 使用 25.8.x LTS，享受长期安全补丁支持 |
| **现有 24.x 集群** | 评估后滚动升级至 25.8.x，客户端 SDK 无需变更 |
| **使用 ZooKeeper 的旧集群** | 按官方迁移指南将 ZooKeeper 替换为 ClickHouse Keeper |

---

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

```mermaid
graph LR
    subgraph AZ1["可用区 A"]
        style AZ1 fill:#e8f5e9,stroke:#4caf50
        K1["Keeper-01<br/>192.168.1.101"]
        CH1["ch-01（分片01主）<br/>192.168.1.101"]
        CH4["ch-04（分片02副本）<br/>192.168.1.104"]
    end
    subgraph AZ2["可用区 B"]
        style AZ2 fill:#e3f2fd,stroke:#2196f3
        K2["Keeper-02<br/>192.168.1.102"]
        CH2["ch-02（分片02主）<br/>192.168.1.102"]
        CH5["ch-05（分片03副本）<br/>192.168.1.105"]
    end
    subgraph AZ3["可用区 C"]
        style AZ3 fill:#fce4ec,stroke:#e91e63
        K3["Keeper-03<br/>192.168.1.103"]
        CH3["ch-03（分片03主）<br/>192.168.1.103"]
        CH6["ch-06（分片01副本）<br/>192.168.1.106"]
    end
```

> ⚠️ **关键设计**：同一分片的主副本必须分布在不同可用区/机架，确保单可用区故障时每个分片仍有存活副本。

### 3.2 节点角色与配置要求

| 角色 | 数量 | 最低配置 | 推荐配置 | 说明 |
|------|------|---------|---------|------|
| ClickHouse Server | 6 | 8C 32G 500G SSD | 16C 64G 2T NVMe SSD | 内存越大，Page Cache 越多，查询越快 |
| ClickHouse Keeper | 3 | 2C 4G 50G SSD | 4C 8G 100G SSD | 仅存元数据，资源需求低 |

> ⚠️ **内存规划**：ClickHouse 大量使用 OS Page Cache，建议为 OS 保留 20% 内存。`max_server_memory_usage_to_ram_ratio` 生产建议设为 0.8。

### 3.3 容量规划

**存储估算公式**：

```
磁盘需求 = 原始数据量/天 × 副本数 × 保留天数 ÷ 压缩比 × 1.3（预留）
示例：日写入 50GB，2 副本，保留 90 天，压缩比 5：
  = 50GB × 2 × 90 ÷ 5 × 1.3 ≈ 2.34TB（每节点约 780GB）
```

| 规模 | 日写入量 | 查询 QPS | Server 节点规格 | Keeper 节点规格 |
|------|---------|---------|----------------|----------------|
| 小规模 | < 10GB/天 | < 100 | 8C 32G 500G SSD × 6 | 2C 4G 50G × 3 |
| 中规模 | 10~100GB/天 | 100~1000 | 16C 64G 2T NVMe × 6 | 4C 8G 100G × 3 |
| 大规模 | > 100GB/天 | > 1000 | 32C 128G 4T NVMe × 6+ | 4C 8G 100G × 3 |

> 以上为参考值，实际需根据业务数据特征（重复度、列数）和压测结果调整。

### 3.4 网络与端口规划

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|---------|------|------|
| 客户端 → ClickHouse Server | 8123/tcp | HTTP | HTTP 接口（REST API、JDBC/ODBC） |
| 客户端 → ClickHouse Server | 9000/tcp | TCP | 原生 TCP 协议（clickhouse-client、高性能写入） |
| ClickHouse Server ↔ Server | 9009/tcp | TCP | 副本间数据同步（InterServer） |
| ClickHouse Server → Keeper | 9181/tcp | TCP | Keeper 客户端连接 |
| Keeper ↔ Keeper | 9234/tcp | TCP | Keeper Raft 内部通信 |
| Prometheus → ClickHouse Server | 9363/tcp | HTTP | Prometheus metrics 采集 |

### 3.5 安装目录规划

| 路径 | 用途 | 备注 |
|------|------|------|
| `/etc/clickhouse-server/` | Server 配置文件目录 | 系统包安装默认路径 |
| `/etc/clickhouse-keeper/` | Keeper 配置文件目录 | 系统包安装默认路径 |
| `/data/clickhouse/data/` | 表数据目录（`path`） | **必须独立大容量磁盘** |
| `/data/clickhouse/tmp/` | 临时文件目录（`tmp_path`） | 大查询排序/JOIN 临时文件，建议与 data 同盘 |
| `/data/clickhouse/logs/` | Server 运行日志 | 建议独立日志盘或与数据盘分离 |
| `/data/clickhouse/backups/` | 备份文件目录 | BACKUP 命令输出路径 |
| `/data/keeper/coordination/log/` | Keeper Raft 日志 | 建议 SSD，写入频繁 |
| `/data/keeper/coordination/snapshots/` | Keeper Raft 快照 | |
| `/data/keeper/logs/` | Keeper 运行日志 | |

---

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

> 🖥️ **执行节点：所有 ClickHouse Server 节点 + 所有 Keeper 节点**

#### 4.1.1 内核与系统级调优

| 参数 | 推荐值 | 作用 |
|------|--------|------|
| `vm.swappiness` | 1 | 减少 swap，避免列式数据被换出 |
| `vm.overcommit_memory` | 1 | 允许 overcommit，大查询内存分配 |
| `net.core.somaxconn` | 65535 | TCP 连接队列上限 |
| `fs.file-max` | 655360 | 文件句柄上限（大表扫描、多分区） |

```bash
cat > /etc/sysctl.d/99-clickhouse.conf << 'EOF'
vm.swappiness = 1
vm.overcommit_memory = 1
net.core.somaxconn = 65535
fs.file-max = 655360
EOF
sysctl -p /etc/sysctl.d/99-clickhouse.conf
```

```bash
# ✅ 验证
sysctl vm.swappiness vm.overcommit_memory net.core.somaxconn fs.file-max
# 预期：vm.swappiness = 1、vm.overcommit_memory = 1、net.core.somaxconn = 65535、fs.file-max = 655360
```

#### 4.1.2 创建用户与目录

```bash
id -u clickhouse &>/dev/null || useradd -r -s /sbin/nologin -d /var/lib/clickhouse clickhouse

mkdir -p /data/clickhouse/{data,tmp,logs,backups}
mkdir -p /data/keeper/{coordination/log,coordination/snapshots,logs}
chown -R clickhouse:clickhouse /data/clickhouse /data/keeper
```

> ⚠️ **Keeper 数据目录权限**：若使用 Docker 部署，容器内 clickhouse 用户 uid=101，需对宿主机挂载目录执行 `chown -R 101:101 /data/keeper`，否则 Keeper 启动报错 `Permission denied ["/var/lib/clickhouse-keeper/coordination"]`。

#### 4.1.3 ulimit

```bash
cat > /etc/security/limits.d/99-clickhouse.conf << 'EOF'
clickhouse soft nofile 65536
clickhouse hard nofile 65536
clickhouse soft nproc 65536
clickhouse hard nproc 65536
EOF
```

#### 4.1.4 防火墙配置

```bash
# ── Rocky Linux 9（firewalld）──────────────
firewall-cmd --permanent --add-port=8123/tcp
firewall-cmd --permanent --add-port=9000/tcp
firewall-cmd --permanent --add-port=9009/tcp
firewall-cmd --permanent --add-port=9181/tcp
firewall-cmd --permanent --add-port=9234/tcp
firewall-cmd --permanent --add-port=9363/tcp
firewall-cmd --reload

# ── Ubuntu 22.04（差异）────────────────────
# ufw allow 8123/tcp && ufw allow 9000/tcp && ufw allow 9009/tcp
# ufw allow 9181/tcp && ufw allow 9234/tcp && ufw allow 9363/tcp
# ufw reload
```

> 📌 注意：云主机通常在安全组中配置端口规则，无需操作 firewalld/ufw。

---

### 4.2 部署步骤

> 🖥️ **执行节点：先部署 Keeper 集群（3 节点），再部署 ClickHouse Server 集群（6 节点）**

#### 4.2.1 安装 ClickHouse Keeper（每 Keeper 节点）

```bash
# ── Rocky Linux 9 ──────────────────────────
dnf install -y dnf-utils
rpm --import https://packages.clickhouse.com/rpm/stable/repodata/repomd.xml.key
dnf config-manager --add-repo https://packages.clickhouse.com/rpm/stable/clickhouse.repo
dnf install -y clickhouse-keeper

# ── Ubuntu 22.04（差异）────────────────────
# apt-get install -y apt-transport-https ca-certificates
# apt-key adv --keyserver keyserver.ubuntu.com --recv E0C56BD4
# echo "deb https://packages.clickhouse.com/deb stable main" > /etc/apt/sources.list.d/clickhouse.list
# apt-get update && apt-get install -y clickhouse-keeper
```

```bash
# ✅ 验证
clickhouse-keeper --version
# 预期输出包含：25.8.18.1
```

#### 4.2.2 配置 ClickHouse Keeper（每节点不同：server_id、hostname）

**必须修改项清单**：

| 参数 | 节点 | 必须修改 |
|------|------|----------|
| `server_id` | 每节点不同 | 1 / 2 / 3 |
| `raft_configuration` 中本节点 `hostname` | 每节点不同 | keeper1 / keeper2 / keeper3（或实际 IP） |
| `raft_configuration` 中 `hostname` | 每节点相同 | 3 个节点 hostname 列表必须一致 |

```bash
# Keeper-01 节点示例（server_id=1）
cat > /etc/clickhouse-keeper/keeper_config.xml << 'EOF'
<clickhouse>
    <logger>
        <level>information</level>
        <log>/data/keeper/logs/clickhouse-keeper.log</log>
        <errorlog>/data/keeper/logs/clickhouse-keeper.err.log</errorlog>
        <size>100M</size>
        <count>3</count>
    </logger>
    <listen_host>0.0.0.0</listen_host>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>1</server_id>
        <log_storage_path>/data/keeper/coordination/log</log_storage_path>
        <snapshot_storage_path>/data/keeper/coordination/snapshots</snapshot_storage_path>
        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
        </coordination_settings>
        <raft_configuration>
            <server>
                <id>1</id>
                <hostname>192.168.1.101</hostname>
                <port>9234</port>
            </server>
            <server>
                <id>2</id>
                <hostname>192.168.1.102</hostname>
                <port>9234</port>
            </server>
            <server>
                <id>3</id>
                <hostname>192.168.1.103</hostname>
                <port>9234</port>
            </server>
        </raft_configuration>
    </keeper_server>
</clickhouse>
EOF
```

> ⚠️ `hostname` 填写实际 IP 或可解析的主机名，`← 根据实际环境修改`。Keeper-02 将 `server_id` 改为 2，`hostname` 对应改为本机 IP。

#### 4.2.3 创建 Keeper Systemd Unit 并启动

```bash
cat > /etc/systemd/system/clickhouse-keeper.service << 'EOF'
[Unit]
Description=ClickHouse Keeper
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=clickhouse
Group=clickhouse
LimitNOFILE=65536
LimitNPROC=65536
OOMScoreAdjust=-500
Restart=on-failure
RestartSec=5s
TimeoutStartSec=60s
TimeoutStopSec=60s
ExecStart=/usr/bin/clickhouse-keeper --config /etc/clickhouse-keeper/keeper_config.xml
WorkingDirectory=/data/keeper

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now clickhouse-keeper
```

```bash
# ✅ 验证
systemctl status clickhouse-keeper
# 预期输出：Active: active (running)
```

#### 4.2.4 安装 ClickHouse Server（每 Server 节点）

```bash
# ── Rocky Linux 9 ──────────────────────────
dnf install -y clickhouse-server clickhouse-client

# ── Ubuntu 22.04（差异）────────────────────
# apt-get install -y clickhouse-server clickhouse-client
```

```bash
# ✅ 验证
clickhouse-server --version
# 预期输出包含：25.8.18.1
```

#### 4.2.5 配置 ClickHouse Server（每节点不同：macros）

**必须修改项清单**：

| 参数 | 节点 | 必须修改 |
|------|------|----------|
| `macros` 中 `shard` | 每节点不同 | 01 / 02 / 03 / 04 / 05 / 06（每分片 2 个，主+副本） |
| `macros` 中 `replica` | 每节点不同 | ch-01 / ch-02 / ... / ch-06（本机唯一标识） |
| `remote_servers` | 每节点相同 | 6 节点列表（host、port、password） |
| `zookeeper` 节点列表 | 每节点相同 | 3 个 Keeper 节点 host:port |

```bash
# ch-01 节点示例（分片 01 主节点）
cat > /etc/clickhouse-server/config.d/cluster.xml << 'EOF'
<clickhouse>
    <remote_servers>
        <cluster_3s_2r>
            <shard>
                <replica><host>192.168.1.101</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
                <replica><host>192.168.1.106</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
            </shard>
            <shard>
                <replica><host>192.168.1.102</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
                <replica><host>192.168.1.104</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
            </shard>
            <shard>
                <replica><host>192.168.1.103</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
                <replica><host>192.168.1.105</host><port>9000</port><user>default</user><password>CHANGE_ME</password></replica>
            </shard>
        </cluster_3s_2r>
    </remote_servers>

    <zookeeper>
        <node><host>192.168.1.101</host><port>9181</port></node>
        <node><host>192.168.1.102</host><port>9181</port></node>
        <node><host>192.168.1.103</host><port>9181</port></node>
    </zookeeper>

    <macros>
        <cluster>cluster_3s_2r</cluster>
        <shard>01</shard>
        <replica>ch-01</replica>
    </macros>

    <path>/data/clickhouse/data/</path>
    <tmp_path>/data/clickhouse/tmp/</tmp_path>
    <log>/data/clickhouse/logs/clickhouse-server.log</log>
    <errorlog>/data/clickhouse/logs/clickhouse-server.err.log</errorlog>

    <backups>
        <allowed_path>/data/clickhouse/backups</allowed_path>
    </backups>

    <prometheus>
        <endpoint>/metrics</endpoint>
        <port>9363</port>
        <metrics>true</metrics>
        <events>true</events>
        <asynchronous_metrics>true</asynchronous_metrics>
    </prometheus>
</clickhouse>
EOF
```

> ⚠️ `CHANGE_ME`、IP 地址均需 `← 根据实际环境修改`。`backups.allowed_path` 为 BACKUP 命令必需，否则报错 `Path is not allowed for backups`。

#### 4.2.6 用户认证配置（生产必须）

```bash
cat > /etc/clickhouse-server/users.d/users.xml << 'EOF'
<clickhouse>
    <users>
        <default>
            <password>CHANGE_ME_STRONG_PASSWORD</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
    </users>
</clickhouse>
EOF
```

> ⚠️ 生产密码必须强密码，`← 根据实际环境修改`。`remote_servers` 中 `password` 需与此一致。

#### 4.2.7 创建 ClickHouse Server Systemd Unit 并启动

```bash
# 系统包安装通常已自带 systemd 单元，检查 /usr/lib/systemd/system/clickhouse-server.service
# 若需自定义，可覆盖 /etc/systemd/system/clickhouse-server.service.d/override.conf

systemctl daemon-reload
systemctl enable --now clickhouse-server
```

```bash
# ✅ 验证
systemctl status clickhouse-server
# 预期输出：Active: active (running)
```

#### 4.2.8 集群初始化与验证

> 🖥️ **执行节点：任意一台 ClickHouse Server 节点**

```bash
clickhouse-client --user default --password CHANGE_ME_STRONG_PASSWORD --query "SELECT cluster, shard_num, replica_num, host_name, port FROM system.clusters WHERE cluster = 'cluster_3s_2r'"
```

> 预期输出：6 行，每行对应一个分片副本，shard_num 为 1/2/3，replica_num 为 1/2。

```bash
# ✅ 验证 Keeper 连接
clickhouse-client --user default --password CHANGE_ME_STRONG_PASSWORD --query "SELECT * FROM system.zookeeper WHERE path = '/'"
# 预期输出：path 列包含 keeper、clickhouse 等
```

```bash
# ✅ 验证 macros（每节点执行，确认 shard/replica 不同）
clickhouse-client --user default --password CHANGE_ME_STRONG_PASSWORD --query "SELECT * FROM system.macros"
# 预期：cluster、shard、replica 三列，shard 与 replica 每节点不同
```

### 4.3 安装后的目录结构

```
/data/clickhouse/
├── data/         # 表数据（MergeTree 列文件、分区目录），修改后需重启
├── tmp/          # 临时文件（大查询排序、JOIN 中间结果），可定期清理
├── logs/         # 运行日志、错误日志、查询日志，建议配置 logrotate
└── backups/      # BACKUP 命令输出路径，需纳入备份策略

/data/keeper/
├── coordination/
│   ├── log/      # Raft 日志，不可手动删除
│   └── snapshots/  # Raft 快照
└── logs/         # Keeper 运行日志
```

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

**Server 主配置**（`/etc/clickhouse-server/config.xml` 或 `config.d/*.xml`）：

| 参数 | 默认值 | 生产建议 | 说明 |
|------|--------|----------|------|
| `path` | /var/lib/clickhouse/ | /data/clickhouse/data/ | 表数据目录，必须大容量磁盘 |
| `tmp_path` | /var/lib/clickhouse/tmp/ | /data/clickhouse/tmp/ | 临时文件 |
| `max_server_memory_usage_to_ram_ratio` | 0.9 | 0.8 | 避免 OOM，为 OS 预留 20% |
| `max_concurrent_queries` | 100 | 200~500 | 按 QPS 调整 |
| `max_memory_usage` | 0 | 单查询内存上限（字节），0 表示不限制，生产建议设值如 10000000000（10GB） |

**Keeper 配置**（`keeper_config.xml`）：

| 参数 | 说明 |
|------|------|
| `server_id` | 集群内唯一，1/2/3 |
| `tcp_port` | 9181，ClickHouse 连接端口 |
| `raft_configuration` | 3 节点 hostname:9234 列表 |
| `operation_timeout_ms` | 10000，操作超时 |
| `session_timeout_ms` | 30000，会话超时 |

### 5.2 生产环境参数优化详解

| 参数 | 默认值 | 推荐值 | 调优理由 |
|------|--------|--------|----------|
| `max_threads` | 8 | CPU 核心数 | 查询并行度 |
| `max_memory_usage` | 0 | 10GB~50GB | 单查询内存上限，防止大查询拖垮集群 |
| `max_execution_time` | 0 | 300 | 单查询超时秒数 |
| `max_insert_block_size` | 1048576 | 1048576 | 插入块大小，默认即可 |
| `max_bytes_before_external_group_by` | 0 | 10GB | 超过此值 GROUP BY 溢出到磁盘 |
| `max_bytes_before_external_sort` | 0 | 10GB | 超过此值 ORDER BY 溢出到磁盘 |

### 5.3 生产环境安全配置

#### 5.3.1 认证配置

生产**必须**设置 `default` 用户密码（见 4.2.6）。可为不同应用创建独立用户：

```sql
CREATE USER app_user IDENTIFIED BY 'app_password';
GRANT SELECT, INSERT ON db_name.* TO app_user;
```

#### 5.3.2 TLS/mTLS 加密通信

ClickHouse 支持 TLS。生产跨机房/公网传输时建议启用：

```xml
<openSSL>
    <server>
        <certificateFile>/etc/clickhouse-server/ssl/server.crt</certificateFile>
        <privateKeyFile>/etc/clickhouse-server/ssl/server.key</privateKeyFile>
    </server>
</openSSL>
```

> 证书生成可使用 `openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes`。内网部署可暂不启用，通过防火墙/安全组限制访问来源。

---

## 6. 快速体验部署（开发 / 测试环境）

### 6.1 快速启动方案选型

Docker Compose 3 节点 KRaft 伪集群（3 Keeper + 3 ClickHouse Server），适合本地验证。**生产严禁使用**。

### 6.2 快速启动步骤与验证

```bash
# 创建验证目录
mkdir -p /tmp/clickhouse-verify/{keeper1,keeper2,keeper3,ch1,ch2,ch3}/{data,logs,config}
chown -R 101:101 /tmp/clickhouse-verify/keeper*/data /tmp/clickhouse-verify/keeper*/logs
chown -R 101:101 /tmp/clickhouse-verify/ch*/data /tmp/clickhouse-verify/ch*/logs
```

> ⚠️ **踩坑**：容器内 clickhouse 用户 uid=101，宿主机挂载目录必须 `chown 101:101`，否则 Keeper 启动报错 `Permission denied`。

```bash
# 使用项目内 docker-compose（若已提供）或参考官方示例
cd /tmp/clickhouse-verify
# docker compose up -d
# sleep 30
```

```bash
# ✅ 验证：集群连接
docker exec ch1 clickhouse-client --user default --password clickhouse123 --query "SELECT version()"
# 预期：25.8.18.1

# ✅ 验证：集群配置
docker exec ch1 clickhouse-client --user default --password clickhouse123 --query "SELECT cluster, shard_num, host_name FROM system.clusters WHERE cluster = 'cluster_3s_1r'"
# 预期：3 行，ch1/ch2/ch3

# ✅ 验证：Keeper 连接
docker exec ch1 clickhouse-client --user default --password clickhouse123 --query "SELECT * FROM system.zookeeper WHERE path = '/'"
# 预期：path 列包含 keeper、clickhouse
```

### 6.3 停止与清理

```bash
docker compose down -v
rm -rf /tmp/clickhouse-verify
```

---

## 7. 日常运维操作

### 7.1 常用管理命令与使用演示

#### 创建 ReplicatedMergeTree 本地表（ON CLUSTER）

```bash
clickhouse-client --user default --password CHANGE_ME --query "
CREATE TABLE IF NOT EXISTS test.events_local ON CLUSTER cluster_3s_2r
(
    event_date Date,
    event_time DateTime,
    user_id UInt64,
    event_type String,
    value Float64
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/test/events_local', '{replica}')
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, user_id)
TTL event_date + INTERVAL 90 DAY
SETTINGS index_granularity = 8192
"
```

> `{shard}`、`{replica}` 为 macros 自动替换。

#### 创建 Distributed 分布式表

```bash
clickhouse-client --user default --password CHANGE_ME --query "
CREATE TABLE IF NOT EXISTS test.events ON CLUSTER cluster_3s_2r
(
    event_date Date,
    event_time DateTime,
    user_id UInt64,
    event_type String,
    value Float64
)
ENGINE = Distributed(cluster_3s_2r, test, events_local, rand())
"
```

#### 插入与查询

```bash
# 插入
clickhouse-client --user default --password CHANGE_ME --query "
INSERT INTO test.events VALUES
    ('2026-03-14', '2026-03-14 10:00:00', 1001, 'click', 1.5),
    ('2026-03-14', '2026-03-14 10:01:00', 1002, 'view', 2.0)
"

# 全局查询（自动聚合各分片）
clickhouse-client --user default --password CHANGE_ME --query "SELECT count(), sum(value) FROM test.events"

# 各分片数据分布（每节点执行）
clickhouse-client --user default --password CHANGE_ME --query "SELECT count() FROM test.events_local"
```

> 验证结果：3 分片时，`rand()` 分片键会将数据均匀分布（如 100 条插入后 ch1:36、ch2:28、ch3:41 行）。

#### 分区与副本状态

```bash
# 查看分区
clickhouse-client --user default --password CHANGE_ME --query "SELECT partition, count() FROM system.parts WHERE database='test' AND table='events_local' GROUP BY partition"

# 副本状态
clickhouse-client --user default --password CHANGE_ME --query "SELECT * FROM system.replicas"
```

### 7.2 备份与恢复

**备份**（需配置 `backups.allowed_path`）：

```bash
clickhouse-client --user default --password CHANGE_ME --query "
BACKUP TABLE test.events_local TO File('/data/clickhouse/backups/events_local_20260314')
"
# 预期输出：uuid  BACKUP_CREATED
```

**恢复**（覆盖已有 ReplicatedMergeTree 表）：

```bash
clickhouse-client --user default --password CHANGE_ME --query "
RESTORE TABLE test.events_local
FROM File('/data/clickhouse/backups/events_local_20260314')
SETTINGS allow_non_empty_tables=true
"
# 预期输出：uuid  RESTORED
```

> ⚠️ **踩坑**：RESTORE 到新表名时，若 ZK 路径已存在（Replica already exists）会报错。覆盖原表时使用 `allow_non_empty_tables=true`。恢复前需确保备份路径在 `allowed_path` 内。

### 7.3 集群扩缩容

**增加分片**：新建分片节点，修改 `remote_servers` 和 `macros`，在 `system.clusters` 中可见后，使用 `CREATE TABLE ... ON CLUSTER` 在新分片创建表，再通过 `ALTER TABLE ... MOVE PARTITION` 或重新导入数据迁移。

**增加副本**：在已有分片内增加节点，配置相同 `shard`、不同 `replica`，启动后会自动从主副本同步数据。

### 7.4 版本升级

滚动升级：逐节点停止 → 升级包 → 启动。建议先升级 Keeper，再升级 Server。升级前备份 `backups` 目录及重要表。

**回滚**：保留旧版本包，升级失败时停止服务、安装旧包、恢复数据目录后启动。

### 7.5 日志清理与轮转

```bash
cat > /etc/logrotate.d/clickhouse-server << 'EOF'
/data/clickhouse/logs/*.log {
    daily
    rotate 14
    size 200M
    compress
    delaycompress
    copytruncate
    missingok
    notifempty
    dateext
    dateformat -%Y%m%d
}
EOF
```

```bash
# 测试配置
logrotate -d /etc/logrotate.d/clickhouse-server
# 手动执行一次
logrotate -f /etc/logrotate.d/clickhouse-server
```

> Keeper 日志路径 `/data/keeper/logs/` 同理配置 logrotate。

---

## 8. 使用手册（数据库专项）

### 8.1 连接与认证

**Python（clickhouse-driver）**：

```python
from clickhouse_driver import Client

client = Client(
    host='192.168.1.101',
    port=9000,
    user='default',
    password='CHANGE_ME',
    settings={'max_execution_time': 300},
    connect_timeout=10,
    send_receive_timeout=300,
)
result = client.execute('SELECT count() FROM test.events')
print(result)
```

**Go（clickhouse-go）**：

```go
import (
    "database/sql"
    _ "github.com/ClickHouse/clickhouse-go/v2"
)

conn, err := sql.Open("clickhouse", "clickhouse://default:CHANGE_ME@192.168.1.101:9000/default?dial_timeout=10s")
if err != nil {
    panic(err)
}
defer conn.Close()
rows, err := conn.Query("SELECT count() FROM test.events")
```

### 8.2 库/表管理命令

```bash
# 创建数据库（ON CLUSTER 在所有节点执行）
clickhouse-client -q "CREATE DATABASE IF NOT EXISTS mydb ON CLUSTER cluster_3s_2r"

# 创建表（见 7.1 ReplicatedMergeTree + Distributed）
# 删除表
clickhouse-client -q "DROP TABLE IF EXISTS test.events ON CLUSTER cluster_3s_2r"
```

### 8.3 数据增删改查

```bash
# 插入
clickhouse-client -q "INSERT INTO test.events VALUES ('2026-03-14', now(), 1, 'type', 1.0)"

# 查询
clickhouse-client -q "SELECT * FROM test.events LIMIT 10"

# 更新/删除（Mutation，异步执行）
clickhouse-client -q "ALTER TABLE test.events_local DELETE WHERE user_id = 0"
clickhouse-client -q "ALTER TABLE test.events_local UPDATE value = 0 WHERE event_type = 'test'"
```

### 8.4 用户与权限管理

```sql
CREATE USER app_user IDENTIFIED BY 'password';
GRANT SELECT, INSERT ON mydb.* TO app_user;
REVOKE INSERT ON mydb.* FROM app_user;
SHOW GRANTS FOR app_user;
```

### 8.5 性能查询与慢查询分析

```sql
-- 查看正在执行的查询
SELECT query_id, user, query, elapsed FROM system.processes;

-- 查看慢查询（需开启 log_queries=1）
SELECT query, query_duration_ms, read_rows FROM system.query_log WHERE type=2 ORDER BY query_duration_ms DESC LIMIT 10;
```

### 8.6 备份恢复命令

见 7.2 节。

### 8.7 集群状态监控命令

```sql
SELECT * FROM system.clusters;
SELECT * FROM system.replicas;
SELECT * FROM system.parts WHERE database='test' AND table='events_local';
```

### 8.8 生产常见故障处理命令

见 10.2 节。

---

## 9. 监控与告警接入

### 9.1 Prometheus 指标暴露

ClickHouse 25.x 内置 Prometheus 端点，端口 9363。无需外部 Exporter。

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'clickhouse'
    static_configs:
      - targets:
          - '192.168.1.101:9363'
          - '192.168.1.102:9363'
          - '192.168.1.103:9363'
          - '192.168.1.104:9363'
          - '192.168.1.105:9363'
          - '192.168.1.106:9363'
```

> 验证：`curl http://192.168.1.101:9363/metrics` 应返回 2000+ 条 ClickHouse 指标。

### 9.2 关键监控指标

| 指标 | 告警阈值 | 说明 |
|------|---------|------|
| `ClickHouseMetrics_Query` | 持续为 0 超过 5 分钟 | 可能服务不可用 |
| `ClickHouseMetrics_ReplicatedFetch` | 持续 > 0 且长时间不降 | 副本同步延迟 |
| `ClickHouseMetrics_Merge` | 持续 > 0 且长时间不降 | 后台 Merge 堆积 |
| `ClickHouseProfileEvents_Query` | 突增后异常 | 查询量异常 |
| `memory_usage` | 接近 `max_server_memory_usage` | 内存压力 |

### 9.3 Grafana Dashboard 推荐

- [ClickHouse Overview](https://grafana.com/grafana/dashboards/14192)（ID: 14192）
- 或使用官方 [ClickHouse monitoring](https://clickhouse.com/docs/en/operations/monitoring) 文档中的 Dashboard JSON

### 9.4 告警规则示例

```yaml
groups:
  - name: clickhouse
    rules:
      - alert: ClickHouseDown
        expr: up{job="clickhouse"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ClickHouse 节点 {{ $labels.instance }} 不可用"
```

---

## 10. 注意事项与生产检查清单

### 10.1 安装前环境核查

| 检查项 | 命令 | 预期结果 |
|--------|------|---------|
| 内核参数 | `sysctl vm.swappiness fs.file-max` | swappiness=1, file-max≥655360 |
| 文件描述符 | `ulimit -n`（clickhouse 用户） | ≥ 65536 |
| 数据目录权限 | `ls -la /data/clickhouse/data/` | 属主 clickhouse |
| Keeper 目录权限 | `ls -la /data/keeper/coordination/` | 属主 clickhouse（或 uid 101） |
| 防火墙端口 | `firewall-cmd --list-ports` | 8123 9000 9009 9181 9234 9363 |
| 时钟同步 | `timedatectl status` | NTP 已同步 |
| 磁盘空间 | `df -h /data/clickhouse/data/` | 可用空间充足 |

### 10.2 常见故障排查与处理指南

#### 故障：Keeper 启动报错 Permission denied

**现象**：`filesystem error: in create_directories: Permission denied ["/var/lib/clickhouse-keeper/coordination"]`

**原因**：宿主机挂载目录属主为 root，容器内 clickhouse 用户（uid=101）无写权限。

**解决**：`chown -R 101:101 /data/keeper`（或对应挂载路径）。

#### 故障：BACKUP 报错 Path is not allowed for backups

**现象**：`Path '/data/clickhouse/backup/xxx' is not allowed for backups, see 'backups.allowed_path'`

**原因**：未配置 `backups.allowed_path`。

**解决**：在 `config.xml` 或 `config.d/*.xml` 中添加：

```xml
<backups>
    <allowed_path>/data/clickhouse/backups</allowed_path>
</backups>
```

#### 故障：RESTORE 报错 Replica already exists

**现象**：`Replica /clickhouse/tables/01/test/events_local/replicas/ch1 already exists`

**原因**：RESTORE 到新表名时，ZK 路径已存在该副本。

**解决**：覆盖原表时使用 `RESTORE TABLE test.events_local FROM ... SETTINGS allow_non_empty_tables=true`；或先 DROP 原表再 RESTORE 到新表。

#### 故障：分片节点宕机后查询失败

**现象**：查询报错 `All replicas are unavailable` 或超时。

**原因**：默认不跳过不可用分片。

**解决**：查询时加 `SETTINGS skip_unavailable_shards=1`，仅跳过不可用分片的数据；或恢复故障节点。

#### 故障：Keeper 单节点宕机后集群仍可用

**说明**：Keeper 使用 Raft 多数派（3 节点中 2 节点存活即可）。验证结果：停止 keeper1 后，ClickHouse 仍可正常写入。

### 10.3 安全加固建议

| 措施 | 说明 |
|------|------|
| 强密码 | default 用户密码 ≥ 16 位，含大小写+数字+特殊字符 |
| 网络隔离 | ClickHouse 部署在内网，通过防火墙/安全组限制访问来源 |
| 最小权限 | 为应用创建独立用户，仅授予所需库表权限 |
| TLS | 跨机房/公网传输时启用 TLS |
| 定期备份 | Crontab 定时执行 BACKUP，备份文件异地存储 |

### 10.4 伪集群验证踩坑与经验总结

1. **Keeper 数据目录权限**：Docker 部署时宿主机挂载目录必须 `chown 101:101`，否则 Keeper 启动失败。生产二进制部署使用 clickhouse 用户，目录属主正确即可。

2. **BACKUP 路径限制**：需在配置中显式 `backups.allowed_path`，否则 BACKUP 命令报错。

3. **RESTORE ReplicatedMergeTree**：覆盖原表需 `allow_non_empty_tables=true`；恢复到新表名时，若 ZK 路径已存在会报 Replica already exists。

4. **分片宕机查询**：使用 `skip_unavailable_shards=1` 可跳过不可用分片，避免全查询失败。

5. **Keeper 多数派**：3 节点 Keeper 中 2 节点存活即可，单节点宕机不影响集群写入。

---

## 11. 参考资料

| 资源 | 链接 |
|------|------|
| ClickHouse 官方文档 | https://clickhouse.com/docs |
| ClickHouse Keeper | https://clickhouse.com/docs/en/operations/keeper |
| ClickHouse 备份 | https://clickhouse.com/docs/en/sql-reference/statements/backup |
| ClickHouse 监控 | https://clickhouse.com/docs/en/operations/monitoring |
| RPM 仓库 | https://packages.clickhouse.com/rpm/stable/ |
| Docker Hub | https://hub.docker.com/r/clickhouse/clickhouse-server |
| Grafana Dashboard | https://grafana.com/grafana/dashboards/14192 |
