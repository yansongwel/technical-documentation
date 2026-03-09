# Rancher 企业级容器管理平台技术文档

**版本**：v1.0  
**状态**：发布  
**维护者**：SRE 团队  
**最后更新**：2026-03-09

---

## 1. 简介

### 1.1 服务介绍与核心特性

Rancher 是一个开源的企业级 Kubernetes 管理平台，旨在简化 Kubernetes 集群的部署、管理和操作。它提供了一个统一的控制平面，允许运维人员从单一界面管理运行在任何基础设施（裸机、私有云、公有云或边缘）上的多个 Kubernetes 集群。

**核心特性：**
*   **多集群统一管理**：集中管理 EKS, AKS, GKE 及自建 K8s 集群。
*   **统一身份认证**：集成 AD/LDAP/OIDC，实现全局 RBAC 策略。
*   **极简部署与运维**：通过 RKE/RKE2 快速构建符合 CIS 标准的 K8s 集群。
*   **应用商店**：内置 Helm Chart 市场，一键部署监控、日志、DevOps 工具链。
*   **混合云支持**：纳管任何位置的 Kubernetes 集群。

### 1.2 适用场景

*   **混合云/多云管理**：企业同时使用 AWS, Azure 和本地数据中心，需要统一视图。
*   **大规模集群运维**：需要批量升级、备份、巡检数百个 K8s 集群。
*   **DevSecOps 落地**：为开发团队提供自助式 K8s 环境，同时保持安全合规。

### 1.3 架构原理图

```mermaid
graph TD
    User[运维/开发人员] -->|HTTPS/443| LB[外部负载均衡器]
    LB -->|Forward| R1[Rancher Node 1]
    LB -->|Forward| R2[Rancher Node 2]
    LB -->|Forward| R3[Rancher Node 3]
    
    subgraph "Rancher Management Cluster (Local)"
        R1 <-->|Etcd/K8s API| R2
        R2 <-->|Etcd/K8s API| R3
        R1 <-->|Etcd/K8s API| R3
    end
    
    R1 -->|Cattle Agent Tunnel| Downstream1[下游集群 A (EKS)]
    R2 -->|Cattle Agent Tunnel| Downstream2[下游集群 B (On-Prem)]
    
    style LB fill:#f9f,stroke:#333
```

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| 组件 | 推荐版本 | 说明 |
| :--- | :--- | :--- |
| **Rancher** | `v2.8.x` (Stable) | 生产环境推荐 Stable 分支，稳定性优先。 |
| **Kubernetes** | `v1.27.x` - `v1.28.x` | 运行 Rancher 的底层集群版本，需参考官方支持矩阵。 |
| **Helm** | `v3.12+` | 必须使用 Helm 3。 |
| **RKE2** | `v1.28.x+rke2r1` | 推荐使用 RKE2 (Rancher Kubernetes Engine 2) 作为底层集群。 |
| **Cert-Manager** | `v1.12.x` | 用于管理 Rancher 的 SSL 证书。 |

### 2.2 版本决策建议

*   **Rancher 版本**：始终选择官方标记为 **Stable** 的最新小版本（如 v2.8.5），避免使用 Prime（商业版）或 Alpha/rc 版本，除非有明确测试需求。
*   **Kubernetes 版本**：Local 集群（运行 Rancher 的集群）不需要追求最新 K8s，**稳定性第一**。建议使用 RKE2 默认推荐的 K8s 版本。
*   **操作系统**：Rancher 对 OS 兼容性较好，Rocky Linux 9 和 Ubuntu 22.04 均为一级支持 OS。

---

## 3. 生产环境规划（高可用架构）

**⚠️ 警告**：生产环境**严禁**使用 `docker run rancher/rancher` 单节点启动。必须将其安装在**高可用 Kubernetes 集群**上。

### 3.1 集群架构图

```text
       +-------------------------+
       |   Load Balancer (L4)    |  <-- 10.0.0.100 (VIP/DNS: rancher.example.com)
       +------------+------------+
                    | (TCP 80/443)
      +-------------+-------------+
      |             |             |
+-----+-----+ +-----+-----+ +-----+-----+
|  Node 01  | |  Node 02  | |  Node 03  |  <-- RKE2 Cluster (Local)
| 10.0.0.11 | | 10.0.0.12 | | 10.0.0.13 |
| (Etcd+CP) | | (Etcd+CP) | | (Etcd+CP) |
+-----------+ +-----------+ +-----------+
```

### 3.2 节点角色与配置要求

