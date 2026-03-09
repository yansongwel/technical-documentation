---
title: K3s与AutoK3s生产级部署与运维指南
author: devinyan
updated: 2026-03-09
version: 1.0.0
---

[TOC]

---

# K3s与AutoK3s生产级部署与运维指南

## 1. 简介

### 1.1 服务介绍与核心特性

**K3s** 是 Rancher 推出的轻量级 Kubernetes 发行版，专为边缘计算、IoT 设备和资源受限环境设计。它完全符合 Kubernetes API 标准，但资源占用极低，非常适合生产环境中的边缘场景和轻量级容器平台。

**AutoK3s** 是 K3s 的自动化部署工具，通过简单的 CLI 命令即可快速创建和管理多个 K3s 集群，支持多云平台部署。

#### K3s 核心特性

- **极简安装**：单一二进制文件，小于 100MB，无外部依赖
- **资源高效**：最低 512MB RAM 即可运行，适合资源受限环境
- **完全合规**：100% 符合 Kubernetes API 标准，无缝迁移
- **安全加固**：默认启用 RBAC、TLS 认证，通过 CIS benchmark
- **高可用支持**：支持外部数据库（MySQL/PostgreSQL/etcd）实现 HA
- **内置存储**：默认 SQLite，支持 MySQL、PostgreSQL、etcd
- **简化维护**：自动轮换证书，自动化升级机制
- **边缘优化**：支持 ARM 架构，离线安装，Air-gap 部署
- **集成工具**：内置 Helm controller、Traefik ingress、ServiceLB

#### AutoK3s 核心特性

- **一键部署**：单命令创建 K3s 集群
- **多云支持**：阿里云、腾讯云、AWS、Azure、VMware、裸金属
- **集群管理**：统一的 CLI 管理多个 K3s 集群
- **自动化运维**：自动扩缩容、自动升级、自动备份
- **配置即代码**：支持 YAML 配置文件管理集群
- **安全集成**：自动配置 TLS 证书和密钥管理

### 1.2 适用场景

| 场景 | K3s | AutoK3s |
|------|-----|---------|
| **边缘计算** | ✅ CDN 节点、IoT 网关 | ✅ 批量部署边缘节点 |
| **CI/CD 环境** | ✅ 轻量级测试集群 | ✅ 快速创建临时集群 |
| **开发测试** | ✅ 本地开发环境 | ✅ 多租户隔离 |
| **小型生产** | ✅ 中小企业容器平台 | ✅ 快速上线 |
| **边缘 AI** | ✅ 边缘推理集群 | ✅ 分布式 AI 节点管理 |
| **混合云** | ✅ 跨云统一部署 | ✅ 多云集群统一管理 |
| **资源受限** | ✅ 树莓派、嵌入式设备 | ❌ 需要控制节点 |
| **IoT 设备** | ✅ 工业物联网网关 | ✅ 大规模设备集群 |

### 1.3 架构原理图

#### K3s 高可用架构图

```mermaid
graph TB
    subgraph "访问层"
        A1[用户/客户端]
        A2[负载均衡 VIP: 6443]
        LB1[HAProxy-01]
        LB2[HAProxy-02]
    end

    subgraph "K3s Server 节点 (3节点)"
        S1[Server-01<br/>192.168.1.10<br/>API Server<br/>Scheduler<br/>Controller]
        S2[Server-02<br/>192.168.1.11<br/>API Server<br/>Scheduler<br/>Controller]
        S3[Server-03<br/>192.168.1.12<br/>API Server<br/>Scheduler<br/>Controller]
    end

    subgraph "K3s Agent 节点 (3+节点)"
        A1[Agent-01<br/>192.168.1.20<br/>Kubelet<br/>Containerd<br/>Flannel]
        A2[Agent-02<br/>192.168.1.21<br/>Kubelet<br/>Containerd<br/>Flannel]
        A3[Agent-03<br/>192.168.1.22<br/>Kubelet<br/>Containerd<br/>Flannel]
        AN[Agent-N<br/>可扩展]
    end

    subgraph "数据存储层 (外部数据库)"
        DB[(PostgreSQL/MySQL<br/>主从复制集群)]
    end

    subgraph "AutoK3s 管理层"
        MGR[AutoK3s CLI<br/>集群管理]
        CFG[集群配置<br/>YAML文件]
    end

    User[用户/运维] --> MGR
    MGR --> CFG
    MGR -.创建/管理.-> S1
    MGR -.创建/管理.-> S2
    MGR -.创建/管理.-> S3

    A1 --> A2
    A2 --> LB1
    A2 --> LB2

    LB1 --> S1
    LB1 --> S2
    LB1 --> S3

    LB2 --> S1
    LB2 --> S2
    LB2 --> S3

    S1 <--> S2
    S2 <--> S3
    S3 <--> S1

    S1 --> DB
    S2 --> DB
    S3 --> DB

    S1 --> A1
    S2 --> A2
    S3 --> A3

    style A2 fill:#3498DB,stroke:#2980B9,color:#fff
    style LB1 fill:#9B59B6,stroke:#6E3A80,color:#fff
    style LB2 fill:#9B59B6,stroke:#6E3A80,color:#fff
    style S1 fill:#E74C3C,stroke:#C0392B,color:#fff
    style S2 fill:#E74C3C,stroke:#C0392B,color:#fff
    style S3 fill:#E74C3C,stroke:#C0392B,color:#fff
    style A1 fill:#27AE60,stroke:#1E8449,color:#fff
    style A2 fill:#27AE60,stroke:#1E8449,color:#fff
    style A3 fill:#27AE60,stroke:#1E8449,color:#fff
    style AN fill:#27AE60,stroke:#1E8449,color:#fff
    style DB fill:#F39C12,stroke:#D68910,color:#fff
    style MGR fill:#1ABC9C,stroke:#16A085,color:#fff
    style CFG fill:#1ABC9C,stroke:#16A085,color:#fff
```

#### AutoK3s 工作流程图

```mermaid
graph LR
    A[AutoK3s CLI] --> B{选择云平台}
    B -->|阿里云| C[Aliyun Provider]
    B -->|腾讯云| D[Tencent Provider]
    B -->|AWS| E[AWS Provider]
    B -->|本地/裸金属| F[SSH Provider]

    C --> G[创建 K3s 集群]
    D --> G
    E --> G
    F --> G

    G --> H[配置外部数据库]
    G --> I[部署 Server 节点]
    G --> J[部署 Agent 节点]

    H --> K[高可用 K3s 集群]
    I --> K
    J --> K

    K --> L[AutoK3s 管理多集群]

    style A fill:#1ABC9C,stroke:#16A085,color:#fff
    style G fill:#3498DB,stroke:#2980B9,color:#fff
    style K fill:#27AE60,stroke:#1E8449,color:#fff
    style L fill:#9B59B6,stroke:#6E3A80,color:#fff
```

**架构说明：**

- **访问层**：通过 VIP 提供统一 API 入口
- **K3s Server 节点**：运行 Kubernetes 控制平面组件
- **K3s Agent 节点**：运行工作负载，轻量级设计
- **数据存储层**：外部数据库（PostgreSQL/MySQL）保证数据一致性
- **AutoK3s 管理层**：统一管理多个 K3s 集群的生命周期

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| K3s 版本 | Kubernetes 版本 | 发布日期 | 状态 | 支持期限 | 推荐场景 |
|----------|-----------------|----------|------|----------|----------|
| **1.29.x** | Kubernetes 1.29.x | 2024-Q4 | 稳定版 | 14个月 | 生产环境（推荐） |
| **1.28.x** | Kubernetes 1.28.x | 2024-Q2 | 稳定版 | 14个月 | 生产环境 |
| **1.27.x** | Kubernetes 1.27.x | 2024-Q1 | 维护模式 | 12个月 | 现有集群 |
| **1.26.x** | Kubernetes 1.26.x | 2023-Q4 | 即将 EOL | 已结束 | 建议升级 |

| AutoK3s 版本 | 兼容 K3s 版本 | 发布日期 | 状态 | 推荐场景 |
|-------------|---------------|----------|------|----------|
| **v0.5.x** | K3s 1.27.x - 1.29.x | 2024-Q4 | 稳定版 | 生产环境（推荐） |
| **v0.4.x** | K3s 1.25.x - 1.28.x | 2024-Q2 | 维护模式 | 现有环境 |
| **v0.3.x** | K3s 1.24.x - 1.26.x | 2023-Q4 | 即将 EOL | 建议升级 |

> 💡 **提示**：K3s 版本号与 Kubernetes 版本号保持一致，如 K3s 1.29.3 = Kubernetes 1.29.3

### 2.2 版本决策建议

**选择 K3s 1.29.x + AutoK3s v0.5.x 系列的情况：**
- 新建生产环境部署
- 需要最新的 Kubernetes 特性支持
- 对资源占用有严格要求的边缘场景
- 计划使用 AutoK3s 进行大规模集群管理
- 需要 ARM 架构支持（树莓派等）

**选择 K3s 1.28.x 系列的情况：**
- 需要更成熟的稳定性
- 依赖特定版本的生态工具链
- 团队对该版本有丰富的运维经验
- 硬件资源较老，需要更好的兼容性

**AutoK3s 使用建议：**
- **多云部署**：需要跨多个云平台统一管理 K3s 集群
- **批量部署**：需要快速创建大量边缘 K3s 集群
- **自动化运维**：需要自动扩缩容、自动升级功能
- **小规模部署**：单集群或少量集群可手动安装 K3s

**版本升级注意事项：**
- 小版本升级（如 1.29.0 → 1.29.5）：支持自动升级，风险较低
- 大版本升级（如 1.28.x → 1.29.x）：建议先在测试环境验证
- 升级前务必备份数据库和重要配置
- K3s 支持自动升级功能，可通过配置启用
- AutoK3s 支持一键升级多集群

---

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

#### 生产级 K3s 高可用架构

