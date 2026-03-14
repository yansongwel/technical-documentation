---
title: etcd 集群生产级部署与运维指南
author: devinyan
updated: 2026-03-14
version: v1.1
middleware_version: 3.6.8
cluster_mode: Raft
verified: true
changelog:
  - version: v1.0
    date: 2026-03-14
    changes: "初始版本，基于 etcd 3.6.8 验证"
  - version: v1.1
    date: 2026-03-14
    changes: "补充 3.3 容量规划；扩展 10.2 故障恢复（单节点/多数节点宕机、数据恢复、Leader 切换、成员误删等）；增加适用范围声明；幂等性修正"
---

> [TOC]

# etcd 集群生产级部署与运维指南

> 📋 **适用范围**：本文档适用于 Rocky Linux 9.x / Ubuntu 22.04 LTS、etcd 3.6.8、Raft 集群模式。
> 最后验证日期：2026-03-14。

## 1. 简介

### 1.1 服务介绍与核心特性

etcd 是分布式键值存储系统，基于 Raft 共识算法实现强一致性，是 Kubernetes、CoreDNS、Kafka 等系统的核心依赖。

**核心特性**：
- **强一致性**：Raft 共识算法保证读写一致性
- **高可用**：3/5/7 节点集群，容忍 (N-1)/2 节点故障
- **Watch 机制**：支持键值变更的实时推送
- **租约（Lease）**：支持 TTL 自动过期，常用于服务发现与分布式锁
- **事务**：支持多键原子事务

### 1.2 适用场景

| 场景 | 说明 |
|------|------|
| Kubernetes 元数据存储 | K8s 默认使用 etcd 存储集群状态 |
| 服务发现 | 配合 CoreDNS、Consul 等实现服务注册与发现 |
| 分布式配置中心 | 集中存储配置，支持 Watch 推送 |
| 分布式锁 | 基于 Lease + 事务实现 |
| 消息队列元数据 | Kafka、RocketMQ 等可选 etcd 作为协调存储 |

### 1.3 架构原理图

```mermaid
graph TB
    subgraph Client["客户端层"]
        style Client fill:#e1f5fe,stroke:#0288d1
        APP["应用程序 / K8s API Server"]
        SDK["etcdctl / 客户端 SDK"]
        APP --> SDK
    end

    subgraph Cluster["etcd Raft 集群（3 节点）"]
        style Cluster fill:#fff3e0,stroke:#f57c00

        subgraph Node1["etcd-01 (Leader)"]
            style Node1 fill:#c8e6c9,stroke:#388e3c
            E1["etcd<br/>2379 / 2380"]
        end
        subgraph Node2["etcd-02 (Follower)"]
            style Node2 fill:#f3e5f5,stroke:#7b1fa2
            E2["etcd<br/>2379 / 2380"]
        end
        subgraph Node3["etcd-03 (Follower)"]
            style Node3 fill:#f3e5f5,stroke:#7b1fa2
            E3["etcd<br/>2379 / 2380"]
        end

        E1 <-->|"Raft 2380"| E2
        E2 <-->|"Raft 2380"| E3
        E3 <-->|"Raft 2380"| E1
    end

    SDK -->|"gRPC 2379"| Cluster
```

### 1.4 版本说明

> 以下版本号均通过 GitHub Releases API 实际查询确认（2026-03-14）。

| 组件 | 版本 | 兼容性 |
|------|------|--------|
| **etcd** | 3.6.8（2026-02 最新稳定版） | Linux x86_64 / ARM64 |
| **etcdctl / etcdutl** | 随 etcd 一同安装 | — |
| **操作系统** | Rocky Linux 9.x / Ubuntu 22.04 LTS 或 24.04 LTS | 内核 ≥ 5.4 |
| **Go**（从源码编译） | ≥ 1.21 | — |

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| etcd 大版本 | 发布周期 | 关键特性 |
|-------------|---------|---------|
| **3.6.x**（当前） | 2025-2026 | 性能优化、安全增强、etcdutl 工具 |
| **3.5.x** | 2022-2025 | 结构化日志、JWT 认证 |
| **3.4.x** | 2019-2022 | 客户端 gRPC 代理、Learner 节点 |

### 2.2 版本决策建议

