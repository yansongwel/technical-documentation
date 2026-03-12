# Elasticsearch 生产级部署与运维指南

本文档提供 Elasticsearch 在生产环境下的高可用部署、配置调优及日常运维操作指南，适用于 Rocky Linux 9 和 Ubuntu 22.04 系统。

## 1. 简介

### 1.1 服务介绍与核心特性
Elasticsearch 是一个基于 Lucene 构建的开源、分布式、RESTful 搜索和分析引擎。
- **分布式架构**：天生支持集群扩展，自动分片与副本管理。
- **近实时搜索**：数据写入后 1秒内即可被搜索。
- **多租户支持**：通过索引隔离不同业务数据。
- **RESTful API**：使用 JSON over HTTP 进行交互，易于集成。

### 1.2 适用场景
- **日志分析**：ELK (Elasticsearch, Logstash, Kibana) 栈的核心组件。
- **全文检索**：电商商品搜索、站内搜索。
- **安全分析**：SIEM (Security Information and Event Management)。
- **指标监控**：应用性能监控 (APM) 数据存储。

### 1.3 架构原理图

```ascii
+---------------------------------------------------------+
|                      Elasticsearch Cluster              |
|                                                         |
|  +-------------+      +-------------+      +-------------+  |
|  |   Node-1    |      |   Node-2    |      |   Node-3    |  |
|  | (Master/Data)|<---->| (Master/Data)|<---->| (Master/Data)|  |
|  |             |      |             |      |             |  |
|  |  [Shard P1] |      |  [Shard R1] |      |  [Shard R2] |  |
|  |  [Shard R2] |      |  [Shard P2] |      |  [Shard P3] |  |
|  +------+------+      +------+------+      +------+------+  |
|         ^                    ^                    ^         |
+---------|--------------------|--------------------|---------+
          |                    |                    |
      +---+--------------------+--------------------+---+
      |                  Load Balancer                  |
      +------------------------+------------------------+
                               |
                        Client Application
```

## 2. 版本选择指南

### 2.1 版本对应关系表

| 版本系列 | 当前状态 | JDK 要求 | 特性说明 |
| :--- | :--- | :--- | :--- |
| **8.x (推荐)** | Current | 内置 JDK 17+ | 默认开启安全特性(TLS/Auth)，性能大幅提升，移除 Mapping Type |
| **7.x** | Maintenance | JDK 11+ | 广泛使用，生态成熟，逐步废弃 Type |
| **6.x** | EOL | JDK 8 | 已停止维护，不建议新项目使用 |

### 2.2 版本决策建议
- **新项目**：强烈建议选择 **8.x** 最新稳定版（如 8.11+）。8.x 默认安全性更高，且在存储效率和查询性能上有显著优化。
- **旧项目迁移**：如果现有应用深度依赖 7.x 特性（如 Transport Client），需评估迁移成本。建议先升级至 7.17，再滚动升级至 8.x。
- **JDK 兼容性**：8.x 版本通常内置了适配的 OpenJDK，无需单独安装 JDK，简化了部署。

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

建议生产环境至少部署 3 个节点，均配置为 Master-eligible 和 Data 角色，以防脑裂（Split-brain）并保证数据高可用。

```ascii
      +---------------------+       +---------------------+       +---------------------+
      |       Node-01       |       |       Node-02       |       |       Node-03       |
      | IP: 192.168.1.101   |       | IP: 192.168.1.102   |       | IP: 192.168.1.103   |
      | Role: Master, Data  |       | Role: Master, Data  |       | Role: Master, Data  |
      +----------+----------+       +----------+----------+       +----------+----------+
                 |                             |                             |
                 +--------------+--------------+--------------+--------------+
                                | Internal Transport (9300)   |
                                +-----------------------------+
```

### 3.2 节点角色与配置要求

| 规格类型 | CPU | 内存 | 磁盘 | 适用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **最低配置** | 2 Core | 4 GB | 50 GB (SSD) | 开发/测试，小规模日志 |
| **推荐配置** | 4-8 Core | 16-32 GB | 500 GB+ (NVMe SSD) | 生产环境，高并发读写 |
| **高性能配置**| 16 Core+ | 64 GB | 1 TB+ (RAID 0/10) | 大规模日志分析，复杂聚合 |