```mermaid
graph TB
    subgraph "负载均衡层 (Nginx/HAProxy)"
        LB1[LB-01: 192.168.1.5<br/>VIP: 192.168.1.4]
        LB2[LB-02: 192.168.1.6<br/>VIP: 192.168.1.4]
    end

    subgraph "K3s Server 节点 (3节点, 奇数个)"
        S1[Server-01<br/>192.168.1.10<br/>API Server<br/>Controller Manager<br/>Scheduler]
        S2[Server-02<br/>192.168.1.11<br/>API Server<br/>Controller Manager<br/>Scheduler]
        S3[Server-03<br/>192.168.1.12<br/>API Server<br/>Controller Manager<br/>Scheduler]
    end

    subgraph "K3s Agent 节点 (3+节点)"
        A1[Agent-01<br/>192.168.1.20<br/>Kubelet+Containerd]
        A2[Agent-02<br/>192.168.1.21<br/>Kubelet+Containerd]
        A3[Agent-03<br/>192.168.1.22<br/>Kubelet+Containerd]
        AN[Agent-N<br/>可扩展]
    end

    subgraph "外部数据存储层"
        PG[(PostgreSQL<br/>主从复制<br/>3节点)]
        MY[(MySQL<br/>Group Replication<br/>3节点)]
        ET[(etcd 集群<br/>3节点)]
    end

    subgraph "存储层 (可选)"
        ST1[Longhorn<br/>分布式存储]
        ST2[NFS/CSI<br/>外部存储]
    end

    subgraph "监控备份层"
        MON[Prometheus+Grafana<br/>监控告警]
        BK[Velero<br/>备份恢复]
    end

    User[用户/应用] --> LB1
    User --> LB2

    LB1 --> S1
    LB1 --> S2
    LB1 --> S3

    LB2 --> S1
    LB2 --> S2
    LB2 --> S3

    S1 <--> S2
    S2 <--> S3
    S3 <--> S1

    S1 --> PG
    S2 --> PG
    S3 --> PG

    S1 --> A1
    S2 --> A2
    S3 --> A3

    A1 --> ST1
    A2 --> ST1
    A3 --> ST2

    S1 -.监控.-> MON
    S2 -.监控.-> MON
    A1 -.监控.-> MON

    S1 -.备份.-> BK
    A1 -.备份.-> BK

    style LB1 fill:#3498DB,stroke:#2980B9,color:#fff
    style LB2 fill:#3498DB,stroke:#2980B9,color:#fff
    style S1 fill:#E74C3C,stroke:#C0392B,color:#fff
    style S2 fill:#E74C3C,stroke:#C0392B,color:#fff
    style S3 fill:#E74C3C,stroke:#C0392B,color:#fff
    style A1 fill:#27AE60,stroke:#1E8449,color:#fff
    style A2 fill:#27AE60,stroke:#1E8449,color:#fff
    style A3 fill:#27AE60,stroke:#1E8449,color:#fff
    style AN fill:#27AE60,stroke:#1E8449,color:#fff
    style PG fill:#F39C12,stroke:#D68910,color:#fff
    style MY fill:#F39C12,stroke:#D68910,color:#fff
    style ET fill:#F39C12,stroke:#D68910,color:#fff
    style BK fill:#9B59B6,stroke:#6E3A80,color:#fff
    style MON fill:#9B59B6,stroke:#6E3A80,color:#fff
```

### 3.2 节点角色与配置要求

#### K3s Server 节点配置（3 节点）

| 配置项 | 最低配置 | 推荐配置 | 说明 |
|--------|----------|----------|------|
| **CPU** | 1 Core | 2 Core+ | 控制平面组件消耗 CPU |
| **内存** | 1 GB | 4 GB+ | 轻量级设计，内存占用低 |
| **磁盘** | 20 GB SSD | 50 GB NVMe SSD | 系统盘 + 日志 + 数据 |
| **网络** | 100 Mbps | 1 Gbps | 节点间通信带宽 |
| **操作系统** | Rocky Linux 9 / Ubuntu 22.04 / Raspberry Pi OS | Rocky Linux 9 / Ubuntu 22.04 | 支持 x86_64 / ARM64 |
| **角色** | Server + Agent | Server + Agent | 控制平面节点 |

#### K3s Agent 节点配置（3+ 节点）

| 配置项 | 最低配置 | 推荐配置 | 说明 |
|--------|----------|----------|------|
| **CPU** | 1 Core | 4 Core+ | 根据业务负载调整 |
| **内存** | 512 MB | 4 GB+ | 根据应用需求调整 |
| **磁盘** | 20 GB SSD | 100 GB NVMe SSD | 容器镜像 + 数据卷 |
| **网络** | 100 Mbps | 1 Gbps | 业务流量带宽 |
| **操作系统** | Rocky Linux 9 / Ubuntu 22.04 / Raspberry Pi OS | Rocky Linux 9 / Ubuntu 22.04 | 支持 x86_64 / ARM64 |
| **角色** | Agent | Agent | 工作负载节点 |

#### 外部数据库配置（PostgreSQL 主从复制）

| 配置项 | 最低配置 | 推荐配置 | 说明 |
|--------|----------|----------|------|
| **CPU** | 2 Core | 4 Core+ | 数据库查询性能 |
| **内存** | 2 GB | 8 GB+ | 缓冲池大小 |
| **磁盘** | 50 GB SSD | 200 GB NVMe SSD | 数据存储 + WAL |
| **网络** | 1 Gbps | 10 Gbps | 复制流量 |
| **节点数** | 2 节点（主从） | 3 节点（主从+从） | 高可用部署 |

#### 负载均衡节点配置（2 节点）

| 配置项 | 最低配置 | 推荐配置 | 说明 |
|--------|----------|----------|------|
| **CPU** | 1 Core | 2 Core | Nginx/HAProxy |
| **内存** | 512 MB | 2 GB | 连接跟踪 |
| **磁盘** | 20 GB SSD | 50 GB SSD | 系统盘 |
| **网络** | 1 Gbps | 10 Gbps | API 流量转发 |
| **VIP** | 192.168.1.4（示例） | 根据规划设置 | 虚拟 IP 地址 |

### 3.3 网络与端口规划

#### K3s Server 节点网络端口

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|----------|------|------|
| LB 节点 VIP | 6443 | TCP | Kubernetes API Server |
| Server 节点间 | 6443 | TCP | Kubernetes API Server |
| Agent 节点 | 6443 | TCP | Kubernetes API Server |
| Server 节点间 | 10250 | TCP | Kubelet API |
| 数据库节点 | 5432 / 3306 / 2379 | TCP | PostgreSQL / MySQL / etcd |
| 监控节点 | 9100 | TCP | Node Exporter |
| 监控节点 | 10259 | TCP | Scheduler 健康 |
| 监控节点 | 10257 | TCP | Controller Manager 健康 |
| CNI 插件 | 8472 | UDP | Flannel VXLAN |
| CNI 插件 | 51820 / 51821 | UDP | Flannel VXLAN（新版） |

#### K3s Agent 节点网络端口

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|----------|------|------|
| Server 节点 | 10250 | TCP | Kubelet API |
| Server 节点 | 9100 | TCP | Node Exporter |
| 所有 Pod | 30000-32767 | TCP/UDP | NodePort 服务范围 |
| 外部访问 | 80/443 | TCP | Ingress HTTP/HTTPS |
| CNI 插件 | 8472 | UDP | Flannel VXLAN |
| CNI 插件 | 51820 / 51821 | UDP | Flannel VXLAN（新版） |

#### 负载均衡节点网络端口

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|----------|------|------|
| 用户/客户端 | 6443 | TCP | Kubernetes API 访问 |
| Server 节点 | 6443 | TCP | 后端健康检查 |
| VRRP 组播 | - | VRRP | Keepalived 心跳 |

#### 数据库节点网络端口

| 源地址 | 目标端口 | 协议 | 用途 |
|--------|----------|------|------|
| K3s Server 节点 | 5432 | TCP | PostgreSQL |
| K3s Server 节点 | 3306 | TCP | MySQL |
| K3s Server 节点 | 2379-2380 | TCP | etcd |
| 数据库节点间 | 5432 / 3306 | TCP | 主从复制 |

#### 防火墙配置清单

```bash
# ── Rocky Linux 9 (firewalld) ──────────────────────────
# Server 节点
firewall-cmd --permanent --add-port=6443/tcp   # Kubernetes API
firewall-cmd --permanent --add-port=10250/tcp  # Kubelet
firewall-cmd --permanent --add-port=8472/udp   # Flannel VXLAN
firewall-cmd --permanent --add-port=51820/udp  # Flannel VXLAN (新版)
firewall-cmd --permanent --add-port=51821/udp  # Flannel VXLAN (新版)
firewall-cmd --permanent --add-port=9100/tcp   # Node Exporter
firewall-cmd --permanent --add-port=10259/tcp  # Scheduler
firewall-cmd --permanent --add-port=10257/tcp  # Controller Manager
firewall-cmd --permanent --add-port=30000-32767/tcp  # NodePort
firewall-cmd --permanent --add-port=30000-32767/udp
firewall-cmd --reload

# Agent 节点
firewall-cmd --permanent --add-port=10250/tcp  # Kubelet
firewall-cmd --permanent --add-port=8472/udp   # Flannel VXLAN
firewall-cmd --permanent --add-port=51820/udp
firewall-cmd --permanent --add-port=51821/udp
firewall-cmd --permanent --add-port=9100/tcp   # Node Exporter
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --permanent --add-port=30000-32767/udp
firewall-cmd --reload

# ── Ubuntu 22.04 (ufw) ───────────────────────────
# Server 节点
ufw allow 6443/tcp   # Kubernetes API
ufw allow 10250/tcp  # Kubelet
ufw allow 8472/udp   # Flannel VXLAN
ufw allow 51820/udp
ufw allow 51821/udp
ufw allow 9100/tcp   # Node Exporter
ufw allow 10259/tcp  # Scheduler
ufw allow 10257/tcp  # Controller Manager
ufw allow 30000:32767/tcp  # NodePort
ufw allow 30000:32767/udp

# Agent 节点
ufw allow 10250/tcp  # Kubelet
ufw allow 8472/udp   # Flannel VXLAN
ufw allow 51820/udp
ufw allow 51821/udp
ufw allow 9100/tcp   # Node Exporter
ufw allow 30000:32767/tcp
ufw allow 30000:32767/udp
```

