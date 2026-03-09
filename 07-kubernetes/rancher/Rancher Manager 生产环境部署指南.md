# Rancher Manager 生产环境部署指南

> **文档版本**: v1.0
> **最后更新**: 2026-03-09
> **适用范围**: 生产环境、高可用架构部署

---

## 目录

1. [简介](#1-简介)
   - [1.1 服务介绍与核心特性](#11-服务介绍与核心特性)
   - [1.2 适用场景](#12-适用场景)
   - [1.3 架构原理](#13-架构原理)
2. [版本选择指南](#2-版本选择指南)
   - [2.1 版本对应关系表](#21-版本对应关系表)
   - [2.2 版本决策建议](#22-版本决策建议)
3. [生产环境规划](#3-生产环境规划)
   - [3.1 集群架构图](#31-集群架构图)
   - [3.2 节点角色与配置要求](#32-节点角色与配置要求)
   - [3.3 网络与端口规划](#33-网络与端口规划)
4. [生产环境部署](#4-生产环境部署)
   - [4.1 前置准备](#41-前置准备)
   - [4.2 Rocky Linux 9 部署步骤](#42-rocky-linux-9-部署步骤)
   - [4.3 Ubuntu 22.04 部署步骤](#43-ubuntu-2204-部署步骤)
   - [4.4 集群初始化与配置](#44-集群初始化与配置)
   - [4.5 安装验证](#45-安装验证)
5. [关键参数配置说明](#5-关键参数配置说明)
   - [5.1 核心配置文件详解](#51-核心配置文件详解)
   - [5.2 生产环境推荐调优参数](#52-生产环境推荐调优参数)
6. [开发/测试环境快速部署](#6-开发测试环境快速部署)
   - [6.1 Docker 快速部署](#61-docker-快速部署)
   - [6.2 Docker Compose 部署](#62-docker-compose-部署)
7. [日常运维操作](#7-日常运维操作)
   - [7.1 常用管理命令](#71-常用管理命令)
   - [7.2 备份与恢复](#72-备份与恢复)
   - [7.3 集群扩缩容](#73-集群扩缩容)
   - [7.4 版本升级](#74-版本升级)
8. [使用手册](#8-使用手册)
   - [8.1 登录与认证](#81-登录与认证)
   - [8.2 集群管理操作](#82-集群管理操作)
   - [8.3 用户与权限管理](#83-用户与权限管理)
   - [8.4 监控与告警配置](#84-监控与告警配置)
   - [8.5 备份恢复操作](#85-备份恢复操作)
9. [注意事项与生产检查清单](#9-注意事项与生产检查清单)
   - [9.1 安装前环境核查](#91-安装前环境核查)
   - [9.2 常见故障排查](#92-常见故障排查)
   - [9.3 安全加固建议](#93-安全加固建议)
10. [参考资料](#10-参考资料)

---

## 1. 简介

### 1.1 服务介绍与核心特性

**Rancher Manager** 是一个开源的企业级多集群 Kubernetes 管理平台，为运维团队提供统一的界面来管理跨多个基础设施的 Kubernetes 集群。

#### 核心特性

| 特性类别 | 功能描述 |
|---------|---------|
| **多集群管理** | 统一管理数百个 Kubernetes 集群，支持多云、混合云部署 |
| **集中式认证** | 统一 RBAC 权限控制，集成 AD/LDAP、OAuth、SAML 等认证方式 |
| **应用商店** | 内置企业级 Helm Chart 应用商店，一键部署常用应用 |
| **CI/CD 集成** | 集成 Fleet、GitOps 实现持续交付和应用自动化部署 |
| **监控告警** | 内置 Prometheus、Grafana、Alerting 实现集群监控 |
| **安全扫描** | 集成镜像扫描、策略管理、安全合规检查 |
| **边缘计算** | 支持 IoT 和边缘场景的轻量级集群管理 |
| **API 支持** | 提供完整的 RESTful API 和 CLI 工具 |

#### 组件架构

```mermaid
graph TB
    subgraph "访问层"
        LB[负载均衡器<br/>Nginx/HAProxy/SLB]
        Ingress[Ingress Controller<br/>Traefik/Nginx]
    end

    subgraph "Rancher Server"
        Rancher[Rancher Manager<br/>API Server + UI]
        API[Rancher API<br/>处理管理请求]
        Auth[认证服务<br/>LDAP/OAuth/SAML]
        Fleet[Fleet Agent<br/>GitOps 控制器]
    end

    subgraph "数据层"
        Etcd[(etcd 集群<br/>配置数据存储)]
        KubeAPI[Kubernetes API<br/>下游集群连接]
    end

    subgraph "下游集群"
        Downstream1[下游集群 1<br/>生产环境]
        Downstream2[下游集群 2<br/>测试环境]
        Downstream3[下游集群 N<br/>边缘节点]
    end

    LB --> Ingress --> Rancher
    Rancher --> API
    Rancher --> Auth
    Rancher --> Fleet
    Rancher --> Etcd
    Rancher --> KubeAPI
    KubeAPI --> Downstream1
    KubeAPI --> Downstream2
    KubeAPI --> Downstream3

    style Rancher fill:#0075a8,color:#fff
    style Etcd fill:#f4511e,color:#fff
```

### 1.2 适用场景

| 场景 | 描述 | 推荐架构 |
|------|------|---------|
| **生产环境** | 管理多个生产级 Kubernetes 集群 | 高可用 3+ 节点 |
| **混合云管理** | 统一管理 AWS、Azure、GCP、私有云集群 | 高可用 + 多云适配 |
| **边缘计算** | 管理分布在边缘位置的数百个轻量级集群 | Rancher + K3s |
| **CI/CD 平台** | 作为应用部署和持续交付的中心平台 | 集成 GitOps (Fleet) |
| **多租户平台** | 为多个团队/部门提供隔离的 Kubernetes 环境 | 多集群 + RBAC |
| **灾难恢复** | 需要备份恢复和故障切换能力 | 高可用 + 备份方案 |

### 1.3 架构原理

Rancher 采用 **双层管理架构**：

1. **Local Cluster (管理集群)**: 运行 Rancher Server 的专用 Kubernetes 集群
2. **Downstream Clusters (下游集群)**: 被 Rancher 管理的业务 Kubernetes 集群

```mermaid
graph LR
    subgraph "管理集群 (Local Cluster)"
        RancherServer[Rancher Server]
        Etcd[(etcd)]
    end

    subgraph "下游集群"
        Cluster1[集群 1<br/>RKE]
        Cluster2[集群 2<br/>EKS]
        Cluster3[集群 3<br/>K3s]
    end

    RancherServer -->|管理指令| Cluster1
    RancherServer -->|管理指令| Cluster2
    RancherServer -->|管理指令| Cluster3
    Cluster1 -->|状态上报| RancherServer
    Cluster2 -->|状态上报| RancherServer
    Cluster3 -->|状态上报| RancherServer
```

**关键原理**：
- Rancher 通过 **Agent** 部署到下游集群建立安全连接
- 使用 **WebSocket** 保持长连接，实现实时状态同步
- 所有配置数据存储在管理集群的 **etcd** 中
- 支持 **多集群联邦** 和 **GitOps** 自动化部署

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| Rancher 版本 | Kubernetes 支持范围 | 推荐下游集群 | 维护状态 | 发布日期 |
|-------------|-------------------|-------------|---------|---------|
| **v2.9.x** (最新稳定) | v1.27 - v1.29 | RKE2, K3s, EKS, AKS, GKE | ✅ 主线维护 | 2025-01 |
| **v2.8.x** | v1.26 - v1.28 | RKE2, K3s, EKS, AKS, GKE | ✅ 维护中 | 2024-06 |
| **v2.7.x** | v1.25 - v1.27 | RKE1❌, RKE2, K3s | ⚠️ 即将 EOL | 2023-11 |
| **v2.6.x** | v1.24 - v1.26 | RKE1❌, RKE2 | ⚠️ 仅安全更新 | 2023-05 |

> **说明**：RKE1 已于 2025年7月31日 到达生命周期结束（EOL），Rancher 2.12.0+ 不再支持 RKE1

#### Kubernetes 发行版支持矩阵

| 下游集群类型 | Rancher 2.9 | Rancher 2.8 | Rancher 2.7 |
|-------------|------------|------------|------------|
| **RKE2** | ✅ v1.27-1.29 | ✅ v1.26-1.28 | ✅ v1.25-1.27 |
| **K3s** | ✅ v1.27-1.29 | ✅ v1.26-1.28 | ✅ v1.25-1.27 |
| **EKS** | ✅ v1.27-1.29 | ✅ v1.26-1.28 | ✅ v1.25-1.27 |
| **AKS** | ✅ v1.27-1.29 | ✅ v1.26-1.28 | ✅ v1.25-1.27 |
| **GKE** | ✅ v1.27-1.29 | ✅ v1.26-1.28 | ✅ v1.25-1.27 |
| **RKE1** | ❌ 已废弃 | ❌ 已废弃 | ⚠️ 最后支持 |

### 2.2 版本决策建议

选择 Rancher 版本时需综合考虑以下因素：

#### **推荐选择 Rancher 2.9.x 的场景**：
- ✅ **新建生产环境**：获得最新功能和安全补丁
- ✅ **需要最新 Kubernetes 支持**：支持 v1.27-1.29
- ✅ **长期维护项目**：主线维护周期长
- ✅ **RKE2 用户**：最佳兼容性和性能

#### **选择 Rancher 2.8.x 的场景**：
- ⚠️ **现有升级路径**：从 2.7 平滑升级
- ⚠️ **稳定性优先**：经过更充分的生产验证
- ⚠️ **特定功能依赖**：某些 2.9 中移除的功能

#### **不推荐的版本**：
- ❌ **Rancher 2.6 及更早**：安全更新有限，建议尽快升级
- ❌ **RKE1 集群**：已 EOL，必须迁移到 RKE2 或其他发行版

#### **版本兼容性检查清单**：
1. [ ] 确认下游集群 Kubernetes 版本
2. [ ] 检查 RKE1 依赖（如有需规划迁移）
3. [ ] 验证硬件资源满足新版本要求
4. [ ] 评估升级窗口和回滚方案
5. [ ] 查看版本 Release Notes 关注 Breaking Changes

---

## 3. 生产环境规划

### 3.1 集群架构图

#### 生产环境高可用架构（3 节点）

```
                           ┌─────────────────┐
                           │   外部负载均衡   │
                           │ (SLB/Nginx/HAProxy)│
                           └────────┬────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
            ┌───────▼───────┐ ┌────▼────┐ ┌───────▼───────┐
            │  Rancher 01   │ │Rancher 02│ │  Rancher 03   │
            │  Control Plane│ │  Control │ │  Control Plane│
            │  + Worker     │ │  + Worker│ │  + Worker     │
            │  8C/16G/200G  │ │8C/16G/200G│ │  8C/16G/200G  │
            └───────┬───────┘ └────┬─────┘ └───────┬───────┘
                    │               │               │
                    └───────────────┼───────────────┘
                                    │
                        ┌───────────▼───────────┐
                        │     etcd 集群         │
                        │   (3 节点 quorum)     │
                        └───────────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
            ┌───────▼───────┐ ┌────▼─────┐ ┌──────▼──────┐
            │ 下游集群 1     │ │下游集群 2 │ │下游集群 N   │
            │ (生产环境)     │ │(测试环境) │ │(边缘节点)   │
            └───────────────┘ └──────────┘ └─────────────┘
```

#### 小型生产架构（单节点 + 备份）

```
                           ┌─────────────────┐
                           │   DNS/负载均衡   │
                           └────────┬────────┘
                                    │
                           ┌────────▼────────┐
                           │  Rancher Server │
                           │  All-in-One     │
                           │  4C/8G/100G     │
                           └────────┬────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
            ┌───────▼───────┐ ┌────▼─────┐ ┌──────▼──────┐
            │   备份存储     │ │下游集群 1│ │下游集群 2   │
            │   (S3/NFS)    │ │          │ │            │
            └───────────────┘ └──────────┘ └─────────────┘
```

### 3.2 节点角色与配置要求

#### 管理集群（Local Cluster）配置

| 角色 | 最低配置 | 推荐配置 | 说明 |
|-----|---------|---------|------|
| **Control Plane** | 2 CPU / 4 GB RAM | 4 CPU / 8 GB RAM | Rancher API Server |
| **etcd 节点** | 2 CPU / 4 GB RAM / 20 GB | 4 CPU / 8 GB RAM / 100 GB | 数据持久化存储 |
| **Worker 节点** | 2 CPU / 4 GB RAM | 4 CPU / 16 GB RAM | 运行 Rancher 组件 |
| **存储** | 50 GB SSD | 200 GB NVMe SSD | 持久化存储要求 |
| **网络** | 100 Mbps | 1 Gbps | 集群间通信 |

#### 生产环境 3 节点配置示例

```bash
# 节点 1 - Control Plane + etcd + Worker
hostname: rancher-01.example.com
cpu: 8 核
memory: 16 GB
disk: 200 GB SSD
os: Rocky Linux 9 / Ubuntu 22.04

# 节点 2 - Control Plane + etcd + Worker
hostname: rancher-02.example.com
cpu: 8 核
memory: 16 GB
disk: 200 GB SSD
os: Rocky Linux 9 / Ubuntu 22.04

# 节点 3 - Control Plane + etcd + Worker
hostname: rancher-03.example.com
cpu: 8 核
memory: 16 GB
disk: 200 GB SSD
os: Rocky Linux 9 / Ubuntu 22.04
```

#### 软件要求

| 组件 | 版本要求 | 说明 |
|-----|---------|------|
| **操作系统** | Rocky Linux 9+ / Ubuntu 22.04+ | 64-bit x86 架构 |
| **Kubernetes** | v1.27 - v1.29 | 管理集群 K8s 版本 |
| **容器运行时** | containerd 1.6+ / Docker 23+ | 推荐使用 containerd |
| **Helm** | v3.12+ | 用于安装 Rancher |
| **Ingress Controller** | Traefik / Nginx | 必需组件 |

### 3.3 网络与端口规划

#### 端口要求

| 端口 | 协议 | 用途 | 外部访问 |
|-----|------|------|---------|
| **80** | TCP | HTTP (重定向到 HTTPS) | ✅ 是 |
| **443** | TCP | HTTPS (Rancher UI/API) | ✅ 是 |
| **6443** | TCP | Kubernetes API Server | ⚠️ 可选 |
| **2376** | TCP | Docker TLS (如使用) | ❌ 否 |
| **10250** | TCP | Kubelet API | ❌ 否 |
| **30000-32767** | TCP | NodePort 服务范围 | ⚠️ 可选 |

#### 网络规划建议

```yaml
# 网络配置示例
network:
  # Rancher Server 访问域名
  rancher_domain: rancher.example.com  # ★ 修改为实际域名

  # Pod 网络段
  pod_cidr: 10.42.0.0/16

  # Service 网络段
  service_cidr: 10.43.0.0/16

  # 集群 DNS
  cluster_dns: 10.43.0.10

  # 负载均衡配置
  load_balancer:
    type: "slb"  # slb / nginx / haproxy
    vip: "192.168.1.100"  # 虚拟IP
```

---

## 4. 生产环境部署

### 4.1 前置准备

#### 系统初始化（所有节点执行）

##### ** Rocky Linux 9 **

```bash
# ── Rocky Linux 9 ──────────────────────────
# 1. 更新系统
sudo dnf update -y

# 2. 安装基础工具
sudo dnf install -y curl wget vim git bash-completion

# 3. 配置主机名
sudo hostnamectl set-hostname rancher-01.example.com  # ← 根据实际修改

# 4. 配置 hosts 文件
cat >> /etc/hosts << 'EOF'
192.168.1.101 rancher-01.example.com rancher-01  # ← 根据实际IP修改
192.168.1.102 rancher-02.example.com rancher-02  # ← 根据实际IP修改
192.168.1.103 rancher-03.example.com rancher-03  # ← 根据实际IP修改
EOF

# 5. 关闭防火墙（或配置规则）
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# 6. 关闭 Swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# 7. 配置内核参数
cat >> /etc/sysctl.d/99-kubernetes.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
EOF
sudo sysctl --system

# 8. 配置时间同步
sudo dnf install -y chrony
sudo systemctl enable --now chronyd
```

##### ** Ubuntu 22.04 **

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 1. 更新系统
sudo apt-get update && sudo apt-get upgrade -y

# 2. 安装基础工具
sudo apt-get install -y curl wget vim git bash-completion

# 3. 配置主机名
sudo hostnamectl set-hostname rancher-01.example.com  # ← 根据实际修改

# 4. 配置 hosts 文件
cat >> /etc/hosts << 'EOF'
192.168.1.101 rancher-01.example.com rancher-01  # ← 根据实际IP修改
192.168.1.102 rancher-02.example.com rancher-02  # ← 根据实际IP修改
192.168.1.103 rancher-03.example.com rancher-03  # ← 根据实际IP修改
EOF

# 5. 配置防火墙
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 6443/tcp
sudo ufw allow 2376/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 30000:32767/tcp

# 6. 关闭 Swap
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# 7. 配置内核参数
cat >> /etc/sysctl.d/99-kubernetes.conf << 'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo modprobe br_netfilter
sudo sysctl --system

# 8. 配置时间同步
sudo apt-get install -y chrony
sudo systemctl enable --now chronyd
```

#### SSH 免密登录配置

```bash
# 在第一个节点生成密钥
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa

# 复制公钥到其他节点
ssh-copy-id root@rancher-02.example.com  # ← 根据实际修改
ssh-copy-id root@rancher-03.example.com  # ← 根据实际修改
```

---

### 4.2 Rocky Linux 9 部署步骤

#### 步骤 1: 安装 Kubernetes 集群（RKE2）

```bash
# ── Rocky Linux 9 ──────────────────────────
# 1. 安装 RKE2（在所有节点执行）
curl -sfL https://get.rke2.io | sh -

# 2. 创建 RKE2 配置目录
mkdir -p /etc/rancher/rke2

# 3. 创建配置文件（第一个节点）
cat > /etc/rancher/rke2/config.yaml << 'EOF'
# RKE2 配置文件
write-kubeconfig-mode: "0644"
tls-san:
  - rancher.example.com  # ★ 修改为实际域名
  - 192.168.1.100        # ★ 负载均衡IP或VIP
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
EOF

# 4. 启动 RKE2 Server（第一个节点）
systemctl enable rke2-server.service
systemctl start rke2-server.service

# 5. 等待节点启动（约 2-3 分钟）
sleep 180

# 6. 获取集群 Token
cat /var/lib/rancher/rke2/server/node-token

# 输出示例：K10b6c...bXzj4::server:...
```

#### 步骤 2: 加入其他节点

```bash
# ── Rocky Linux 9 ──────────────────────────
# 在其他节点执行（rancher-02、rancher-03）

# 1. 创建配置文件
cat > /etc/rancher/rke2/config.yaml << 'EOF'
write-kubeconfig-mode: "0644"
server: https://192.168.1.101:9345  # ★ 第一个节点IP
token: "K10b6c...bXzj4::server:..."  # ★ 从节点1获取的Token
tls-san:
  - rancher.example.com  # ★ 修改为实际域名
EOF

# 2. 启动 RKE2 Server
systemctl enable rke2-server.service
systemctl start rke2-server.service
```

#### 步骤 3: 验证集群状态

```bash
# ── Rocky Linux 9 ──────────────────────────
# 配置 kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
mkdir -p ~/.kube
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
chmod 600 ~/.kube/config

# 安装 kubectl（如果未安装）
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 验证节点状态
kubectl get nodes

# 预期输出：
# NAME             STATUS   ROLES                       AGE   VERSION
# rancher-01       Ready    control-plane,etcd,master   5m    v1.28.8
# rancher-02       Ready    control-plane,etcd,master   3m    v1.28.8
# rancher-03       Ready    control-plane,etcd,master   2m    v1.28.8
```

---

### 4.3 Ubuntu 22.04 部署步骤

#### 步骤 1: 安装 Kubernetes 集群（K3s）

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 1. 安装 K3s（在所有节点执行）
curl -sfL https://get.k3s.io | sh -

# 2. 查看获取的 Token
cat /var/lib/rancher/k3s/server/node-token

# 输出示例：K10b6c...bXzj4::server:...
```

#### 步骤 2: 配置集群（第一个节点）

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 1. 停止默认安装的 K3s
sudo systemctl stop k3s

# 2. 创建配置文件
cat > /etc/rancher/k3s/config.yaml << 'EOF'
write-kubeconfig-mode: "0644"
tls-san:
  - rancher.example.com  # ★ 修改为实际域名
  - 192.168.1.100        # ★ VIP 或负载均衡IP
cluster-cidr: 10.42.0.0/16
service-cidr: 10.43.0.0/16
disable: traefik          # 禁用默认 Ingress
EOF

# 3. 重启 K3s
sudo systemctl start k3s
```

#### 步骤 3: 加入其他节点

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 在其他节点执行（rancher-02、rancher-03）

# 1. 安装 K3s 并加入集群
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.101:6443 \
  K3S_TOKEN=K10b6c...bXzj4::server:... sh -  # ★ 替换实际Token

# 2. 验证节点加入
sudo k3s kubectl get nodes
```

---

### 4.4 集群初始化与配置

#### 安装 Helm

```bash
# ── Rocky Linux 9 ──────────────────────────
# ── Ubuntu 22.04 ───────────────────────────
# 两种系统通用安装方式

# 1. 下载 Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# 2. 验证安装
helm version

# 预期输出：v3.x.x
```

#### 安装 Cert-Manager（必需）

```bash
# 1. 添加 Jetstack 仓库
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. 安装 Cert-Manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.14.0 \
  --set installCRDs=true

# 3. 验证安装
kubectl get pods -n cert-manager

# 预期输出：3 个 Pod 运行中
# NAME                                      READY   STATUS    RESTARTS   AGE
# cert-manager-xxx                         1/1     Running   0          2m
# cert-manager-cainjector-xxx              1/1     Running   0          2m
# cert-manager-webhook-xxx                 1/1     Running   0          2m
```

#### 添加 Rancher Helm 仓库

```bash
# 添加 Rancher 稳定版仓库
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# 查看可用版本
helm search repo rancher-stable/rancher --versions
```

---

### 4.5 安装验证

#### 安装 Rancher

```bash
# 1. 创建命名空间
kubectl create namespace cattle-system

# 2. 使用 Helm 安装 Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \  # ★ 修改为实际域名
  --set replicas=3 \
  --set ingress.tls.source=rancher \
  --set rancherImageTag=v2.9.0 \         # ★ 指定版本
  --set bootstrapPassword=admin \        # ★ 设置初始管理员密码
  --timeout 10m

# 3. 等待安装完成（约 5-10 分钟）
kubectl -n cattle-system rollout status deployment/rancher
```

#### 验证安装状态

```bash
# 1. 检查 Pod 状态
kubectl get pods -n cattle-system

# 预期输出：
# NAME                       READY   STATUS    RESTARTS   AGE
# rancher-xxx               1/1     Running   0          5m
# rancher-xxx               1/1     Running   0          5m
# rancher-xxx               1/1     Running   0          5m

# 2. 检查 Service
kubectl get svc -n cattle-system

# 预期输出：
# NAME      TYPE       EXTERNAL-IP   PORT(S)                      AGE
# rancher   ClusterIP  <none>        80/TCP,443/TCP              10m

# 3. 检查 Ingress
kubectl get ingress -n cattle-system

# 预期输出：
# NAME      CLASS    HOSTS                  ADDRESS        PORTS     AGE
# rancher   <none>   rancher.example.com    192.168.1.101  80, 443   10m

# 4. 查看 Rancher 日志
kubectl logs -n cattle-system -l app=rancher --tail=100 -f
```

#### 访问 Rancher

1. **配置 DNS 解析**：
   ```bash
   # 添加 DNS A 记录
   rancher.example.com  A  192.168.1.100  # VIP 或负载均衡IP
   ```

2. **访问 Rancher UI**：
   - URL: `https://rancher.example.com`
   - 用户名: `admin`
   - 密码: `admin`（安装时设置的 bootstrapPassword）

3. **首次登录设置**：
   - 修改管理员密码
   - 设置服务器 URL（确保可以从下游集群访问）
   - 同意使用条款

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

#### Helm Values 配置文件

```bash
cat > rancher-values.yaml << 'EOF'
# Rancher Manager 生产环境配置
# ⚠️ 所有标记 ★ 的参数必须根据实际环境修改

# ==================== 基本配置 ====================
hostname: rancher.example.com  # ★ Rancher 访问域名（必填）

# 管理员密码
# ⚠️ 生产环境必须修改复杂密码
bootstrapPassword: "YourStrongPassword123!"  # ★ 初始管理员密码

# Rancher 镜像标签
rancherImageTag: v2.9.0  # 指定版本，建议锁定版本

# ==================== 高可用配置 ====================
replicas: 3  # 副本数，生产环境必须 ≥ 3

# ==================== TLS/SSL 配置 ====================
ingress:
  tls:
    source: rancher  # 使用 Rancher 自动生成证书
    # 其他选项：rancher / secret / letsEncrypt

# Let's Encrypt 配置（如使用）
letsEncrypt:
  email: admin@example.com  # ★ 证书邮箱
  environment: production  # production / staging

# 使用已有证书（可选）
# extraEnv:
#   - name: CATTLE_TLS_KEY
#     valueFrom:
#       secretKeyRef:
#         name: tls-secret
#         key: tls.key
#   - name: CATTLE_TLS_CERT
#     valueFrom:
#       secretKeyRef:
#         name: tls-secret
#         key: tls.crt

# ==================== 镜像仓库配置 ====================
# ⚠️ 离线环境或私有镜像仓库必须配置
# systemDefaultRegistry: registry.example.com  # 私有镜像仓库地址

# 私有镜像仓库认证
# privateRegistry:
#   registrySuffix: registry.example.com
#   password: registry-password
#   username: registry-username

# ==================== 资源限制 ====================
resources:
  limits:
    cpu: 1000m
    memory: 2000Mi
  requests:
    cpu: 500m
    memory: 1000Mi

# ==================== 持久化存储 ====================
# ⚠️ 生产环境强烈建议配置持久化存储
# persistence:
#   enabled: true
#   storageClass: "fast-ssd"  # ★ 存储类名称
#   size: 20G

# ==================== 代理配置（如需要） ====================
# proxy: http://proxy.example.com:8888
# noProxy: 127.0.0.1,localhost,.local,.internal

# ==================== 功能开关 ====================
features:
  # 多集群管理
  multi-cluster-management: true

  # Fleet GitOps
  fleet: true

  # 监控
  monitoring: true

# ==================== 调试选项 ====================
# ⚠️ 生产环境建议关闭
logLevel: info  # debug / info / warn / error
debug: false

# ==================== 高级配置 ====================
# 设置 Rancher Server URL
# ⚠️ 确保下游集群可以访问此地址
rancherUrl: https://rancher.example.com  # ★ 对外访问URL

# 审计日志
auditLog:
  level: 1  # 0=关闭, 1=元数据, 2=请求, 3=请求响应
  destination: sidecar  # sidecar / hostPath
  hostPath: /var/log/rancher/audit

# ==================== 附加组件 ====================
# 安装 Ingress Controller（如集群未安装）
# ingressController:
#   enabled: true
#   type: default

# ==================== 时区设置 ====================
tz: Asia/Shanghai  # 设置时区
EOF
```

### 5.2 生产环境推荐调优参数

#### Kubernetes 集群调优

```bash
# ── Rocky Linux 9 ──────────────────────────
# ── Ubuntu 22.04 ───────────────────────────

# 1. 调整 etcd 性能（RKE2 集群）
cat >> /etc/rancher/rke2/config.yaml << 'EOF'
# etcd 性能调优
etcd-expose-metrics: true
etcd-snapshot-schedule-cron: "0 */6 * * *"  # 每6小时快照
etcd-snapshot-retention: 28  # 保留28个快照
EOF

# 2. 调整容器运行时
mkdir -p /etc/containerd
cat > /etc/containerd/config.toml << 'EOF'
version = 2
[plugins."io.containerd.grpc.v1.cri"]
  systemd_cgroup = true
  max_container_log_line_size = -1
[plugins."io.containerd.grpc.v1.cri".containerd]
  discard_unpacked_layers = true
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["https://registry-1.docker.io"]
EOF

systemctl restart containerd
```

#### Rancher 性能优化

```bash
# 创建优化的 Values 文件
cat > rancher-values-prod.yaml << 'EOF'
# 生产环境优化配置

# 增加资源配额
resources:
  limits:
    cpu: 2000m      # ★ 根据 CPU 核心数调整
    memory: 4096Mi  # ★ 根据内存大小调整
  requests:
    cpu: 1000m
    memory: 2048Mi

# 启用亲和性（确保 Pod 分散）
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app
                operator: In
                values:
                  - rancher
          topologyKey: kubernetes.io/hostname

# 调整并发参数
env:
  - name: CATTLE_API_MAX_REQUEST_TIMEOUT
    value: "300"  # 5分钟
  - name: CATTLE_API_RATE_LIMIT
    value: "500"  # 每秒请求限制
  - name: CATTLE_CLIENT_MAX_CONNECTIONS
    value: "500"

# 启用缓存
caching:
  enabled: true
  clusterExpiry: 24h
  authExpiry: 30m
EOF

# 应用优化配置
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  -f rancher-values-prod.yaml \
  --reuse-values
```

---

## 6. 开发/测试环境快速部署

### 6.1 Docker 快速部署

> ⚠️ **警告**: Docker 方式仅适用于测试和开发环境，**不可用于生产环境**！

```bash
# ── Rocky Linux 9 ──────────────────────────
# ── Ubuntu 22.04 ───────────────────────────

# 1. 安装 Docker（如未安装）
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker

# 2. 启动 Rancher 容器
docker run -d \
  --restart=unless-stopped \
  --name rancher \
  -p 80:80 -p 443:443 \
  --privileged \
  rancher/rancher:v2.9.0

# 3. 等待启动（约 2-3 分钟）
sleep 180

# 4. 查看日志
docker logs -f rancher

# 5. 获取初始密码
docker logs rancher 2>&1 | grep "Bootstrap Password:"

# 预期输出：
# INFO: Bootstrap Password: xxxxxxxxxxxxxxxx

# 6. 访问 Rancher
# URL: https://<服务器IP>
# 用户名: admin
# 密码: (上面获取的 Bootstrap Password)
```

### 6.2 Docker Compose 部署

```bash
# 创建 Docker Compose 配置
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  rancher:
    image: rancher/rancher:v2.9.0
    container_name: rancher
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    privileged: true
    volumes:
      - rancher-data:/var/lib/rancher
    environment:
      - CATTLE_BOOTSTRAP_PASSWORD=admin123  # ★ 设置初始密码
    labels:
      - "com.rancher.type=rancher"

volumes:
  rancher-data:
    driver: local
EOF

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps
docker-compose logs -f
```

---

## 7. 日常运维操作

### 7.1 常用管理命令

#### kubectl 常用命令

```bash
# 配置 kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml  # RKE2
# export KUBECONFIG=/etc/rancher/k3s/k3s.yaml   # K3s

# 查看节点
kubectl get nodes -o wide

# 查看所有命名空间
kubectl get ns

# 查看 Rancher Pods
kubectl get pods -n cattle-system

# 查看 Rancher 日志
kubectl logs -n cattle-system -l app=rancher --tail=100 -f

# 进入 Rancher Pod
kubectl exec -it -n cattle-system $(kubectl get pod -n cattle-system -l app=rancher -o jsonpath='{.items[0].metadata.name}') -- bash

# 查看资源使用
kubectl top nodes
kubectl top pods -n cattle-system

# 查看事件
kubectl get events -n cattle-system --sort-by='.lastTimestamp'

# 导出配置
kubectl get configmap -n cattle-system rancher-config -o yaml > rancher-config-backup.yaml
```

#### Helm 常用命令

```bash
# 查看 Release 状态
helm status rancher -n cattle-system

# 查看 Release 历史
helm history rancher -n cattle-system

# 列出所有 Values
helm get values rancher -n cattle-system

# 升级 Rancher
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  -f rancher-values.yaml

# 回滚到上一版本
helm rollback rancher -n cattle-system

# 卸载 Rancher
helm uninstall rancher -n cattle-system
```

#### Rancher CLI 常用命令

```bash
# 安装 Rancher CLI
curl -L https://github.com/rancher/cli/releases/download/v2.9.0/rancher-linux-amd64-v2.9.0.tar.gz | tar zx
sudo mv rancher-v2.9.0/rancher /usr/local/bin/rancher

# 登录 Rancher
rancher login https://rancher.example.com --token <TOKEN> --skip-verify

# 查看集群列表
rancher cluster ls

# 查看集群详情
rancher cluster inspect <CLUSTER_ID>

# 创建集群
rancher cluster create --template "K3s" my-cluster

# 删除集群
rancher cluster delete <CLUSTER_ID>
```

### 7.2 备份与恢复

#### 备份 Rancher

```bash
# 方式 1: 使用 Rancher 内置备份
# 1. 在 Rancher UI 中创建备份
# 导航到: 更多菜单 -> 备份 -> 创建备份

# 方式 2: 手动备份 etcd
# ── Rocky Linux 9 (RKE2) ──────────────────────────
# 触发 etcd 快照
rke2 etcd-snapshot save --name backup-$(date +%Y%m%d-%H%M%S)

# 列出快照
ls -lh /var/lib/rancher/rke2/server/db/snapshots/

# ── Ubuntu 22.04 (K3s) ───────────────────────────
# 备份 K3s 数据库
k3s etcd-snapshot save --name backup-$(date +%Y%m%d-%H%M%S)

# 方式 3: 备份 Rancher 配置
kubectl get configmap -n cattle-system rancher-config -o yaml > rancher-config-$(date +%Y%m%d).yaml
kubectl get secret -n cattle-system rancher-tls -o yaml > rancher-tls-$(date +%Y%m%d).yaml
```

#### 恢复 Rancher

```bash
# ── Rocky Linux 9 (RKE2) ──────────────────────────
# 1. 停止 RKE2 服务
systemctl stop rke2-server

# 2. 恢复 etcd 快照
rke2 etcd-snapshot restore --name backup-20250309-120000

# 3. 启动 RKE2 服务
systemctl start rke2-server

# 4. 验证恢复
kubectl get nodes

# ── Ubuntu 22.04 (K3s) ───────────────────────────
# 1. 停止 K3s 服务
systemctl stop k3s

# 2. 恢复快照
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/backup-20250309-120000

# 3. 启动 K3s 服务
systemctl start k3s
```

### 7.3 集群扩缩容

#### 添加管理集群节点

```bash
# ── Rocky Linux 9 ──────────────────────────
# 在新节点上执行

# 1. 安装 RKE2
curl -sfL https://get.rke2.io | sh -

# 2. 创建配置
cat > /etc/rancher/rke2/config.yaml << 'EOF'
write-kubeconfig-mode: "0644"
server: https://192.168.1.101:9345  # 已有节点IP
token: "K10b6c...bXzj4::server:..."  # 从已有节点获取Token
tls-san:
  - rancher.example.com
  - 192.168.1.104  # 新节点IP
EOF

# 3. 启动服务
systemctl enable rke2-server.service
systemctl start rke2-server.service

# 4. 在控制节点验证
kubectl get nodes
```

#### 移除节点

```bash
# 1. 删除节点（在控制节点执行）
kubectl delete node rancher-04.example.com

# 2. 在被删除节点上清理
# ── Rocky Linux 9 ──────────────────────────
systemctl stop rke2-server
systemctl disable rke2-server
rm -rf /etc/rancher/rke2
rm -rf /var/lib/rancher/rke2

# ── Ubuntu 22.04 ───────────────────────────
systemctl stop k3s
systemctl disable k3s
rm -rf /etc/rancher/k3s
rm -rf /var/lib/rancher/k3s
```

### 7.4 版本升级

#### 升级前准备

```bash
# 1. 备份当前配置
kubectl get configmap -n cattle-system rancher-config -o yaml > rancher-config-backup.yaml
helm get values rancher -n cattle-system > rancher-values-backup.yaml

# 2. 检查当前版本
helm status rancher -n cattle-system

# 3. 查看可用版本
helm search repo rancher-stable/rancher --versions

# 4. 阅读版本 Release Notes
# 访问: https://github.com/rancher/rancher/releases
```

#### 执行升级

```bash
# 1. 更新 Helm 仓库
helm repo update

# 2. 添加新版本仓库（如需要）
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

# 3. 执行升级
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set rancherImageTag=v2.9.1 \
  -f rancher-values.yaml \
  --timeout 15m

# 4. 监控升级进度
kubectl -n cattle-system rollout status deployment/rancher

# 5. 查看新 Pods 状态
kubectl get pods -n cattle-system -l app=rancher
```

#### 回滚升级

```bash
# 1. 查看 Helm 历史版本
helm history rancher -n cattle-system

# 2. 回滚到上一版本
helm rollback rancher -n cattle-system

# 3. 回滚到指定版本
helm rollback rancher -n cattle-system 3  # 回滚到第3个版本

# 4. 验证回滚
kubectl get pods -n cattle-system -l app=rancher
```

---

## 8. 使用手册

### 8.1 登录与认证

#### 首次登录配置

```bash
# 1. 访问 Rancher UI
# URL: https://rancher.example.com

# 2. 首次登录步骤：
#    - 用户名: admin
#    - 密码: (安装时设置的 bootstrapPassword)

# 3. 修改管理员密码
# 导航到: 右上角用户菜单 -> 修改密码

# 4. 设置服务器 URL
# 导航到: 设置 -> 全局设置 -> Server URL
# 填写: https://rancher.example.com  # 确保下游集群可访问

# 5. 同意使用条款
```

#### 创建 API Token

```bash
# 在 UI 中创建 Token
# 导航到: 右上角用户菜单 -> API & Keys -> 添加 API Key

# 使用 Token 进行 CLI 认证
rancher login https://rancher.example.com \
  --token token-xxxxx:xxxxxx \
  --skip-verify

# 使用 Token 进行 API 调用
curl -u "token-xxxxx:xxxxxx" \
  https://rancher.example.com/v3/clusters
```

### 8.2 集群管理操作

#### 创建下游集群

```bash
# 方式 1: 通过 UI 创建
# 1. 导航到: 集群管理 -> 创建
# 2. 选择集群类型:
#    - 使用现有节点（自定义）
#    - 云服务提供商（EKS/AKS/GKE）
#    - RKE2 / K3s 模板
# 3. 配置集群参数
# 4. 获取节点注册命令
# 5. 在目标节点执行注册命令

# 方式 2: 通过 CLI 创建
rancher cluster create \
  --template "K3s" \
  --name my-k3s-cluster \
  --description "My K3s test cluster"

# 方式 3: 通过 API 创建
curl -X POST \
  -u "token-xxxxx:xxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "cluster",
    "name": "my-cluster",
    "description": "My test cluster",
    "rancherKubernetesEngineConfig": {...}
  }' \
  https://rancher.example.com/v3/clusters
```

#### 节点管理

```bash
# 注册节点到现有集群
# 1. 在 UI 中获取节点命令
#    导航到: 集群管理 -> 选择集群 -> 节点 -> 编辑
# 2. 在目标节点执行生成的命令
#    通常类似：
#    curl -sfL https://rancher.example.com/v3/import/xxxxx.sh | sh -

# 查看集群节点
kubectl get nodes --context=my-cluster

# 排水节点（维护）
kubectl drain node-01 --ignore-daemonsets --delete-emptydir-data

# 恢复节点
kubectl uncordon node-01

# 删除节点
kubectl delete node node-01
```

### 8.3 用户与权限管理

#### 创建用户

```bash
# 通过 UI 创建用户
# 导航到: 用户管理 -> 用户 -> 创建用户

# 通过 API 创建用户
curl -X POST \
  -u "token-xxxxx:xxxxxx" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "user",
    "username": "devops-user",
    "password": "StrongPassword123!",
    "name": "DevOps User",
    "email": "devops@example.com"
  }' \
  https://rancher.example.com/v3/users
```

#### 配置 RBAC

```bash
# 创建自定义角色
# 导航到: 用户管理 -> 角色 -> 创建角色

# 角色示例：只读访问
name: Cluster Read-Only
description: Read-only access to clusters
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]

# 分配用户到集群
# 导航到: 集群管理 -> 选择集群 -> 成员 -> 添加成员
# 选择用户和角色权限

# 配置全局权限
# 导航到: 用户管理 -> 全局权限 -> 编辑
```

#### LDAP/AD 集成

```bash
# 配置 LDAP 认证
# 导航到: 用户管理 -> 认证 -> LDAP

# 配置示例：
Server: ldap.example.com:636
Port: 636
Bind DN: cn=admin,dc=example,dc=com
Bind Password: xxxxxx
User Search Base: ou=users,dc=example,dc=com
Group Search Base: ou=groups,dc=example,dc=com

# 测试连接并保存
```

### 8.4 监控与告警配置

#### 启用集群监控

```bash
# 方式 1: 通过 UI 启用
# 导航到: 集群管理 -> 选择集群 -> 工具 -> 监控
# 点击"启用"

# 方式 2: 通过 Helm 启用
helm install rancher-monitoring rancher-stable/rancher-monitoring \
  --namespace cattle-monitoring-system \
  --set grafana.persistence.enabled=true \
  --set prometheus.persistence.enabled=true

# 访问 Grafana
# URL: https://rancher.example.com/c/c-xxxxx/grafana
```

#### 配置告警

```bash
# 创建告警规则
# 导航到: 集群管理 -> 选择集群 -> 告警 -> 创建规则

# 告警示例：Pod 异常重启
名称: Pod Restart Alert
条件: Pod 重启次数 > 5
持续时间: 5 分钟
通知: Webhook / Email / Slack

# 配置通知接收器
# 导航到: 集群管理 -> 选择集群 -> 告警 -> 通知接收器

# Webhook 配置示例
Name: Slack Webhook
URL: https://hooks.slack.com/services/xxx/yyy/zzz
```

### 8.5 备份恢复操作

#### 创建定期备份

```bash
# 通过 UI 配置定期备份
# 导航到: 更多菜单 -> 备份 -> 创建定期备份

# 配置示例：
名称: daily-backup
备份类型: 本地存储 / S3
频率: 每天凌晨 2 点
保留: 7 个备份

# S3 配置示例：
S3 Bucket: my-backup-bucket
S3 Region: us-east-1
S3 Endpoint: https://s3.amazonaws.com
访问密钥: AKIAIOSFODNN7EXAMPLE
密钥: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### 执行灾难恢复

```bash
# 从备份恢复集群

# 1. 准备新的 Kubernetes 集群
#    （确保版本与备份时兼容）

# 2. 安装相同版本的 Rancher
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \
  --set replicas=3 \
  --set bootstrapPassword=admin

# 3. 上传备份文件
#    通过 UI 上传或手动放置到指定路径

# 4. 执行恢复
#    导航到: 更多菜单 -> 备份 -> 恢复
#    选择备份文件并执行恢复

# 5. 验证恢复结果
kubectl get nodes
kubectl get clusters --all-namespaces
```

---

## 9. 注意事项与生产检查清单

### 9.1 安装前环境核查

#### 系统检查清单

```bash
# ── Rocky Linux 9 / Ubuntu 22.04 ──────────────────────────

# 1. 检查操作系统版本
cat /etc/os-release
# 要求：Rocky Linux 9+ 或 Ubuntu 22.04+

# 2. 检查架构
uname -m
# 要求：x86_64

# 3. 检查 CPU 核心数
nproc
# 最低：2 核，推荐：4+ 核

# 4. 检查内存
free -h
# 最低：4 GB，推荐：8+ GB

# 5. 检查磁盘空间
df -h
# 最低：50 GB，推荐：200+ GB SSD

# 6. 检查网络连通性
ping -c 4 8.8.8.8
curl -I https://www.google.com

# 7. 检查 DNS 解析
nslookup rancher.example.com  # ★ 替换为实际域名

# 8. 检查时区设置
timedatectl
# 建议：timedatectl set-timezone Asia/Shanghai

# 9. 检查时间同步
timedatectl status
# NTP synchronized: yes

# 10. 检查防火墙状态
# Rocky Linux:
systemctl status firewalld
# Ubuntu:
ufw status
```

#### 端口检查清单

```bash
# 检查关键端口是否被占用
for port in 80 443 6443 2376 10250; do
  echo "Checking port $port..."
  netstat -tuln | grep $port || ss -tuln | grep $port
done

# 预期结果：
# 80/tcp - 应该可用（或被 Ingress 占用）
# 443/tcp - 应该可用（或被 Ingress 占用）
# 6443/tcp - Kubernetes API（RKE2/K3s 启动后占用）
# 2376/tcp - Docker TLS（如使用 Docker）
# 10250/tcp - Kubelet API
```

#### DNS 检查清单

```bash
# 1. 检查域名解析
dig +short rancher.example.com
# 应返回：Rancher VIP 或负载均衡IP

# 2. 检查反向解析
dig -x 192.168.1.100
# 应返回：rancher.example.com

# 3. 检查 DNS 服务器
cat /etc/resolv.conf
```

### 9.2 常见故障排查

#### 故障 1: Pod 无法启动

```bash
# 现象：Rancher Pod 处于 Pending 或 CrashLoopBackOff 状态

# 排查步骤：
# 1. 查看 Pod 状态
kubectl get pods -n cattle-system
kubectl describe pod <pod-name> -n cattle-system

# 2. 查看 Pod 日志
kubectl logs <pod-name> -n cattle-system --previous

# 3. 常见原因和解决方案：

# 原因 A: 镜像拉取失败
# 解决：检查镜像仓库连接，配置私有仓库
docker pull rancher/rancher:v2.9.0

# 原因 B: 资源不足
# 解决：增加节点资源或调整资源限制
kubectl top nodes

# 原因 C: 存储卷挂载失败
# 解决：检查 StorageClass 配置
kubectl get sc
```

#### 故障 2: 无法访问 Rancher UI

```bash
# 现象：浏览器无法打开 https://rancher.example.com

# 排查步骤：
# 1. 检查 Ingress 配置
kubectl get ingress -n cattle-system
kubectl describe ingress rancher -n cattle-system

# 2. 检查 Service
kubectl get svc -n cattle-system
kubectl describe svc rancher -n cattle-system

# 3. 检查证书
kubectl get secret -n cattle-system rancher-tls -o yaml

# 4. 测试本地访问
curl -k https://localhost -H "Host: rancher.example.com"

# 5. 常见原因：
# - DNS 解析错误
# - 负载均衡器配置错误
# - 防火墙阻止
# - 证书问题
```

#### 故障 3: 集群节点 NotReady

```bash
# 现象：kubectl get nodes 显示节点状态为 NotReady

# 排查步骤：
# 1. 查看节点详情
kubectl describe node <node-name>

# 2. 检查 kubelet 状态
# Rocky Linux (RKE2):
systemctl status rke2-agent

# Ubuntu (K3s):
systemctl status k3s-agent

# 3. 查看 kubelet 日志
journalctl -u rke2-agent -f  # RKE2
journalctl -u k3s-agent -f   # K3s

# 4. 常见原因：
# - 容器运行时问题
# - 网络插件问题
# - 资源不足
# - kubelet 配置错误
```

#### 故障 4: 下游集群连接失败

```bash
# 现象：下游集群显示"等待连接"或"连接失败"

# 排查步骤：
# 1. 检查 Rancher Server URL
kubectl get configmap -n cattle-system rancher-config -o yaml | grep server-url

# 2. 检查网络连通性
# 在下游集群节点上：
curl -k https://rancher.example.com/ping

# 3. 检查 Agent Pod 状态
kubectl get pods -n cattle-system | grep agent
kubectl logs -n cattle-system <agent-pod> --tail=100

# 4. 常见原因：
# - Rancher Server URL 不可访问
# - 防火墙阻止
# - Token 过期
# - 网络策略限制
```

### 9.3 安全加固建议

#### 访问控制

```bash
# 1. 修改默认密码
# ⚠️ 首次登录必须修改 admin 密码

# 2. 启用 TLS/SSL
# 生产环境必须使用有效证书，避免使用自签名证书

# 3. 配置防火墙规则
# Rocky Linux:
cat > /etc/firewalld/services/rancher.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Rancher</short>
  <description>Rancher Server Ports</description>
  <port protocol="tcp" port="80"/>
  <port protocol="tcp" port="443"/>
  <port protocol="tcp" port="6443"/>
</service>
EOF

firewall-cmd --permanent --add-service=rancher
firewall-cmd --reload

# Ubuntu:
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 6443/tcp
ufw enable

# 4. 限制 API 访问
# 配置 RBAC，限制用户权限

# 5. 启用审计日志
# 见 5.1 节配置
```

#### 数据安全

```bash
# 1. 启用 etcd 加密（RKE2）
cat >> /etc/rancher/rke2/config.yaml << 'EOF'
secrets-encryption: true
EOF

# 2. 配置定期备份
# 见 8.5 节

# 3. 使用私有镜像仓库
# 离线环境或安全要求高的环境必须配置

# 4. 限制容器特权
# 修改 Pod 安全策略
```

#### 网络安全

```bash
# 1. 配置网络策略
cat > network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: rancher-network-policy
  namespace: cattle-system
spec:
  podSelector:
    matchLabels:
      app: rancher
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53  # DNS
    - protocol: UDP
      port: 53
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 6443  # Kubernetes API
EOF

kubectl apply -f network-policy.yaml

# 2. 使用 Ingress 认证
# 在 Ingress 配置中添加 Basic Auth 或 OAuth
```

---

## 10. 参考资料

### 官方文档

- [Rancher Manager 官方文档](https://ranchermanager.docs.rancher.com/zh)
- [安装要求文档](https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/installation-requirements)
- [高可用安装指南](https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster)
- [备份恢复指南](https://ranchermanager.docs.rancher.com/zh/how-to-guides/new-user-guides/backup-restore-and-disaster-recovery)
- [Rancher 中文文档](https://docs.rancher.cn/docs/rancher2.5/overview/)

### 版本兼容性

- [Rancher v2.9 支持矩阵](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-9/)
- [Kubernetes 版本兼容性](https://kubernetes.io/docs/setup/release/version-skew-policy/)
- [RKE2 文档](https://docs.rke2.io/)
- [K3s 文档](https://docs.k3s.io/)

### 相关工具

- [Helm 官方文档](https://helm.sh/docs/)
- [kubectl 命令参考](https://kubernetes.io/docs/reference/kubectl/)
- [containerd 文档](https://containerd.io/docs/)

### 社区资源

- [Rancher GitHub](https://github.com/rancher/rancher)
- [Rancher 论坛](https://forums.rancher.com/)
- [Rancher Slack](https://slack.rancher.io/)
- [Rancher Blog](https://www.rancher.com/blog/)

### 相关文档

> 📎 **参考**: [Sealos 部署文档](../sealos/README.md) - Sealos 是另一款 Kubernetes 集群管理工具
> 📎 **参考**: [Kubernetes 基础文档](https://kubernetes.io/zh/docs/home/) - Kubernetes 官方中文文档

---

**文档结束**

> 💡 **提示**: 如有问题或建议，请查阅 [Rancher 官方文档](https://ranchermanager.docs.rancher.com/zh) 或提交 Issue。