> **注意**：Elasticsearch 堆内存（Heap Size）建议设置为物理内存的 50%，且最大不超过 31GB（以利用 Compressed Oops 技术）。

### 3.3 网络与端口规划

| 端口号 | 协议 | 说明 | 访问限制 |
| :--- | :--- | :--- | :--- |
| **9200** | TCP/HTTP | REST API 接口，客户端交互 | 仅对内网应用或 Load Balancer 开放 |
| **9300** | TCP | 集群节点间通信 (Transport) | 仅对集群内部节点开放 |

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

**1. 配置主机名解析**
确保所有节点 `/etc/hosts` 包含集群所有 IP：
```bash
cat >> /etc/hosts << 'EOF'
192.168.1.101 node-01
192.168.1.102 node-02
192.168.1.103 node-03
EOF
```

**2. 禁用 Swap (必须)**
Elasticsearch 严重依赖内存，Swap 会导致性能急剧下降。
```bash
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab
```

**3. 调整系统内核参数**
增加虚拟内存区域映射数量和文件描述符限制。

```bash
cat >> /etc/sysctl.conf << 'EOF'
vm.max_map_count=262144
EOF

sysctl -p
```

**4. 调整资源限制**
```bash
cat >> /etc/security/limits.conf << 'EOF'
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
elasticsearch soft nofile 65535
elasticsearch hard nofile 65535
EOF
```

### 4.2 部署步骤

#### ── Rocky Linux 9 ──────────────────────────
```bash
# 导入 GPG Key
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# 添加 Yum 源
cat > /etc/yum.repos.d/elasticsearch.repo << 'EOF'
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

# 安装
dnf install -y elasticsearch
```

#### ── Ubuntu 22.04 ───────────────────────────
```bash
# 安装依赖
apt-get update && apt-get install -y apt-transport-https gnupg

# 导入 GPG Key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# 添加 APT 源
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list

# 安装
apt-get update && apt-get install -y elasticsearch
```

### 4.4 集群初始化与配置

以下配置以 `node-01` 为例，其他节点需修改 `node.name` 和 `network.host`。

**编辑配置文件：**
```bash
# 备份默认配置
cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

# 写入生产配置 (Node-01 示例)
cat > /etc/elasticsearch/elasticsearch.yml << 'EOF'
# ======================== Cluster =========================
cluster.name: my-es-cluster               # ★ 集群名称，所有节点必须一致
node.name: node-01                        # ★ 节点名称，每个节点唯一

# ======================== Network =========================
network.host: 192.168.1.101               # ★ 本机 IP，绑定监听地址
http.port: 9200
transport.port: 9300

# ======================== Discovery =======================
# ★ 集群初始主节点列表（仅在集群首次启动时需要，之后可注释）
cluster.initial_master_nodes: ["node-01", "node-02", "node-03"]

# ★ 种子主机列表，用于节点发现
discovery.seed_hosts: ["192.168.1.101", "192.168.1.102", "192.168.1.103"]

# ======================== Paths ===========================
path.data: /var/lib/elasticsearch         # ⚠️ 数据存储路径，建议挂载独立大磁盘
path.logs: /var/log/elasticsearch

# ======================== Memory ==========================
bootstrap.memory_lock: true               # ★ 锁定内存，防止 Swap

# ======================== Security (8.x Default) ==========
xpack.security.enabled: false             # ⚠️ 生产环境建议开启 (true)，此处为简化演示设为 false
xpack.security.enrollment.enabled: false

xpack.security.http.ssl:
  enabled: false
xpack.security.transport.ssl:
  enabled: false
EOF
```

> **⚠️ 安全说明**：ES 8.x 默认开启 Security (TLS/Auth)。若开启，首次启动会生成 `elastic` 用户密码和 Enrollment Token。为简化集群搭建流程，上述配置暂时关闭了 Security。生产环境**强烈建议**开启 Security 并配置 TLS 证书。

**JVM 堆内存配置：**
```bash
cat >> /etc/elasticsearch/jvm.options.d/heap.options << 'EOF'
-Xms4g  # ★ 根据实际物理内存调整，建议为物理内存 50%
-Xmx4g
EOF
```

**启动服务：**
```bash
# Reload systemd
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
```

### 4.5 安装验证