---

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

#### 4.1.1 系统初始化

```bash
# ── Rocky Linux 9 ──────────────────────────
# 配置主机名
hostnamectl set-hostname k3s-server-01  # ← 根据实际节点修改
# Server 节点: k3s-server-01/02/03
# Agent 节点: k3s-agent-01/02/03
# LB 节点: k3s-lb-01/02

# 配置 hosts 文件（所有节点一致）
cat >> /etc/hosts << 'EOF'
192.168.1.5  k3s-lb-01
192.168.1.6  k3s-lb-02
192.168.1.10 k3s-server-01
192.168.1.11 k3s-server-02
192.168.1.12 k3s-server-03
192.168.1.20 k3s-agent-01
192.168.1.21 k3s-agent-02
192.168.1.22 k3s-agent-03
192.168.1.4  k3s-api  # ← VIP 地址
192.168.1.30 pg-master
192.168.1.31 pg-slave-01
192.168.1.32 pg-slave-02
EOF

# 更新系统
dnf update -y

# ── Ubuntu 22.04 ───────────────────────────
# 配置主机名
hostnamectl set-hostname k3s-server-01

# 配置 hosts 文件
cat >> /etc/hosts << 'EOF'
192.168.1.5  k3s-lb-01
192.168.1.6  k3s-lb-02
192.168.1.10 k3s-server-01
192.168.1.11 k3s-server-02
192.168.1.12 k3s-server-03
192.168.1.20 k3s-agent-01
192.168.1.21 k3s-agent-02
192.168.1.22 k3s-agent-03
192.168.1.4  k3s-api
192.168.1.30 pg-master
192.168.1.31 pg-slave-01
192.168.1.32 pg-slave-02
EOF

# 更新系统
apt-get update && apt-get upgrade -y
```

#### 4.1.2 关闭 Swap 分区

```bash
# ── Rocky Linux 9 & Ubuntu 22.04 ──────────────────────────
# 临时关闭
swapoff -a

# 永久关闭
sed -ri 's/^(.*swap.*)$/#\1/g' /etc/fstab

# 验证
free -h
```

#### 4.1.3 配置内核参数

```bash
# ── Rocky Linux 9 & Ubuntu 22.04 ──────────────────────────
cat >> /etc/sysctl.d/99-k3s.conf << 'EOF'
# 网络配置
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1

# 连接跟踪
net.netfilter.nf_conntrack_max = 1000000
net.netfilter.nf_conntrack_tcp_timeout_established = 86400

# 文件描述符
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# 内存配置
vm.overcommit_memory = 1
vm.panic_on_oom = 0
vm.swappiness = 0

# IP 分片
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_retries2 = 15
EOF

# ── Rocky Linux 9 ──────────────────────────
# 加载内核模块
cat >> /etc/modules-load.d/k3s.conf << 'EOF'
br_netfilter
overlay
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
xt_conntrack
EOF

modprobe br_netfilter
modprobe overlay
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack
modprobe xt_conntrack

# 应用内核参数
sysctl --system

# ── Ubuntu 22.04 ───────────────────────────
# 加载内核模块
cat >> /etc/modules-load.d/k3s.conf << 'EOF'
br_netfilter
overlay
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
xt_conntrack
EOF

modprobe br_netfilter
modprobe overlay
modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack
modprobe xt_conntrack

# 应用内核参数
sysctl --system
```

#### 4.1.4 配置时间同步

```bash
# ── Rocky Linux 9 ──────────────────────────
# 安装 chrony
dnf install -y chrony

# 启动并启用 chronyd
systemctl enable --now chronyd

# 验证时间同步
chronyc sources -v

# ── Ubuntu 22.04 ───────────────────────────
# 安装 chrony
apt-get install -y chrony

# 启动并启用 chronyd
systemctl enable --now chronyd

# 验证时间同步
chronyc sources -v
```

#### 4.1.5 配置 SELinux（仅 Rocky Linux）

```bash
# ── Rocky Linux 9 ──────────────────────────
# 设置 SELinux 为 Permissive 模式（K3s 推荐）
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 验证
getenforce

# ── Ubuntu 22.04 ───────────────────────────
# Ubuntu 不使用 SELinux，无需配置
# AppArmor 通常默认启用且兼容 K3s
```

### 4.2 Rocky Linux 9 部署步骤

#### 4.2.1 部署外部数据库（PostgreSQL）

> 📎 **注意**：K3s 高可用架构必须使用外部数据库（PostgreSQL/MySQL/etcd）

```bash
# ── Rocky Linux 9 ──────────────────────────
# 在所有数据库节点安装 PostgreSQL
dnf install -y postgresql-server postgresql-contrib

# 初始化数据库（主节点）
postgresql-setup --initdb --unit postgresql

# 启动 PostgreSQL
systemctl enable --now postgresql

# 设置密码
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'your_secure_password';\""

# 创建 K3s 数据库
su - postgres -c "psql -c \"CREATE DATABASE k3s;\""

# 配置主从复制（主节点 pg-master）
cat >> /var/lib/pgsql/data/pg_hba.conf << 'EOF'
# 允许从节点连接
host    replication     replicator      192.168.1.31/32      md5
host    replication     replicator      192.168.1.32/32      md5
EOF

# 创建复制用户
su - postgres -c "psql -c \"CREATE USER replicator REPLICATION LOGIN PASSWORD 'replica_password';\""

# 修改配置文件
cat >> /var/lib/pgsql/data/postgresql.conf << 'EOF'
listen_addresses = '*'
wal_level = replica
max_wal_senders = 3
wal_keep_size = 100
EOF

# 重启 PostgreSQL
systemctl restart postgresql

# 配置从节点（pg-slave-01, pg-slave-02）
# 停止 PostgreSQL
systemctl stop postgresql

# 清空数据目录
rm -rf /var/lib/pgsql/data/*

# 使用 pg_basebackup 复制主节点数据
su - postgres -c "pg_basebackup -h pg-master -D /var/lib/pgsql/data -U replicator -P -v -R"

# 创建 standby.signal 文件
touch /var/lib/pgsql/data/standby.signal

# 配置连接信息
cat >> /var/lib/pgsql/data/postgresql.conf << 'EOF'
primary_conninfo = 'host=pg-master port=5432 user=replicator password=replica_password'
EOF

# 启动从节点
systemctl start postgresql
```

#### 4.2.2 下载并安装 K3s

```bash
# ── Rocky Linux 9 ──────────────────────────
# 下载 K3s 安装脚本
curl -sfL https://get.k3s.io | sh -

# 验证安装
k3s --version
```

#### 4.2.3 配置 K3s Server 节点

```bash
# ── Rocky Linux 9 ──────────────────────────
# 创建 Server 配置文件（第一个 Server 节点）
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ★ 集群 Token（⚠️ 所有节点必须一致）
token: my-k3s-cluster-token-001  # ← ⚠️ 修改为安全的随机 token

# ★ 节点名称（⚠️ 每个节点唯一）
node-name: k3s-server-01  # ← 根据实际节点修改

# ★ 集群 CIDR（⚠️ 避免与现有网络冲突）
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16

# ★ 外部数据库配置（⚠️ 高可用必须配置）
datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"  # ← ⚠️ 修改数据库密码

# ★ TLS SAN（⚠️ 必须包含 VIP 和所有 Server IP）
tls-san:
  - 192.168.1.4  # ← VIP
  - 192.168.1.10  # ← Server-01 IP
  - 192.168.1.11  # ← Server-02 IP
  - 192.168.1.12  # ← Server-03 IP
  - k3s-api.example.com  # ← ⚠️ 根据实际域名修改

# 禁用本地组件
disable:
  - traefik  # 禁用内置 Traefik Ingress
  - servicelb  # 禁用内置 ServiceLB

# 启用功能
enable-pprof: false  # 性能分析
kube-apiserver-arg:
  - "feature-gates=ServiceInternalTrafficPolicy=true"

# 网络配置
flannel-backend: "vxlan"  # Flannel 后端（vxlan, host-gw, wireguard）

# 日志配置
v: 2  # 日志级别（0-6）
EOF

# 启动 K3s Server
systemctl enable k3s
systemctl start k3s

# 等待节点启动（约 1-2 分钟）
sleep 120

# 验证节点状态
kubectl get nodes

# 获取 Token
cat /var/lib/rancher/k3s/server/node-token
```

#### 4.2.4 配置其他 Server 节点

```bash
# ── Rocky Linux 9 ──────────────────────────
# 在 Server-02 和 Server-03 上创建配置文件
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ★ 集群 Token（⚠️ 与第一个 Server 节点一致）
token: my-k3s-cluster-token-001  # ← ⚠️ 与第一个节点一致

# ★ 节点名称（⚠️ 每个节点唯一）
node-name: k3s-server-02  # ← Server-02 修改为 k3s-server-02

# ★ 集群 CIDR（⚠️ 与第一个 Server 节点一致）
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16

# ★ 外部数据库配置（⚠️ 与第一个 Server 节点一致）
datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"

# ★ TLS SAN（⚠️ 与第一个 Server 节点一致）
tls-san:
  - 192.168.1.4
  - 192.168.1.10
  - 192.168.1.11
  - 192.168.1.12
  - k3s-api.example.com

# 禁用本地组件
disable:
  - traefik
  - servicelb

# 网络配置
flannel-backend: "vxlan"

# 日志配置
v: 2
EOF

# 启动 K3s Server
systemctl enable k3s
systemctl start k3s
```

### 4.3 Ubuntu 22.04 部署步骤

