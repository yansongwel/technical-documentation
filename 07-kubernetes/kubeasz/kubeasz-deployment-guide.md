# Kubeasz — 生产级 Kubernetes 集群部署指南

> **工具简介**：kubeasz 是基于 Ansible Playbook + 二进制方式部署的 Kubernetes 集群自动化工具，由 [easzlab](https://github.com/easzlab/kubeasz) 开源维护。它不依赖国内网络环境，支持离线安装，几乎可配置任意组件参数，并通过了 CNCF 一致性测试。

---

## 目录

1. [工具特性概览](#1-工具特性概览)
2. [支持的操作系统与版本对应关系](#2-支持的操作系统与版本对应关系)
3. [生产环境规划](#3-生产环境规划)
4. [安装方式一：外网环境（有互联网访问）](#4-安装方式一外网环境有互联网访问)
5. [安装方式二：内网离线环境（无互联网访问）](#5-安装方式二内网离线环境无互联网访问)
6. [集群关键配置说明](#6-集群关键配置说明)
7. [安装后验证](#7-安装后验证)
8. [集群日常运维](#8-集群日常运维)
9. [注意事项与特别说明](#9-注意事项与特别说明)

> 💡 **说明**：kubeasz 通过 Ansible Playbook 会自动完成所有节点的前置准备工作（关闭 swap、配置内核参数、同步时间、设置主机名等）。使用者只需完成 **SSH 免密登录配置**，其余优化项均由 kubeasz 内部 playbook 统一处理，无需手动干预。

---

## 1. 工具特性概览

| 特性         | 说明                                        |
|------------|-------------------------------------------|
| 部署方式     | Ansible Playbook + 二进制（无需翻墙）               |
| 支持架构     | `amd64` / `arm64`                         |
| 容器运行时   | containerd v1.7.x / v2.0.x / v2.1.x       |
| 网络插件     | Calico、Cilium、Flannel、Kube-OVN、Kube-Router |
| HA 支持     | Master 多节点高可用、etcd 三节点集群                  |
| 离线安装     | 支持完整离线包（包含二进制+镜像+系统包）                     |
| 多 OS 支持  | Ubuntu、CentOS/RHEL、Debian、Kylin、openEuler 等 |

---

## 2. 支持的操作系统与版本对应关系

### 2.1 支持的 Linux 操作系统

| 操作系统 | 支持版本 |
|---|---|
| Ubuntu | 16.04 / 18.04 / 20.04 / **22.04** ✅推荐 / 24.04 |
| CentOS / RHEL | 7 / 8 / **9** ✅推荐 |
| Rocky Linux | 8 / **9** ✅推荐 |
| Alma Linux | 8 / 9 |
| Debian | 10 / **11** ✅推荐 |
| Kylin Linux V10 | Tercel / Lance（国产信创） |
| openEuler | 22.03 LTS / 24.03 LTS（华为欧拉） |
| Alibaba Linux | 2.1903 / 3.2104 |
| Anolis OS | 8.x RHCK / 8.x ANCK |
| openSUSE Leap | 15.x |

> **⚠️ 生产环境推荐**：优先选择 Ubuntu 22.04 LTS 或 Rocky Linux 9，长期支持稳定，社区资源丰富。

### 2.2 kubeasz 与 Kubernetes 版本对应关系

> **‼️ 特别说明**：选择版本时，请根据 **业务对 K8s 版本的要求** 及 **所在公司的升级策略** 来锁定版本，不建议生产环境盲目追最新版。

| kubeasz 版本 | Kubernetes 版本 | 发布时间     | 推荐状态 |
|------------|---------------|----------|------|
| v3.6.1     | v1.27.x       | 2023-06  | 历史稳定 |
| v3.6.2     | v1.28.x       | 2023-09  | 历史稳定 |
| v3.6.3     | v1.29.x       | 2024-01  | 稳定   |
| v3.6.4     | v1.30.x       | 2024-05  | 稳定   |
| v3.6.5     | v1.31.x       | 2024-09  | 稳定   |
| v3.6.6     | v1.32.x       | 2025-01  | ✅ 推荐 |
| v3.6.7     | v1.33.x       | 2025-06  | 新版   |
| v3.6.8     | v1.34.x       | 2025-09  | 最新   |

**版本选择决策逻辑：**

```text
生产环境版本选择建议：

1. 如果您是新建集群（2025年）         → 选择 kubeasz v3.6.6 (K8s v1.32.x)
   理由：已稳定半年以上，bugfix 充分，社区生态同步完善

2. 如果您需要与现有集群保持兼容        → 选择与现有集群相同的大版本
   理由：避免 API 版本不兼容导致现有应用故障

3. 如果您有信创/国产化要求           → 联系厂商确认认证的 K8s 版本后再选择
   理由：部分信创 OS 需要特定内核的版本验证

4. 不推荐生产使用最新版（如 v1.34）    → 新版本往往 3~6 个月后才稳定
   理由：避免踩到新 API 弃用坑

查看最新版本：https://github.com/easzlab/kubeasz/releases
```

### 2.3 如何判断当前环境适合的版本

```bash
# 1. 检查当前操作系统版本
cat /etc/os-release

# 2. 检查内核版本（K8s 1.28+ 要求内核 ≥ 4.14，推荐 ≥ 5.10）
uname -r

# 3. 检查 CPU 架构
uname -m
# x86_64 → 选 amd64 版本
# aarch64 → 选 arm64 版本

# 4. 如果已有 K8s 集群，检查现有版本
kubectl version --short 2>/dev/null || echo "无现有集群"
```

---

## 3. 生产环境规划

### 3.1 集群架构规划

```
                        ┌─────────────────────────────────────────┐
                        │           负载均衡层 (LB)                 │
                        │   HAProxy / Nginx / 云 LB / VIP(keepalived)│
                        └─────────┬──────────────┬────────────────┘
                                  │              │
                       ┌──────────▼──┐    ┌──────▼──────────┐
                       │  Master-01  │    │   Master-02      │
                       │  (Control   │    │   (Control       │
                       │   Plane)    │    │    Plane)        │
                       └─────────────┘    └─────────────────-┘
                                  │              │
                       ┌──────────▼──────────────▼─────────┐
                       │          etcd 集群 (3节点)           │
                       │  etcd-01 / etcd-02 / etcd-03        │
                       └────────────────────────────────────┘
                                  │
                    ┌─────────────┼──────────────┐
                    │             │              │
           ┌────────▼──┐  ┌───────▼──┐  ┌───────▼──┐
           │  Worker-01 │  │ Worker-02│  │ Worker-03│
           │  (Node)    │  │ (Node)   │  │ (Node)   │
           └────────────┘  └──────────┘  └──────────┘
```

### 3.2 生产环境最低节点配置

| 节点角色 | 数量        | 最低配置             | 推荐配置              | 说明              |
|-------|-----------|------------------|-------------------|-----------------|
| 部署节点  | 1         | 2C4G             | 4C8G              | 运行 Ansible，可临时复用 Master |
| Master | **≥ 2**   | 4C8G / 50G SSD   | 8C16G / 100G SSD  | 生产至少2个，推荐3个     |
| etcd  | **≥ 3**   | 4C8G / 50G SSD   | 8C16G / 100G SSD  | 奇数节点，推荐独立部署     |
| Node  | **≥ 2**   | 8C16G / 100G SSD | 16C32G / 200G SSD | 按业务负载弹性扩展       |

> **⚠️ 注意**：etcd 对磁盘 I/O 性能极度敏感，**必须使用 SSD**，不可使用机械硬盘。

### 3.3 网络规划

```text
# 各网络 CIDR 必须不与现有网络冲突！根据实际情况修改

物理网络（主机 IP）   ：192.168.10.0/24  ← 根据您的实际环境调整
Pod 网络 CIDR       ：10.20.0.0/16     ← 容器间通信，不对外暴露
Service 网络 CIDR   ：10.100.0.0/16    ← K8s Service IP 范围
DNS Service IP     ：10.100.0.2       ← CoreDNS IP，需在 Service CIDR 内
```

---

## 4. 安装方式一：外网环境（有互联网访问）

> **适用场景**：部署节点可以访问 GitHub 和 Docker Hub（或已配置国内镜像加速）。

> ✅ **无需手动前置准备**：kubeasz 的 Ansible Playbook 会在部署阶段自动完成所有节点的初始化（关闭 swap、配置内核参数、SELinux、时区同步、主机名设置等）。您只需要提前配置好 **SSH 免密登录**，其余一切交给 kubeasz。

### 4.1 在部署节点安装 Docker

```bash
# ===========================
# 安装 Docker（kubeasz 的 ezdown 工具运行需要 Docker）
# ===========================

# Ubuntu 22.04
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker --now

# CentOS/Rocky Linux 9
yum install -y yum-utils
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker --now
```

### 4.3 配置 SSH 免密登录

```bash
# ===========================
# 在部署节点执行：生成 SSH 密钥
# ===========================
ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa

# 将公钥拷贝到所有节点（包括自身）
# ⚠️ 替换为实际 IP 列表
for ip in 192.168.10.10 192.168.10.11 192.168.10.20 192.168.10.21 192.168.10.22 192.168.10.30 192.168.10.31 192.168.10.32; do
    ssh-copy-id -i ~/.ssh/id_rsa.pub root@${ip}
done

# 验证免密登录
ssh root@192.168.10.10 hostname
```

### 4.4 下载 kubeasz 与组件

```bash
# ===========================
# 步骤 1：下载 ezdown 工具
# ===========================

# ⚠️ 根据您要部署的 K8s 版本选择对应的 kubeasz 版本
# 参考本文第 2.2 节版本对应关系表
export KUBEASZ_VER=3.6.6   # ← 根据需要修改，推荐生产使用此版本

mkdir -p /opt/kubeasz
cd /opt/kubeasz

# 下载 ezdown 脚本（如 GitHub 访问慢可用镜像站）
curl -fsSL https://github.com/easzlab/kubeasz/releases/download/${KUBEASZ_VER}/ezdown -o ezdown
chmod +x ezdown

# ===========================
# 步骤 2：下载 kubeasz 项目代码和所有二进制文件
# ===========================
# -D：下载默认 K8s 版本的所有组件（二进制 + 镜像）
./ezdown -D

# 或指定特定 K8s 版本：
# ./ezdown -D -k v1.32.3

# 下载完成后，检查文件
ls /etc/kubeasz/
# 预期输出：bin/ clusters/ docs/ example/ manifests/ playbooks/ roles/ ...

# ===========================
# 步骤 3（可选）：下载额外组件
# ===========================
./ezdown -X harbor   # 下载 Harbor 镜像仓库
./ezdown -X prometheus  # 下载 Prometheus 监控
./ezdown -X ingress-nginx  # 下载 Nginx Ingress
```

### 4.5 初始化集群配置

```bash
# ===========================
# 创建集群配置（以 k8s-prod 为集群名称示例）
# ===========================

# ⚠️ 集群名称请根据实际命名规范定义，全小写+连字符
export CLUSTER_NAME=k8s-prod   # ← 修改为您的集群名称

cd /etc/kubeasz
# 使用 ezctl 工具创建集群配置目录
./ezctl new ${CLUSTER_NAME}

# 配置文件位置：
# /etc/kubeasz/clusters/${CLUSTER_NAME}/hosts       ← 节点清单
# /etc/kubeasz/clusters/${CLUSTER_NAME}/config.yml  ← 集群参数
```

### 4.6 配置 hosts 节点清单

```bash
# 编辑节点清单文件
vi /etc/kubeasz/clusters/k8s-prod/hosts
```

节点清单示例（`hosts` 文件完整配置，格式参考 [官方 hosts.multi-node](https://github.com/easzlab/kubeasz/blob/master/example/hosts.multi-node)）：

```ini
# ==========================================================
# kubeasz 集群节点配置文件
# ⚠️ 所有 IP 地址请根据实际环境修改
# k8s_nodename 只能包含小写字母、数字、'-' 或 '.'，且必须以字母或数字开头/结尾
# ==========================================================

# ---- etcd 节点 ----
# 生产环境至少 3 个节点，使用奇数个节点（3/5/7）
[etcd]
192.168.10.20
192.168.10.21
192.168.10.22

# ---- Master 控制平面节点（为每个节点设置唯一 k8s_nodename）----
[kube_master]
192.168.10.10 k8s_nodename='master-01'
192.168.10.11 k8s_nodename='master-02'
192.168.10.12 k8s_nodename='master-03'

# ---- Worker 节点 ----
[kube_node]
192.168.10.30 k8s_nodename='worker-01'
192.168.10.31 k8s_nodename='worker-02'
192.168.10.32 k8s_nodename='worker-03'

# ---- Harbor 镜像仓库（可选）----
# NEW_INSTALL=true 表示由 kubeasz 安装 Harbor；false 表示使用已有 Harbor
[harbor]
#192.168.10.50 NEW_INSTALL=false

# ---- 外部负载均衡（可选）----
# kubeasz 会自动在 ex_lb 节点部署 HAProxy + Keepalived 实现高可用
# EX_APISERVER_VIP：多个 LB 节点共享的 VIP 地址（Keepalived 漂移 IP）
# LB_ROLE=master：VIP 主节点；LB_ROLE=backup：VIP 备节点
[ex_lb]
#192.168.10.60 LB_ROLE=backup EX_APISERVER_VIP=192.168.10.100 EX_APISERVER_PORT=8443
#192.168.10.61 LB_ROLE=master EX_APISERVER_VIP=192.168.10.100 EX_APISERVER_PORT=8443

# ---- NTP 时间服务器（可选，kubeasz 自动配置 chrony）----
[chrony]
#192.168.10.10

# ---- 全局变量 ----
[all:vars]
# API Server 安全端口
SECURE_PORT="6443"

# 容器运行时：containerd（K8s >= 1.24 已不支持 Docker）
CONTAINER_RUNTIME="containerd"

# 网络插件：calico / flannel / cilium / kube-ovn / kube-router
CLUSTER_NETWORK="calico"

# kube-proxy 模式：ipvs（推荐）或 iptables
PROXY_MODE="ipvs"

# Service CIDR（不能与主机网络重叠）
SERVICE_CIDR="10.68.0.0/16"

# Pod CIDR（不能与主机网络和 Service CIDR 重叠）
CLUSTER_CIDR="172.20.0.0/16"

# NodePort 范围
NODE_PORT_RANGE="30000-32767"

# 集群 DNS 域
CLUSTER_DNS_DOMAIN="cluster.local"

# 以下变量通常保持默认，无需修改
bin_dir="/opt/kube/bin"
base_dir="/etc/kubeasz"
ca_dir="/etc/kubernetes/ssl"
k8s_nodename=''
ansible_python_interpreter=/usr/bin/python3
```

> **⚠️ 高可用说明**：如需 Master 高可用，只需在 `[ex_lb]` 中配置 LB 节点 IP 和 VIP，kubeasz 会自动在这些节点上部署 **HAProxy + Keepalived**，无需手动安装配置。

---

## 5. 安装方式二：内网离线环境（无互联网访问）

> **适用场景**：生产内网环境，节点无法访问互联网，需要完整离线包。

### 5.1 离线安装整体流程

```
[有网络的跳板机]                         [内网生产环境]
      │                                        │
      │ 1. 下载 kubeasz 离线包                  │
      │    ./ezdown -D                         │
      │    ./ezdown -S（打包）                  │
      │                                        │
      ├────── 2. 传输离线包 ──────────────────→│
      │       scp / U盘 / 内网 FTP              │
      │                                        │
      │                                 3. 解压并安装
      │                                 4. 配置并部署
```

### 5.2 在跳板机（有网络）准备离线包

```bash
# ===========================
# 在跳板机上执行（需安装 Docker）
# ===========================

export KUBEASZ_VER=3.6.6

mkdir -p /opt/kubeasz-offline
cd /opt/kubeasz-offline

# 下载 ezdown
curl -fsSL https://github.com/easzlab/kubeasz/releases/download/${KUBEASZ_VER}/ezdown -o ezdown
chmod +x ezdown

# 下载所有组件（二进制 + 容器镜像 + kubeasz 代码）
# 这一步会下载几 GB 的内容，需要保持网络畅通
./ezdown -D

# ⚠️ 如需指定 K8s 版本：./ezdown -D -k v1.32.3

# 下载额外组件（按需选择）
./ezdown -X harbor         # Harbor 镜像仓库
./ezdown -X prometheus     # Prometheus 监控
./ezdown -X ingress-nginx  # Nginx Ingress Controller
./ezdown -X nfs-provisioner  # NFS 动态存储

# 打包成完整离线安装包（-S 表示 Package）
./ezdown -S
# 打包完成后会生成 /opt/kubeasz-offline/kubeasz_${KUBEASZ_VER}.tar.gz

# 查看生成的离线包
ls -lh /opt/kubeasz-offline/
```

### 5.3 将离线包传输到内网

```bash
# 方式 A：通过 SCP 传输（如果跳板机与内网互通）
scp /opt/kubeasz-offline/kubeasz_3.6.6.tar.gz root@192.168.10.10:/opt/

# 方式 B：通过内网文件服务器（推荐大文件）
# 1. 上传到内网 FTP/HTTP 服务器
# 2. 在部署节点下载：
#    wget http://192.168.10.200/packages/kubeasz_3.6.6.tar.gz -P /opt/

# 方式 C：U 盘物理传输（完全隔离内网）
# 拷贝离线包到 U 盘，插入部署节点后挂载并复制

# ===========================
# 以下步骤在内网部署节点执行
# ===========================
mkdir -p /opt/kubeasz-offline
tar -xzf /opt/kubeasz_3.6.6.tar.gz -C /opt/kubeasz-offline/

# 加载 Docker 镜像（kubeasz ezdown依赖的工具镜像）
docker load -i /opt/kubeasz-offline/down/kubeasz-*.tar
```

### 5.4 内网部署节点安装 Docker（离线）

```bash
# ===========================
# 如果内网部署节点没有 Docker，需要离线安装
# ===========================
# 从离线包中安装系统依赖（kubeasz 离线包含系统软件包）

# Ubuntu 22.04 离线安装 Docker
cd /opt/kubeasz-offline/down/packages/
apt-get install -y --no-install-recommends \
    ./docker-ce_*.deb \
    ./docker-ce-cli_*.deb \
    ./containerd.io_*.deb

systemctl enable docker --now

# CentOS/Rocky Linux 9 离线安装
yum localinstall -y docker-ce-*.rpm docker-ce-cli-*.rpm containerd.io-*.rpm
systemctl enable docker --now
```

### 5.5 内网配置私有镜像仓库（Harbor）

> **‼️ 特别说明**：生产内网环境强烈建议提前搭建 Harbor 私有镜像仓库，所有组件镜像从内网拉取，避免对外网的任何依赖。

```bash
# ===========================
# 配置 Docker 使用内网 Harbor（部署节点 + 所有 K8s 节点）
# ===========================
# ⚠️ 替换 192.168.10.50 为您实际的 Harbor 地址

cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://192.168.10.50"],   # ← 使用内网 Harbor 加速
  "insecure-registries": ["192.168.10.50:80"],       # ← 如使用 HTTP 协议需配置
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker
```

### 5.6 启动离线部署

```bash
# ===========================
# 在内网部署节点执行（与外网安装步骤一致，但使用本地离线包）
# ===========================

# 运行 kubeasz 容器（ezdown 已打包好的工具镜像）
cd /opt/kubeasz-offline
./ezdown -S -i     # -i 表示使用离线模式

# 初始化集群配置
cd /etc/kubeasz
./ezctl new k8s-prod

# 编辑 hosts 和 config.yml（参考第 4.6 节）
vi /etc/kubeasz/clusters/k8s-prod/hosts
vi /etc/kubeasz/clusters/k8s-prod/config.yml

# 开始部署
./ezctl setup k8s-prod all
```

---

## 6. 集群关键配置说明

### 6.1 `config.yml` 参数详解

```bash
# 打开配置文件
vi /etc/kubeasz/clusters/k8s-prod/config.yml
```

以下是关键配置注释版本（完整配置参考 [官方 config.yml](https://github.com/easzlab/kubeasz/blob/master/example/config.yml)）：

```yaml
# ===========================================================
# kubeasz 集群核心配置文件
# 文件路径：/etc/kubeasz/clusters/<集群名>/config.yml
# ⚠️ CIDR 范围一旦设定不可随意更改（影响运行中的 Pod）
# ===========================================================

############################
# role:deploy — 部署基础配置
############################
# 离线/在线安装系统软件包
INSTALL_SOURCE: "online"        # 有网络时用 online；内网离线时用 offline

# CA 根证书有效期（默认100年）
CA_EXPIRY: "876000h"
# 组件证书有效期（默认50年）
CERT_EXPIRY: "438000h"

# 是否强制重建 CA（生产环境不建议设为 true）
CHANGE_CA: false

# kubeconfig 中的集群名和 context 名
CLUSTER_NAME: "cluster1"
CONTEXT_NAME: "context-{{ CLUSTER_NAME }}"

# 是否由 kubeasz 自动设置主机名（推荐开启，读取 k8s_nodename）
ENABLE_SETTING_HOSTNAME: true


############################
# role:etcd — etcd 数据存储
############################
# etcd 数据目录（推荐使用 SSD 单独分区）
ETCD_DATA_DIR: "/var/lib/etcd"
# etcd WAL 目录（设置独立路径可避免磁盘 IO 竞争，提高性能）
ETCD_WAL_DIR: ""                # 留空则与 ETCD_DATA_DIR 同路径


############################
# role:runtime — 容器运行时
############################
# 是否启用镜像加速仓库
ENABLE_MIRROR_REGISTRY: true

# 私有/不安全仓库地址（协议头不能省略）
INSECURE_REG:
  - "http://easzlab.io.local:5000"
  - "https://reg.yourcompany.com"

# pause 基础镜像（内网环境替换为内部镜像仓库地址）
SANDBOX_IMAGE: "easzlab.io.local:5000/easzlab/pause:3.9"

# containerd 存储目录（推荐挂载独立大容量数据盘）
CONTAINERD_ROOT_DIR: "/var/lib/containerd"
CONTAINERD_STATE_DIR: "/run/containerd"
CONTAINERD_CONFIG_DIR: "/etc/containerd"
CONTAINERD_SERVICE_NAME: "containerd.service"


############################
# role:kube-master — 控制面
############################
# ★ Master 节点证书 SAN（可添加多个 IP 和域名）
# 必须包含 LB VIP、所有 Master IP、域名（如有）
MASTER_CERT_HOSTS:
  - "10.1.1.1"                  # ← 替换为你的 LB VIP
  - "k8s.yourcompany.com"       # ← 替换为你的 API Server 域名（可选）

# 每个 Node 的 Pod CIDR 块长度（/24 表示每个节点最多 254 个 Pod）
NODE_CIDR_LEN: 24

# 是否启用 API Server Audit 审计日志（生产建议开启）
ENABLE_CLUSTER_AUDIT: false


############################
# role:kube-node — 工作节点
############################
# kubelet 根目录（建议指向大容量数据盘）
KUBELET_ROOT_DIR: "/var/lib/kubelet"

# 每个节点最大 Pod 数量
MAX_PODS: 110

# 是否为 K8s 组件预留系统资源（生产建议开启）
KUBE_RESERVED_ENABLED: "no"    # 建议改为 yes，并配置具体预留值
SYS_RESERVED_ENABLED: "no"     # 建议改为 yes，防止系统资源耗尽


############################
# role:network — 网络插件
############################
# ★ 选择网络插件：calico / flannel / cilium / kube-ovn / kube-router
# 生产推荐 calico（策略丰富）或 cilium（eBPF 高性能，须内核 ≥ 5.10）
CLUSTER_NETWORK: "calico"  # 在 hosts 文件 [all:vars] 中设置，此处仅说明

# [calico] host IP 自动发现方式（可手工指定 IP 或用 can-reach 自动发现）
IP_AUTODETECTION_METHOD: "can-reach={{ groups['kube_master'][0] }}"

# [calico] 网络封装模式（公有云/不支持 BGP 时用 vxlan；自有机房用 bird）
CALICO_NETWORKING_BACKEND: "bird"

# [calico] 是否启用 Route Reflector（集群规模 > 50 节点时建议开启）
CALICO_RR_ENABLED: false
# CALICO_RR_NODES: ["192.168.1.1", "192.168.1.2"]
CALICO_RR_NODES: []

# [cilium] 版本及可观测性开关
cilium_connectivity_check: false
cilium_hubble_enabled: false
cilium_hubble_ui_enabled: false
```

### 6.2 网络插件选择对比

| 网络插件 | 性能 | NetworkPolicy | BGP | 要求内核 | 适用场景 |
|---|---|---|---|---|---|
| **Calico** | ⭐⭐⭐⭐ | ✅ 支持 | ✅ 支持 | ≥ 3.10 | **推荐**，适合大多数生产场景 |
| **Cilium** | ⭐⭐⭐⭐⭐ | ✅ 丰富 | ✅ 支持 | **≥ 5.10** | 高性能场景，基于 eBPF |
| **Flannel** | ⭐⭐⭐ | ❌ 不支持 | ❌ | ≥ 3.10 | 简单测试 / 小集群 |
| **Kube-OVN** | ⭐⭐⭐⭐ | ✅ 支持 | ✅ | ≥ 3.10 | 多租户、SDN场景 |

### 6.3 高可用方案说明

> ✅ **kubeasz 原生支持 HA，无需手动安装 HAProxy / Keepalived。**

kubeasz 在检测到 `[ex_lb]` 组不为空时，会**自动在指定 LB 节点上部署 HAProxy + Keepalived**，只需在 `hosts` 文件中配置节点和 VIP 即可。

**配置方法**（在 `hosts` 文件中修改 `[ex_lb]` 组）：

```ini
# 双节点 HA LB 示例（一主一备，自动 VIP 漂移）
[ex_lb]
192.168.10.60 LB_ROLE=backup EX_APISERVER_VIP=192.168.10.100 EX_APISERVER_PORT=8443
192.168.10.61 LB_ROLE=master EX_APISERVER_VIP=192.168.10.100 EX_APISERVER_PORT=8443
```

| 参数 | 说明 |
|------|------|
| `LB_ROLE=master` | VIP 主节点，Keepalived `state MASTER`，优先级更高 |
| `LB_ROLE=backup` | VIP 备节点，Keepalived `state BACKUP` |
| `EX_APISERVER_VIP` | 多个 LB 节点共享的虚拟 IP（VIP），所有 K8s 节点通过此 IP 访问 API Server |
| `EX_APISERVER_PORT` | HAProxy 监听端口，内网可保持 `8443`，避免与 API Server `6443` 冲突 |

配置完成后，kubeasz 在 `setup all` 阶段会自动完成 HAProxy 和 Keepalived 的安装与配置。

参考：[官方 hosts.multi-node](https://github.com/easzlab/kubeasz/blob/master/example/hosts.multi-node)

---

## 7. 安装后验证

### 7.1 执行安装命令

```bash
# ===========================
# 开始一键安装（在部署节点执行）
# ===========================
cd /etc/kubeasz

# 完整安装（推荐）
./ezctl setup k8s-prod all

# 或分步安装（适合排错）：
./ezctl setup k8s-prod 01  # 基础准备
./ezctl setup k8s-prod 02  # 安装 etcd
./ezctl setup k8s-prod 03  # 安装容器运行时
./ezctl setup k8s-prod 04  # 安装 Master
./ezctl setup k8s-prod 05  # 安装 Node
./ezctl setup k8s-prod 06  # 安装网络插件
./ezctl setup k8s-prod 07  # 安装集群插件
```

### 7.2 验证集群状态

```bash
# ===========================
# 安装完成后，在 Master 节点验证
# ===========================

# 查看节点状态（所有节点应为 Ready）
kubectl get nodes -o wide

# 预期输出：
# NAME        STATUS   ROLES          AGE   VERSION   INTERNAL-IP
# master-01   Ready    control-plane  5m    v1.32.3   192.168.10.10
# master-02   Ready    control-plane  5m    v1.32.3   192.168.10.11
# node-01     Ready    <none>         3m    v1.32.3   192.168.10.30
# node-02     Ready    <none>         3m    v1.32.3   192.168.10.31
# node-03     Ready    <none>         3m    v1.32.3   192.168.10.32

# 查看系统 Pod 状态（所有 Pod 应为 Running）
kubectl get pods -n kube-system

# 查看集群整体信息
kubectl cluster-info

# 验证 etcd 集群健康
etcdctl endpoint health \
    --endpoints=https://192.168.10.20:2379,https://192.168.10.21:2379,https://192.168.10.22:2379 \
    --cacert=/etc/kubernetes/ssl/ca.pem \
    --cert=/etc/etcd/ssl/etcd.pem \
    --key=/etc/etcd/ssl/etcd-key.pem

# 部署测试应用验证网络
kubectl create deployment test-nginx --image=nginx:alpine --replicas=3
kubectl expose deployment test-nginx --port=80 --type=NodePort
kubectl get pods -o wide    # 查看 Pod 分布
kubectl get svc test-nginx  # 查看 NodePort 端口
curl http://192.168.10.30:<NodePort>  # 访问测试

# 清理测试资源
kubectl delete deployment test-nginx
kubectl delete svc test-nginx
```

---

## 8. 集群日常运维

### 8.1 扩容 Worker 节点

```bash
# 在 /etc/hosts 和 hosts 文件中添加新节点 IP 后执行：
./ezctl add-node k8s-prod 192.168.10.33
```

### 8.2 扩容 Master 节点

```bash
./ezctl add-master k8s-prod 192.168.10.12
```

### 8.3 集群升级

```bash
# 升级前务必备份 etcd 数据！
./ezctl upgrade k8s-prod
```

### 8.4 etcd 备份与恢复

> kubeasz 提供了内置的 etcd 备份与恢复命令，通过 Ansible Playbook 统一管理，无需手动调用 `etcdctl`。
> 参考文档：[cluster_restore.md](https://github.com/easzlab/kubeasz/blob/master/docs/op/cluster_restore.md)

#### 备份集群（快照 etcd 数据）

```bash
# 方式一：使用 ezctl 命令（推荐）
cd /etc/kubeasz
./ezctl backup k8s-prod

# 方式二：手动执行等效的 ansible-playbook
ansible-playbook -i clusters/k8s-prod/hosts \
    -e @clusters/k8s-prod/config.yml \
    playbooks/94.backup.yml
```

备份文件默认存储在部署节点的以下目录：

```
/etc/kubeasz/clusters/k8s-prod/backup/
├── snapshot_20260301120000.db   # 每次备份自动生成，文件名含时间戳
├── snapshot_20260302140000.db
└── snapshot.db                  # 始终指向最近一次备份（会被覆盖）
```

> 💡 **生产建议**：将备份目录挂载到独立存储（如 NFS/OSS），并配置 crontab 定期自动备份：

```bash
# 每天凌晨 2 点自动备份
echo "0 2 * * * root cd /etc/kubeasz && ./ezctl backup k8s-prod >> /var/log/kubeasz-backup.log 2>&1" \
    > /etc/cron.d/kubeasz-backup
```

#### 恢复集群（从备份快照还原）

```bash
# 可在 roles/cluster-restore/defaults/main.yml 中指定要恢复的快照版本
# 默认使用最近一次备份（snapshot.db）

# 方式一：使用 ezctl 命令（推荐）
cd /etc/kubeasz
./ezctl restore k8s-prod

# 方式二：手动执行等效的 ansible-playbook
ansible-playbook -i clusters/k8s-prod/hosts \
    -e @clusters/k8s-prod/config.yml \
    playbooks/95.restore.yml
```

#### 集群严重故障时的完整恢复流程

若 master/etcd/node 等组件出现不可恢复的问题，可按以下步骤重建并恢复：

```bash
# 步骤 1：清理损坏集群
./ezctl clean k8s-prod
# 等效：ansible-playbook -i clusters/k8s-prod/hosts -e @clusters/k8s-prod/config.yml playbooks/99.clean.yml

# 步骤 2：重新安装各组件（按顺序执行）
./ezctl setup k8s-prod 01   # 基础准备
./ezctl setup k8s-prod 02   # 安装 etcd
./ezctl setup k8s-prod 03   # 安装容器运行时
./ezctl setup k8s-prod 04   # 安装 Master
./ezctl setup k8s-prod 05   # 安装 Node
# ... 继续其余步骤

# 步骤 3：从备份快照恢复数据
./ezctl restore k8s-prod
```

> ⚠️ **注意**：恢复完成后需等待一段时间，让 K8s 的 Pod / Service 等资源重建完毕，再验证集群状态。

---

## 9. 注意事项与特别说明

### ⚠️ 生产环境必读清单

#### 9.1 安装前检查

```bash
# 必须检查项（安装前在所有节点执行）：

# ① swap 是否关闭
free -h  # Swap 行应全为 0

# ② SELinux 是否关闭（RHEL系）
getenforce  # 应输出 Disabled

# ③ 时间同步是否正常（误差 > 2秒会导致 etcd 异常）
chronyc tracking | grep "System time"
# 节点间时间对比：
ssh 192.168.10.11 date && date

# ④ 内核参数是否满足
sysctl net.bridge.bridge-nf-call-iptables  # 应为 1
sysctl net.ipv4.ip_forward               # 应为 1

# ⑤ 端口是否被占用
ss -tlnp | grep -E "6443|2379|2380|10250|10251|10252"
# 所有端口应无占用

# ⑥ 磁盘空间（etcd 节点 /var/lib 至少 20GB 可用）
df -h /var/lib
```

#### 9.2 网络 CIDR 规划注意事项

> **‼️ 特别说明**：以下是生产环境最常见的 CIDR 冲突问题，安装前必须确认！

```text
❌ 常见错误配置（导致网络不通）：

场景：公司内网使用 10.0.0.0/8 网段，而 CLUSTER_CIDR 也配置为 10.20.0.0/16
→ Pod CIDR 与内网网段重叠，Pod 之间及 Pod 与内网主机通信将异常！

✅ 正确做法：

1. 先确认公司内网已使用的 IP 段
   ip route show && cat /etc/network/interfaces

2. 避开已用网段来规划 CIDR：
   - 如果内网是 192.168.0.0/16：
     Pod CIDR 可用 10.20.0.0/16，Service CIDR 用 10.100.0.0/16
   - 如果内网是 10.0.0.0/8：
     Pod CIDR 可用 172.20.0.0/16，Service CIDR 用 172.30.0.0/16
```

#### 9.3 证书相关注意事项

```text
‼️ 证书 SAN（Subject Alternative Name）必须包含以下所有访问方式：

✅ 必须包含：
   - 所有 Master 节点 IP（192.168.10.10，192.168.10.11...）
   - LB/VIP IP（192.168.10.100）
   - Kubernetes Service IP（10.100.0.1）
   - localhost / 127.0.0.1
   - 如有域名，也需加入（如 k8s.yourcompany.com）

❌ 如果遗漏：
   - kubectl 连接时报 "x509: certificate is valid for..."
   - 解决方案：需要重新生成证书（kubeasz 支持 ./ezctl rebuild-ca k8s-prod）
```

#### 9.4 etcd 常见问题

```text
问题 1：etcd 启动失败，日志报 "request cluster ID mismatch"
原因：etcd 数据目录存在旧数据
解决：rm -rf /var/lib/etcd/member && systemctl restart etcd
      ⚠️ 非新集群初始化时执行此操作前必须先备份！

问题 2：etcd 集群性能下降，日志频繁报 "apply entries took too long"
原因：磁盘 I/O 不足（使用了机械硬盘）
解决：更换为 SSD，或给 etcd 进程提高 I/O 优先级
      ionice -c2 -n0 -p $(pgrep etcd)

问题 3：etcd 集群数据量持续增长（默认上限 2GB）
原因：K8s 会频繁写入资源状态，需要定期压缩
解决：配置自动压缩 --auto-compaction-retention=1  # 保留1小时历史
```

#### 9.5 生产环境安全加固建议

```bash
# ① 限制 API Server 只监听内网 IP（不对公网暴露）
# 在 config.yml 中配置：
# APISERVER_EXTRA_ARGS:
#   bind-address: "192.168.10.10"  # 只绑定内网 IP

# ② 启用 RBAC（kubeasz 默认启用，无需额外配置）

# ③ 禁用匿名访问
# APISERVER_EXTRA_ARGS:
#   anonymous-auth: "false"

# ④ 定期轮换证书（建议加入运维日历）
./ezctl renew-certs k8s-prod    # 重新签发证书（需要重启相关组件）

# ⑤ 配置 Pod 安全策略（K8s 1.25+ 使用 Pod Security Admission）
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
```

#### 9.6 常用故障排查命令

```bash
# 查看 kubelet 日志
journalctl -u kubelet -n 100 --no-pager

# 查看 kube-apiserver 日志
journalctl -u kube-apiserver -n 100 --no-pager

# 查看 etcd 日志
journalctl -u etcd -n 100 --no-pager

# 查看 containerd 日志
journalctl -u containerd -n 100 --no-pager

# 查看某 Pod 的容器日志
kubectl logs -n kube-system <pod-name> --previous  # --previous 查看崩溃前日志

# 查看节点资源使用情况（需 metrics-server）
kubectl top nodes
kubectl top pods -A

# 检查节点网络连通性
kubectl run -it --rm test-net --image=busybox --restart=Never -- sh
# 在 Pod 内测试 DNS：nslookup kubernetes.default
# 在 Pod 内测试连通性：wget -O- http://<target-service>
```

---

## 附录

### A. 快速参考命令

```bash
# 集群管理命令（在部署节点执行）
./ezctl                        # 查看所有命令
./ezctl list                   # 列出所有集群
./ezctl new k8s-prod           # 创建新集群配置
./ezctl setup k8s-prod all     # 全量安装
./ezctl add-node k8s-prod <IP> # 添加 Worker 节点
./ezctl add-master k8s-prod <IP> # 添加 Master 节点
./ezctl del-node k8s-prod <IP>  # 删除 Worker 节点
./ezctl upgrade k8s-prod       # 升级集群
./ezctl backup k8s-prod        # 备份集群
./ezctl restore k8s-prod       # 恢复集群
```

### B. 参考链接

| 资源 | 链接 |
|---|---|
| kubeasz GitHub | https://github.com/easzlab/kubeasz |
| 官方离线安装文档 | https://github.com/easzlab/kubeasz/blob/master/docs/setup/offline_install.md |
| 集群规划文档 | https://github.com/easzlab/kubeasz/blob/master/docs/setup/00-planning_and_overall_intro.md |
| 网络插件配置 | https://github.com/easzlab/kubeasz/tree/master/docs/setup/network-plugin |
| 版本发布列表 | https://github.com/easzlab/kubeasz/releases |
| K8s 版本策略 | https://kubernetes.io/zh-cn/releases/version-skew-policy/ |