| 场景 | 建议 |
|------|------|
| **新建集群** | 直接使用 3.6.8 |
| **现有 3.5.x 集群** | 参考 [升级指南](https://etcd.io/docs/v3.6/upgrades/upgrade_3_6/) 滚动升级 |
| **K8s 兼容性** | K8s 1.28+ 推荐 etcd 3.5+，1.30+ 推荐 3.6+ |

---

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

```mermaid
graph LR
    subgraph AZ1["可用区 A"]
        style AZ1 fill:#e8f5e9,stroke:#4caf50
        E1["etcd-01<br/>192.168.1.101"]
    end

    subgraph AZ2["可用区 B"]
        style AZ2 fill:#e3f2fd,stroke:#2196f3
        E2["etcd-02<br/>192.168.1.102"]
    end

    subgraph AZ3["可用区 C"]
        style AZ3 fill:#fce4ec,stroke:#e91e63
        E3["etcd-03<br/>192.168.1.103"]
    end

    E1 <-->|"2380"| E2
    E2 <-->|"2380"| E3
    E3 <-->|"2380"| E1
```

### 3.2 节点角色与配置要求

| 角色 | 最低配置 | 推荐配置 |
|------|---------|---------|
| etcd 节点 | 2C4G、50GB SSD | 4C8G、100GB NVMe SSD |
| 网络 | 千兆内网 | 万兆内网（高 QPS 场景） |

> ⚠️ **存储**：etcd 对磁盘延迟敏感，必须使用 SSD，禁止使用 HDD 或 NFS。

### 3.3 容量规划

etcd 存储元数据与键值对，单集群建议控制在 8GB 以内，key 数量 < 100M。按规模参考：

| 规模 | 数据量 | 节点规格 | 备份保留 | 说明 |
|------|--------|---------|---------|------|
| 小规模 | < 1GB | 2C 4G 50G SSD × 3 | 7 天 | K8s 小集群、配置中心 |
| 中规模 | 1~4GB | 4C 8G 100G NVMe × 3 | 14 天 | K8s 生产集群、多业务配置 |
| 大规模 | 4~8GB | 4C 8G 200G NVMe × 5 | 30 天 | 高 QPS、建议 5 节点 |

**估算公式**：`磁盘需求 = 数据量 × 2（WAL+快照） × 1.3（预留）`。超过 8GB 建议拆分为多集群或迁移到专用存储。

### 3.4 网络与端口规划

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|---------|------|------|
| 客户端 / K8s API Server | 2379 | TCP | 客户端 gRPC |
| etcd 节点互访 | 2380 | TCP | Raft 共识通信 |
| Prometheus | 2379 | TCP | /metrics 指标采集 |

### 3.5 安装目录规划

| 路径 | 用途 | 规划说明 |
|------|------|----------|
| `/opt/etcd/` | 安装根目录 | 程序与配置集中管理 |
| `/opt/etcd/bin/` | 可执行文件 | etcd、etcdctl、etcdutl |
| `/opt/etcd/conf/` | 配置文件 | etcd.conf、systemd 环境变量 |
| `/data/etcd/` | 数据目录 | 独立挂载 SSD，与程序分离 |
| `/data/etcd/log/` | 日志目录 | 可选，默认 stderr |

**推荐目录树**：
```
/opt/etcd/
├── bin/          # etcd、etcdctl、etcdutl
├── conf/         # 配置文件
└── ssl/          # TLS 证书（生产建议启用）

/data/etcd/
├── data/         # --data-dir 数据目录
└── log/          # 日志（若配置 --log-outputs 文件）
```

---

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

> **作用**：为 etcd 准备内核调优、用户与目录、ulimit、NTP 等，不调优内核的部署只能算「能跑」，不能算「生产级」。

#### 4.1.1 内核与系统级调优（Pre-flight Tuning）

| 参数 | 推荐值 | 作用 | 验证命令 |
|------|--------|------|----------|
| `fs.file-max` | 655360 | 提高系统文件句柄上限 | `sysctl fs.file-max` |
| `vm.swappiness` | 0 或 1 | 降低 swap 倾向，避免 etcd 被换出 | `sysctl vm.swappiness` |
| `net.core.somaxconn` | 4096 | 提高 TCP 连接队列 | `sysctl net.core.somaxconn` |

```bash
cat > /etc/sysctl.d/99-etcd.conf << 'EOF'
fs.file-max = 655360
vm.swappiness = 0
net.core.somaxconn = 4096
EOF
sysctl -p /etc/sysctl.d/99-etcd.conf
```

```bash
# ✅ 验证
sysctl fs.file-max vm.swappiness net.core.somaxconn
# 预期：fs.file-max = 655360、vm.swappiness = 0、net.core.somaxconn = 4096
```

#### 4.1.2 创建 etcd 用户与目录

```bash
id -u etcd &>/dev/null || useradd -r -s /sbin/nologin -d /opt/etcd etcd
mkdir -p /opt/etcd/{bin,conf,ssl}
mkdir -p /data/etcd/{data,log}
chown -R etcd:etcd /opt/etcd /data/etcd
chmod 750 /opt/etcd/ssl
```

#### 4.1.3 设置 ulimit

```bash
cat > /etc/security/limits.d/99-etcd.conf << 'EOF'
etcd soft nofile 65536
etcd hard nofile 65536
etcd soft nproc 65536
etcd hard nproc 65536
EOF
```

#### 4.1.4 时间同步

```bash
timedatectl set-ntp true
timedatectl status  # 预期：NTP synchronized: yes
```

---

### 4.2 部署步骤

> 🖥️ **执行节点**：所有 etcd 节点（etcd-01、etcd-02、etcd-03）

#### 4.2.1 下载并安装 etcd

```bash
ETCD_VER=v3.6.8
DOWNLOAD_URL="https://github.com/etcd-io/etcd/releases/download"

[ -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz ] || \
  curl -L -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  "${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz"

tar xzf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp --strip-components=1
cp /tmp/etcd /tmp/etcdctl /tmp/etcdutl /opt/etcd/bin/
chown etcd:etcd /opt/etcd/bin/*
chmod 755 /opt/etcd/bin/*
```

```bash
# ✅ 验证
/opt/etcd/bin/etcd --version  # 预期：etcd Version: 3.6.8
```

#### 4.2.2 配置环境变量（以 etcd-01 为例）

```bash
NODE_NAME="etcd-01"
NODE_IP="192.168.1.101"
CLUSTER="etcd-01=http://192.168.1.101:2380,etcd-02=http://192.168.1.102:2380,etcd-03=http://192.168.1.103:2380"

cat > /opt/etcd/conf/etcd.env << EOF
ETCD_NAME=${NODE_NAME}
ETCD_DATA_DIR=/data/etcd/data
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://${NODE_IP}:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${NODE_IP}:2380"
ETCD_INITIAL_CLUSTER="${CLUSTER}"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-prod"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
chown etcd:etcd /opt/etcd/conf/etcd.env
```

> etcd-02、etcd-03 仅 `NODE_NAME`、`NODE_IP` 不同，`CLUSTER` 三节点必须相同。

#### 4.2.3 创建 systemd 服务

```bash
cat > /etc/systemd/system/etcd.service << 'EOF'
[Unit]
Description=etcd key-value store
Documentation=https://etcd.io
After=network.target

[Service]
Type=notify
User=etcd
EnvironmentFile=/opt/etcd/conf/etcd.env
ExecStart=/opt/etcd/bin/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
```

---

### 4.3 集群初始化与配置

```bash
# 所有节点执行（建议 01→02→03 间隔 2 秒）
systemctl enable --now etcd
```

```bash
# ✅ 验证（任意节点）
export ETCDCTL_API=3
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 endpoint health
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 member list -w table
# 预期：3 节点 healthy，均为 started
```

---

### 4.4 安装验证

```bash
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 put testkey "hello-etcd"
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 get testkey
# 预期：testkey / hello-etcd

/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 endpoint status -w table
# 预期：1 个 IS LEADER 为 true
```

---

### 4.5 安装后的目录结构

| 路径 | 用途 | 运维关注点 |
|------|------|------------|
| `/opt/etcd/bin/` | etcd、etcdctl、etcdutl | 升级时替换二进制 |
| `/opt/etcd/conf/` | etcd.env 环境配置 | 修改后需 systemctl restart etcd |
| `/data/etcd/data/` | 数据目录（--data-dir） | 必须纳入备份 |
| `/data/etcd/log/` | 日志（若配置） | 建议 logrotate |

```
/opt/etcd/
├── bin/          # etcd、etcdctl、etcdutl
├── conf/         # etcd.env 环境变量
└── ssl/          # TLS 证书（生产建议启用）

/data/etcd/
├── data/         # Raft 日志与快照，必须备份
└── log/          # 应用日志
```

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

etcd 使用环境变量（`/opt/etcd/conf/etcd.env`）。**必须修改项**：

| 参数 | 必须修改 | 说明 |
|------|----------|------|
| ETCD_NAME | ★ | 本节点名称，集群内唯一 |
| ETCD_LISTEN_CLIENT_URLS / ADVERTISE | ★ | 客户端地址，生产建议 HTTPS |
| ETCD_INITIAL_CLUSTER | ★ | 所有节点 peer URL，三节点必须相同 |
| ETCD_INITIAL_ADVERTISE_PEER_URLS | ★ | 本节点 peer 地址 |
| ETCD_INITIAL_CLUSTER_TOKEN | ⚠️ | 集群令牌，多集群共存时区分 |

**逐行注释示例**（etcd-01）：

```bash
# etcd.env - etcd-01 (192.168.1.101)
ETCD_NAME=etcd-01
ETCD_DATA_DIR=/data/etcd/data              # 数据目录，需 SSD

# 客户端：0.0.0.0 表示所有网卡；生产建议 https + TLS
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.1.101:2379"

# 集群内部 Raft 通信
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.1.101:2380"
ETCD_INITIAL_CLUSTER="etcd-01=http://192.168.1.101:2380,etcd-02=http://192.168.1.102:2380,etcd-03=http://192.168.1.103:2380"

ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-prod"
ETCD_INITIAL_CLUSTER_STATE="new"           # new=新建；existing=加入已有
ETCD_QUOTA_BACKEND_BYTES="2147483648"      # 2GB 存储配额
```

### 5.2 生产环境参数优化详解

| 参数 | 默认值 | 推荐值 | 说明 |
|------|--------|--------|------|
| `ETCD_AUTO_COMPACTION_RETENTION` | 0 | `1` 或 `24` | 自动压缩，单位小时，防止 DB 无限增长 |
| `ETCD_AUTO_COMPACTION_MODE` | periodic | periodic | periodic=按时间、revision=按版本数 |
| `ETCD_MAX_REQUEST_BYTES` | 1572864 | 1572864 | 单请求最大字节 |
| `ETCD_LOG_LEVEL` | info | info | debug/info/warn/error |
| `ETCD_LOG_OUTPUTS` | default | stderr | 或 /data/etcd/log/etcd.log |

```bash
# 追加到已有 etcd.env（4.2.2 已创建基础配置，此处补充调优参数）
cat >> /opt/etcd/conf/etcd.env << 'EOF'

ETCD_AUTO_COMPACTION_RETENTION="1"
ETCD_AUTO_COMPACTION_MODE="periodic"
ETCD_MAX_REQUEST_BYTES="1572864"
ETCD_LOG_LEVEL="info"
ETCD_LOG_OUTPUTS="stderr"
EOF
```

### 5.3 生产环境认证配置（用户与密码）

> 生产环境**必须**启用认证。etcd 支持 RBAC 与用户密码。

**建议**：集群正常后，先创建 root、启用 auth，再创建业务用户。

#### 5.3.1 创建 root 并启用认证

```bash
export ETCDCTL_API=3
ENDPOINTS="http://127.0.0.1:2379"

/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS role add root
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS user add root
# 按提示输入密码，如：YourNewRootPassword123!

/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS user grant-role root root
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS auth enable
```

**非交互式添加用户**：

```bash
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS user add appuser --interactive=false --new-user-password='YourAppPassword123!'

/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS role add approle
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS role grant-permission approle readwrite /app/
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS user grant-role appuser approle
```

#### 5.3.2 启用认证后的连接

```bash
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 --user=root:YourNewRootPassword123! put key val
/opt/etcd/bin/etcdctl --endpoints=http://127.0.0.1:2379 --user=appuser:YourAppPassword123! get /app/config
```

#### 5.3.3 修改密码

```bash
/opt/etcd/bin/etcdctl --endpoints=$ENDPOINTS --user=root:OldPassword user passwd root
```

> ⚠️ `auth enable` 前必须存在 root 且已绑定 root 角色。启用后妥善保管 root 密码。

---

## 6. 快速体验部署（开发 / 测试环境）

### 6.1 快速启动方案选型
Docker Compose 3 节点伪集群，适合本地验证。

### 6.2 快速启动步骤与验证

**方式一**：在文档目录执行（若已有 docker-compose.yml）：
```bash
cd $(dirname <文档路径>)/..   # 或 cd 02-message-queue/etcd/etcd-cluster-production
docker compose up -d
sleep 5
docker exec etcd1 etcdctl endpoint health --endpoints=http://localhost:2379,http://etcd2:2379,http://etcd3:2379
```

**方式二**：任意目录创建并启动（自包含）：
```bash
mkdir -p /tmp/etcd-verify && cd /tmp/etcd-verify

cat > docker-compose.yml << 'EOF'
services:
  etcd1:
    image: quay.io/coreos/etcd:v3.6.8
    container_name: etcd1
    command:
      - etcd
      - --name=etcd1
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd1:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd1:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=verify
      - --initial-cluster-state=new
    ports: ["23791:2379", "23801:2380"]
    networks: [etcd-net]
  etcd2:
    image: quay.io/coreos/etcd:v3.6.8
    container_name: etcd2
    command:
      - etcd
      - --name=etcd2
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd2:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd2:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=verify
      - --initial-cluster-state=new
    ports: ["23792:2379", "23802:2380"]
    networks: [etcd-net]
  etcd3:
    image: quay.io/coreos/etcd:v3.6.8
    container_name: etcd3
    command:
      - etcd
      - --name=etcd3
      - --data-dir=/etcd-data
      - --listen-client-urls=http://0.0.0.0:2379
      - --advertise-client-urls=http://etcd3:2379
      - --listen-peer-urls=http://0.0.0.0:2380
      - --initial-advertise-peer-urls=http://etcd3:2380
      - --initial-cluster=etcd1=http://etcd1:2380,etcd2=http://etcd2:2380,etcd3=http://etcd3:2380
      - --initial-cluster-token=verify
      - --initial-cluster-state=new
    ports: ["23793:2379", "23803:2380"]
    networks: [etcd-net]
networks:
  etcd-net: {}
EOF

docker compose up -d
sleep 5
docker exec etcd1 etcdctl endpoint health --endpoints=http://localhost:2379,http://etcd2:2379,http://etcd3:2379
```

### 6.3 停止与清理

```bash
docker compose down -v
```

---

## 7. 日常运维操作

### 7.1 常用管理命令与使用演示

| 命令 | 说明 |
|------|------|
| `etcdctl endpoint health` | 健康检查 |
| `etcdctl member list` | 成员列表 |
| `etcdctl endpoint status` | 节点状态（含 Leader） |
| `etcdctl put key val` | 写入 |
| `etcdctl get key` | 读取 |

```bash
# 健康检查（预期：3 个 endpoint 均 healthy）
ETCDCTL_API=3 etcdctl endpoint health --endpoints=http://192.168.1.101:2379,http://192.168.1.102:2379,http://192.168.1.103:2379

# 成员列表
etcdctl member list --endpoints=http://127.0.0.1:2379

# 节点状态（含 Leader 标记，true 表示该节点为 Leader）
etcdctl endpoint status --endpoints=http://192.168.1.101:2379,http://192.168.1.102:2379,http://192.168.1.103:2379

# 写入与读取
etcdctl put /app/config '{"key":"value"}' --endpoints=http://127.0.0.1:2379
etcdctl get /app/config --endpoints=http://127.0.0.1:2379
```

**客户端连接代码片段**（Python + Go）：

```python
# Python（etcd3）
import etcd3

client = etcd3.client(host='192.168.1.101', port=2379)
client.put('/app/config', '{"key":"value"}')
value, _ = client.get('/app/config')
print(value)
```

```go
// Go（go.etcd.io/etcd/client/v3）
package main

import (
    "context"
    "log"
    "time"
    "go.etcd.io/etcd/client/v3"
)

func main() {
    cli, err := clientv3.New(clientv3.Config{
        Endpoints:   []string{"http://192.168.1.101:2379", "http://192.168.1.102:2379"},
        DialTimeout: 5 * time.Second,
    })
    if err != nil { log.Fatal(err) }
    defer cli.Close()

    _, err = cli.Put(context.Background(), "/app/config", `{"key":"value"}`)
    if err != nil { log.Fatal(err) }

    resp, err := cli.Get(context.Background(), "/app/config")
    if err != nil { log.Fatal(err) }
    for _, v := range resp.Kvs { log.Printf("%s", v.Value) }
}
```

### 7.2 备份与恢复

**备份**：
```bash
ETCDCTL_API=3 /opt/etcd/bin/etcdctl snapshot save /backup/etcd/etcd-$(date +%Y%m%d_%H%M%S).db \
  --endpoints=http://127.0.0.1:2379
```

**恢复**（每节点执行，`--name`、`--initial-advertise-peer-urls` 按节点修改）：
```bash
systemctl stop etcd
rm -rf /data/etcd/data/*

/opt/etcd/bin/etcdutl snapshot restore /backup/etcd/etcd-xxx.db \
  --name=etcd-01 \
  --data-dir=/data/etcd/data \
  --initial-cluster=etcd-01=http://192.168.1.101:2380,etcd-02=http://192.168.1.102:2380,etcd-03=http://192.168.1.103:2380 \
  --initial-cluster-token=etcd-cluster-prod \
  --initial-advertise-peer-urls=http://192.168.1.101:2380

chown -R etcd:etcd /data/etcd/data
systemctl start etcd
```

### 7.3 集群扩缩容
参考 [etcd 官方运维指南](https://etcd.io/docs/v3.6/op-guide/runtime-configuration/)。

### 7.4 版本升级
参考 [升级指南](https://etcd.io/docs/v3.6/upgrades/upgrade_3_6/)。

### 7.5 日志清理与轮转

**logrotate 配置**：
```bash
cat > /etc/logrotate.d/etcd << 'EOF'
/data/etcd/log/*.log {
    daily
    rotate 14
    size 100M
    compress
    delaycompress
    copytruncate
    missingok
    notifempty
}
EOF
```
验证：`logrotate -d /etc/logrotate.d/etcd`

---

## 9. 监控与告警接入

### 9.1 Prometheus 指标
etcd 内置 `/metrics`，无需单独 Exporter。端点：`http://{node}:2379/metrics`。

### 9.2 关键监控指标

| 指标 | 说明 | 告警建议 |
|------|------|---------|
| `etcd_server_has_leader` | 是否有 Leader | 0 告警 |
| `etcd_server_leader_changes_seen_total` | Leader 切换 | 1h 内 > 3 告警 |
| `etcd_disk_backend_commit_duration_seconds` | 磁盘延迟 | p99 > 0.5s 告警 |

### 9.3 Grafana Dashboard
Dashboard ID：**3070**（etcd 官方）

### 9.4 告警规则示例
```yaml
- alert: EtcdNoLeader
  expr: etcd_server_has_leader == 0
  for: 1m
  labels: { severity: critical }
  annotations: { summary: "etcd 集群无 Leader" }
```

---

## 10. 注意事项与生产检查清单

### 10.1 安装前环境核查
- [ ] 3 节点时钟同步（NTP）
- [ ] 2379、2380 端口互通
- [ ] 数据目录使用 SSD
- [ ] 内核参数已调优

### 10.2 常见故障排查与处理指南

#### 故障一：节点无法加入集群

**现象**：`etcdctl member list` 仅显示 1~2 个节点，新节点日志报 `connection refused` 或 `cluster id mismatch`。

**原因**：
- `ETCD_INITIAL_CLUSTER` 三节点配置不一致（名称、IP、端口）
- `ETCD_INITIAL_CLUSTER_TOKEN` 不同
- 2380 端口未放行或网络不通

**排查步骤**：
```bash
# 1. 检查各节点环境变量是否一致
cat /opt/etcd/conf/etcd.env | grep ETCD_INITIAL_CLUSTER

# 2. 测试 2380 互通
nc -zv 192.168.1.102 2380   # 从 101 测试到 102

# 3. 查看已有成员
etcdctl member list --endpoints=http://127.0.0.1:2379
```

**解决方案**：确保 3 节点 `ETCD_INITIAL_CLUSTER`、`ETCD_INITIAL_CLUSTER_TOKEN` 完全一致；防火墙放行 2380；修复网络后重启 etcd。

---

#### 故障二：集群无 Leader（etcd_server_has_leader=0）

**现象**：`etcdctl endpoint status` 无 Leader 标记，客户端读写超时，Prometheus 告警 `etcd_server_has_leader == 0`。

**Raft 状态流转图**：

```mermaid
stateDiagram-v2
    [*] --> Follower
    Follower --> Candidate: 选举超时（未收到 Leader 心跳）
    Candidate --> Leader: 获得多数票（N/2+1）
    Candidate --> Follower: 发现更高 term 或超时
    Leader --> Follower: 发现更高 term（网络分区后少数派）
    Follower --> [*]: 节点宕机
    Leader --> [*]: 节点宕机
```

**原因**：
- **节点数不足半数**：3 节点集群中 2 节点宕机，无法形成多数派
- **网络分区**：少数派（1 节点）无法选举，多数派（2 节点）可继续服务
- **磁盘满**：etcd 无法写入 WAL，节点自退出
- **时钟严重漂移**：Raft 依赖时间，漂移过大导致选举异常

**排查步骤**：
```bash
# 1. 检查存活节点数
etcdctl endpoint status --endpoints=http://node1:2379,http://node2:2379,http://node3:2379

# 2. 检查各节点磁盘
df -h /data/etcd/data

# 3. 检查各节点 etcd 进程与日志
systemctl status etcd
journalctl -u etcd -n 50 --no-pager
```

**解决方案**：

| 场景 | 恢复思路 |
|------|---------|
| 1 节点宕机 | 恢复该节点即可，2/3 多数派仍可读写，无需人工干预 |
| 2 节点宕机 | **无法自动恢复**，需尽快恢复至少 1 个节点使多数派（2/3）恢复；若 2 节点永久丢失，需从快照重建集群（见故障五） |
| 网络分区 | 多数派侧可继续服务；少数派侧无法选举，网络恢复后自动同步 |
| 磁盘满 | 扩容或清理磁盘，重启 etcd；调小 `ETCD_AUTO_COMPACTION_RETENTION` 减少空间占用 |

---

#### 故障三：单节点宕机恢复

**现象**：某节点 `systemctl status etcd` 显示 failed 或机器宕机。

**恢复思路**：

1. **若为进程异常退出**：`systemctl restart etcd`，数据目录完整时自动从其他节点同步
2. **若为机器宕机**：修复机器后启动 etcd，加入现有集群（`--initial-cluster-state=existing`）
3. **若数据目录损坏**：从备份快照恢复该节点（见故障五），或删除该成员后重新添加

**验证**：
```bash
etcdctl endpoint health --endpoints=http://node1:2379,http://node2:2379,http://node3:2379
# 预期：3 个 endpoint 均 healthy
```

---

#### 故障四：多数节点宕机（2/3 节点永久丢失）

**现象**：3 节点集群中 2 节点磁盘损坏或机器不可恢复，仅 1 节点存活，集群无法形成多数派。

**恢复思路**：**必须从快照重建集群**，存活节点的数据可能不是最新，需使用故障前最后一次完整备份。

```bash
# 1. 在存活节点或备份服务器上，使用最近一次快照
# 2. 在 3 台新机器上执行（或复用 1 台存活 + 2 台新机器）：
systemctl stop etcd
rm -rf /data/etcd/data/*

/opt/etcd/bin/etcdutl snapshot restore /backup/etcd/etcd-20260314.db \
  --name=etcd-01 \
  --data-dir=/data/etcd/data \
  --initial-cluster=etcd-01=http://192.168.1.101:2380,etcd-02=http://192.168.1.102:2380,etcd-03=http://192.168.1.103:2380 \
  --initial-cluster-token=etcd-cluster-recovery \
  --initial-advertise-peer-urls=http://192.168.1.101:2380

chown -R etcd:etcd /data/etcd/data

# 3. 修改 etcd 启动参数：--initial-cluster-state=existing
# 4. 三节点同时启动
systemctl start etcd
```

> ⚠️ **注意**：恢复后 `initial-cluster-token` 会变化，依赖该 token 的客户端（如 K8s）需重启。恢复会丢失快照之后的数据。

---

#### 故障五：数据损坏或误删后从快照恢复

**现象**：数据目录损坏、误执行 `etcdctl del --prefix ""` 等导致数据丢失。

**恢复思路**：

1. **单节点数据损坏**：停止该节点，清空数据目录，从其他节点通过 `etcdctl snapshot save` 拉取最新快照，用 `etcdutl snapshot restore` 恢复后重启，以新成员身份加入（或复用原成员配置，`--initial-cluster-state=existing`）
2. **全集群恢复**：按故障四执行，使用最近一次备份快照

**备份恢复验证**（伪集群验证通过）：
```bash
# 备份
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd/etcd-$(date +%Y%m%d_%H%M%S).db --endpoints=http://127.0.0.1:2379

# 恢复（每节点 --name、--initial-advertise-peer-urls 不同）
etcdutl snapshot restore /backup/etcd/etcd-xxx.db --name=etcd-01 --data-dir=/data/etcd/data \
  --initial-cluster=etcd-01=http://192.168.1.101:2380,etcd-02=http://192.168.1.102:2380,etcd-03=http://192.168.1.103:2380 \
  --initial-cluster-token=etcd-cluster-prod --initial-advertise-peer-urls=http://192.168.1.101:2380
```

---

#### 故障六：Leader 频繁切换

**现象**：`etcd_server_leader_changes_seen_total` 在 1 小时内增加 > 3 次，客户端偶发超时。

**原因**：网络抖动、磁盘 I/O 延迟高、CPU 负载过高导致心跳超时，触发重新选举。

**排查步骤**：
```bash
# 查看 Leader 切换历史
curl -s http://127.0.0.1:2379/metrics | grep etcd_server_leader_changes

# 检查磁盘延迟
curl -s http://127.0.0.1:2379/metrics | grep etcd_disk_backend_commit_duration
```

**解决方案**：
- 检查网络质量，避免跨机房延迟过高
- 确保使用 SSD，避免 HDD 或 NFS
- 调大 `ETCD_ELECTION_TIMEOUT`（默认 1000ms，谨慎调整）
- 降低集群负载，扩容节点或拆分业务

---

#### 故障七：磁盘空间不足

**现象**：日志报 `no space left on device`，etcd 进程退出。

**解决**：
1. 扩容磁盘或清理其他文件
2. 调小 `ETCD_AUTO_COMPACTION_RETENTION`（如从 3 改为 1，单位小时）
3. 恢复磁盘空间后重启 etcd
4. **预防**：对数据目录配置 Prometheus 磁盘使用率告警（> 80% 告警）

---

#### 故障八：成员误删

**现象**：误执行 `etcdctl member remove <member_id>`，导致集群成员数减少。

**恢复思路**：
- 若删除的节点仍存活：用 `etcdctl member add` 重新添加，需提供 `--peer-urls`，新成员会获得新 ID
- 若删除后集群仍满足多数派：可继续运行，补足新节点即可
- 若删除后不足多数派：需从快照恢复（见故障四）

---

### 10.3 安全加固建议
- 启用 TLS（`--cert-file`、`--key-file`、`--trusted-ca-file`）
- 启用 RBAC 认证
- 限制 2379、2380 仅内网访问

### 10.4 伪集群验证踩坑与经验总结

| 问题现象 | 原因 | 解决方式 |
|---------|------|---------|
| member list 为空 | 容器启动延迟 | 等待 5~10 秒后重试 |
| snapshot restore 报错 | etcd 3.6 参数变化 | 用 `etcdutl snapshot restore` |
| initial-cluster 写 127.0.0.1 | 多节点需实际 IP | 生产必须用可解析地址 |

---

## 11. 参考资料

- [etcd 官方文档](https://etcd.io/docs/v3.6/)
- [etcd 运维指南](https://etcd.io/docs/v3.6/op-guide/)
- [etcd 升级指南](https://etcd.io/docs/v3.6/upgrades/upgrade_3_6/)