#### 4.3.1 下载并安装 K3s

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 下载 K3s 安装脚本
curl -sfL https://get.k3s.io | sh -

# 验证安装
k3s --version
```

#### 4.3.2 配置 K3s Server 节点

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 创建 Server 配置文件（配置内容与 Rocky Linux 相同）
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ★ 集群 Token
token: my-k3s-cluster-token-001  # ← ⚠️ 修改为安全的随机 token

# ★ 节点名称
node-name: k3s-server-01  # ← 根据实际节点修改

# ★ 集群 CIDR
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16

# ★ 外部数据库配置
datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"

# ★ TLS SAN
tls-san:
  - 192.168.1.4
  - 192.168.1.10
  - 192.168.1.11
  - 192.168.1.12
  - k3s-api.example.com

# 禁用本地组件
disable:
  - traefik
  - servicelb

# 网络配置
flannel-backend: "vxlan"

# 日志配置
v: 2
EOF

# 启动 K3s Server
systemctl enable k3s
systemctl start k3s
```

### 4.4 集群初始化与配置

#### 4.4.1 配置负载均衡器

在 **LB-01** 和 **LB-02** 节点上配置 Nginx 和 Keepalived：

```bash
# ── Rocky Linux 9 & Ubuntu 22.04 ──────────────────────────
# 安装 Nginx 和 Keepalived

# ── Rocky Linux 9 ──────────────────────────
dnf install -y nginx keepalived

# ── Ubuntu 22.04 ───────────────────────────
apt-get install -y nginx keepalived

# 配置 Nginx
cat >> /etc/nginx/nginx.conf << 'EOF'
stream {
    upstream k3s_api {
        least_conn;
        server 192.168.1.10:6443 max_fails=3 fail_timeout=5s;
        server 192.168.1.11:6443 max_fails=3 fail_timeout=5s;
        server 192.168.1.12:6443 max_fails=3 fail_timeout=5s;
    }

    server {
        listen 6443;
        proxy_pass k3s_api;
        proxy_timeout 1s;
        proxy_connect_timeout 1s;
    }
}
EOF

# 配置 Keepalived（LB-01）
cat >> /etc/keepalived/keepalived.conf << 'EOF'
vrrp_script chk_nginx {
    script "killall -0 nginx"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER  # ← LB-02 改为 BACKUP
    interface eth0  # ← ⚠️ 根据实际网卡修改
    virtual_router_id 51
    priority 100  # ← LB-02 改为 90
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k3s-nginx  # ← ⚠️ 修改为安全密码
    }
    virtual_ipaddress {
        192.168.1.4  # ← VIP 地址
    }
    track_script {
        chk_nginx
    }
}
EOF

# 启动服务
systemctl enable --now nginx
systemctl enable --now keepalived

# 验证 VIP
ip addr show | grep 192.168.1.4
```

#### 4.4.2 配置 K3s Agent 节点

```bash
# ── 所有系统通用 ──────────────────────────
# 获取 Server 节点的 Token
# 在任意 Server 节点执行：
cat /var/lib/rancher/k3s/server/node-token

# 在 Agent 节点安装 K3s Agent
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.4:6443 \
  K3S_TOKEN=SERVER_NODE_TOKEN sh -

# 或者创建配置文件
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ★ Server URL
server-url: https://192.168.1.4:6443  # ← VIP 地址

# ★ 集群 Token（⚠️ 从 Server 节点获取）
token: SERVER_NODE_TOKEN  # ← ⚠️ 替换为实际 Token

# ★ 节点名称（⚠️ 每个节点唯一）
node-name: k3s-agent-01  # ← 根据实际节点修改

# 节点标签（可选）
node-label:
  - "node-role.kubernetes.io/worker=true"
EOF

# 启动 K3s Agent
systemctl enable k3s-agent
systemctl start k3s-agent
```

#### 4.4.3 配置 kubectl

```bash
# ── 所有系统通用 ──────────────────────────
# K3s 自动配置 kubectl
# kubeconfig 位于: /etc/rancher/k3s/k3s.yaml

# 复制 kubeconfig 到用户目录
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config

# 或者创建环境变量
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc

# 验证连接
kubectl get nodes
kubectl get pods -A
```

### 4.5 安装验证（含预期输出）

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 验证节点状态
kubectl get nodes -o wide

# 预期输出（所有节点应为 Ready 状态）：
# NAME              STATUS   ROLES                       AGE   VERSION
# k3s-server-01     Ready    control-plane,master      10m   v1.29.3+k3s1
# k3s-server-02     Ready    control-plane,master      9m    v1.29.3+k3s1
# k3s-server-03     Ready    control-plane,master      8m    v1.29.3+k3s1
# k3s-agent-01      Ready    <none>                     7m    v1.29.3+k3s1
# k3s-agent-02      Ready    <none>                     7m    v1.29.3+k3s1
# k3s-agent-03      Ready    <none>                     7m    v1.29.3+k3s1

# 2. 验证系统 Pod 状态
kubectl get pods -A

# 预期输出（所有 Pod 应为 Running 或 Completed 状态）：
# NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE
# kube-system   local-path-provisioner-xxx                1/1     Running     0          10m
# kube-system   metrics-server-xxx                        1/1     Running     0          10m
# kube-system   coredns-xxx                               1/1     Running     0          10m
# kube-system   helm-install-traefik-crd-xxx              0/1     Completed   0          9m
# kube-system   svclb-traefik-xxx                         1/1     Running     0          8m

# 3. 验证集群信息
kubectl cluster-info

# 预期输出：
# Kubernetes control plane is running at https://localhost:6443
# CoreDNS is running at https://localhost:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
# Metrics-server is running at https://localhost:6443/api/v1/namespaces/kube-system/services/kube-metrics-server:https/proxy

# 4. 验证数据库连接
# 在任意 Server 节点查看日志
journalctl -u k3s -f | grep database

# 预期输出（显示连接到 PostgreSQL）：
# INFO[0000] Database is currently connected

# 5. 验证网络连通性
kubectl run test-pod --image=busybox --restart=Never --command -- sleep 3600
kubectl exec test-pod -- nslookup kubernetes.default

# 预期输出（能解析 kubernetes.default）：
# Server:    10.43.0.10
# Address 1: 10.43.0.10 kube-dns.kube-system.svc.cluster.local

# 清理测试 Pod
kubectl delete pod test-pod

# 6. 验证高可用
# 停止一个 Server 节点
ssh k3s-server-01 "systemctl stop k3s"

# 验证集群仍正常工作
kubectl get nodes

# 恢复 Server 节点
ssh k3s-server-01 "systemctl start k3s"
```

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

#### 5.1.1 Server 节点配置文件

```bash
# ── 所有系统通用 ──────────────────────────
cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ====================
# 集群配置
# ====================

# ★ 集群 Token（⚠️ 所有节点必须一致）
token: my-k3s-cluster-token-001  # ← ⚠️ 修改为安全的随机 token

# ★ 节点名称（⚠️ 每个节点唯一）
node-name: k3s-server-01  # ← 每个节点修改为唯一名称

# ★ 集群 CIDR（⚠️ 避免与现有网络冲突）
cluster-cidr: 10.42.0.0/16  # ← Pod 网络地址段
service-cidr: 10.43.0.0/16  # ← Service 网络地址段

# ★ Cluster DNS 服务 IP（⚠️ 必须在 service-cidr 范围内）
cluster-dns: 10.43.0.10  # ← 默认值，通常无需修改

# ====================
# 数据存储配置
# ====================

# ★ 外部数据库（⚠️ 高可用必须配置）
datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"  # ← ⚠️ 修改数据库密码

# 其他数据库选项（MySQL）：
# datastore-endpoint: "mysql://username:password@tcp(mysql-master:3306)/k3s"

# etcd 选项：
# datastore-endpoint: "https://etcd-01:2379,https://etcd-02:2379,https://etcd-03:2379"

# ====================
# API Server 配置
# ====================

# ★ TLS 证书额外 SAN（⚠️ 必须包含 VIP、所有 Server IP、域名）
tls-san:
  - 192.168.1.4        # ← VIP 地址
  - 192.168.1.10       # ← Server-01 IP
  - 192.168.1.11       # ← Server-02 IP
  - 192.168.1.12       # ← Server-03 IP
  - k3s-api.example.com    # ← ⚠️ API 访问域名

# 绑定地址
bind-address: 0.0.0.0  # 监听所有接口
https-listen-port: 6443  # API Server 端口

# ====================
# 网络配置
# ====================

# Flannel 后端模式（vxlan, host-gw, wireguard, none）
flannel-backend: "vxlan"  # ← 推荐使用 vxlan

# 禁用网络策略（如果使用其他 CNI）
# flannel-backend: "none"

# Node IP 地址
# node-ip: 192.168.1.10  # ← ⚠️ 多网卡时指定节点 IP

# Node 外部 IP
# node-external-ip: 192.168.1.10  # ← ⚠️ 外部访问 IP

# ====================
# 组件配置
# ====================

# ★ 禁用内置组件（根据需求调整）
disable:
  - traefik  # 禁用内置 Traefik Ingress
  - servicelb  # 禁用内置 ServiceLB
  # - metrics-server  # 禁用 metrics-server
  # - local-storage  # 禁用 local-storage
  # - cloud-controller-manager  # 禁用云控制器

# 启用功能
enable-pprof: false  # 性能分析（调试用）

# ★ API Server 额外参数
kube-apiserver-arg:
  - "feature-gates=ServiceInternalTrafficPolicy=true"
  - "audit-log-path=/var/log/k3s/audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"

# ★ Controller Manager 额外参数
kube-controller-manager-arg:
  - "node-monitor-grace-period=40s"
  - "node-monitor-period=5s"

# ★ Scheduler 额外参数
kube-scheduler-arg:
  - "node-monitor-grace-period=40s"

# ★ Kubelet 额外参数
kubelet-arg:
  - "max-pods=110"  # 最大 Pod 数量
  - "serialize-image-pulls=false"  # 并行拉取镜像
  - "image-pull-progress-deadline=10m"

