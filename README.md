# 🚀 SRE 高级运维技术文档库

> **定位**：生产级别的 SRE（Site Reliability Engineering）运维技术文档，涵盖企业级主流开源中间件的部署、配置、调优与最佳实践。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docs](https://img.shields.io/badge/Docs-Production%20Grade-brightgreen)](.)
[![Middleware](https://img.shields.io/badge/中间件-80%2B-blue)](.)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](.)

---

## 📋 目录导航

| # | 大类 | 涵盖技术 |
|---|------|---------|
| 00 | [🐧 Linux 操作系统基础](#-00--linux-操作系统基础) | Rocky Linux · Ubuntu · 内核参数优化 · iptables · firewalld · 系统初始化 |
| 01 | [🗄️ 数据库](#️-01--数据库) | MySQL · Redis · MongoDB · Elasticsearch · PostgreSQL · TiDB · ClickHouse · Cassandra · **InfluxDB** |
| 02 | [📨 消息队列 & 流处理](#-02--消息队列--流处理) | Kafka · RabbitMQ · RocketMQ · Pulsar · NATS |
| 03 | [🔄 CI/CD](#-03--cicd-持续集成与交付) | Jenkins · Jenkins X · ArgoCD · GitLab CI · Tekton · Drone · Devtron · KubeVela |
| 04 | [🌐 API 网关 & Ingress](#-04--api-网关--ingress) | Nginx · OpenResty · APISIX · Higress · Traefik · Kong · Envoy |
| 05 | [🕸️ 服务网格](#️-05--服务网格-service-mesh) | Istio · Linkerd · Consul Connect |
| 06 | [📊 可观测性](#-06--可观测性-observability) | Prometheus · Grafana · VictoriaMetrics · Vector · Fluentd · Fluent Bit · Loki · **Logstash** · ELK · Graylog · OpenObserve · Jaeger · OpenTelemetry · SkyWalking |
| 07 | [☸️ Kubernetes](#️-07--kubernetes-集群) | 集群部署(**kubeasz · kubespray · KuboardSpray · kind**) · 存储 · 网络 · 安全 · Helm · Kustomize · Velero |
| 08 | [🔍 服务注册 & 配置中心](#-08--服务注册--配置中心) | Consul · etcd · Nacos · ZooKeeper · **Apollo** · **Sentinel** |
| 09 | [🔐 安全](#-09--安全-security) | Vault · Cert-Manager · Keycloak · OPA · Falco · **Bitwarden** |
| 10 | [💾 分布式存储](#-10--分布式存储) | MinIO · Ceph · Rook · Longhorn · NFS · **GlusterFS** |
| 11 | [📦 容器 & 镜像仓库](#-11--容器--镜像仓库) | Harbor · Docker · Docker Compose · Containerd |
| 12 | [⚖️ 负载均衡 & 高可用](#️-12--负载均衡--高可用) | HAProxy · Keepalived · LVS |
| 13 | [⏰ 任务调度](#-13--任务调度) | Airflow · XXL-Job · Elastic-Job |
| 14 | [🔗 网络 & VPN](#-14--网络--vpn) | WireGuard · OpenVPN · Calico · Cilium |
| 15 | [⚙️ IaC & 配置管理](#️-15--iac--配置管理) | Ansible · SaltStack · Terraform · **Vagrant** |
| 16 | [🛠️ 语言运行环境](#️-16--语言运行环境) | Python · Go · PHP · Java · Node.js |

---

## 🌟 项目简介

本文档库由 SRE 团队维护，提供企业级生产环境的中间件部署与运维文档：

- ✅ **生产级别**：配置均来源于真实生产环境验证
- ✅ **多部署方式**：提供 Docker、Linux 原生服务等多种部署方式
- ✅ **详细注释**：配置文件提供完整中文注释
- ✅ **架构图示**：每个组件包含架构图与部署拓扑
- ✅ **全面覆盖**：覆盖 SRE 涉及的 80+ 主流开源中间件
- ✅ **本地验证**：配套 Vagrant 模板，在本地 Windows 多节点 VM 中验证文档正确性

---

## 📐 文档规范

每个中间件文档统一遵循以下结构：

```
01-技术简介与架构图
02-环境准备与版本选择
03-部署方式A（Linux 原生）
04-部署方式B（Docker / Docker Compose）
05-核心配置详解（含中文注释）
06-生产级参数调优
07-高可用与集群方案
08-监控与告警接入
09-常见问题与排障
10-版本升级指南
```

### 🐧 操作系统兼容性要求

> **所有中间件部署文档必须同时覆盖以下两种操作系统，确保在不同生产环境下均可直接使用：**

| 系统 | 版本要求 | 包管理器 |
|------|---------|---------|
| **Rocky Linux** | 9.x（推荐）/ 8.x | `dnf` / `yum` |
| **Ubuntu** | 24.04 LTS（推荐）/ 22.04 LTS | `apt` / `apt-get` |

**书写规范：**

1. **相同命令**：直接写一份，无需重复
2. **命令存在差异**：使用独立代码块并在顶部注释系统名称明确区分，例如：

```bash
# ── Rocky Linux 9 ──────────────────────────────
dnf install -y <package>

# ── Ubuntu 22.04 ───────────────────────────────
apt-get install -y <package>
```

3. **仓库配置差异**：分别给出各系统的仓库添加命令
4. **服务管理**：均使用 `systemctl`（两系统一致，无需区分）
5. **路径差异**：在注释中显式说明，例如：
   - Rocky Linux：`/etc/yum.repos.d/`
   - Ubuntu：`/etc/apt/sources.list.d/`

> ⚠️ **注意**：若某个命令或配置仅适用于其中一个系统，必须用 `# ── Rocky Linux 9 ──` 或 `# ── Ubuntu 22.04 ──` 注释块单独标注，禁止混写造成歧义。

---

## 📁 完整目录结构

```
technical-documentation/
│
├── 📂 17-linux-os/               # Linux 操作系统基础
│   ├── rocky-linux/              # Rocky Linux 7/8/9 系统配置
│   ├── ubuntu/                   # Ubuntu 系统配置
│   ├── kernel-optimization/      # 内核参数调优
│   ├── iptables/                 # iptables 防火墙详解
│   ├── firewalld/                # firewalld 防火墙详解
│   └── system-init/              # 系统初始化 & 安全基线
│
├── 📂 01-databases/              # 数据库
│   ├── elasticsearch/            # 全文搜索引擎
│   ├── mysql/                    # 关系型数据库
│   ├── redis/                    # 内存数据库/缓存
│   ├── mongodb/                  # 文档数据库
│   ├── postgresql/               # 高级关系型数据库
│   ├── tidb/                     # 分布式 HTAP 数据库
│   ├── clickhouse/               # 列式分析数据库
│   ├── cassandra/                # 分布式 NoSQL
│   └── influxdb/                 # 高性能时序数据库
│
├── 📂 02-message-queue/          # 消息队列 & 流处理
│   ├── kafka/                    # 分布式流处理平台
│   ├── rabbitmq/                 # AMQP 消息代理
│   ├── rocketmq/                 # 阿里云消息队列
│   ├── pulsar/                   # 云原生消息流平台
│   └── nats/                     # 轻量级高性能消息系统
│
├── 📂 03-cicd/                   # CI/CD 持续集成与交付
│   ├── jenkins/                  # Jenkins 流水线
│   ├── jenkins-x/                # Cloud Native CI/CD
│   ├── argocd/                   # GitOps 持续交付
│   ├── gitlab-ci/                # GitLab 内置 CI
│   ├── tekton/                   # Kubernetes 原生 CI/CD
│   ├── drone/                    # 容器驱动 CI
│   ├── devtron/                  # K8s 软件交付工作流
│   └── kubevela/                 # OAM 云原生应用交付
│
├── 📂 04-api-gateway/            # API 网关 & Ingress
│   ├── nginx/                    # 高性能 Web 服务器
│   ├── openresty/                # Nginx + LuaJIT
│   ├── apisix/                   # 云原生 API 网关
│   ├── higress/                  # 下一代云原生网关
│   ├── traefik/                  # 云原生反向代理
│   ├── kong/                     # 企业级插件化网关
│   └── envoy/                    # 高性能 L7 代理
│
├── 📂 05-service-mesh/           # 服务网格
│   ├── istio/                    # 功能完备的服务网格
│   ├── linkerd/                  # 轻量级服务网格
│   └── consul-connect/           # HashiCorp 服务网格
│
├── 📂 06-observability/          # 可观测性（Metrics/Logs/Traces）
│   ├── prometheus/               # 指标采集与告警
│   ├── grafana/                  # 可视化监控面板
│   ├── victoriametrics/          # 高性能时序数据库
│   ├── alertmanager/             # 告警路由与管理
│   ├── vector/                   # 统一数据采集管道
│   ├── fluentd/                  # 统一日志收集层
│   ├── fluent-bit/               # 轻量级日志采集
│   ├── logstash/                 # 数据采集与转换管道
│   ├── loki/                     # Grafana 日志聚合
│   ├── elk/                      # Elasticsearch+Logstash+Kibana
│   ├── graylog/                  # 企业级日志管理
│   ├── openobserve/              # 云原生可观测平台
│   ├── jaeger/                   # 分布式链路追踪
│   ├── opentelemetry/            # 可观测性标准框架
│   └── skywalking/               # APM 应用性能监控
│
├── 📂 07-kubernetes/             # Kubernetes 集群
│   ├── cluster-setup/            # 集群标准化部署（kubeadm）
│   ├── kubeasz/                  # kubeasz 二进制高可用部署
│   ├── kubespray/                # Ansible 自动化集群部署
│   ├── kuboard-spray/            # KuboardSpray 可视化部署
│   ├── kind/                     # Kind 本地开发测试集群
│   ├── storage/                  # 持久化存储方案
│   ├── networking/               # 网络插件与策略
│   ├── security/                 # 安全加固与 RBAC
│   ├── helm-charts/              # Helm Chart 最佳实践
│   ├── kustomize/                # 声明式配置管理
│   └── velero/                   # 集群备份与恢复
│
├── 📂 08-service-discovery/      # 服务注册 & 配置中心
│   ├── consul/                   # 服务发现与配置
│   ├── etcd/                     # 分布式 KV 存储
│   ├── nacos/                    # 阿里云配置中心
│   ├── zookeeper/                # 分布式协调服务
│   ├── apollo/                   # 携程配置中心
│   └── sentinel/                 # 阿里流量控制与熔断降级
│
├── 📂 09-security/               # 安全
│   ├── vault/                    # 密钥与证书管理
│   ├── cert-manager/             # K8s 证书自动化
│   ├── keycloak/                 # 身份认证与 SSO
│   ├── opa/                      # 通用策略引擎
│   ├── falco/                    # 运行时安全检测
│   └── bitwarden/                # 开源企业密码管理
│
├── 📂 10-storage/                # 分布式存储
│   ├── minio/                    # S3 兼容对象存储
│   ├── ceph/                     # 统一分布式存储
│   ├── rook/                     # K8s 存储编排
│   ├── longhorn/                 # K8s 块存储
│   ├── nfs/                      # 网络文件系统
│   └── glusterfs/                # 分布式文件系统
│
├── 📂 11-container-registry/     # 容器 & 镜像仓库
│   ├── harbor/                   # 企业级镜像仓库
│   ├── docker/                   # 容器引擎
│   ├── docker-compose/           # 多容器编排工具
│   └── containerd/               # OCI 容器运行时
│
├── 📂 12-load-balancer/          # 负载均衡 & 高可用
│   ├── haproxy/                  # TCP/HTTP 负载均衡
│   ├── keepalived/               # VIP 高可用漂移
│   └── lvs/                      # Linux 内核负载均衡
│
├── 📂 13-scheduler/              # 任务调度
│   ├── airflow/                  # 数据管道调度
│   ├── xxl-job/                  # 分布式任务调度
│   └── elastic-job/              # 弹性作业框架
│
├── 📂 14-networking/             # 网络 & VPN
│   ├── wireguard/                # 高性能 VPN
│   ├── openvpn/                  # 企业级 VPN
│   ├── calico/                   # K8s 网络策略
│   └── cilium/                   # eBPF K8s 网络
│
├── 📂 15-iac/                    # IaC & 配置管理
│   ├── ansible/                  # Agentless 自动化运维
│   ├── saltstack/                # 大规模配置管理
│   ├── terraform/                # 基础设施即代码
│   └── vagrant/                  # 本地多节点 VM 快速验证环境
│       ├── Vagrant使用指南.md
│       └── 启动示例文件/
│           ├── Vagrantfile_Rocky9      # Rocky9 单机模板（旧）
│           ├── Vagrantfile_Ubuntu24    # Ubuntu24 单机模板（旧）
│           ├── Vagrantfile_1Node       # 单节点通用模板（含 Docker）
│           ├── Vagrantfile_3Nodes_DB   # 3 节点数据库集群模板
│           ├── Vagrantfile_5Nodes_K8s  # 3Master+2Worker K8s 模板
│           └── Vagrantfile_7Nodes_FullHA # 3M+3W+1存储 全量 HA 模板
│
└── 📂 16-runtime-env/            # 语言运行环境
    ├── python/                   # Python 多版本环境
    ├── golang/                   # Go 环境管理
    ├── php/                      # PHP-FPM 环境
    ├── java/                     # JDK/JVM 环境
    └── nodejs/                   # Node.js 版本管理
```

---

## 🗂 技术分类导航

### 🐧 00 · Linux 操作系统基础

> ⚡ **所有中间件部署的地基** — 规范化的 OS 配置与调优

| 模块 | 简介 | 文档 |
|------|------|------|
| **Rocky Linux 7/8/9** | 源配置、最小化安装、安全基线 | [📄 文档](./17-linux-os/rocky-linux/) |
| **Ubuntu** | 源配置（阿里云/清华源）、初始化规范 | [📄 文档](./17-linux-os/ubuntu/) |
| **内核参数优化** | sysctl 生产调优（网络/内存/文件句柄） | [📄 文档](./17-linux-os/kernel-optimization/) |
| **iptables** | 四表五链详解、规则编写、生产示例 | [📄 文档](./17-linux-os/iptables/) |
| **firewalld** | zone 管理、rich rules、生产配置 | [📄 文档](./17-linux-os/firewalld/) |
| **系统初始化** | 主机名/时区/NTP/SSH 加固/用户规范 | [📄 文档](./17-linux-os/system-init/) |

---

### 🗄️ 01 · 数据库

| 技术 | 类型 | 简介 | 文档 |
|------|------|------|------|
| **Elasticsearch** | 搜索/分析 | 分布式全文搜索引擎 | [📄 文档](./01-databases/elasticsearch/) |
| **MySQL** | 关系型 | 主流 RDBMS，MGR / 主从 | [📄 文档](./01-databases/mysql/) |
| **Redis** | 内存/缓存 | Cluster / Sentinel 高可用 | [📄 文档](./01-databases/redis/) |
| **MongoDB** | 文档型 | ReplicaSet / Sharding 集群 | [📄 文档](./01-databases/mongodb/) |
| **PostgreSQL** | 关系型 | 功能强大的开源 RDBMS | [📄 文档](./01-databases/postgresql/) |
| **TiDB** | 分布式 HTAP | MySQL 兼容分布式数据库 | [📄 文档](./01-databases/tidb/) |
| **ClickHouse** | 列式/OLAP | 极速列式分析数据库 | [📄 文档](./01-databases/clickhouse/) |
| **Cassandra** | NoSQL | 高可用分布式宽列数据库 | [📄 文档](./01-databases/cassandra/) |
| **InfluxDB** | 时序型 | 高性能时序数据库，IoT/监控首选 | [📄 文档](./01-databases/influxdb/) |

---

### 📨 02 · 消息队列 & 流处理

| 技术 | 简介 | 文档 |
|------|------|------|
| **Kafka** | 高吞吐分布式流处理，大厂首选 | [📄 文档](./02-message-queue/kafka/) |
| **RabbitMQ** | AMQP 消息代理，灵活路由 | [📄 文档](./02-message-queue/rabbitmq/) |
| **RocketMQ** | 阿里云开源，金融级消息队列 | [📄 文档](./02-message-queue/rocketmq/) |
| **Pulsar** | 云原生多租户消息流平台 | [📄 文档](./02-message-queue/pulsar/) |
| **NATS** | 轻量高性能云原生消息系统 | [📄 文档](./02-message-queue/nats/) |

---

### 🔄 03 · CI/CD 持续集成与交付

| 技术 | 简介 | 文档 |
|------|------|------|
| **Jenkins** | 老牌 CI/CD，插件生态最丰富 | [📄 文档](./03-cicd/jenkins/) |
| **Jenkins X** | 面向 K8s 的云原生 CI/CD | [📄 文档](./03-cicd/jenkins-x/) |
| **ArgoCD** | GitOps 持续交付，声明式管理 | [📄 文档](./03-cicd/argocd/) |
| **GitLab CI** | GitLab 内置 CI/CD 流水线 | [📄 文档](./03-cicd/gitlab-ci/) |
| **Tekton** | K8s 原生 CI/CD 框架 | [📄 文档](./03-cicd/tekton/) |
| **Drone** | 容器驱动轻量 CI 平台 | [📄 文档](./03-cicd/drone/) |
| **Devtron** | K8s 软件交付工作流平台 | [📄 文档](./03-cicd/devtron/) |
| **KubeVela** | OAM 标准云原生应用交付 | [📄 文档](./03-cicd/kubevela/) |

---

### 🌐 04 · API 网关 & Ingress

| 技术 | 简介 | 文档 |
|------|------|------|
| **Nginx** | 高性能反向代理与负载均衡 | [📄 文档](./04-api-gateway/nginx/) |
| **OpenResty** | Nginx + LuaJIT 可编程平台 | [📄 文档](./04-api-gateway/openresty/) |
| **APISIX** | 高性能云原生 API 网关 | [📄 文档](./04-api-gateway/apisix/) |
| **Higress** | 阿里云下一代 Ingress/API 网关 | [📄 文档](./04-api-gateway/higress/) |
| **Traefik** | 云原生自动化反向代理 | [📄 文档](./04-api-gateway/traefik/) |
| **Kong** | 企业级插件化 API 网关 | [📄 文档](./04-api-gateway/kong/) |
| **Envoy** | 高性能 L7 代理（Istio 数据面） | [📄 文档](./04-api-gateway/envoy/) |

---

### 🕸️ 05 · 服务网格 (Service Mesh)

| 技术 | 简介 | 文档 |
|------|------|------|
| **Istio** | 功能完备的服务网格，业界标准 | [📄 文档](./05-service-mesh/istio/) |
| **Linkerd** | 轻量级 Rust 实现服务网格 | [📄 文档](./05-service-mesh/linkerd/) |
| **Consul Connect** | HashiCorp 服务网格方案 | [📄 文档](./05-service-mesh/consul-connect/) |

---

### 📊 06 · 可观测性（Observability）

> 覆盖 **Metrics（指标）**、**Logs（日志）**、**Traces（链路追踪）** 三大支柱

| 技术 | 支柱 | 简介 | 文档 |
|------|------|------|------|
| **Prometheus** | Metrics | 主流时序指标采集与告警 | [📄 文档](./06-observability/prometheus/) |
| **Grafana** | 可视化 | 多数据源统一监控面板 | [📄 文档](./06-observability/grafana/) |
| **VictoriaMetrics** | Metrics | 高性能低成本 Prometheus 替代 | [📄 文档](./06-observability/victoriametrics/) |
| **Alertmanager** | 告警 | Prometheus 告警路由与分组 | [📄 文档](./06-observability/alertmanager/) |
| **Logstash** | 采集/转换 | 强大的数据采集、过滤与转换管道 | [📄 文档](./06-observability/logstash/) |
| **Vector** | 采集管道 | 高性能统一日志/指标数据管道 | [📄 文档](./06-observability/vector/) |
| **Fluentd** | Logs | 统一日志收集与转发 | [📄 文档](./06-observability/fluentd/) |
| **Fluent Bit** | Logs | 轻量级日志采集 Agent | [📄 文档](./06-observability/fluent-bit/) |
| **Loki** | Logs | Grafana 原生日志聚合 | [📄 文档](./06-observability/loki/) |
| **ELK Stack** | Logs | Elasticsearch+Logstash+Kibana | [📄 文档](./06-observability/elk/) |
| **Graylog** | Logs | 企业级集中日志管理 | [📄 文档](./06-observability/graylog/) |
| **OpenObserve** | 全栈 | 云原生轻量级可观测平台 | [📄 文档](./06-observability/openobserve/) |
| **Jaeger** | Traces | 分布式链路追踪系统 | [📄 文档](./06-observability/jaeger/) |
| **OpenTelemetry** | 采集标准 | 可观测性数据采集标准 | [📄 文档](./06-observability/opentelemetry/) |
| **SkyWalking** | APM | 应用性能监控与链路追踪 | [📄 文档](./06-observability/skywalking/) |

---

### ☸️ 07 · Kubernetes 集群

| 模块 | 简介 | 文档 |
|------|------|------|
| **集群标准化部署** | kubeadm 生产集群搭建 | [📄 文档](./07-kubernetes/cluster-setup/) |
| **kubeasz** | 二进制方式高可用 K8s 部署 | [📄 文档](./07-kubernetes/kubeasz/) |
| **kubespray** | Ansible 自动化 K8s 集群部署 | [📄 文档](./07-kubernetes/kubespray/) |
| **KuboardSpray** | 可视化 Web 界面 K8s 集群部署 | [📄 文档](./07-kubernetes/kuboard-spray/) |
| **kind** | Docker 容器模拟 K8s 本地开发集群 | [📄 文档](./07-kubernetes/kind/) |
| **持久化存储** | Ceph / NFS / Local Path | [📄 文档](./07-kubernetes/storage/) |
| **网络方案** | Calico / Cilium / Flannel | [📄 文档](./07-kubernetes/networking/) |
| **安全加固** | RBAC / NetworkPolicy / OPA | [📄 文档](./07-kubernetes/security/) |
| **Helm Charts** | 常用 Chart 定制与最佳实践 | [📄 文档](./07-kubernetes/helm-charts/) |
| **Kustomize** | 声明式 K8s 配置覆盖管理 | [📄 文档](./07-kubernetes/kustomize/) |
| **Velero** | 集群备份与灾难恢复 | [📄 文档](./07-kubernetes/velero/) |

---

### 🔍 08 · 服务注册 & 配置中心

| 技术 | 简介 | 文档 |
|------|------|------|
| **Consul** | 服务发现、健康检查、KV 配置 | [📄 文档](./08-service-discovery/consul/) |
| **etcd** | K8s 核心分布式 KV 存储 | [📄 文档](./08-service-discovery/etcd/) |
| **Nacos** | 阿里云服务发现与动态配置 | [📄 文档](./08-service-discovery/nacos/) |
| **ZooKeeper** | 分布式协调服务（Kafka/HBase 依赖） | [📄 文档](./08-service-discovery/zookeeper/) |
| **Apollo** | 携程开源分布式配置中心 | [📄 文档](./08-service-discovery/apollo/) |
| **Sentinel** | 阿里开源流量控制、熔断降级组件 | [📄 文档](./08-service-discovery/sentinel/) |

---

### 🔐 09 · 安全 (Security)

| 技术 | 简介 | 文档 |
|------|------|------|
| **Vault** | HashiCorp 密钥与证书管理 | [📄 文档](./09-security/vault/) |
| **Cert-Manager** | K8s 自动化 TLS 证书管理 | [📄 文档](./09-security/cert-manager/) |
| **Keycloak** | 开源身份认证与 SSO | [📄 文档](./09-security/keycloak/) |
| **OPA** | 通用策略即代码引擎 | [📄 文档](./09-security/opa/) |
| **Falco** | 容器运行时安全检测 | [📄 文档](./09-security/falco/) |
| **Bitwarden** | 开源企业级团队密码管理 | [📄 文档](./09-security/bitwarden/) |

---

### 💾 10 · 分布式存储

| 技术 | 简介 | 文档 |
|------|------|------|
| **MinIO** | S3 兼容高性能对象存储 | [📄 文档](./10-storage/minio/) |
| **Ceph** | 统一分布式存储（对象/块/文件） | [📄 文档](./10-storage/ceph/) |
| **Rook** | K8s 云原生 Ceph 编排 | [📄 文档](./10-storage/rook/) |
| **Longhorn** | K8s 轻量级分布式块存储 | [📄 文档](./10-storage/longhorn/) |
| **NFS** | 网络文件共享系统 | [📄 文档](./10-storage/nfs/) |
| **GlusterFS** | 高可用分布式文件系统 | [📄 文档](./10-storage/glusterfs/) |

---

### 📦 11 · 容器 & 镜像仓库

| 技术 | 简介 | 文档 |
|------|------|------|
| **Harbor** | 企业级云原生镜像仓库 | [📄 文档](./11-container-registry/harbor/) |
| **Docker** | 容器引擎，生产配置与安全加固 | [📄 文档](./11-container-registry/docker/) |
| **Docker Compose** | 多容器应用编排工具 | [📄 文档](./11-container-registry/docker-compose/) |
| **Containerd** | 工业级 OCI 容器运行时 | [📄 文档](./11-container-registry/containerd/) |

---

### ⚖️ 12 · 负载均衡 & 高可用

| 技术 | 简介 | 文档 |
|------|------|------|
| **HAProxy** | 高性能 TCP/HTTP 负载均衡 | [📄 文档](./12-load-balancer/haproxy/) |
| **Keepalived** | VRRP 协议 VIP 高可用漂移 | [📄 文档](./12-load-balancer/keepalived/) |
| **LVS** | Linux 内核级负载均衡 | [📄 文档](./12-load-balancer/lvs/) |

---

### ⏰ 13 · 任务调度

| 技术 | 简介 | 文档 |
|------|------|------|
| **Airflow** | 数据管道 DAG 任务调度 | [📄 文档](./13-scheduler/airflow/) |
| **XXL-Job** | 轻量级分布式任务调度 | [📄 文档](./13-scheduler/xxl-job/) |
| **Elastic-Job** | 弹性分布式作业框架 | [📄 文档](./13-scheduler/elastic-job/) |

---

### 🔗 14 · 网络 & VPN

| 技术 | 简介 | 文档 |
|------|------|------|
| **WireGuard** | 现代高性能 VPN 协议 | [📄 文档](./14-networking/wireguard/) |
| **OpenVPN** | 经典企业级 SSL VPN | [📄 文档](./14-networking/openvpn/) |
| **Calico** | K8s BGP 网络策略插件 | [📄 文档](./14-networking/calico/) |
| **Cilium** | eBPF 驱动 K8s 高性能网络 | [📄 文档](./14-networking/cilium/) |

---

### ⚙️ 15 · IaC & 配置管理

| 技术 | 简介 | 文档 |
|------|------|------|
| **Ansible** | Agentless 自动化运维，Playbook 管理 | [📄 文档](./15-iac/ansible/) |
| **SaltStack** | 大规模节点配置管理与远程执行 | [📄 文档](./15-iac/saltstack/) |
| **Terraform** | 基础设施即代码，多云资源管理 | [📄 文档](./15-iac/terraform/) |
| **Vagrant** | 本地多节点 VM 快速验证环境 | [📄 使用指南](./15-iac/vagrant/Vagrant使用指南.md) |

---

### 🧪 本地验证环境（Vagrant）

> 本文档库的文档均将在本地 VM 中验证后再交付，确保零错误。以下 Vagrantfile 均基于 **Rocky Linux 9**。

| Vagrantfile | 适用场景 | 节点 | 内存消耗 | IP 段 |
|-------------|---------|--------|---------|-------|
| [Vagrantfile_1Node](./15-iac/vagrant/启动示例文件/Vagrantfile_1Node) | Docker/单机部署类（Nginx/Jenkins/Harbor） | 1 | 8 GB | 192.168.33.10 |
| [Vagrantfile_3Nodes_DB](./15-iac/vagrant/启动示例文件/Vagrantfile_3Nodes_DB) | 数据库集群（MySQL/Redis/MongoDB/ES/Kafka） | 3 | 3×16 = 48 GB | 192.168.34.101-103 |
| [Vagrantfile_5Nodes_K8s](./15-iac/vagrant/启动示例文件/Vagrantfile_5Nodes_K8s) | K8s 集群（Sealos/kubeadm/kubeasz） | 5（3M+2W） | 5×16 = 80 GB | 192.168.35.101/111 |
| [Vagrantfile_7Nodes_FullHA](./15-iac/vagrant/启动示例文件/Vagrantfile_7Nodes_FullHA) | 全量 HA（K8s+Ceph存储） | 7（3M+3W+1S） | 7×16 ≈ 112 GB | 192.168.36.101/111/121 |

**快速启动（PowerShell）**：

```powershell
# 进入工作目录
cd D:\YOUR_PROJECT

# 指定 Vagrantfile 名称启动
$env:VAGRANT_VAGRANTFILE = "Vagrantfile_3Nodes_DB"
vagrant up

# 登录节点
vagrant ssh db-node1

# 关闭所有虚拟机
vagrant halt
```

> 📤 详细用法参考：📄 [倍者详细指南](./15-iac/vagrant/Vagrant使用指南.md)

---

### 🛠️ 16 · 语言运行环境

> 多版本共存、虚拟环境、生产级 JVM/FPM 参数调优

| 语言 | 简介 | 文档 |
|------|------|------|
| **Python** | pyenv 版本管理、venv、pip 私有源 | [📄 文档](./16-runtime-env/python/) |
| **Go** | 多版本安装、GOPATH/Modules、交叉编译 | [📄 文档](./16-runtime-env/golang/) |
| **PHP** | PHP-FPM 安装与调优、多版本共存 | [📄 文档](./16-runtime-env/php/) |
| **Java** | OpenJDK / Oracle JDK、JVM 调优参数 | [📄 文档](./16-runtime-env/java/) |
| **Node.js** | nvm 多版本、npm/yarn/pnpm 配置 | [📄 文档](./16-runtime-env/nodejs/) |

---

## 🤝 贡献指南

1. **文档格式**：所有文档使用 Markdown（`.md`）
2. **命名规范**：文件名小写 + 连字符，如 `deployment-guide.md`
3. **版本标注**：文档头部注明适用版本与更新时间
4. **配置注释**：所有配置示例必须含中文注释
5. **结构图**：架构图优先使用 Mermaid 或 ASCII 图

---

## 📅 维护信息

| 项目 | 信息 |
|------|------|
| 维护团队 | SRE Team |
| 文档语言 | 中文（简体）|
| 适用环境 | 生产环境（Production Grade）|
| 中间件数量 | 80+ |
| 最后更新 | 2026-03 |

---

> 💡 **提示**：使用 `Ctrl + F` 搜索技术名称快速定位，或点击顶部导航表格跳转对应大类。