在任意节点执行：
```bash
curl -X GET "http://localhost:9200/_cat/nodes?v"
```

**预期输出：**
```text
ip            heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
192.168.1.101           15          45   5    0.10    0.05     0.01 cdfhilmrstw *      node-01
192.168.1.102           12          40   3    0.08    0.04     0.01 cdfhilmrstw -      node-02
192.168.1.103           14          42   4    0.09    0.06     0.01 cdfhilmrstw -      node-03
```
可以看到 3 个节点均已加入集群，且有一个 Master (`*`)。

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

文件路径：`/etc/elasticsearch/elasticsearch.yml`

| 参数名 | 默认值 | 说明 | 生产建议 |
| :--- | :--- | :--- | :--- |
| `cluster.name` | elasticsearch | 集群标识 | **必须修改**，防止误加入其他集群 |
| `node.name` | (hostname) | 节点标识 | **必须修改**，保持易读性 |
| `path.data` | /var/lib/... | 数据目录 | 建议挂载高性能 SSD 盘 |
| `bootstrap.memory_lock` | false | 内存锁定 | **设置为 true**，配合 `limit.conf` |
| `network.host` | localhost | 绑定 IP | 设置为服务器内网 IP |
| `discovery.seed_hosts` | - | 发现列表 | 填写所有 Master 候选节点 IP |
| `cluster.initial_master_nodes` | - | 初始主节点 | 仅首次启动需配置，填写节点名 |

### 5.2 生产环境推荐调优参数

**1. 索引刷新间隔 (Refresh Interval)**
默认 1s。如果是海量数据写入场景，建议调大以减少 I/O 压力。
```json
PUT /_cluster/settings
{
  "persistent": {
    "indices.recovery.max_bytes_per_sec": "100mb"
  }
}
```

**2. 字段数据缓存 (Fielddata Cache)**
限制 Fielddata 内存使用，防止 OOM。
```yaml
indices.fielddata.cache.size: 20%
```

## 6. 开发/测试环境快速部署（Docker Compose）

**⚠️ 注意：此方案仅适用于开发或测试环境，生产环境请使用物理机或虚拟机集群部署。**

### 6.1 Docker Compose 部署（单机）

创建 `docker-compose.yml`：

```bash
cat >> docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.1
    container_name: elasticsearch
    environment:
      - node.name=es-single
      - cluster.name=es-docker-cluster
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - es-net

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.1
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
    networks:
      - es-net

volumes:
  es_data:
    driver: local

networks:
  es-net:
    driver: bridge
EOF
```

### 6.2 启动与验证

```bash
docker-compose up -d

# 验证
curl http://localhost:9200
```

### 6.3 三节点 Docker Compose（开启账号密码认证 + TLS，生产级配置基线）

适用场景：
- 单台宿主机上以多容器方式运行 3 个 Elasticsearch 节点，便于你按“接近生产”的安全配置（TLS + 账号密码）进行验证与演练。
- 该方案不具备多宿主机容灾能力：宿主机故障会导致整个集群不可用。真正生产环境高可用建议使用多机部署（物理机/VM/K8s）。

本方案已在本仓库生成可直接使用的目录：
- `compose-3nodes-secure/`：三节点 Compose
- `compose-3nodes-secure/config/`：生产级配置文件（每节点一份）
- `compose-3nodes-secure/setup/instances.yml`：证书签发实例清单（包含 `localhost`）

#### 6.3.1 前置条件（宿主机）

Linux 宿主机（推荐）：
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

Docker Desktop（Windows/macOS）：
- 如果使用 WSL2 后端：在 WSL2 发行版内设置 `vm.max_map_count=262144`，并确保设置可持久化。

#### 6.3.2 配置说明

1) 修改 `.env`（必须）
- 路径：`compose-3nodes-secure/.env`
- 至少需要修改：
  - `ELASTIC_PASSWORD`：`elastic` 内置超级用户密码（请设置强密码）
  - `ES_HEAP`：堆大小（例如 `2g`、`4g`，建议为容器可用内存的 50% 且不超过 ~31g）

2) 配置文件（已生成）
- `compose-3nodes-secure/config/es01.yml`
- `compose-3nodes-secure/config/es02.yml`
- `compose-3nodes-secure/config/es03.yml`