# ====================
# 镜像配置
# ====================

# 私有镜像仓库（可选）
# system-default-registry: "registry.example.com"

# 镜像仓库配置（可选）
# registries:
#   custom:
#     https://registry.example.com/v1/
#     mirrors:
#       docker.io:
#         endpoint:
#           - "https://registry.example.com"

# ====================
# 日志配置
# ====================

# 日志级别（0-6，默认 2）
v: 2

# 日志输出
# log: /var/log/k3s.log  # 输出到文件

# ====================
# 安全配置
# ====================

# Pod 安全标准
# pod-security-admission-config-file: /etc/rancher/k3s/psa.yaml

# Rootless 模式（⚠️ 仅在特定环境使用）
# rootless: true
EOF
```

#### 5.1.2 Agent 节点配置文件

```bash
# ── 所有系统通用 ──────────────────────────
cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ====================
# Server 连接配置
# ====================

# ★ Server URL（⚠️ 指向 VIP 或第一个 Server 节点）
server-url: https://192.168.1.4:6443  # ← VIP 地址

# ★ 集群 Token（⚠️ 从 Server 节点获取，保持一致）
token: SERVER_NODE_TOKEN  # ← ⚠️ 替换为实际 Token

# ★ 节点名称（⚠️ 每个节点唯一）
node-name: k3s-agent-01  # ← 每个节点修改为唯一名称

# ====================
# 网络配置
# ====================

# Flannel 后端（⚠️ 与 Server 节点保持一致）
flannel-backend: "vxlan"

# Node IP 地址
# node-ip: 192.168.1.20  # ← ⚠️ 多网卡时指定节点 IP

# Node 外部 IP
# node-external-ip: 192.168.1.20  # ← ⚠️ 外部访问 IP

# ====================
# 节点标签和污点
# ====================

# ★ 节点标签（可选）
node-label:
  - "node-role.kubernetes.io/worker=true"
  - "topology.kubernetes.io/zone=us-west-1"  # 可用区标签
  - "node-type=general"  # 自定义标签

# ★ 节点污点（可选，用于专用节点）
# node-taint:
#   - "Key1=Value1:NoSchedule"
#   - "Key2=Value2:NoExecute"

# ====================
# 容器运行时配置
# ====================

# 容器运行时端点
# container-runtime-endpoint: /run/k3s/containerd/containerd.sock

# ====================
# 镜像配置
# ====================

# 私有镜像仓库
# system-default-registry: "registry.example.com"

# ====================
# 日志配置
# ====================

# 日志级别
v: 2

# ====================
# 性能调优
# ====================

# Kubelet 额外参数
kubelet-arg:
  - "max-pods=110"
  - "serialize-image-pulls=false"
  - "image-pull-progress-deadline=10m"

# ====================
# 安全配置
# ====================

# Rootless 模式
# rootless: true
EOF
```

### 5.2 生产环境推荐调优参数

#### 5.2.1 Kubernetes 组件调优

```bash
# ── 所有系统通用 ──────────────────────────
cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# ====================
# API Server 调优
# ====================

kube-apiserver-arg:
  # ★ 客户端 QPS 限制
  - "max-requests-inflight=400"
  - "max-mutating-requests-inflight=200"

  # ★ 请求超时时间
  - "request-timeout=300s"

  # ★ 事件保留时间
  - "event-ttl=168h"  # 7 天

  # ★ 启用审计日志
  - "audit-log-path=/var/log/k3s/audit.log"
  - "audit-log-maxage=30"
  - "audit-log-maxbackup=10"
  - "audit-log-maxsize=100"

  # ★ 令牌请求大小限制
  - "max-request-size=3145728"  # 3MB

# ====================
# Controller Manager 调优
# ====================

kube-controller-manager-arg:
  # ★ 并发同步工作数
  - "concurrent-deployment-syncs=10"
  - "concurrent-gc-syncs=10"
  - "concurrent-namespace-syncs=10"
  - "concurrent-replicaset-syncs=10"

  # ★ 节点监控周期
  - "node-monitor-grace-period=40s"
  - "node-monitor-period=5s"
  - "node-startup-grace-period=60s"

  # ★ POD 恢复间隔
  - "pod-eviction-timeout=2m"

# ====================
# Scheduler 调优
# ====================

kube-scheduler-arg:
  # ★ 调度器并发数
  - "kube-api-qps=50"
  - "kube-api-burst=100"

  # ★ 调度器超时
  - "kubeconfig-request-timeout=30s"

# ====================
# Kubelet 调优
# ====================

kubelet-arg:
  # ★ 最大 Pod 数量（默认 110）
  - "max-pods=200"

  # ★ 镜像拉取并发数
  - "serialize-image-pulls=false"
  - "image-pull-progress-deadline=10m"

  # ★ Pod 清理策略
  - "pod-eviction-timeout=2m"
  - "maximum-dead-containers-per-container=3"

  # ★ 资源预留
  - "enforce-node-allocatable=pods"
  - "system-reserved=cpu=500m,memory=1Gi"
  - "kube-reserved=cpu=500m,memory=1Gi"

  # ★ 驱逐阈值
  - "eviction-hard=memory.available<100Mi,nodefs.available<10%,imagefs.available<15%"
EOF
```

#### 5.2.2 系统级调优

```bash
# ── 所有系统通用 ──────────────────────────
# 内核参数优化
cat >> /etc/sysctl.d/99-k3s-tuning.conf << 'EOF'
# 网络性能优化
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_max_syn_backlog = 8192

# TCP 优化
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# 连接跟踪优化
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_established = 1200

# 文件系统优化
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576

# 共享内存
kernel.shmmax = 68719476736
kernel.shmall = 4294967296

# 虚拟内存
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 1
EOF

sysctl --system

# 文件描述符限制
cat >> /etc/security/limits.d/k3s.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
* soft memlock unlimited
* hard memlock unlimited
EOF
```

#### 5.2.3 数据库调优（PostgreSQL）

```bash
# ── 所有系统通用 ──────────────────────────
# PostgreSQL 主节点配置
cat >> /var/lib/pgsql/data/postgresql.conf << 'EOF'
# ★ 连接配置
max_connections = 200  # ← 根据节点数量调整

# ★ 内存配置
shared_buffers = 2GB  # ← 系统内存的 25%
effective_cache_size = 6GB  # ← 系统内存的 50-75%
work_mem = 32MB  # ← 每个查询操作的工作内存
maintenance_work_mem = 256MB

# ★ WAL 配置
wal_buffers = 64MB
checkpoint_completion_target = 0.9
max_wal_size = 4GB
min_wal_size = 1GB

# ★ 查询优化
random_page_cost = 1.1  # SSD 使用此值
effective_io_concurrency = 200  # SSD 并发 I/O

# ★ 日志配置
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
EOF

# 重启 PostgreSQL
systemctl restart postgresql
```

---

## 6. 开发/测试环境快速部署（Docker Compose）

### 6.1 Docker Compose 部署（单机或伪集群）

> ⚠️ **重要提示**：以下部署方式仅适用于开发/测试环境，**不适用于生产环境**。

#### 6.1.1 单节点 K3s 快速部署

```bash
# ── 所有系统通用 ──────────────────────────
# 创建项目目录
mkdir -p ~/k3s-dev
cd ~/k3s-dev

# 创建 Docker Compose 配置
cat >> docker-compose.yml << 'EOF'
version: '3.8'

services:
  # K3s 单节点集群
  k3s-single:
    image: rancher/k3s:v1.29.3-k3s1
    container_name: k3s-single
    hostname: k3s-single
    privileged: true
    restart: unless-stopped
    ports:
      - "6443:6443"    # Kubernetes API
      - "80:80"        # HTTP
      - "443:443"      # HTTPS
    volumes:
      - ./data/k3s:/var/lib/rancher/k3s
      - ./data/kubelet:/var/lib/kubelet
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    environment:
      - K3S_KUBECONFIG_OUTPUT=/output/kubeconfig.yaml
      - K3S_KUBECONFIG_MODE=644
    tmpfs:
      - /run
      - /var/run
    networks:
      k3s-dev-net:
        ipv4_address: 172.28.0.10
    healthcheck:
      test: ["CMD", "kubectl", "get", "nodes"]
      interval: 30s
      timeout: 10s
      retries: 3

  # PostgreSQL 数据库
  postgres:
    image: postgres:15-alpine
    container_name: k3s-postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: k3s
      POSTGRES_USER: k3s
      POSTGRES_PASSWORD: k3s123  # ← ⚠️ 仅测试环境
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks:
      k3s-dev-net:
        ipv4_address: 172.28.0.20

  # Redis 缓存
  redis:
    image: redis:7-alpine
    container_name: k3s-redis
    restart: unless-stopped
    ports:
      - "6379:6379"
    command: redis-server --requirepass redis123  # ← ⚠️ 仅测试环境
    volumes:
      - ./data/redis:/data
    networks:
      k3s-dev-net:
        ipv4_address: 172.28.0.30

  # NFS 服务器
  nfs:
    image: itsthenetwork/nfs-server-alpine:latest
    container_name: k3s-nfs
    restart: unless-stopped
    privileged: true
    ports:
      - "2049:2049"
    environment:
      SHARED_DIRECTORY: /export
    volumes:
      - ./data/nfs:/export
    networks:
      k3s-dev-net:
        ipv4_address: 172.28.0.40

networks:
  k3s-dev-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/24
EOF

# 启动开发环境
docker compose up -d

# 等待 K3s 启动
sleep 60

# 获取 kubeconfig
docker cp k3s-single:/output/kubeconfig.yaml ~/k3s-dev/kubeconfig.yaml

# 配置 kubectl
export KUBECONFIG=~/k3s-dev/kubeconfig.yaml