| 角色 | 数量 | 最低配置 | 推荐配置 | 磁盘 |
| :--- | :--- | :--- | :--- | :--- |
| **Rancher Server** | 3 | 4C / 8G | 8C / 16G | 100G SSD (Etcd 性能敏感) |
| **Load Balancer** | 2 (主备) | 2C / 4G | 4C / 8G | - |

### 3.3 网络与端口规划

*   **入站规则**：
    *   TCP 80, 443: 负载均衡器 -> Rancher Nodes (Ingress)。
    *   TCP 6443: Kubernetes API Server (管理端访问)。
    *   TCP 9345: RKE2 节点注册端口。
*   **节点间互通**：所有节点需互通内网端口 (2379, 2380, 10250 等)。
*   **DNS**：必须配置一个可解析的域名（如 `rancher.mycompany.com`）指向 LB VIP。

---

## 4. 生产环境部署

本指南采用 **RKE2** (轻量级、安全合规的 K8s 发行版) 部署底层集群，再通过 **Helm** 安装 Rancher。

### 4.1 前置准备（所有节点）

1.  **主机名设置**：确保唯一且符合 DNS 规范。
2.  **时间同步**：配置 Chrony/NTP。
3.  **关闭 Swap**：Kubernetes 强制要求。

### 4.2 [Rocky Linux 9 部署步骤]

```bash
# ── Rocky Linux 9 ──────────────────────────
# 1. 关闭防火墙
systemctl stop firewalld && systemctl disable firewalld

# 2. 禁用 SELinux (RKE2 支持 SELinux，但建议初次部署设为 Permissive 减少排错复杂度)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 3. 安装依赖工具
dnf install -y curl wget git container-selinux

# 4. 关闭 Swap
swapoff -a
sed -i '/swap/d' /etc/fstab
```

### 4.3 [Ubuntu 22.04 部署步骤]

```bash
# ── Ubuntu 22.04 ───────────────────────────
# 1. 关闭防火墙
ufw disable

# 2. 安装依赖工具
apt-get update
apt-get install -y curl wget git

# 3. 关闭 Swap
swapoff -a
sed -i '/swap/d' /etc/fstab
```

### 4.4 集群初始化与配置 (RKE2 + Rancher)

**Step 1: 安装 RKE2 (第一个节点)**

```bash
# 创建 RKE2 配置文件
mkdir -p /etc/rancher/rke2
cat >> /etc/rancher/rke2/config.yaml << 'EOF'
# ★ 必须设置：用于节点加入的 Token
token: "my-shared-secret-token"   # ← ⚠️ 生产环境请生成随机复杂字符串
tls-san:
  - "rancher.example.com"         # ← ⚠️ 修改为你的 Rancher 域名
  - "10.0.0.100"                  # ← ⚠️ 修改为 LB VIP
EOF

# 安装并启动 RKE2 Server
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server --now

# 配置 kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
/var/lib/rancher/rke2/bin/kubectl get nodes
```

**Step 2: 加入其他 Master 节点**

在 Node 2 和 Node 3 执行：

```bash
mkdir -p /etc/rancher/rke2
cat >> /etc/rancher/rke2/config.yaml << 'EOF'
server: https://10.0.0.11:9345    # ← ⚠️ 修改为第一个节点的 IP
token: "my-shared-secret-token"   # ← 必须与第一台一致
tls-san:
  - "rancher.example.com"
EOF

curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server --now
```

**Step 3: 安装 Helm 与 Cert-Manager**

```bash
# 安装 Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 安装 Cert-Manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# 验证 Pod 状态
kubectl get pods -n cert-manager
```

**Step 4: 使用 Helm 安装 Rancher**

```bash
# 添加 Rancher 仓库
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# 创建 Namespace
kubectl create namespace cattle-system

# ★ 安装 Rancher (SSL 终止在 Rancher 自身)
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \   # ★ ← 必须修改为实际域名
  --set bootstrapPassword=admin          # ★ ← 设置初始密码
```

### 4.5 安装验证

执行以下命令检查部署状态：

```bash
# 1. 检查 Rancher Deployment
kubectl -n cattle-system rollout status deploy/rancher
# 预期输出：deployment "rancher" successfully rolled out

# 2. 检查 Ingress
kubectl get ingress -n cattle-system
# 预期输出：ADDRESS 列应有 IP，HOSTS 列应为配置的域名

# 3. 浏览器访问
# 打开 https://rancher.example.com，应看到登录界面
```

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解 (`values.yaml`)

虽然我们使用了命令行参数安装，但建议将配置固化为 `values.yaml` 以便后续升级。