配置要点：
- 开启安全能力：`xpack.security.enabled: true`
- HTTP/Transport 全链路 TLS：`xpack.security.http.ssl.*`、`xpack.security.transport.ssl.*`
- 禁止危险操作：`action.destructive_requires_name: true`

#### 6.3.3 启动（三节点）

在目录 `compose-3nodes-secure/` 下执行：
```bash
docker compose up -d
docker compose ps
```

首次启动会自动生成 CA 与节点证书（保存在 Docker volume `certs` 内），随后启动 3 个节点。

#### 6.3.4 导出 CA 证书（用于本机 curl 校验 HTTPS）

在 `compose-3nodes-secure/` 下执行：
```bash
docker compose cp es01:/usr/share/elasticsearch/config/certs/ca/ca.crt ./ca.crt
```

#### 6.3.5 验证（HTTPS + Basic Auth）

Linux/macOS：
```bash
curl --cacert ./ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200
curl --cacert ./ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cat/nodes?v
curl --cacert ./ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://localhost:9200/_cluster/health?pretty
```

Windows PowerShell（注意使用 curl.exe）：
```powershell
curl.exe --cacert .\ca.crt -u "elastic:你的密码" https://localhost:9200
curl.exe --cacert .\ca.crt -u "elastic:你的密码" https://localhost:9200/_cat/nodes?v
curl.exe --cacert .\ca.crt -u "elastic:你的密码" https://localhost:9200/_cluster/health?pretty
```

#### 6.3.6 常见问题排查

- 端口占用：修改 `compose-3nodes-secure/.env` 的 `ES_HTTP_PORT`
- 内存不足：减小 `ES_HEAP`，并确认 Docker 分配给宿主机/WSL 的内存足够
- 启动失败（内核参数）：确保 `vm.max_map_count=262144`
- 查看日志：
  ```bash
  docker compose logs -f es01
  ```

## 7. 日常运维操作

### 7.1 常用管理命令

```bash
# 查看集群健康状态
curl -X GET "localhost:9200/_cluster/health?pretty"

# 查看所有节点信息
curl -X GET "localhost:9200/_cat/nodes?v"

# 查看所有索引
curl -X GET "localhost:9200/_cat/indices?v"

# 查看分片分配情况
curl -X GET "localhost:9200/_cat/shards?v"
```

### 7.2 备份与恢复

Elasticsearch 使用 Snapshot API 进行备份，需先配置共享文件系统（如 NFS）或 S3。

**1. 注册仓库 (Repository)**
```bash
curl -X PUT "localhost:9200/_snapshot/my_backup" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/mnt/backups"
  }
}
'
```

**2. 创建快照 (Snapshot)**
```bash
# 备份所有索引
curl -X PUT "localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true"
```

**3. 恢复快照**
```bash
curl -X POST "localhost:9200/_snapshot/my_backup/snapshot_1/_restore"
```

### 7.3 集群扩缩容
- **扩容**：在新节点配置相同的 `cluster.name` 和 `discovery.seed_hosts`，启动后会自动加入集群。
- **缩容**：先将待下线节点排除，等待数据迁移完成。
  ```bash
  PUT _cluster/settings
  {
    "transient" : {
      "cluster.routing.allocation.exclude._ip" : "192.168.1.103"
    }
  }
  ```

### 7.4 版本升级
推荐使用 **Rolling Upgrade**（滚动升级）：
1. 停止一个非 Master 节点。
2. 升级软件包。
3. 启动节点，等待加入集群。
4. 确认集群状态变绿。
5. 重复上述步骤。

## 8. 使用手册（数据库专项）

### 8.1 连接与认证
如果开启了 Security，需使用 `-u` 参数：
```bash
curl -u elastic:password -X GET "http://localhost:9200/"
```

### 8.2 库/表/索引管理命令

```bash
# 创建索引 (相当于建库/表)
curl -X PUT "localhost:9200/my-index-001" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  }
}
'

# 删除索引
curl -X DELETE "localhost:9200/my-index-001"

# 查看索引 Mapping (表结构)
curl -X GET "localhost:9200/my-index-001/_mapping?pretty"
```

### 8.3 数据增删改查（CRUD）