# 验证集群
kubectl get nodes
kubectl get pods -A
```

### 6.2 启动与验证

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 验证服务状态
docker compose ps

# 预期输出（所有服务应为 Up 状态）：
# NAME              COMMAND                  SERVICE            STATUS
# k3s-single        "/bin/k3s server"        k3s-single         Up (healthy)
# k3s-postgres      "docker-entrypoint.s…"   postgres           Up
# k3s-redis         "redis-server --req…"    redis              Up
# k3s-nfs           "/usr/bin/nfs-server…"   nfs                Up

# 2. 验证集群状态
export KUBECONFIG=~/k3s-dev/kubeconfig.yaml
kubectl get nodes

# 预期输出：
# NAME         STATUS   ROLES                       AGE   VERSION
# k3s-single   Ready    control-plane,master      2m    v1.29.3+k3s1

# 3. 部署测试应用
kubectl create deployment nginx --image=nginx --replicas=2
kubectl expose deployment nginx --port=80 --type=NodePort

# 4. 验证应用运行
kubectl get pods
kubectl get svc

# 5. 访问测试应用
NODE_PORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
curl http://localhost:$NODE_PORT

# 6. 清理资源
kubectl delete deployment nginx
kubectl delete svc nginx

# 7. 停止开发环境
docker compose down

# 8. 清理数据（可选）
# rm -rf ~/k3s-dev/data/*
```

---

## 7. 日常运维操作

### 7.1 常用管理命令

#### 7.1.1 集群管理命令

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 查看集群信息
kubectl cluster-info
kubectl version

# 2. 查看节点状态
kubectl get nodes -o wide
kubectl describe node <node-name>

# 3. 查看集群资源使用
kubectl top nodes
kubectl top pods -A

# 4. 查看命名空间
kubectl get ns
kubectl create namespace <namespace-name>

# 5. 查看所有 Pod
kubectl get pods -A
kubectl get pods -n <namespace>

# 6. 查看 K3s 版本
k3s --version
k3s-agent --version

# 7. 查看 K3s 服务状态
systemctl status k3s  # Server 节点
systemctl status k3s-agent  # Agent 节点

# 8. 查看 K3s 日志
journalctl -u k3s -f
journalctl -u k3s-agent -f

# 9. 查看组件日志
kubectl logs -n kube-system -l app=local-path-provisioner
kubectl logs -n kube-system -l k8s-app=kube-dns

# 10. 查看集群事件
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -n <namespace>
```

#### 7.1.2 应用管理命令

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 创建 Deployment
kubectl create deployment <name> --image=<image> --replicas=<count>

# 2. 扩缩容
kubectl scale deployment <name> --replicas=<count> -n <namespace>

# 3. 更新镜像
kubectl set image deployment/<name> <container>=<new-image> -n <namespace>

# 4. 回滚
kubectl rollout undo deployment/<name> -n <namespace>

# 5. 查看滚动更新状态
kubectl rollout status deployment/<name> -n <namespace>

# 6. 查看更新历史
kubectl rollout history deployment/<name> -n <namespace>

# 7. 创建 Service
kubectl expose deployment <name> --port=80 --type=ClusterIP -n <namespace>

# 8. 创建 Ingress（如果部署了 Traefik）
kubectl create ingress <name> --class=traefik \
  --rule=example.com/=app-service:80 -n <namespace>

# 9. 应用资源清单
kubectl apply -f deployment.yaml

# 10. 删除资源
kubectl delete deployment <name> -n <namespace>
kubectl delete -f deployment.yaml

# 11. 强制删除 Pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

#### 7.1.3 故障排查命令

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 查看 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 2. 查看 Pod 日志
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --tail=100 -f
kubectl logs <pod-name> -n <namespace> --previous  # 之前容器日志

# 3. 进入 Pod 容器
kubectl exec -it <pod-name> -n <namespace> -- sh

# 4. 端口转发（本地调试）
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>

# 5. 从本地复制文件到 Pod
kubectl cp /local/file.txt <pod-name>:/remote/ -n <namespace>

# 6. 从 Pod 复制文件到本地
kubectl cp <pod-name>:/remote/file.txt /local/ -n <namespace>

# 7. 查看节点资源分配
kubectl describe node <node-name> | grep -A 5 "Allocated resources"

# 8. 查看集群资源配额
kubectl describe quota -n <namespace>

# 9. 查看持久卷状态
kubectl get pv,pvc -n <namespace>

# 10. 查看 CRD（自定义资源）
kubectl get crd
kubectl get <custom-resource> -A
```

### 7.2 备份与恢复

#### 7.2.1 集群备份

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 备份 K3s 配置
tar -czf k3s-config-backup-$(date +%Y%m%d).tar.gz /etc/rancher/k3s/

# 2. 备份 kubeconfig
cp /etc/rancher/k3s/k3s.yaml ~/backup/k3s-config-$(date +%Y%m%d).yaml

# 3. 备份 PostgreSQL 数据库（如果使用外部数据库）
pg_dump -h pg-master -U postgres k3s > ~/backup/k3s-db-$(date +%Y%m%d).sql

# 4. 使用 Velero 备份（推荐）
# 安装 Velero CLI
curl -L https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz -o velero.tar.gz
tar -xvf velero.tar.gz
mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/
chmod +x /usr/local/bin/velero

# 安装 Velero 到 K3s
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero \
  --secret-file /credentials/velero-aws \
  --use-volume-snapshots=false \
  --backup-location-config region=us-east-1

# 创建备份
velero backup create <backup-name> --include-namespaces <namespace>

# 创建定时备份
velero schedule create daily-backup \
  --schedule="0 3 * * *" \
  --ttl 168h \
  --include-namespaces <namespace>

# 列出备份
velero backup get

# 查看备份详情
velero backup describe <backup-name>

# 5. 定时备份脚本
cat >> /usr/local/bin/k3s-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/k3s"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d-%H%M%S)

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份 K3s 配置
tar -czf $BACKUP_DIR/k3s-config-$DATE.tar.gz /etc/rancher/k3s/

# 备份数据库
pg_dump -h pg-master -U postgres k3s > $BACKUP_DIR/k3s-db-$DATE.sql

# 备份资源清单
kubectl get all --all-namespaces -o yaml > $BACKUP_DIR/k3s-resources-$DATE.yaml

# 清理旧备份
find $BACKUP_DIR -name "k3s-*" -mtime +$RETENTION_DAYS -delete

# 记录日志
echo "[$(date)] K3s backup completed" >> /var/log/k3s-backup.log
EOF

chmod +x /usr/local/bin/k3s-backup.sh

# 添加定时任务（每天凌晨 3 点执行）
crontab -e
# 添加：
0 3 * * * /usr/local/bin/k3s-backup.sh
```

#### 7.2.2 集群恢复

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 恢复 K3s 配置
tar -xzf k3s-config-backup-20260309.tar.gz -C /

# 2. 恢复数据库
psql -h pg-master -U postgres k3s < ~/backup/k3s-db-20260309.sql

# 3. 重启 K3s
systemctl restart k3s  # Server 节点
systemctl restart k3s-agent  # Agent 节点

# 4. 使用 Velero 恢复
velero restore create --from-backup <backup-name>

# 5. 恢复特定命名空间
velero restore create --from-backup <backup-name> --include-namespaces <namespace>

# 6. 验证恢复
kubectl get nodes
kubectl get pods -A
```

### 7.3 集群扩缩容

#### 7.3.1 添加 Server 节点

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 准备新节点（参考第 4.1 节前置准备）

# 2. 在新节点安装 K3s Server
curl -sfL https://get.k3s.io | sh-

# 3. 创建 Server 配置文件
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
token: my-k3s-cluster-token-001  # ← ⚠️ 与现有节点一致
node-name: k3s-server-04  # ← 新节点唯一名称
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"  # ← ⚠️ 与现有节点一致
tls-san:
  - 192.168.1.4
  - 192.168.1.10
  - 192.168.1.11
  - 192.168.1.12
  - 192.168.1.13  # ← 新节点 IP
  - k3s-api.example.com
disable:
  - traefik
  - servicelb
flannel-backend: "vxlan"
v: 2
EOF

# 4. 启动 K3s Server
systemctl enable k3s
systemctl start k3s

# 5. 验证新节点加入
kubectl get nodes
```

#### 7.3.2 添加 Agent 节点

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 准备新节点（参考第 4.1 节前置准备）

# 2. 在新节点安装 K3s Agent
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.4:6443 \
  K3S_TOKEN=SERVER_NODE_TOKEN sh -

# 或者创建配置文件
mkdir -p /etc/rancher/k3s

cat >> /etc/rancher/k3s/config.yaml << 'EOF'
server-url: https://192.168.1.4:6443  # ← VIP 地址
token: SERVER_NODE_TOKEN  # ← ⚠️ 与 Server 节点一致
node-name: k3s-agent-04  # ← 新节点唯一名称
node-label:
  - "node-role.kubernetes.io/worker=true"
EOF

# 3. 启动 K3s Agent
systemctl enable k3s-agent
systemctl start k3s-agent

# 4. 验证新节点加入
kubectl get nodes
```

#### 7.3.3 删除节点

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 驱逐节点（安全删除 Pod）
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force

# 2. 删除节点（从集群移除）
kubectl delete node <node-name>

# 3. 在被删除的节点上清理 K3s
# Agent 节点
systemctl stop k3s-agent
systemctl disable k3s-agent
rm -rf /etc/rancher/k3s
rm -rf /var/lib/rancher/k3s

# Server 节点（⚠️ 谨慎操作）
# ⚠️ 确保是最后一个要删除的 Server 节点
systemctl stop k3s
systemctl disable k3s
rm -rf /etc/rancher/k3s
rm -rf /var/lib/rancher/k3s

# 4. 更新负载均衡器配置
# 从 Nginx/HAProxy 配置中删除已移除节点的后端
```

### 7.4 版本升级（★ 必须包含回滚方案）

#### 7.4.1 升级准备

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 备份集群（⚠️ 必须执行）
/usr/local/bin/k3s-backup.sh

# 2. 检查当前版本
k3s --version
kubectl version

# 3. 查看可升级版本
# 查看官方文档：https://github.com/k3s-io/k3s/releases

# 4. 验证集群健康
kubectl get nodes
kubectl get pods -A

# 5. 检查升级兼容性
# ⚠️ K3s 支持跨一个小版本升级（如 1.28.x → 1.29.x）
# ⚠️ 不建议跳过版本升级（如 1.27.x → 1.29.x）
```