```bash
cat >> rancher-values.yaml << 'EOF'
# Rancher 域名
hostname: rancher.example.com  # ★

# 副本数 (高可用必须 >= 3)
replicas: 3                    # ★

# Ingress 配置
ingress:
  tls:
    source: rancher            # 使用 Cert-Manager 生成自签名证书 (生产推荐 'secret' 并自行导入证书)
  extraAnnotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"

# 资源限制 (生产环境建议设置)
resources:
  requests:
    cpu: 200m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
EOF
```

### 5.2 生产环境推荐调优参数

建议在 RKE2 配置中开启 Etcd 快照保留策略：

```bash
cat >> /etc/rancher/rke2/config.yaml << 'EOF'
# Etcd 快照配置
etcd-snapshot-schedule-cron: "0 */4 * * *"  # 每4小时备份一次
etcd-snapshot-retention: 24                 # 保留最近24份
EOF
```

---

## 6. 开发/测试环境快速部署（Docker Compose）

**⚠️ 警告**：Docker Compose 方式仅限个人开发测试，不可用于生产！生产环境数据丢失风险极高。

### 6.1 Docker Compose 部署（单机）

```bash
cat >> docker-compose.yml << 'EOF'
version: '3'
services:
  rancher:
    image: rancher/rancher:v2.8.5
    container_name: rancher
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    privileged: true
    volumes:
      - ./rancher_data:/var/lib/rancher
EOF
```

### 6.2 启动与验证

```bash
# 启动
docker-compose up -d

# 查看日志
docker logs -f rancher

# 验证
# 访问 https://<本机IP>，忽略证书警告
```

---

## 7. 日常运维操作

### 7.1 常用管理命令

```bash
# 查看 Rancher Pod 状态
kubectl get pods -n cattle-system

# 查看下游集群 Agent 连接日志
kubectl logs -l app=rancher -n cattle-system
```

### 7.2 备份与恢复

Rancher 的核心数据存储在 Local 集群的 Etcd 中，也可以使用 Rancher Backup Operator 进行应用级备份。

```bash
# 安装 Backup Operator
helm install rancher-backup rancher-charts/rancher-backup \
  -n rancher-backup --create-namespace

# 创建备份 CR
cat <<EOF | kubectl apply -f -
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: rancher-backup-daily
spec:
  resourceSetName: rancher-resource-set
  retentionCount: 10
  schedule: "0 0 * * *"
EOF
```

### 7.3 集群扩缩容

针对底层 RKE2 集群的扩容（增加 Rancher 承载能力）：

1.  在新节点安装 RKE2（参考 4.4 节 Step 2）。
2.  启动服务后，RKE2 自动加入集群。
3.  Rancher Deployment 会自动调度到新节点（如果设置了 HPA 或手动调整 replicas）。

### 7.4 版本升级

使用 Helm 升级 Rancher 是标准做法。

```bash
# 1. 更新仓库
helm repo update

# 2. 获取最新版本
helm search repo rancher-stable/rancher

# 3. 执行升级
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.example.com \
  --set replicas=3 \
  --version v2.9.0
```

---

## 9. 注意事项与生产检查清单

### 9.1 安装前环境核查

*   [ ] **域名解析**：`ping rancher.example.com` 必须解析到 LB IP。
*   [ ] **80/443 端口**：确保 LB 到后端节点的端口连通。
*   [ ] **WebSocket 支持**：LB 必须支持 WebSocket 协议（Rancher 依赖 WS 与下游 Agent 通信）。

### 9.2 常见故障排查

**故障 1：UI 无法访问，Ingress 报错**
*   **现象**：浏览器 502/503。
*   **排查**：
    ```bash
    kubectl get pods -n ingress-nginx   # 检查 Ingress Controller
    kubectl get ep -n cattle-system     # 检查 Service 是否关联到 Pod
    ```

**故障 2：下游集群无法导入**
*   **现象**：`cattle-cluster-agent` 报 `CrashLoopBackOff`。
*   **排查**：
    *   检查下游节点是否能通过 HTTPS 访问 Rancher 域名。
    *   若是自签名证书，确保 Agent 容器内信任了 CA（使用 `CATTLE_CA_CHECKSUM` 环境变量）。

### 9.3 安全加固建议

1.  **TLS 证书**：生产环境务必使用商业 CA 证书或企业内部 CA，避免使用默认的自签名证书。
2.  **Local 集群隔离**：运行 Rancher 的 Local 集群**不要**部署业务应用，保持纯净。
3.  **定期备份**：配置 Etcd 快照和 Rancher Backup Operator 双重备份。

---

## 10. 参考资料

*   [Rancher 官方文档 (中文)](https://ranchermanager.docs.rancher.com/zh/)
*   [RKE2 安装指南](https://docs.rke2.io/)
*   [Helm 安装 Rancher 教程](https://ranchermanager.docs.rancher.com/zh/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster)
