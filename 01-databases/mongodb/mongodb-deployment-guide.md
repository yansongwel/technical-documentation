# MongoDB 生产级集群部署指南

> **版本推荐**：MongoDB 7.0.x（LTS）
> **更新时间**：2026-03
> **覆盖模式**：副本集（Replica Set）→ 分片集群（Sharded Cluster）

---

## 目录

1. [简介与版本选型](#1-简介与版本选型)
2. [部署模式选型](#2-部署模式选型)
3. [环境规划](#3-环境规划)
4. [安装 MongoDB](#4-安装-mongodb)
5. [方案一：副本集（Replica Set）](#5-方案一副本集replica-set)
6. [方案二：分片集群（Sharded Cluster）](#6-方案二分片集群sharded-cluster)
7. [生产级 mongod.conf 全量配置注释](#7-生产级-mongodconf-全量配置注释)
8. [安全加固（认证 + TLS + RBAC）](#8-安全加固认证--tls--rbac)
9. [性能调优](#9-性能调优)
10. [监控接入](#10-监控接入)
11. [备份与恢复](#11-备份与恢复)
12. [常用运维命令大全](#12-常用运维命令大全)
13. [常见问题排查](#13-常见问题排查)

---

## 1. 简介与版本选型

### 1.1 MongoDB 简介

MongoDB 是基于 **文档模型** 的 NoSQL 数据库，以 BSON（二进制 JSON）格式存储数据，天然支持：

- 📄 **灵活 Schema**：无需预定义表结构，适合半结构化、频繁变化的数据
- 🔍 **丰富查询**：支持嵌套文档查询、聚合管道、地理空间索引
- 🌐 **水平扩展**：原生分片集群，PB 级数据线性扩容
- 🔄 **高可用**：副本集自动选主，故障切换秒级完成
- ⚡ **事务支持**：4.0+ 支持多文档 ACID 事务，7.0 大幅优化事务性能

### 1.2 版本选型

| 版本 | 主要特性 | 状态 | 推荐 |
|------|---------|------|------|
| MongoDB 5.x | 时序集合、可变分片键 | EOL | ❌ 不推荐 |
| MongoDB 6.x | 可查询加密、聚合增强 | 维护中 | ⚠️ 可用 |
| **MongoDB 7.0.x** | 事务性能大幅提升、复合通配索引 | **LTS** | ✅ **生产首选** |
| MongoDB 7.3.x | 最新特性持续引入 | 最新 | ⚠️ 观望中 |

> **生产建议**：选择 **MongoDB 7.0.x LTS**，长期支持至 2027 年。

### 1.3 MongoDB 7.0 关键改进

```
MongoDB 7.0+
  ├── 事务性能：单分片事务性能提升 ~10%，多分片事务提升更大
  ├── 复合通配索引：一个索引覆盖多个动态字段
  ├── 可查询加密（QE）正式 GA：数据在传输和存储中全程加密
  ├── 分析型聚合增强：$percentile、$median 新运算符
  └── Atlas Search 集成增强
```

---

## 2. 部署模式选型

```
┌──────────────┬─────────────────────────┬──────────────────────────────┐
│  模式         │  副本集 Replica Set       │  分片集群 Sharded Cluster      │
├──────────────┼─────────────────────────┼──────────────────────────────┤
│  节点数       │  3～7 个（奇数）           │  ≥9 个（3分片×3副本+3 mongos）  │
│  数据量       │  < 单节点磁盘上限（实践<2T） │  TB～PB 级，无上限             │
│  高可用       │  ✅ 自动选主故障切换        │  ✅ 每个分片独立副本集          │
│  水平扩展     │  ❌ 只能读写分离           │  ✅ 动态添加分片               │
│  查询路由     │  直连主节点              │  mongos 路由器自动分发          │
│  运维复杂度   │  低                     │  高                           │
│  适用场景     │  < 1TB，中小型生产        │  > 1TB，大数据量，高并发写      │
└──────────────┴─────────────────────────┴──────────────────────────────┘
```

---

## 3. 环境规划

### 3.1 副本集节点规划（推荐 3 节点）

```
         ┌─────────────────────────────────────────────┐
         │              副本集 rs0                       │
         │                                             │
         │  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
         │  │ Primary  │  │Secondary │  │Secondary │  │
         │  │mongo-01  │  │mongo-02  │  │mongo-03  │  │
         │  │:27017    │→─│:27017    │  │:27017    │  │
         │  │(读写)    │  │(只读)    │  │(只读)    │  │
         │  └──────────┘  └──────────┘  └──────────┘  │
         │         ↑ 选举(quorum=2)                    │
         └─────────────────────────────────────────────┘
                         ↑
                    应用连接字符串:
       mongodb://mongo-01:27017,mongo-02:27017,mongo-03:27017/
                   ?replicaSet=rs0&readPreference=secondaryPreferred
```

| 角色 | 主机名 | IP | 端口 | 规格 |
|------|--------|----|------|------|
| Primary | `mongo-01` | `192.168.10.31` | 27017 | 8C32G / 500G SSD |
| Secondary-1 | `mongo-02` | `192.168.10.32` | 27017 | 8C32G / 500G SSD |
| Secondary-2 | `mongo-03` | `192.168.10.33` | 27017 | 8C32G / 500G SSD |

> **⚠️ 注意**：MongoDB 对内存极度敏感，WiredTiger 引擎默认使用 50% 物理内存作为缓存，32G 内存节点约有 15G 用于数据缓存。

### 3.2 分片集群节点规划

```
客户端
  │
  ▼
┌─────────────────────────────────────┐
│         mongos 路由层（3 节点）        │
│  mongos-01  mongos-02  mongos-03    │
└──────────────────┬──────────────────┘
                   │ 查询路由
       ┌───────────┼───────────┐
       ▼           ▼           ▼
  ┌─────────┐ ┌─────────┐ ┌─────────┐
  │ Shard-1  │ │ Shard-2  │ │ Shard-3  │
  │ 3节点RS  │ │ 3节点RS  │ │ 3节点RS  │
  └─────────┘ └─────────┘ └─────────┘
       ▲
  ┌─────────┐
  │ Config  │  配置服务器（3 节点 RS）
  │  Server │  存储集群元数据
  └─────────┘
```

| 组件 | 主机名 | IP | 端口 |
|------|--------|----|------|
| Config Server-1 | `mongo-cfg-01` | `192.168.10.40` | 27019 |
| Config Server-2 | `mongo-cfg-02` | `192.168.10.41` | 27019 |
| Config Server-3 | `mongo-cfg-03` | `192.168.10.42` | 27019 |
| Shard1-Primary | `mongo-s1-01` | `192.168.10.43` | 27018 |
| Shard1-Secondary | `mongo-s1-02` | `192.168.10.44` | 27018 |
| Shard1-Secondary | `mongo-s1-03` | `192.168.10.45` | 27018 |
| Shard2-Primary | `mongo-s2-01` | `192.168.10.46` | 27018 |
| Shard2-Secondary | `mongo-s2-02` | `192.168.10.47` | 27018 |
| Shard2-Secondary | `mongo-s2-03` | `192.168.10.48` | 27018 |
| Shard3-Primary | `mongo-s3-01` | `192.168.10.49` | 27018 |
| Shard3-Secondary | `mongo-s3-02` | `192.168.10.50` | 27018 |
| Shard3-Secondary | `mongo-s3-03` | `192.168.10.51` | 27018 |
| mongos-1 | `mongo-gw-01` | `192.168.10.52` | 27017 |
| mongos-2 | `mongo-gw-02` | `192.168.10.53` | 27017 |
| mongos-3 | `mongo-gw-03` | `192.168.10.54` | 27017 |

---

## 4. 安装 MongoDB

### 4.1 添加官方仓库（所有节点）

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 导入 GPG 公钥
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

# 添加官方 APT 仓库（noble = Ubuntu 24.04 代号）
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/7.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get update
```

### 4.2 安装 MongoDB

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
dnf install -y mongodb-org

# 锁定版本（防止意外升级）
echo "exclude=mongodb-org,mongodb-org-database,mongodb-org-server,mongodb-mongosh,mongodb-org-mongos,mongodb-org-tools" >> /etc/yum.conf

# ── Ubuntu 24.04 ───────────────────────────────────────────────
apt-get install -y mongodb-org

# 锁定版本（防止意外升级）
echo "mongodb-org hold"          | dpkg --set-selections
echo "mongodb-org-database hold" | dpkg --set-selections
echo "mongodb-org-server hold"   | dpkg --set-selections
echo "mongodb-mongosh hold"      | dpkg --set-selections
```

```bash
# ── 以下命令两个系统相同 ────────────────────────────────────────
# 验证
mongod --version
mongosh --version
```

### 4.3 创建目录与系统用户

```bash
# 创建数据目录（建议挂载独立 SSD）
mkdir -p /data/mongodb/data      # 数据文件
mkdir -p /data/mongodb/log       # 日志
mkdir -p /data/mongodb/journal   # Journal 目录（可与数据同盘）
mkdir -p /etc/mongodb/ssl        # TLS 证书

# 设置权限
chown -R mongod:mongod /data/mongodb
chmod 750 /data/mongodb/data
chmod 750 /etc/mongodb/ssl

# 生成副本集内部通信密钥文件（所有副本集节点保持相同）
# 在任意一台节点生成，然后拷贝到所有节点
openssl rand -base64 756 > /etc/mongodb/keyfile
chmod 400 /etc/mongodb/keyfile
chown mongod:mongod /etc/mongodb/keyfile

# 将 keyfile 同步到其他节点
for host in 192.168.10.32 192.168.10.33; do
    scp /etc/mongodb/keyfile root@${host}:/etc/mongodb/keyfile
    ssh root@${host} "chown mongod:mongod /etc/mongodb/keyfile && chmod 400 /etc/mongodb/keyfile"
done
```

---

## 5. 方案一：副本集（Replica Set）

### 5.1 各节点 mongod.conf 配置

```bash
# 三台节点配置基本相同，只需修改各自的 net.bindIp
# 以下以 mongo-01（192.168.10.31）为例
cat > /etc/mongod.conf << 'EOF'
# ============================================================
# MongoDB 生产配置文件（副本集模式）
# 节点：mongo-01 (192.168.10.31)
# ============================================================

# ---- 系统日志 ----
systemLog:
  destination: file
  path: /data/mongodb/log/mongod.log
  logAppend: true                    # 追加写入（不覆盖）
  # 日志级别：0=info, 1=debug, 2-5=更详细（生产保持默认0）
  verbosity: 0
  # 是否输出 JSON 格式日志（便于 ELK/Loki 采集）
  logRotate: reopen                  # 日志轮转方式（reopen=配合 logrotate 工具）

# ---- 数据存储 ----
storage:
  dbPath: /data/mongodb/data         # 数据文件目录（必须是 SSD）
  journal:
    enabled: true                    # 开启 Journal（崩溃恢复必需，生产必须开启）
    commitIntervalMs: 100            # Journal 提交间隔（毫秒）
  engine: wiredTiger                 # 存储引擎（7.0 只支持 WiredTiger）
  wiredTiger:
    engineConfig:
      # WiredTiger 缓存大小：默认 max(50% RAM - 1G, 256MB)
      # ⚠️ 生产中根据实际内存调整，建议设为物理内存的 40%~50%
      cacheSizeGB: 14                # 32G 内存推荐设 14G
      journalCompressor: snappy      # Journal 压缩算法（snappy/zlib/none）
      directoryForIndexes: false     # 是否将索引单独存放目录（大集合建议 true）
    collectionConfig:
      blockCompressor: snappy        # 集合数据压缩（snappy 性能最优，zlib 比率最高）
    indexConfig:
      prefixCompression: true        # 索引前缀压缩（默认 true，节省内存）

# ---- 网络 ----
net:
  port: 27017
  # ⚠️ 生产只绑定内网 IP + 本地回环，禁止 0.0.0.0
  bindIp: 192.168.10.31,127.0.0.1
  maxIncomingConnections: 65536      # 最大入站连接数
  compression:
    compressors: snappy,zlib,zstd    # 客户端与服务端通信压缩（降低带宽）
  tls:
    mode: disabled                   # 生产建议：requireTLS（见第8节）
    # certificateKeyFile: /etc/mongodb/ssl/mongod.pem
    # CAFile: /etc/mongodb/ssl/ca.pem

# ---- 安全 ----
security:
  # keyFile 用于副本集成员间内部认证（所有节点保持相同）
  keyFile: /etc/mongodb/keyfile
  authorization: enabled             # 开启客户端访问认证

# ---- 进程管理 ----
processManagement:
  timeZoneInfo: /usr/share/zoneinfo  # 时区信息目录

# ---- 操作日志 ----
operationProfiling:
  # 慢操作阈值（毫秒），超过此时间的操作写入 system.profile
  slowOpThresholdMs: 100
  # 采样率（全量采样=1.0，按比例=0.0~1.0，生产建议 0.01 避免性能影响）
  mode: slowOp                       # off/slowOp/all（生产用 slowOp）
  slowOpSampleRate: 1.0

# ---- 副本集配置 ----
replication:
  replSetName: rs0                   # ⚠️ 整个副本集所有节点必须保持一致
  # oplog 大小（MB）：越大允许从节点的复制延迟越长
  # 默认：min(5% 磁盘空间, 50GB)，生产可适当调大
  oplogSizeMB: 51200                 # 50GB oplog（根据写入量调整）

# ---- 分片配置（副本集模式不需要，留作注释）----
# sharding:
#   clusterRole: shardsvr            # 分片集群时開启

EOF

# 设置配置文件权限
chown mongod:mongod /etc/mongod.conf
chmod 640 /etc/mongod.conf
```

### 5.2 启动并初始化副本集

```bash
# 三台节点各自启动 mongod
systemctl enable mongod --now
systemctl status mongod

# ⚠️ 以下仅在 Primary 节点（mongo-01）执行一次

# 连接到 mongo-01
mongosh --host 192.168.10.31 --port 27017

# 在 mongosh 中初始化副本集
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "192.168.10.31:27017", priority: 2 },   // Primary 候选（优先级最高）
    { _id: 1, host: "192.168.10.32:27017", priority: 1 },   // Secondary
    { _id: 2, host: "192.168.10.33:27017", priority: 1 }    // Secondary
  ]
})

# 等待副本集完成初始化（约 30 秒）
# 验证副本集状态
rs.status()

# 查看详细配置
rs.conf()
```

### 5.3 创建管理员账号（副本集初始化后）

```bash
# 连接到 Primary 节点
mongosh --host 192.168.10.31 --port 27017

# 在 admin 数据库创建超级管理员
use admin
db.createUser({
  user: "admin",
  pwd: "AdminStr0ngP@ss2026",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "clusterAdmin", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "dbAdminAnyDatabase", db: "admin" }
  ]
})

# 验证登录
mongosh --host 192.168.10.31 --port 27017 \
    -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin
```

### 5.4 副本集连接字符串（客户端）

```
# 完整副本集连接字符串（应用程序使用）
mongodb://admin:AdminStr0ngP@ss2026@192.168.10.31:27017,192.168.10.32:27017,192.168.10.33:27017/yourdb?replicaSet=rs0&authSource=admin&readPreference=secondaryPreferred&connectTimeoutMS=5000&serverSelectionTimeoutMS=5000

# 参数说明：
# replicaSet=rs0                    → 指定副本集名称（关键！）
# readPreference=secondaryPreferred → 优先读从节点（减轻主节点压力）
# authSource=admin                  → 认证数据库
# connectTimeoutMS=5000            → 连接超时 5 秒
```

---

## 6. 方案二：分片集群（Sharded Cluster）

### 6.1 部署 Config Server（3 台节点）

```bash
# Config Server 配置（所有 cfg 节点相同，修改对应 bindIp）
cat > /etc/mongod-config.conf << 'EOF'
systemLog:
  destination: file
  path: /data/mongodb/log/mongod-config.log
  logAppend: true

storage:
  dbPath: /data/mongodb/config-data
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2         # Config Server 数据量小，2G 缓存足够

net:
  port: 27019
  bindIp: 192.168.10.40,127.0.0.1  # ⚠️ 改为各节点本机 IP

security:
  keyFile: /etc/mongodb/keyfile
  authorization: enabled

replication:
  replSetName: rs-config

sharding:
  clusterRole: configsvr    # 声明为配置服务器角色
EOF

systemctl start mongod

# 初始化 Config Server 副本集（只在 cfg-01 执行）
mongosh --host 192.168.10.40 --port 27019
rs.initiate({
  _id: "rs-config",
  configsvr: true,
  members: [
    { _id: 0, host: "192.168.10.40:27019" },
    { _id: 1, host: "192.168.10.41:27019" },
    { _id: 2, host: "192.168.10.42:27019" }
  ]
})
```

### 6.2 部署 Shard（每个分片 3 台）

```bash
# 以 Shard-1 的 s1-01 为例（三台节点配置相同，修改 bindIp）
cat > /etc/mongod-shard.conf << 'EOF'
systemLog:
  destination: file
  path: /data/mongodb/log/mongod-shard.log
  logAppend: true

storage:
  dbPath: /data/mongodb/shard-data
  wiredTiger:
    engineConfig:
      cacheSizeGB: 14        # ⚠️ 根据实际内存调整

net:
  port: 27018
  bindIp: 192.168.10.43,127.0.0.1  # ⚠️ 改为各节点本机 IP

security:
  keyFile: /etc/mongodb/keyfile
  authorization: enabled

replication:
  replSetName: rs-shard1    # Shard2 改为 rs-shard2，Shard3 改为 rs-shard3
  oplogSizeMB: 51200

sharding:
  clusterRole: shardsvr     # 声明为分片角色
EOF

systemctl start mongod

# 初始化各分片副本集（在各分片的 primary 节点执行）
# Shard-1（在 s1-01 执行）
mongosh --host 192.168.10.43 --port 27018
rs.initiate({
  _id: "rs-shard1",
  members: [
    { _id: 0, host: "192.168.10.43:27018", priority: 2 },
    { _id: 1, host: "192.168.10.44:27018", priority: 1 },
    { _id: 2, host: "192.168.10.45:27018", priority: 1 }
  ]
})
# Shard-2/3 类似，修改 replSetName 和 IP
```

### 6.3 部署 mongos 路由器（3 台）

```bash
# mongos 无需存储引擎和数据目录
cat > /etc/mongos.conf << 'EOF'
systemLog:
  destination: file
  path: /data/mongodb/log/mongos.log
  logAppend: true

net:
  port: 27017
  bindIp: 192.168.10.52,127.0.0.1  # ⚠️ 改为各 mongos 本机 IP
  maxIncomingConnections: 65536

security:
  keyFile: /etc/mongodb/keyfile

sharding:
  # Config Server 副本集连接字符串
  configDB: rs-config/192.168.10.40:27019,192.168.10.41:27019,192.168.10.42:27019
EOF

# mongos 使用独立 systemd 服务
cat > /etc/systemd/system/mongos.service << 'EOF'
[Unit]
Description=MongoDB Shard Router
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/mongos --config /etc/mongos.conf --fork
ExecStop=/usr/bin/mongosh --port 27017 --eval "db.adminCommand({shutdown: 1})"
User=mongod
Group=mongod
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mongos --now
```

### 6.4 添加分片并启用分片集合

```bash
# 连接到任意 mongos
mongosh --host 192.168.10.52 --port 27017

# 先创建管理员（首次连接无需认证，创建后需认证）
use admin
db.createUser({
  user: "admin",
  pwd: "AdminStr0ngP@ss2026",
  roles: [{ role: "root", db: "admin" }]
})

# 添加所有分片
sh.addShard("rs-shard1/192.168.10.43:27018,192.168.10.44:27018,192.168.10.45:27018")
sh.addShard("rs-shard2/192.168.10.46:27018,192.168.10.47:27018,192.168.10.48:27018")
sh.addShard("rs-shard3/192.168.10.49:27018,192.168.10.50:27018,192.168.10.51:27018")

# 验证分片添加成功
sh.status()

# ---- 对数据库和集合启用分片 ----

# 1. 对数据库启用分片
sh.enableSharding("yourdb")

# 2. 对集合启用分片（需要选择合适的分片键）
# 方式 A：哈希分片（数据分布均匀，适合写入密集型）
sh.shardCollection("yourdb.orders", { "_id": "hashed" })

# 方式 B：范围分片（适合范围查询，但可能数据不均匀）
sh.shardCollection("yourdb.logs", { "createTime": 1, "userId": 1 })

# 3. 查看集合分片状态
db.orders.getShardDistribution()
```

---

## 7. 生产级 mongod.conf 全量配置注释

```yaml
# ============================================================
# MongoDB 7.0 生产级完整配置（关键参数说明）
# ============================================================

systemLog:
  destination: file
  path: /data/mongodb/log/mongod.log
  logAppend: true
  logRotate: reopen              # 配合 logrotate 工具使用

storage:
  dbPath: /data/mongodb/data
  journal:
    enabled: true                # 必须开启，否则崩溃后数据可能损坏
    commitIntervalMs: 100
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 14            # 生产关键参数：约为总物理内存 × 0.4~0.5
      journalCompressor: snappy  # snappy：CPU 消耗低，压缩比适中
      directoryForIndexes: true  # true：索引与数据分开存放（可分配到不同磁盘）
    collectionConfig:
      blockCompressor: snappy    # 数据文件压缩
    indexConfig:
      prefixCompression: true    # 索引前缀压缩，节约内存

net:
  port: 27017
  bindIp: 192.168.10.31,127.0.0.1
  maxIncomingConnections: 65536
  compression:
    compressors: snappy,zlib,zstd  # 支持多种压缩，客户端协商选择
  tls:
    mode: requireTLS             # 生产推荐：requireTLS
    certificateKeyFile: /etc/mongodb/ssl/mongod.pem
    CAFile: /etc/mongodb/ssl/ca.pem
    disabledProtocols: TLS1_0,TLS1_1  # 禁用旧版 TLS

security:
  keyFile: /etc/mongodb/keyfile
  authorization: enabled
  javascriptEnabled: false       # 生产关闭 JavaScript 执行（防注入）

operationProfiling:
  slowOpThresholdMs: 100         # 100ms 以上的操作进入慢日志
  mode: slowOp
  slowOpSampleRate: 1.0

replication:
  replSetName: rs0
  oplogSizeMB: 51200             # 50GB，oplog 越大从节点容忍延迟越大

setParameter:
  # 最大允许排队等待锁的操作数（超过返回错误而非等待）
  maxTransactionLockRequestTimeoutMillis: 5000
  # 连接池相关
  connPoolMaxConnsPerHost: 200
  # 游标空闲超时（毫秒），超时自动关闭
  cursorTimeoutMillis: 600000    # 10 分钟
```

---

## 8. 安全加固（认证 + TLS + RBAC）

### 8.1 生成 TLS 自签证书

```bash
# 生产环境建议使用企业 CA 或 Let's Encrypt
# 以下为自签证书示例（测试/内网环境）

mkdir -p /etc/mongodb/ssl && cd /etc/mongodb/ssl

# 生成 CA 根证书
openssl req -new -x509 -days 3650 -extensions v3_ca \
    -keyout ca.key -out ca.pem \
    -subj "/C=CN/O=YourCompany/CN=MongoDB-CA"

# 生成节点证书（每台节点重复执行，修改 CN 和 IP）
openssl req -new -nodes \
    -keyout mongod.key -out mongod.csr \
    -subj "/C=CN/O=YourCompany/CN=mongo-01.internal"

# 签署证书（添加 SAN）
cat > mongod.ext << 'EOF'
subjectAltName = IP:192.168.10.31,IP:127.0.0.1,DNS:mongo-01
EOF
openssl x509 -req -days 3650 -in mongod.csr \
    -CA ca.pem -CAkey ca.key -CAcreateserial \
    -out mongod.crt -extfile mongod.ext

# 合并为 PEM 文件（MongoDB 要求 key+cert 合并）
cat mongod.key mongod.crt > mongod.pem
chmod 400 mongod.pem mongod.key ca.pem
chown mongod:mongod mongod.pem ca.pem
```

### 8.2 RBAC 角色与用户管理

```javascript
// 连接 mongosh 后执行（在 admin 库）
use admin

// 创建只读用户（业务只读账号）
db.createUser({
  user: "readonly",
  pwd: "ReadOnlyP@ss2026",
  roles: [{ role: "readAnyDatabase", db: "admin" }]
})

// 创建应用账号（只能访问指定数据库）
use yourdb
db.createUser({
  user: "appuser",
  pwd: "AppUserP@ss2026",
  roles: [
    { role: "readWrite", db: "yourdb" }
  ]
})

// 创建 DBA 账号（可管理数据库，不能修改用户权限）
use admin
db.createUser({
  user: "dba",
  pwd: "DbaP@ss2026",
  roles: [
    { role: "dbAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" },
    { role: "clusterMonitor", db: "admin" }
  ]
})

// 修改用户密码
db.changeUserPassword("appuser", "NewP@ss2026")

// 查看所有用户
db.getUsers()

// 删除用户
db.dropUser("username")
```

---

## 9. 性能调优

### 9.1 系统内核参数

```bash
cat > /etc/sysctl.d/99-mongodb.conf << 'EOF'
# ============================================================
# MongoDB 专项内核参数调优
# ============================================================

# 文件描述符上限
fs.file-max = 1000000

# TCP 连接优化
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_tw_reuse = 1

# 内存分配（允许内存过量提交，MongoDB fork 进程需要）
vm.overcommit_memory = 1

# 减小 swappiness（MongoDB 是内存密集型，尽量不使用 swap）
vm.swappiness = 1

# NUMA 策略（多 CPU 系统）
# 关闭 zone_reclaim_mode 避免 NUMA 内存分配不均
vm.zone_reclaim_mode = 0
EOF

sysctl -p /etc/sysctl.d/99-mongodb.conf

# ⚠️ 禁用透明大页（Transparent Huge Pages）
# MongoDB 官方要求！否则出现性能抖动和高延迟
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" > /sys/kernel/mm/transparent_hugepage/defrag

# 永久生效
cat >> /etc/rc.d/rc.local << 'EOF'
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" > /sys/kernel/mm/transparent_hugepage/defrag
EOF
chmod +x /etc/rc.d/rc.local
```

### 9.2 文件描述符与用户限制

```bash
cat > /etc/security/limits.d/mongodb.conf << 'EOF'
mongod    soft    nofile    65535
mongod    hard    nofile    65535
mongod    soft    nproc     65535
mongod    hard    nproc     65535
EOF
```

### 9.3 索引优化建议

```javascript
// 查看集合索引
db.orders.getIndexes()

// 查看慢查询中缺少索引的情况
db.setProfilingLevel(1, { slowms: 100 })
db.system.profile.find({ millis: { $gt: 100 } }).sort({ ts: -1 }).limit(10)

// 创建复合索引（字段顺序：等值查询字段在前，范围查询字段在后）
db.orders.createIndex({ userId: 1, createTime: -1 })

// 创建后台索引（不阻塞读写）
db.orders.createIndex({ status: 1 }, { background: true })

// 创建 TTL 索引（过期自动删除）
db.logs.createIndex({ createTime: 1 }, { expireAfterSeconds: 2592000 })  // 30天

// 分析查询执行计划
db.orders.explain("executionStats").find({ userId: "u001", status: "paid" })

// 查找未使用的索引（定期清理）
db.orders.aggregate([{ $indexStats: {} }])
```

---

## 10. 监控接入

### 10.1 mongodb_exporter 接入 Prometheus

```bash
# 下载 mongodb_exporter
curl -LO https://github.com/percona/mongodb_exporter/releases/latest/download/mongodb_exporter-0.40.0.linux-amd64.tar.gz
tar -xzf mongodb_exporter-*.tar.gz

# 创建监控账号（最小权限）
mongosh --host 192.168.10.31 -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin
use admin
db.createUser({
  user: "monitor",
  pwd: "MonitorP@ss2026",
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }
  ]
})

# 启动 exporter
./mongodb_exporter \
    --mongodb.uri "mongodb://monitor:MonitorP@ss2026@192.168.10.31:27017/admin?replicaSet=rs0" \
    --web.listen-address ":9216" \
    --collect-all &

# prometheus.yml 配置
# - job_name: 'mongodb'
#   static_configs:
#     - targets: ['192.168.10.31:9216']
```

### 10.2 关键监控指标

```
关键 Prometheus / mongostat 指标：
─────────────────────────────────────────────────────────────
mongodb_up                               # 节点存活
mongodb_rs_members_state                 # 副本集成员状态（1=Primary,2=Secondary）
mongodb_rs_oplog_head_timestamp          # 主节点最新 oplog 时间戳
mongodb_mongod_connections{state="current"}  # 当前连接数
mongodb_mongod_wiredtiger_cache_bytes_currently_in_cache  # WT 缓存使用量
mongodb_mongod_wiredtiger_cache_max_bytes_configured      # WT 缓存上限
mongodb_mongod_op_latencies_latency_total               # 操作延迟（读/写/命令）
rate(mongodb_mongod_metrics_document_total[5m])          # 文档操作 QPS
mongodb_mongod_global_lock_current_queue_total          # 全局锁等待队列（告警：> 0）
mongodb_mongod_repl_buffer_count                        # 复制缓冲区大小
─────────────────────────────────────────────────────────────
```

---

## 11. 备份与恢复

### 11.1 mongodump / mongorestore（逻辑备份）

```bash
# ⚠️ 从 Secondary 节点备份，不影响 Primary 读写
# 全库备份
mongodump \
    --host 192.168.10.32:27017 \
    --username admin \
    --password 'AdminStr0ngP@ss2026' \
    --authenticationDatabase admin \
    --oplog \                           # 记录备份期间的 oplog（保证一致性）
    --gzip \                            # 压缩输出
    --out /backup/mongodb/$(date +%Y%m%d_%H%M%S)

# 单库备份
mongodump \
    --host 192.168.10.32:27017 \
    --username admin \
    --password 'AdminStr0ngP@ss2026' \
    --authenticationDatabase admin \
    --db yourdb \
    --gzip \
    --out /backup/mongodb/yourdb_$(date +%Y%m%d)

# 从备份恢复（全量）
mongorestore \
    --host 192.168.10.31:27017 \
    --username admin \
    --password 'AdminStr0ngP@ss2026' \
    --authenticationDatabase admin \
    --oplogReplay \                     # 重放 oplog（恢复到一致点）
    --gzip \
    --drop \                            # 恢复前先删除现有集合（谨慎）
    /backup/mongodb/20260301_020000/

# 自动备份脚本（crontab）
echo "0 2 * * * mongod /usr/local/bin/mongo-backup.sh >> /var/log/mongodb/backup.log 2>&1" > /etc/cron.d/mongodb-backup
```

### 11.2 文件系统快照备份（推荐生产使用）

```bash
# 使用 LVM 快照（需要 MongoDB 数据目录在 LVM 卷上）

# 步骤 1：锁定 MongoDB 写入（确保数据一致性）
mongosh --host 127.0.0.1 -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin \
    --eval "db.fsyncLock()"

# 步骤 2：创建 LVM 快照
lvcreate -L 50G -s -n mongodb_snap /dev/vg_data/lv_mongodb

# 步骤 3：立即解锁（尽快！最小化锁定时间）
mongosh --host 127.0.0.1 -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin \
    --eval "db.fsyncUnlock()"

# 步骤 4：挂载快照并备份
mount -o ro /dev/vg_data/mongodb_snap /mnt/mongo_snap
tar -czf /backup/mongodb_$(date +%Y%m%d).tar.gz -C /mnt/mongo_snap .
umount /mnt/mongo_snap
lvremove -f /dev/vg_data/mongodb_snap
```

---

## 12. 常用运维命令大全

### 12.1 连接与认证

```bash
# 连接副本集（推荐，自动选择主节点）
mongosh "mongodb://admin:AdminStr0ngP@ss2026@192.168.10.31:27017,192.168.10.32:27017,192.168.10.33:27017/admin?replicaSet=rs0"

# 直连单节点
mongosh --host 192.168.10.31 --port 27017 \
    -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin

# 通过 URI 连接（含 TLS）
mongosh "mongodb://admin:pass@host:27017/admin?tls=true&tlsCAFile=/etc/mongodb/ssl/ca.pem"
```

### 12.2 副本集运维

```javascript
// 查看副本集状态（重点关注 stateStr 和 optimeDate）
rs.status()

// 查看副本集配置
rs.conf()

// 查看 Primary 是哪台节点
rs.isMaster()  // 或 rs.hello()（7.0+）

// 查看 oplog 使用情况
rs.printReplicationInfo()         // Primary 的 oplog 状态
rs.printSecondaryReplicationInfo() // 所有 Secondary 的复制延迟

// 修改副本集成员配置
var cfg = rs.conf()
cfg.members[1].priority = 0       // 将 Secondary 设为不可选主
cfg.members[1].hidden = true      // 隐藏节点（不接收客户端连接）
cfg.members[1].slaveDelay = 3600  // 延迟复制 1 小时（延迟备份）
rs.reconfig(cfg)

// 手动触发选主（将另一节点设为 Primary）
rs.stepDown()  // 当前 Primary 主动降级，触发重新选举
rs.stepDown(120)  // 120 秒内不参与选举

// 添加新节点到副本集
rs.add("192.168.10.34:27017")

// 添加仲裁节点（不存储数据，只参与选举投票）
rs.addArb("192.168.10.35:27017")

// 移除节点
rs.remove("192.168.10.34:27017")

// 冻结节点（指定秒数内不参与选举）
rs.freeze(120)
```

### 12.3 数据库与集合管理

```javascript
// 切换/创建数据库
use yourdb

// 查看数据库列表
show dbs

// 查看当前库的所有集合
show collections

// 查看数据库大小
db.stats()
db.stats(1024 * 1024)  // 以 MB 为单位

// 查看集合统计
db.orders.stats()
db.orders.stats({ indexDetails: true })  // 包含索引详情

// 查看集合文档数
db.orders.countDocuments()
db.orders.estimatedDocumentCount()       // 估算（更快，从元数据读取）

// 压缩集合（清理碎片，会阻塞，低峰期执行）
db.runCommand({ compact: "orders" })
```

### 12.4 查询与聚合

```javascript
// 基础查询
db.orders.find({ status: "paid", userId: "u001" })
db.orders.find({ amount: { $gt: 100 } }).sort({ createTime: -1 }).limit(10)

// 查询计划分析（重要！用于索引优化）
db.orders.explain("executionStats").find({ userId: "u001" })
// 关注：winningPlan、totalKeysExamined、totalDocsExamined、executionTimeMillis

// 聚合管道
db.orders.aggregate([
  { $match: { status: "paid", createTime: { $gte: ISODate("2026-01-01") } } },
  { $group: { _id: "$userId", total: { $sum: "$amount" }, count: { $sum: 1 } } },
  { $sort: { total: -1 } },
  { $limit: 10 }
])

// 使用 allowDiskUse（聚合数据超过 100MB 时必须）
db.orders.aggregate([
  { $sort: { createTime: -1 } }
], { allowDiskUse: true })
```

### 12.5 索引管理

```javascript
// 查看所有索引
db.orders.getIndexes()

// 创建索引
db.orders.createIndex({ userId: 1, createTime: -1 }, {
  name: "idx_userid_time",
  background: true    // 非阻塞建索引（7.0+ 默认后台建索引）
})

// 创建唯一索引
db.orders.createIndex({ orderId: 1 }, { unique: true })

// 创建部分索引（只对满足条件的文档建索引）
db.orders.createIndex(
  { createTime: -1 },
  { partialFilterExpression: { status: "active" } }
)

// 查看索引使用统计
db.orders.aggregate([{ $indexStats: {} }])

// 删除索引
db.orders.dropIndex("idx_userid_time")

// 删除所有索引（_id 索引除外，谨慎！）
db.orders.dropIndexes()

// 触发索引重建（修复损坏/碎片化）
db.orders.reIndex()
```

### 12.6 慢查询与性能分析

```javascript
// 开启 Profiling（生产谨慎全量开启）
db.setProfilingLevel(0)           // 关闭
db.setProfilingLevel(1, { slowms: 100 })  // 只记录慢查询（推荐）
db.setProfilingLevel(2)           // 记录所有操作（慎用）

// 查看 Profiling 状态
db.getProfilingStatus()

// 查询慢操作日志
db.system.profile.find({
  millis: { $gt: 100 }
}).sort({ ts: -1 }).limit(20).pretty()

// 实时查看当前正在执行的操作
db.currentOp({ active: true })

// 终止某个慢操作（opid 从 currentOp 获取）
db.killOp(12345)

// 实时监控（类似 iostat）
mongostat --host 192.168.10.31 -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin -n 10

// 实时监控各集合的读写操作
mongotop --host 192.168.10.31 -u admin -p 'AdminStr0ngP@ss2026' --authenticationDatabase admin 5
```

### 12.7 分片集群运维

```javascript
// 连接 mongos 后执行
// 查看分片状态
sh.status()

// 查看集群整体状态
db.adminCommand({ listShards: 1 })

// 查看均衡器状态
sh.getBalancerState()
sh.isBalancerRunning()

// 停止均衡器（维护时使用）
sh.stopBalancer()
sh.startBalancer()

// 查看 Chunk 分布
db.adminCommand({ collStats: "yourdb.orders" })

// 手动触发 Chunk 迁移
sh.moveChunk("yourdb.orders", { userId: "u001" }, "rs-shard2")

// 查看分片分布不均情况
db.orders.getShardDistribution()
```

### 12.8 用户与权限管理

```javascript
// 查看当前用户
db.runCommand({ connectionStatus: 1 })

// 查看用户列表
use admin
db.system.users.find({}, { user: 1, roles: 1 }).pretty()

// 授予额外角色
db.grantRolesToUser("appuser", [{ role: "read", db: "anotherdb" }])

// 撤销角色
db.revokeRolesFromUser("appuser", [{ role: "readWrite", db: "yourdb" }])

// 更新用户密码
db.changeUserPassword("appuser", "NewP@ss2026")

// 删除用户
db.dropUser("username")
```

### 12.9 运维常用管理命令

```javascript
// 查看服务器状态（综合信息）
db.serverStatus()
db.serverStatus().connections      // 连接数统计
db.serverStatus().opcounters       // 各类操作计数
db.serverStatus().wiredTiger.cache // WT 缓存使用

// 刷新磁盘（将内存数据刷盘）
db.runCommand({ fsync: 1 })

// 锁定写入（配合快照备份）
db.runCommand({ fsyncLock: 1 })
db.runCommand({ fsyncUnlockDeprecated: 1 })  // 解锁

// 动态修改配置（7.0+ 更多参数支持动态修改）
db.adminCommand({ setParameter: 1, slowOpThresholdMs: 50 })

// 清理孤儿文档（分片集群 Shard 迁移后遗留）
db.adminCommand({ cleanupOrphaned: "yourdb.orders" })

// 查看数据库日志（最后 N 条）
db.adminCommand({ getLog: "global" })

// 优雅关闭
db.adminCommand({ shutdown: 1, timeoutSecs: 30 })
```

---

## 13. 常见问题排查

### 13.1 副本集选举失败

```javascript
// 现象：rs.status() 显示所有节点 state 为 SECONDARY，没有 PRIMARY
// 原因：投票节点不足（需要超过半数）

// 排查步骤
rs.status()   // 查看各节点状态和错误信息
// 检查 members[n].lastHeartbeatMessage 中的错误

// 强制重新配置（quorum 不足时紧急使用，数据可能损失）
rs.reconfig(cfg, { force: true })
```

### 13.2 复制延迟过高

```javascript
// 查看复制延迟
rs.printSecondaryReplicationInfo()

// 检查 oplog 是否足够
rs.printReplicationInfo()  // 查看 oplog 时间跨度（log length start to end）

// 如果 oplog 时间跨度 < 复制延迟，从节点会触发全同步
// 解决：增大 oplogSizeMB（需重启）

// 临时降低复制压力
db.adminCommand({ replSetSyncFrom: "192.168.10.31:27017" })  // 指定同步源
```

### 13.3 WiredTiger 缓存不足

```bash
# 现象：serverStatus().wiredTiger.cache 中 pages read into cache 持续增加
# 说明：缓存命中率低，大量磁盘 IO

# 检查缓存使用率
mongosh --eval 'db.serverStatus().wiredTiger.cache'

# 动态调整缓存（需要重启才能完全生效）
mongosh --eval 'db.adminCommand({ setParameter: 1, wiredTigerEngineRuntimeConfig: "cache_size=16G" })'
```

### 13.4 连接数耗尽

```javascript
// 查看连接数
db.serverStatus().connections
// current: 当前连接数
// available: 剩余可用连接数
// totalCreated: 历史总连接数

// 查看各客户端连接详情
db.currentOp(true)

// 找出空闲超长的连接并强制关闭
var ops = db.currentOp(true)
ops.inprog.filter(op => op.secs_running > 3600)
   .forEach(op => db.killOp(op.opid))
```

### 13.5 磁盘空间不足

```javascript
// 查看各数据库大小
db.adminCommand({ listDatabases: 1, nameOnly: false })

// 查看集合详情（含碎片）
db.orders.stats()
// storageSize: 实际占用空间
// size: 文档逻辑大小
// 差值大说明碎片多，可执行 compact

// 压缩数据库（生产需停写，或读副本执行）
db.runCommand({ compact: "orders" })

// 统计索引大小
db.orders.totalIndexSize()
```

---

## 附录：运维快查卡片

```
┌─────────────────────────────────────────────────────────────────┐
│                   MongoDB 生产运维快查                             │
├──────────────────────────┬──────────────────────────────────────┤
│  副本集状态               │  rs.status()                         │
│  谁是 Primary            │  rs.isMaster()                       │
│  复制延迟               │  rs.printSecondaryReplicationInfo()   │
│  oplog 使用情况          │  rs.printReplicationInfo()            │
│  手动降主               │  rs.stepDown()                        │
│  实时 QPS               │  mongostat（命令行工具）               │
│  实时热表               │  mongotop（命令行工具）                │
│  慢查询                 │  db.system.profile.find(...)          │
│  当前操作               │  db.currentOp({ active: true })      │
│  终止操作               │  db.killOp(opid)                     │
│  开启慢日志              │  db.setProfilingLevel(1,{slowms:100})│
│  索引使用统计            │  db.col.aggregate([{$indexStats:{}}]) │
│  查询计划分析            │  db.col.explain("executionStats").find│
│  分片状态               │  sh.status()                          │
│  均衡器开关              │  sh.stopBalancer() / sh.startBalancer │
│  集合分片分布            │  db.col.getShardDistribution()       │
│  全库备份               │  mongodump --oplog --gzip             │
│  全库恢复               │  mongorestore --oplogReplay --gzip    │
│  锁定写入（快照备份）     │  db.fsyncLock()                      │
│  WT 缓存状态            │  db.serverStatus().wiredTiger.cache   │
└──────────────────────────┴──────────────────────────────────────┘
```

---

## 14. Docker Compose 快速部署（测试 / 开发专用）

> ## ⚠️ 重要声明
>
> **以下 Docker Compose 方案仅用于本地开发和功能测试，严禁用于生产环境！**
>
> **原因：**
> - 容器内存限制会导致 WiredTiger 缓存行为异常
> - 单机伪集群，无法模拟真实网络分区、节点故障场景
> - 无 keyFile 内部认证、无 TLS 加密
> - 无内核参数优化（THP、vm.overcommit_memory 等）
> - 数据卷随 `docker compose down -v` 删除后全部丢失

---

### 14.1 方案一：副本集（1 Primary + 2 Secondary）

**目录结构：**
```
mongodb-replicaset/
├── docker-compose.yml
└── init-replica.js
```

**Step 1：创建初始化脚本**

```bash
mkdir -p ~/mongodb-replicaset && cd ~/mongodb-replicaset

# 副本集初始化脚本（容器启动后执行）
cat > init-replica.js << 'EOF'
// ⚠️ 测试用副本集初始化脚本
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },
    { _id: 1, host: "mongo2:27017", priority: 1 },
    { _id: 2, host: "mongo3:27017", priority: 1 }
  ]
});

// 等待选主完成
sleep(3000);

// 创建测试管理员
db = db.getSiblingDB("admin");
db.createUser({
  user: "admin",
  pwd: "TestMongo2026",
  roles: [{ role: "root", db: "admin" }]
});

print("✅ Replica Set initialized successfully!");
EOF
```

**Step 2：docker-compose.yml**

```yaml
# ============================================================
# MongoDB 副本集测试环境（1主 + 2从）
# ⚠️ 仅用于开发/测试，禁止用于生产！
# ============================================================
version: '3.8'

services:

  # ----------- MongoDB 节点 1（Primary 候选）-----------
  mongo1:
    image: mongo:7.0
    container_name: mongo1
    hostname: mongo1
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: TestMongo2026
    command: >
      mongod
      --replSet rs0
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.5
    volumes:
      - mongo1-data:/data/db
    networks:
      mongo-net:
        ipv4_address: 172.29.0.11
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  # ----------- MongoDB 节点 2（Secondary）-----------
  mongo2:
    image: mongo:7.0
    container_name: mongo2
    hostname: mongo2
    ports:
      - "27018:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: TestMongo2026
    command: >
      mongod
      --replSet rs0
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.5
    volumes:
      - mongo2-data:/data/db
    networks:
      mongo-net:
        ipv4_address: 172.29.0.12
    restart: unless-stopped

  # ----------- MongoDB 节点 3（Secondary）-----------
  mongo3:
    image: mongo:7.0
    container_name: mongo3
    hostname: mongo3
    ports:
      - "27019:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: TestMongo2026
    command: >
      mongod
      --replSet rs0
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.5
    volumes:
      - mongo3-data:/data/db
    networks:
      mongo-net:
        ipv4_address: 172.29.0.13
    restart: unless-stopped

  # ----------- 初始化容器（一次性任务）-----------
  mongo-init:
    image: mongo:7.0
    container_name: mongo-init
    volumes:
      - ./init-replica.js:/init-replica.js:ro
    networks:
      - mongo-net
    depends_on:
      mongo1:
        condition: service_healthy
    # 连接 mongo1 执行初始化脚本
    command: >
      mongosh --host mongo1:27017 --file /init-replica.js
    restart: "no"

volumes:
  mongo1-data:
  mongo2-data:
  mongo3-data:

networks:
  mongo-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.29.0.0/24
```

**Step 3：启动与验证**

```bash
# 启动（等待 init 容器完成初始化，约 30~60 秒）
docker compose up -d

# 观察初始化日志
docker logs -f mongo-init
# 看到 "✅ Replica Set initialized successfully!" 即成功

# 验证副本集状态
docker exec mongo1 mongosh -u admin -p TestMongo2026 --authenticationDatabase admin \
    --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"
# 预期：mongo1:27017 PRIMARY  mongo2:27017 SECONDARY  mongo3:27017 SECONDARY

# 测试写入
docker exec mongo1 mongosh -u admin -p TestMongo2026 --authenticationDatabase admin \
    --eval "use testdb; db.col.insertOne({name:'test', ts: new Date()})"

# 验证从节点复制（在 mongo2 读取）
docker exec mongo2 mongosh -u admin -p TestMongo2026 --authenticationDatabase admin \
    --eval "db.getMongo().setReadPref('secondary'); use testdb; db.col.find()"

# 模拟 Primary 故障
docker stop mongo1
# 等待约 10 秒，查看是否自动选出新 Primary
docker exec mongo2 mongosh -u admin -p TestMongo2026 --authenticationDatabase admin \
    --eval "rs.isMaster().ismaster"   # 预期 true（mongo2 成为新 Primary）

# 恢复
docker start mongo1

# 停止并清理
docker compose down -v
```

**客户端连接字符串（本地测试）：**

```
mongodb://admin:TestMongo2026@localhost:27017,localhost:27018,localhost:27019/testdb?replicaSet=rs0&authSource=admin
```

---

### 14.2 方案二：分片集群（简化版：1 Config + 2 Shard + 1 mongos）

> 完整的分片集群（3×3+3 共 15 节点）资源消耗过大，此处提供**最小可用分片集群**用于功能验证，每个角色只部署 1 个节点（无副本）。

**docker-compose.yml**

```yaml
# ============================================================
# MongoDB 分片集群测试环境（最小化：1 Config + 2 Shard + 1 mongos）
# ⚠️ 每个角色单节点（无HA），仅用于开发/测试，禁止用于生产！
# ============================================================
version: '3.8'

services:

  # ----------- Config Server（单节点副本集）-----------
  configsvr:
    image: mongo:7.0
    container_name: mongo-configsvr
    hostname: configsvr
    ports:
      - "27019:27017"
    command: >
      mongod
      --configsvr
      --replSet rs-config
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.25
    volumes:
      - configsvr-data:/data/db
    networks:
      mongo-shard-net:
        ipv4_address: 172.30.0.10
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s

  # ----------- Shard 1（单节点副本集）-----------
  shard1:
    image: mongo:7.0
    container_name: mongo-shard1
    hostname: shard1
    ports:
      - "27018:27017"
    command: >
      mongod
      --shardsvr
      --replSet rs-shard1
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.5
    volumes:
      - shard1-data:/data/db
    networks:
      mongo-shard-net:
        ipv4_address: 172.30.0.11
    restart: unless-stopped

  # ----------- Shard 2（单节点副本集）-----------
  shard2:
    image: mongo:7.0
    container_name: mongo-shard2
    hostname: shard2
    ports:
      - "27020:27017"
    command: >
      mongod
      --shardsvr
      --replSet rs-shard2
      --bind_ip_all
      --wiredTigerCacheSizeGB 0.5
    volumes:
      - shard2-data:/data/db
    networks:
      mongo-shard-net:
        ipv4_address: 172.30.0.12
    restart: unless-stopped

  # ----------- mongos 路由器-----------
  mongos:
    image: mongo:7.0
    container_name: mongo-mongos
    hostname: mongos
    ports:
      - "27017:27017"
    # mongos 无需数据目录，直接指向 configsvr
    command: >
      mongos
      --configdb rs-config/configsvr:27017
      --bind_ip_all
    networks:
      mongo-shard-net:
        ipv4_address: 172.30.0.20
    depends_on:
      - configsvr
      - shard1
      - shard2
    restart: unless-stopped

  # ----------- 初始化容器（一次性任务）-----------
  mongo-shard-init:
    image: mongo:7.0
    container_name: mongo-shard-init
    networks:
      - mongo-shard-net
    depends_on:
      configsvr:
        condition: service_healthy
    command: >
      bash -c "
        sleep 10
        echo '--- Init Config Server RS ---'
        mongosh --host configsvr:27017 --eval \"rs.initiate({_id:'rs-config',configsvr:true,members:[{_id:0,host:'configsvr:27017'}]})\"
        sleep 5
        echo '--- Init Shard1 RS ---'
        mongosh --host shard1:27017 --eval \"rs.initiate({_id:'rs-shard1',members:[{_id:0,host:'shard1:27017'}]})\"
        sleep 5
        echo '--- Init Shard2 RS ---'
        mongosh --host shard2:27017 --eval \"rs.initiate({_id:'rs-shard2',members:[{_id:0,host:'shard2:27017'}]})\"
        sleep 10
        echo '--- Add Shards to Cluster ---'
        mongosh --host mongos:27017 --eval \"sh.addShard('rs-shard1/shard1:27017')\"
        mongosh --host mongos:27017 --eval \"sh.addShard('rs-shard2/shard2:27017')\"
        echo '--- Create Admin User ---'
        mongosh --host mongos:27017 --eval \"
          use admin;
          db.createUser({user:'admin',pwd:'TestShard2026',roles:[{role:'root',db:'admin'}]});
        \"
        echo '✅ Sharded Cluster initialized!'
      "
    restart: "no"

volumes:
  configsvr-data:
  shard1-data:
  shard2-data:

networks:
  mongo-shard-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/24
```

**启动与验证**

```bash
# 启动（等待约 60 秒初始化完成）
docker compose up -d

# 观察初始化日志
docker logs -f mongo-shard-init
# 看到 "✅ Sharded Cluster initialized!" 即成功

# 验证集群状态
docker exec mongo-mongos mongosh -u admin -p TestShard2026 --authenticationDatabase admin \
    --eval "sh.status()"
# 预期看到两个 Shard 和它们的状态

# 对数据库启用分片
docker exec mongo-mongos mongosh -u admin -p TestShard2026 --authenticationDatabase admin \
    --eval "sh.enableSharding('testdb'); sh.shardCollection('testdb.orders', {_id: 'hashed'})"

# 写入测试数据
docker exec mongo-mongos mongosh -u admin -p TestShard2026 --authenticationDatabase admin \
    --eval "
      use testdb;
      for(let i=0; i<1000; i++) db.orders.insertOne({orderId:i, amount:Math.random()*1000});
      print('Inserted 1000 docs');
    "

# 查看分片分布
docker exec mongo-mongos mongosh -u admin -p TestShard2026 --authenticationDatabase admin \
    --eval "use testdb; db.orders.getShardDistribution()"

# 停止并清理
docker compose down -v
```

**客户端连接字符串（通过 mongos 路由）：**

```
mongodb://admin:TestShard2026@localhost:27017/testdb?authSource=admin
```

> 💡 **提示**：连接分片集群时直接连接 `mongos` 端口即可，客户端无需感知分片架构，mongos 自动路由请求。