#### 7.4.2 手动升级步骤

```bash
# ── 所有系统通用 ──────────────────────────
# 方法一：使用安装脚本升级（推荐）

# 1. 升级 Server 节点（逐个升级）

# 在 Server-01 执行
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.29.4 sh -

# 等待节点就绪
kubectl wait --for=condition=ready node k3s-server-01 --timeout=600s

# 验证 Pod 运行正常
kubectl get pods -A | grep -v Running

# 在 Server-02 执行（重复上述步骤）
# ...

# 在 Server-03 执行（重复上述步骤）
# ...

# 2. 升级 Agent 节点（逐个升级）

# 在每个 Agent 节点执行
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.29.4 sh -

# 3. 验证集群升级
kubectl get nodes
kubectl get pods -A
k3s --version

# 方法二：使用二进制文件升级

# 1. 下载新版本二进制
wget https://github.com/k3s-io/k3s/releases/download/v1.29.4+k3s1/k3s
chmod +x k3s

# 2. 停止 K3s
systemctl stop k3s  # 或 k3s-agent

# 3. 替换二进制文件
cp k3s /usr/local/bin/

# 4. 启动 K3s
systemctl start k3s  # 或 k3s-agent
```

#### 7.4.3 自动升级配置

```bash
# ── 所有系统通用 ──────────────────────────
# 配置自动升级（⚠️ 谨慎使用）
cat >> /etc/rancher/k3s/config.yaml << 'EOF'
# 自动升级通道（stable, latest, testing）
auto-deploy: true  # 启用自动部署
system-default-registry: "docker.io"
EOF

# 或使用环境变量控制升级策略
# 在 /etc/systemd/system/k3s.service 添加：
# Environment="K3S_AUTO_DEPLOY=true"
# Environment="K3S_CHANNEL=stable"
```

#### 7.4.4 回滚方案

```bash
# ── 所有系统通用 ──────────────────────────
# 方案一：数据库快照恢复（推荐）

# 1. 停止所有 Server 节点
systemctl stop k3s

# 2. 恢复数据库到升级前状态
pg_dump -h pg-master -U postgres k3s < ~/backup/k3s-db-pre-upgrade.sql

# 3. 恢复旧版本 K3s
wget https://github.com/k3s-io/k3s/releases/download/v1.28.10+k3s1/k3s
chmod +x k3s
cp k3s /usr/local/bin/

# 4. 启动第一个 Server 节点
systemctl start k3s

# 5. 其他 Server 节点启动
# 在 Server-02 和 Server-03 执行：
wget https://github.com/k3s-io/k3s/releases/download/v1.28.10+k3s1/k3s
chmod +x k3s
cp k3s /usr/local/bin/
rm -rf /var/lib/rancher/k3s/server/db  # 清理数据目录
systemctl start k3s

# 6. 升级 Agent 节点回退
# 在所有 Agent 节点执行：
wget https://github.com/k3s-io/k3s/releases/download/v1.28.10+k3s1/k3s
chmod +x k3s
cp k3s /usr/local/bin/
systemctl restart k3s-agent

# 7. 验证回滚
kubectl get nodes
kubectl get pods -A
k3s --version

# 方案二：完全重置重建
# 如果回滚失败，可以考虑完全重置集群
# ⚠️ 这将导致所有数据丢失，仅在极端情况下使用

# 在所有节点执行：
systemctl stop k3s  # 或 k3s-agent
rm -rf /etc/rancher/k3s
rm -rf /var/lib/rancher/k3s

# 按照 4.4 节重新部署集群
```

---

## 9. 注意事项与生产检查清单

### 9.1 安装前环境核查

| 检查项 | 检查命令 | 预期结果 | 重要性 |
|--------|----------|----------|--------|
| **操作系统版本** | `cat /etc/os-release` | Rocky Linux 9 / Ubuntu 22.04 | ⭐⭐⭐ |
| **CPU 架构** | `uname -m` | x86_64 / aarch64 / armv7l | ⭐⭐⭐ |
| **CPU 核心数** | `nproc` | Server≥1核，Agent≥1核 | ⭐⭐⭐ |
| **内存大小** | `free -h` | Server≥1GB，Agent≥512MB | ⭐⭐⭐ |
| **磁盘空间** | `df -h` | ≥20GB 可用空间 | ⭐⭐⭐ |
| **网络连通性** | `ping -c 3 <目标IP>` | 所有节点互通 | ⭐⭐⭐ |
| **DNS 解析** | `nslookup kubernetes.default.svc.cluster.local` | 可解析 | ⭐⭐ |
| **时间同步** | `chronyc sources -v` | NTP 服务器在线 | ⭐⭐⭐ |
| **Swap 状态** | `free -h` | Swap 行为 0 | ⭐⭐⭐ |
| **防火墙状态** | `firewall-cmd --list-all` / `ufw status` | 必要端口已开放 | ⭐⭐⭐ |
| **SELinux 状态** | `getenforce` | Permissive / Disabled | ⭐⭐⭐ |
| **文件描述符** | `ulimit -n` | ≥65536 | ⭐⭐ |
| **内核模块** | `lsmod \| grep br_netfilter` | br_netfilter 已加载 | ⭐⭐⭐ |
| **内核参数** | `sysctl net.ipv4.ip_forward` | 1 | ⭐⭐⭐ |
| **数据库连接** | `psql -h pg-master -U postgres` | 可连接 | ⭐⭐⭐ |
| **K3s 二进制** | `k3s --version` | 版本正确 | ⭐⭐⭐ |

### 9.2 常见故障排查

#### 9.2.1 节点 NotReady 状态

**现象**：
```bash
kubectl get nodes
# NAME           STATUS     ROLES                       AGE   VERSION
# k3s-server-01  NotReady   control-plane,master      30m   v1.29.3+k3s1
```

**可能原因**：
1. CNI 网络插件未就绪
2. 节点资源不足
3. 容器运行时故障
4. 数据库连接失败

**排查步骤**：
```bash
# 1. 查看节点详情
kubectl describe node k3s-server-01

# 2. 检查 CNI 插件
kubectl get pods -n kube-system | grep flannel

# 3. 检查节点资源
kubectl top nodes
free -h
df -h

# 4. 查看 K3s 日志
journalctl -u k3s -f

# 5. 检查数据库连接
psql -h pg-master -U postgres k3s -c "SELECT 1;"

# 6. 检查网络配置
ip addr show
route -n
```

**解决方案**：
```bash
# 1. 重启 CNI Pod
kubectl delete pod -n kube-system -l app=flannel

# 2. 检查并修复网络配置
ip link show flannel.1
ip link show cni0

# 3. 重启 K3s
systemctl restart k3s
```

#### 9.2.2 Pod 一直 Pending 状态

**现象**：
```bash
kubectl get pods -A
# NAME                          READY   STATUS    RESTARTS   AGE
# nginx-deployment-xxx-xxx      0/1     Pending   0          5m
```

**可能原因**：
1. 集群资源不足
2. 节点选择器不匹配
3. 污点和容忍度冲突
4. 持久卷未挂载

**排查步骤**：
```bash
# 1. 查看 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 2. 查看事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 3. 检查节点资源
kubectl top nodes
kubectl describe node <node-name>

# 4. 检查 PV/PV 状态
kubectl get pv,pvc -n <namespace>
```

**解决方案**：
```bash
# 1. 添加节点
# 参考 7.3.2 节添加 Agent 节点

# 2. 调整资源请求
kubectl set resources deployment <name> \
  --requests=cpu=100m,memory=128Mi -n <namespace>

# 3. 移除污点
kubectl taint nodes <node-name> key:NoSchedule-

# 4. 创建 PV
kubectl apply -f pv.yaml
```

#### 9.2.3 镜像拉取失败（ImagePullBackOff）

**现象**：
```bash
kubectl get pods -n <namespace>
# NAME                          READY   STATUS              RESTARTS   AGE
# app-pod                       0/1     ImagePullBackOff    0          3m
```

**可能原因**：
1. 镜像不存在或标签错误
2. 镜像仓库认证失败
3. 网络问题无法访问镜像仓库
4. 镜像太大拉取超时

**排查步骤**：
```bash
# 1. 查看 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 2. 手动拉取镜像测试
crictl pull <image>

# 3. 检查容器运行时
crictl images
crictl info
```

**解决方案**：
```bash
# 1. 修正镜像名称和标签
kubectl set image deployment/<name> \
  <container>=<correct-image> -n <namespace>

# 2. 配置私有镜像仓库
cat >> /etc/rancher/k3s/registries.yaml << 'EOF'
mirrors:
  docker.io:
    endpoint:
      - "https://registry.example.com"
EOF

systemctl restart k3s

# 3. 预拉取镜像
crictl pull <image>
```

#### 9.2.4 数据库连接失败

**现象**：
```bash
# K3s 无法启动
journalctl -u k3s -f
# ERRO[0000] failed to connect to database
```

**可能原因**：
1. 数据库服务未启动
2. 数据库连接信息错误
3. 网络问题无法访问数据库
4. 数据库权限不足

**排查步骤**：
```bash
# 1. 检查数据库服务
systemctl status postgresql

# 2. 测试数据库连接
psql -h pg-master -U postgres k3s -c "SELECT 1;"

# 3. 检查网络连通性
ping -c 3 pg-master
telnet pg-master 5432

# 4. 检查数据库权限
psql -h pg-master -U postgres -c "\du"

# 5. 检查数据库日志
tail -f /var/lib/pgsql/data/pg_log/postgresql-*.log
```