```bash
# 插入文档 (Create)
curl -X POST "localhost:9200/my-index-001/_doc/" -H 'Content-Type: application/json' -d'
{
  "user": "kimchy",
  "post_date": "2023-11-15T14:12:12",
  "message": "trying out Elasticsearch"
}
'

# 根据 ID 查询 (Read)
curl -X GET "localhost:9200/my-index-001/_doc/<DOC_ID>"

# 简单搜索 (Search)
curl -X GET "localhost:9200/my-index-001/_search?q=user:kimchy"

# DSL 复杂搜索
curl -X GET "localhost:9200/my-index-001/_search" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "message": "Elasticsearch"
    }
  }
}
'

# 更新文档 (Update)
curl -X POST "localhost:9200/my-index-001/_update/<DOC_ID>" -H 'Content-Type: application/json' -d'
{
  "doc": {
    "message": "updated message"
  }
}
'

# 删除文档 (Delete)
curl -X DELETE "localhost:9200/my-index-001/_doc/<DOC_ID>"
```

### 8.4 用户与权限管理 (需开启 Security)

```bash
# 创建用户
curl -u elastic -X POST "localhost:9200/_security/user/jdoe" -H 'Content-Type: application/json' -d'
{
  "password" : "userpassword",
  "roles" : [ "monitoring_user" ],
  "full_name" : "John Doe"
}
'
```

### 8.5 性能查询与慢查询分析

**设置慢查询日志阈值：**
```bash
curl -X PUT "localhost:9200/my-index-001/_settings" -H 'Content-Type: application/json' -d'
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.fetch.warn": "1s"
}
'
```
日志位置：`/var/log/elasticsearch/my-es-cluster_index_search_slowlog.log`

### 8.6 备份恢复命令
> 见 7.2 节。

### 8.7 主从/集群状态监控命令

```bash
# 监控集群健康 (含颜色 green/yellow/red)
watch -n 1 'curl -s localhost:9200/_cluster/health?pretty'

# 监控节点堆内存使用
curl -s localhost:9200/_cat/nodes?v&h=name,heap.percent,ram.percent,cpu
```

### 8.8 生产常见故障处理命令

**场景：集群变红 (Red)**
说明有主分片丢失。
```bash
# 查看未分配分片的原因
curl -X GET "localhost:9200/_cluster/allocation/explain?pretty"
```

**场景：集群变黄 (Yellow)**
说明有副本分片未分配（通常是节点数不足以分配副本）。
```bash
# 临时将副本数设为 0 (仅用于单节点恢复绿灯)
curl -X PUT "localhost:9200/*/_settings" -H 'Content-Type: application/json' -d'
{
    "index" : {
        "number_of_replicas" : 0
    }
}
'
```

## 9. 注意事项与生产检查清单

### 9.1 安装前环境核查
- [ ] **JDK 版本**：确认是否使用内置 JDK 或系统 JDK 版本兼容。
- [ ] **内存**：确认物理内存充足，且 Swap 已禁用。
- [ ] **磁盘**：确认数据盘为 SSD，且剩余空间 > 20%。
- [ ] **内核参数**：`vm.max_map_count` 是否已修改 (> 262144)。
- [ ] **文件句柄**：`ulimit -n` 是否 > 65535。

### 9.2 常见故障排查

**报错：master_not_discovered_exception**
- **原因**：无法找到主节点，通常是网络不通或 `discovery.seed_hosts` 配置错误。
- **排查**：检查防火墙端口 9300 是否开放，检查 `cluster.name` 是否一致。

**报错：max virtual memory areas vm.max_map_count [65530] is too low**
- **解决**：执行 `sysctl -w vm.max_map_count=262144` 并写入 `/etc/sysctl.conf`。

### 9.3 安全加固建议
- **开启 TLS**：节点间通信 (Transport) 和 HTTP 接口均应启用 TLS 加密。
- **启用 RBAC**：使用 Role-Based Access Control 限制用户权限。
- **网络隔离**：9200 端口不要直接暴露在公网，使用 Nginx 反向代理并配置 IP 白名单。
- **定期备份**：配置 SLM (Snapshot Lifecycle Management) 自动备份。

## 10. 参考资料
- [Elasticsearch 官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Elasticsearch 生产环境配置建议](https://www.elastic.co/guide/en/elasticsearch/reference/current/system-config.html)