**解决方案**：
```bash
# 1. 启动数据库服务
systemctl start postgresql

# 2. 修正连接信息
# 编辑 /etc/rancher/k3s/config.yaml
# datastore-endpoint: "postgres://correct_user:correct_password@correct_host:5432/k3s"

# 3. 重启 K3s
systemctl restart k3s
```

### 9.3 安全加固建议

#### 9.3.1 启用 Pod 安全标准

```bash
# ── 所有系统通用 ──────────────────────────
# 配置命名空间隔离
cat >> pod-security-policy.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: restricted
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF

kubectl apply -f pod-security-policy.yaml
```

#### 9.3.2 网络安全

```bash
# ── 所有系统通用 ──────────────────────────
# 启用 NetworkPolicy
cat >> network-policy-deny-all.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

kubectl apply -f network-policy-deny-all.yaml
```

#### 9.3.3 访问控制

```bash
# ── 所有系统通用 ──────────────────────────
# 创建只读用户
cat >> readonly-user.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: readonly-user
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: readonly-role
subjects:
- kind: ServiceAccount
  name: readonly-user
  namespace: kube-system
EOF

kubectl apply -f readonly-user.yaml
```

#### 9.3.4 系统安全

```bash
# ── Rocky Linux 9 ──────────────────────────
# 配置 SELinux
setenforce 1
sed -i 's/^SELINUX=permissive$/SELINUX=enforcing/' /etc/selinux/config

# 启用防火墙
systemctl enable --now firewalld

# 限制 SSH 访问
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# ── Ubuntu 22.04 ───────────────────────────
# 配置 UFW
ufw enable
ufw default deny incoming
ufw default allow outgoing

# 配置 AppArmor
aa-enforce /etc/apparmor.d/*

# 限制 SSH 访问
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# ── 所有系统通用 ──────────────────────────
# 安装 Fail2ban
# Rocky Linux
dnf install -y fail2ban
systemctl enable --now fail2ban

# Ubuntu
apt-get install -y fail2ban
systemctl enable --now fail2ban
```

---

## 10. AutoK3s 自动化部署

### 10.1 AutoK3s 简介

**AutoK3s** 是 K3s 的自动化部署工具，提供以下能力：

- **一键部署**：单命令创建 K3s 集群
- **多云支持**：阿里云、腾讯云、AWS、Azure、VMware、SSH
- **集群管理**：统一管理多个 K3s 集群
- **自动化运维**：自动扩缩容、自动升级、自动备份
- **配置即代码**：YAML 配置文件管理集群

### 10.2 安装 AutoK3s

```bash
# ── 所有系统通用 ──────────────────────────
# 下载 AutoK3s CLI
curl -sS https://raw.githubusercontent.com/cnrancher/autok3s/main/scripts/install.sh | INSTALL_VERSION=v0.5.0 sh

# 验证安装
autok3s version

# 配置自动补全
# Bash
echo "source <(autok3s completion bash)" >> ~/.bashrc
source ~/.bashrc

# Zsh
echo "source <(autok3s completion zsh)" >> ~/.zshrc
source ~/.zshrc
```

### 10.3 使用 AutoK3s 部署 K3s 集群

#### 10.3.1 SSH Provider 部署（裸金属/虚拟机）

```bash
# ── 所有系统通用 ──────────────────────────
# 创建集群配置
cat >> k3s-cluster.yaml << 'EOF'
name: k3s-prod-cluster
provider: ssh
ssh:
  # SSH 连接信息
  user: root  # ← ⚠️ 根据实际环境修改
  password: your_ssh_password  # ← ⚠️ 建议使用密钥认证
  # key-path: /path/to/private_key  # ← SSH 密钥路径

  # Master 节点
  master:
    - 192.168.1.10
    - 192.168.1.11
    - 192.168.1.12

  # Worker 节点
  worker:
    - 192.168.1.20
    - 192.168.1.21
    - 192.168.1.22

# K3s 配置
options:
  # 集群 Token
  token: my-k3s-cluster-token-001  # ← ⚠️ 修改为安全的随机 token

  # 外部数据库
  datastore-endpoint: "postgres://postgres:your_secure_password@pg-master:5432/k3s"

  # TLS SAN
  tls-san:
    - 192.168.1.4
    - k3s-api.example.com

  # 网络配置
  cluster-cidr: 10.42.0.0/16
  service-cidr: 10.43.0.0/16
  flannel-backend: vxlan

  # 禁用组件
  disable:
    - traefik
    - servicelb

  # 日志级别
  v: 2
EOF

# 创建集群
autok3s join -c k3s-cluster.yaml

# 查看集群状态
autok3s list

# 查看集群详情
autok3s describe k3s-prod-cluster

# 获取 kubeconfig
autok3s kubeconfig k3s-prod-cluster > ~/.kube/k3s-prod-config

# 使用 kubectl 管理集群
export KUBECONFIG=~/.kube/k3s-prod-config
kubectl get nodes
```

#### 10.3.2 阿里云 Provider 部署

```bash
# ── 所有系统通用 ──────────────────────────
# 配置阿里云凭证
export ALIYUN_ACCESS_KEY_ID="your_access_key"  # ← ⚠️ 根据实际环境修改
export ALIYUN_ACCESS_KEY_SECRET="your_secret_key"  # ← ⚠️ 根据实际环境修改

# 创建集群
autok3s create \
  --provider aliyun \
  --name k3s-aliyun-cluster \
  --region cn-hangzhou \
  --master-count 3 \
  --worker-count 3 \
  --master-type ecs.c6.large \
  --worker-type ecs.c6.xlarge \
  --token my-k3s-cluster-token-001 \
  --datastore-endpoint "postgres://postgres:your_password@pg-master:5432/k3s"

# 查看集群
autok3s list
autok3s describe k3s-aliyun-cluster
```

#### 10.3.3 集群管理操作

```bash
# ── 所有系统通用 ──────────────────────────
# 1. 扩容 Worker 节点
autok3s scale k3s-prod-cluster --worker-add 2

# 2. 缩容 Worker 节点
autok3s scale k3s-prod-cluster --worker-remove 1

# 3. 升级集群
autok3s upgrade k3s-prod-cluster --k3s-version v1.29.4

# 4. 删除集群
autok3s delete k3s-prod-cluster

# 5. 获取集群 kubeconfig
autok3s kubeconfig k3s-prod-cluster

# 6. 查看集群日志
autok3s logs k3s-prod-cluster

# 7. 重启集群
autok3s restart k3s-prod-cluster
```

### 10.4 AutoK3s 高级功能

#### 10.4.1 多集群管理

```bash
# ── 所有系统通用 ──────────────────────────
# 创建多个集群
autok3s join -c cluster-1.yaml
autok3s join -c cluster-2.yaml
autok3s join -c cluster-3.yaml

# 查看所有集群
autok3s list

# 切换上下文
autok3s context cluster-1
autok3s context cluster-2

# 批量操作
autok3s upgrade --all --k3s-version v1.29.4

# 健康检查
autok3s health-check --all
```

#### 10.4.2 自动化备份

```bash
# ── 所有系统通用 ──────────────────────────
# 配置自动备份
cat >> autok3s-backup.yaml << 'EOF'
name: backup-policy
schedule: "0 3 * * *"  # 每天凌晨 3 点
retention: 7  # 保留 7 天
destination:
  type: s3
  endpoint: https://s3.example.com
  bucket: k3s-backups
  access-key: your_access_key
  secret-key: your_secret_key
EOF

# 应用备份策略
autok3s backup create -f autok3s-backup.yaml
```

---

## 11. 参考资料

### 11.1 官方文档

- **K3s 官方网站**：https://k3s.io
- **K3s 文档**：https://docs.k3s.io
- **K3s GitHub 仓库**：https://github.com/k3s-io/k3s
- **AutoK3s GitHub 仓库**：https://github.com/cnrancher/autok3s
- **Rancher 官方网站**：https://rancher.com
- **Rancher 中文文档**：https://docs.rancher.cn/docs/k3s/
- **Kubernetes 官方文档**：https://kubernetes.io/docs/

### 11.2 社区资源

- **Rancher 论坛**：https://forums.rancher.com/
- **Rancher Slack**：https://slack.rancher.io/
- **Rancher University**：https://rancher.com/training
- **Kubernetes 中文社区**：https://www.kubernetes.org.cn/
- **云原生社区**：https://cloudnative.to/

### 11.3 相关工具

- **kubectl**：Kubernetes 命令行工具
- **Helm**：Kubernetes 包管理器
- **k3sup**：K3s 快速部署工具
- **k3d**：K3s 在 Docker 中运行
- **Istio**：服务网格
- **Prometheus**：监控和告警
- **Grafana**：可视化监控
- **Velero**：备份和恢复工具
- **Longhorn**：分布式存储

### 11.4 学习资源

- **Kubernetes 基础教程**：https://kubernetes.io/docs/tutorials/
- **Rancher 认证**：https://rancher.com/training/certifications/
- **CKA 认证考试**：https://www.cncf.io/certification/cka/
- **CKAD 认证考试**：https://www.cncf.io/certification/ckad/
- **边缘计算指南**：https://www.cncf.io/reports/edge-computing/

### 11.5 版本发布说明

- **K3s 发布日志**：https://github.com/k3s-io/k3s/releases
- **AutoK3s 发布日志**：https://github.com/cnrancher/autok3s/releases
- **Kubernetes 发布说明**：https://kubernetes.io/docs/setup/release/notes/
- **变更日志**：https://docs.k3s.io/known_issues/

---

**文档维护信息**

- **文档版本**：1.0.0
- **最后更新**：2026-03-09
- **维护者**：devinyan
- **适用 K3s 版本**：v1.29.x
- **适用 AutoK3s 版本**：v0.5.x

---

**版权声明**

本文档基于 CC BY-NC-SA 4.0 许可证发布。允许在非商业用途下自由转载、修改和分发，但需保留原作者署名并使用相同许可协议。

本文档中的所有配置示例、脚本和命令仅供参考，请在生产环境使用前充分测试并根据实际环境调整。
