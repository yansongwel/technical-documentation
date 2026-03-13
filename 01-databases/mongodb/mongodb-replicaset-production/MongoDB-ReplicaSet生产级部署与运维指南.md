---
title: MongoDB-ReplicaSet 生产级部署与运维指南
author: devinyan
updated: 2026-03-13
version: v1.0
middleware_version: 7.0.30
cluster_mode: Replica Set
verified: true
---

> [TOC]

# MongoDB-ReplicaSet 生产级部署与运维指南

## 1. 简介

### 1.1 服务介绍与核心特性

MongoDB 是基于文档模型的 NoSQL 数据库，以 BSON（二进制 JSON）格式存储数据。Replica Set（副本集）是 MongoDB 官方内置的高可用复制方案，核心特性：

- **主从复制**：单主多从，主节点承载全部写入，从节点异步复制
- **自动 Failover**：主节点宕机时，从节点自动选举新主（秒级切换）
- **读写分离**：支持 `readPreference` 将读请求路由到从节点
- **数据冗余**：多副本保证单点故障不丢数据
- **事务支持**：4.0+ 支持多文档 ACID 事务，7.0 大幅优化事务性能

### 1.2 适用场景

| 场景 | 说明 |
|------|------|
| 业务主库 | 订单、用户、配置等核心业务数据，需高可用 |
| 会话存储 | 分布式 Session，支持 TTL 索引自动过期 |
| 内容管理 | 半结构化文档、富文本、元数据存储 |
| 日志/埋点 | 高写入量、Schema 灵活变化的日志类数据 |
| 配置中心 | 微服务配置存储，支持变更通知 |

### 1.3 架构原理图

```mermaid
graph TB
    subgraph Client["客户端层"]
        style Client fill:#e1f5fe,stroke:#0288d1
        APP["应用程序"]
        DRV["MongoDB Driver<br/>(replicaSet=rs0)"]
        APP --> DRV
    end

    subgraph RS["Replica Set rs0（3 节点）"]
        style RS fill:#fff3e0,stroke:#f57c00

        subgraph Primary["Primary"]
            style Primary fill:#c8e6c9,stroke:#388e3c
            P["mongod<br/>192.168.1.101:27017<br/>读写"]
        end
        subgraph Sec1["Secondary-1"]
            style Sec1 fill:#f3e5f5,stroke:#7b1fa2
            S1["mongod<br/>192.168.1.102:27017<br/>只读"]
        end
        subgraph Sec2["Secondary-2"]
            style Sec2 fill:#f3e5f5,stroke:#7b1fa2
            S2["mongod<br/>192.168.1.103:27017<br/>只读"]
        end

        P -->|"oplog 复制"| S1
        P -->|"oplog 复制"| S2
        S1 -.->|"心跳/选举"| S2
        S1 -.->|"心跳/选举"| P
        S2 -.->|"心跳/选举"| P
    end

    DRV -->|"写 + 主读"| P
    DRV -->|"读（secondaryPreferred）"| S1
    DRV -->|"读（secondaryPreferred）"| S2
```

### 1.4 版本说明

> 以下版本号均通过 Docker Hub + 官方仓库实际查询确认（2026-03-13 验证）。

| 组件 | 版本 | 兼容性 |
|------|------|--------|
| **MongoDB Server** | 7.0.30 | Linux x86_64 / ARM64 |
| **mongosh** | 2.7.0（随 mongodb-org 安装） | — |
| **mongodb_exporter** | v0.40.0+（Prometheus 指标导出） | 兼容 MongoDB 5.x-8.x |
| **操作系统** | Rocky Linux 9.x / Ubuntu 22.04 LTS 或 24.04 LTS | 内核 ≥ 5.4 |

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| MongoDB 大版本 | 发布周期 | Replica Set 支持 | 关键特性 |
|----------------|---------|------------------|---------|
| **8.x**（当前最新） | 2025+ | 完整支持 | 并发写入 +20%、读吞吐 +36%、`null` 查询语义变更 |
| **7.x**（LTS） | 2023-2027 | 完整支持 | 事务性能提升、复合通配索引、可查询加密 GA |
| **6.x** | 2022-2024 | 完整支持 | 可查询加密预览、聚合增强 |

> 📌 注意：7.x → 8.x 升级需评估 `null` 查询语义变更。详见 [MongoDB 集群方案选型指南](../MongoDB集群方案选型指南.md)。

### 2.2 版本决策建议

| 场景 | 建议 |
|------|------|
| **新建集群** | 优先 7.0.30（LTS 至 2027），或 8.2.x（需评估业务兼容性） |
| **现有 7.x 集群** | 可滚动升级至 8.x，注意 `null` 查询语义 |
| **现有 6.x 集群** | 必须先升级至 7.x，再升级至 8.x |

---

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

```mermaid
graph LR
    subgraph AZ1["可用区 A / 机架 A"]
        style AZ1 fill:#e8f5e9,stroke:#4caf50
        P["Primary<br/>192.168.1.101<br/>读写"]
    end

    subgraph AZ2["可用区 B / 机架 B"]
        style AZ2 fill:#e3f2fd,stroke:#2196f3
        S1["Secondary-1<br/>192.168.1.102<br/>只读"]
    end

    subgraph AZ3["可用区 C / 机架 C"]
        style AZ3 fill:#fce4ec,stroke:#e91e63
        S2["Secondary-2<br/>192.168.1.103<br/>只读"]
    end

    P -->|"oplog 复制"| S1
    P -->|"oplog 复制"| S2
```

> ⚠️ **关键设计**：主从节点必须分布在不同可用区/机架，确保单个可用区故障时集群仍可选举出主节点。

### 3.2 节点角色与配置要求

| 角色 | 数量 | 最低配置 | 推荐配置 | 说明 |
|------|------|---------|---------|------|
| Primary | 1 | 4C 8G 200G SSD | 8C 32G 500G NVMe SSD | 承载全部写入，WiredTiger 缓存建议物理内存 40%-50% |
| Secondary | 2 | 4C 8G 200G SSD | 8C 32G 500G NVMe SSD | 故障接管 + 读分离 |

> ⚠️ **内存规划**：`storage.wiredTiger.engineConfig.cacheSizeGB` 建议设为物理内存的 **40%-50%**。

### 3.3 网络与端口规划

| 源 | 目标端口 | 协议 | 用途 |
|----|---------|------|------|
| 客户端 → mongod | 27017/tcp | MongoDB Wire Protocol | 数据读写、管理 |
| mongod ↔ mongod | 27017/tcp | MongoDB Wire Protocol | oplog 复制、心跳、选举 |
| 运维机 → mongod | 27017/tcp | MongoDB Wire Protocol | mongosh 管理 |
| Prometheus → mongodb_exporter | 9216/tcp | HTTP | 指标采集 |

---

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

> 🖥️ **执行节点：所有节点（3 台）**

#### 4.1.1 系统优化

```bash
cat > /etc/sysctl.d/99-mongodb.conf << 'EOF'
vm.swappiness = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
EOF

sysctl -p /etc/sysctl.d/99-mongodb.conf
```

```bash
# ★ 关闭 Transparent Huge Pages（THP）—— MongoDB 强烈建议关闭
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never > /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/defrag'

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now disable-thp.service
```

```bash
# ✅ 验证
cat /sys/kernel/mm/transparent_hugepage/enabled
# 预期输出：always madvise [never]
```

```bash
cat > /etc/security/limits.d/99-mongodb.conf << 'EOF'
mongod soft nofile 65535
mongod hard nofile 65535
mongod soft nproc 65535
mongod hard nproc 65535
EOF
```

#### 4.1.2 创建目录与 keyfile

```bash
mkdir -p /data/mongodb/{data,log}
mkdir -p /etc/mongodb
mkdir -p /backup/mongodb

# 生成 keyfile（在任意一台节点执行，然后同步到其他节点）
openssl rand -base64 756 > /etc/mongodb/keyfile
chmod 400 /etc/mongodb/keyfile
chown mongod:mongod /etc/mongodb/keyfile

# 将 keyfile 同步到其他节点（替换为实际 IP）
# for host in 192.168.1.102 192.168.1.103; do
#   scp /etc/mongodb/keyfile root@${host}:/etc/mongodb/keyfile
#   ssh root@${host} "chown mongod:mongod /etc/mongodb/keyfile && chmod 400 /etc/mongodb/keyfile"
# done
```

#### 4.1.3 防火墙配置

```bash
# ── Rocky Linux 9（firewalld）──────────────
firewall-cmd --permanent --add-port=27017/tcp
firewall-cmd --reload

# ✅ 验证
firewall-cmd --list-ports
# 预期输出包含：27017/tcp
```

```bash
# ── Ubuntu 22.04（差异）────────────────────
# ufw allow 27017/tcp
# ufw reload
```

> 📌 注意：云主机通常在安全组中配置端口规则，无需操作 firewalld/ufw。

### 4.2 部署步骤

> 🖥️ **执行节点：所有节点（3 台）**

#### 4.2.1 添加 MongoDB 官方仓库并安装

```bash
# ── Rocky Linux 9 ──────────────────────────
cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'EOF'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

dnf install -y mongodb-org

# 锁定版本（防止意外升级）
echo "exclude=mongodb-org,mongodb-org-database,mongodb-org-server,mongodb-mongosh,mongodb-org-tools" >> /etc/yum.conf
```

```bash
# ── Ubuntu 22.04（差异）────────────────────
# curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
#   gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
# echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
#   tee /etc/apt/sources.list.d/mongodb-org-7.0.list
# apt-get update && apt-get install -y mongodb-org
# echo "mongodb-org hold" | dpkg --set-selections
```

```bash
# ✅ 验证
mongod --version
# 预期输出：db version v7.0.30

mongosh --version
# 预期输出：2.7.0
```

#### 4.2.2 配置文件

> 🖥️ **执行节点：每个节点分别配置（修改 `net.bindIp`）**

以 Primary 候选节点（192.168.1.101）为例，其他节点替换对应 IP：

```bash
cat > /etc/mongod.conf << 'EOF'
# ============================================================
# MongoDB 生产配置（Replica Set）
# 节点：192.168.1.101 ← 根据实际 IP 修改
# ============================================================

systemLog:
  destination: file
  path: /data/mongodb/log/mongod.log
  logAppend: true
  verbosity: 0

storage:
  dbPath: /data/mongodb/data
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 14                    # ★ ← 根据物理内存调整，建议 40%-50%
      journalCompressor: zstd
    collectionConfig:
      blockCompressor: zstd

net:
  port: 27017
  bindIp: 192.168.1.101,127.0.0.1        # ★ ← 根据本节点实际 IP 修改
  maxIncomingConnections: 20000
  compression:
    compressors: snappy,zlib,zstd

processManagement:
  timeZoneInfo: /usr/share/zoneinfo

replication:
  replSetName: rs0                        # ★ ← 副本集名称，所有节点一致
  oplogSizeMB: 2048                       # ★ ← 写入量大时建议 5120 或更大

security:
  authorization: enabled
  keyFile: /etc/mongodb/keyfile

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 200                 # ★ ← 慢操作阈值（ms）
  slowOpSampleRate: 1.0
EOF

chown mongod:mongod /etc/mongod.conf
chmod 640 /etc/mongod.conf
```

```bash
chown -R mongod:mongod /data/mongodb /etc/mongodb
```

#### 4.2.3 启动服务

```bash
mkdir -p /etc/systemd/system/mongod.service.d
cat > /etc/systemd/system/mongod.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/mongod --config /etc/mongod.conf
EOF

systemctl daemon-reload
systemctl enable --now mongod
```

```bash
# ✅ 验证
systemctl status mongod
# 预期输出：Active: active (running)
```

### 4.3 集群初始化与配置

> 🖥️ **执行节点：任意一台节点（建议 Primary 候选）**

确认 3 个节点全部启动后，在**任意一台**执行初始化（此时尚未开启认证，可直连）：

```bash
mongosh --host 192.168.1.101 --port 27017 --eval "
rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: '192.168.1.101:27017', priority: 2 },
    { _id: 1, host: '192.168.1.102:27017', priority: 1 },
    { _id: 2, host: '192.168.1.103:27017', priority: 1 }
  ]
})
"
```

> ⚠️ `host` 必须使用**其他节点可解析的地址**（IP 或 DNS），不能使用 `localhost`。

等待约 30 秒后，创建管理员用户（**必须在 Primary 上执行**）：

```bash
sleep 30

mongosh --host 192.168.1.101 --port 27017 --eval "
db.getSiblingDB('admin').createUser({
  user: 'admin',
  pwd: 'YourStr0ngP@ssw0rd!',           // ★ ← 根据实际环境修改
  roles: [
    { role: 'root', db: 'admin' }
  ]
})
"
```

> ⚠️ 创建用户后，`security.authorization: enabled` 生效，后续所有操作需认证。

### 4.4 安装验证

> 🖥️ **执行节点：任意一台节点**

```bash
# ✅ 验证副本集状态
mongosh --host 192.168.1.101 --port 27017 -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr, health: m.health}))"
# 预期输出：1 个 PRIMARY、2 个 SECONDARY，health 均为 1
```

```bash
# ✅ 验证连接
mongosh --host 192.168.1.101 --port 27017 -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "db.adminCommand({ping:1})"
# 预期输出：{ ok: 1, ... }
```

```bash
# ✅ 验证读写（副本集连接串自动路由到 Primary）
mongosh "mongodb://admin:YourStr0ngP@ssw0rd!@192.168.1.101:27017,192.168.1.102:27017,192.168.1.103:27017/?replicaSet=rs0&authSource=admin" --eval "
db = db.getSiblingDB('test');
db.verify.insertOne({ts: new Date(), note: 'deploy-check'});
db.verify.find().toArray();
"
# 预期输出：包含插入的文档
```

---

## 5. 关键参数配置说明

### 5.1 核心参数分类汇总

| 分类 | 参数 | 推荐值 | 说明 |
|------|------|--------|------|
| **存储** | `storage.wiredTiger.engineConfig.cacheSizeGB` | 物理内存 40%-50% | ★ WiredTiger 缓存 |
| **存储** | `storage.wiredTiger.collectionConfig.blockCompressor` | `zstd` | 压缩比优于 snappy |
| **复制** | `replication.replSetName` | `rs0` | 所有节点必须一致 |
| **复制** | `replication.oplogSizeMB` | 2048～51200 | ★ 写入量大时增大 |
| **安全** | `security.authorization` | `enabled` | ★ 生产必须开启 |
| **安全** | `security.keyFile` | `/etc/mongodb/keyfile` | 副本集内部认证 |
| **网络** | `net.bindIp` | 内网 IP + 127.0.0.1 | ★ 禁止 0.0.0.0 |
| **profiling** | `operationProfiling.mode` | `slowOp` | 仅记录慢操作 |
| **profiling** | `operationProfiling.slowOpThresholdMs` | 200 | 超过此值记入 system.profile |

### 5.2 oplog 大小规划

| 写入量 | 建议 oplogSizeMB |
|--------|------------------|
| 低（< 1GB/天） | 2048 |
| 中（1-10GB/天） | 10240 |
| 高（> 10GB/天） | 51200 或更大 |

> ⚠️ oplog 过小会导致从节点落后时触发全量同步，影响可用性。

---

## 6. 快速体验部署（开发 / 测试环境）

> ⚠️ **本章方案仅适用于开发/测试环境，严禁用于生产。** 使用 Docker Compose 在单机模拟 3 节点副本集。

### 6.1 快速启动方案选型

Replica Set 最少需要 3 个节点，选择 Docker Compose 在单机启动 3 个容器模拟集群，是最便捷的体验方式。

### 6.2 快速启动步骤与验证

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
# .env 已预设 MONGO_VERSION=7.0.30（与验证版本一致）

docker compose up -d
```

```bash
# 等待健康检查通过（约 60 秒）
sleep 60

# ✅ 验证副本集状态
docker exec mongo1 mongosh --quiet -u admin -p ChangeMe_ThisIsNotSafe --authenticationDatabase admin --eval "rs.status().members.map(m => ({name: m.name, stateStr: m.stateStr, health: m.health}))"
# 预期输出：1 个 PRIMARY，2 个 SECONDARY，health 均为 1
```

```bash
# ✅ 验证读写（连接任一节点，驱动会自动路由到 Primary）
docker exec mongo2 mongosh --quiet -u admin -p ChangeMe_ThisIsNotSafe --authenticationDatabase admin --eval "
db = db.getSiblingDB('app_db');
db.test.insertOne({name: 'verify', ts: new Date()});
db.test.find().toArray();
"
# 预期输出：包含插入的文档
```

### 6.3 停止与清理

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
docker compose down -v
docker system prune -f
```

---

## 7. 日常运维操作

### 7.1 常用管理命令

#### 副本集状态检查

```bash
# 副本集整体状态
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "rs.status()"

# 副本集配置
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "rs.conf()"

# 当前主节点
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "db.hello().primary"

# 从节点复制延迟
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "rs.printSecondaryReplicationInfo()"
```

#### 手动 Failover

```bash
# 在 Primary 上执行（安全 failover，等待从节点同步完成）
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "rs.stepDown(60)"
```

#### 慢查询与性能

```bash
# 当前操作
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "db.currentOp()"

# 服务器状态
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "db.serverStatus()"
```

### 7.2 备份与恢复

#### mongodump 逻辑备份

```bash
# 全量备份（在 Primary 或 Secondary 上执行）
mongodump --uri="mongodb://admin:YourStr0ngP@ssw0rd!@192.168.1.101:27017,192.168.1.102:27017,192.168.1.103:27017/?replicaSet=rs0&authSource=admin" \
  --out=/backup/mongodb/dump-$(date +%Y%m%d%H%M%S) \
  --gzip

# 恢复
mongorestore --uri="mongodb://admin:YourStr0ngP@ssw0rd!@192.168.1.101:27017/?authSource=admin" \
  --dir=/backup/mongodb/dump-20260313160000 \
  --gzip
```

### 7.3 集群扩缩容

#### 添加节点

```bash
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "
rs.add({host: '192.168.1.104:27017', priority: 1})
"
```

#### 移除节点

```bash
mongosh -u admin -p 'YourStr0ngP@ssw0rd!' --authenticationDatabase admin --eval "
rs.remove('192.168.1.104:27017')
"
```

### 7.4 版本升级

#### 滚动升级步骤（不停机）

```
1. 先升级所有 Secondary 节点（逐个操作）
2. 在 Primary 上执行 rs.stepDown(60)，等待 Primary 切换
3. 升级原 Primary（现已降为 Secondary）
4. 完成
```

#### 回滚方案

```
1. 停止已升级节点：systemctl stop mongod
2. 降级包：dnf downgrade mongodb-org
3. 启动服务
```

> ⚠️ 升级前务必执行 mongodump 全量备份至 `/backup/mongodb/`。

---

## 8. 使用手册（数据库专项）

### 8.1 连接与认证

```bash
# 单节点连接
mongosh "mongodb://admin:YourStr0ngP@ssw0rd!@192.168.1.101:27017/?authSource=admin"

# 副本集连接（推荐，自动故障转移）
mongosh "mongodb://admin:YourStr0ngP@ssw0rd!@192.168.1.101:27017,192.168.1.102:27017,192.168.1.103:27017/?replicaSet=rs0&authSource=admin"

# 读优先从节点
mongosh "mongodb://.../?replicaSet=rs0&readPreference=secondaryPreferred"
```

### 8.2 库/集合/索引管理

```javascript
// 创建索引
db.mycol.createIndex({field: 1})
db.mycol.createIndex({field: 1}, {unique: true})

// 查看索引
db.mycol.getIndexes()
```

### 8.3 数据增删改查（CRUD）

```javascript
// 插入
db.mycol.insertOne({name: "test", ts: new Date()})

// 查询
db.mycol.find({status: "active"})
db.mycol.findOne({_id: ObjectId("...")})

// 更新
db.mycol.updateOne({_id: id}, {$set: {status: "done"}})

// 删除
db.mycol.deleteOne({_id: id})
```

### 8.4 用户与权限管理

```javascript
// 创建应用用户
db.getSiblingDB('admin').createUser({
  user: 'appuser',
  pwd: 'AppP@ssw0rd',
  roles: [{ role: 'readWrite', db: 'mydb' }]
})

// 查看用户
db.getSiblingDB('admin').getUsers()
```

### 8.5 主从/副本集状态监控

```javascript
rs.status()       // 副本集状态
rs.conf()         // 副本集配置
rs.printSecondaryReplicationInfo()  // 从节点复制延迟
db.hello()        // 当前节点角色与选举信息
```

---

## 9. 监控与告警接入

### 9.1 Prometheus 指标暴露（mongodb_exporter）

```bash
# 下载 mongodb_exporter
cd /tmp
[ -f mongodb_exporter-0.40.0.linux-amd64.tar.gz ] || \
  wget -O mongodb_exporter-0.40.0.linux-amd64.tar.gz \
  "https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-amd64.tar.gz"

tar xzf mongodb_exporter-0.40.0.linux-amd64.tar.gz
cp mongodb_exporter-0.40.0.linux-amd64/mongodb_exporter /usr/local/bin/
chmod +x /usr/local/bin/mongodb_exporter
```

```bash
cat > /etc/systemd/system/mongodb-exporter.service << 'EOF'
[Unit]
Description=MongoDB Exporter for Prometheus
After=network.target

[Service]
Type=simple
User=mongod
ExecStart=/usr/local/bin/mongodb_exporter \
  --mongodb.uri="mongodb://admin:YourStr0ngP@ssw0rd!@127.0.0.1:27017/?authSource=admin" \
  --web.listen-address=:9216
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mongodb-exporter.service
```

```bash
# ✅ 验证
curl -s http://localhost:9216/metrics | grep "mongodb_up"
# 预期输出：mongodb_up 1
```

### 9.2 关键监控指标

| 指标名 | 含义 | 告警阈值 |
|--------|------|---------|
| `mongodb_up` | 实例是否可达 | = 0 告警（Critical） |
| `mongodb_connections_current` | 当前连接数 | > maxIncomingConnections × 80% 告警 |
| `mongodb_replset_member_state` | 副本集成员状态 | 1=Primary, 2=Secondary，其他异常 |
| `mongodb_replset_lag` | 从节点复制延迟 | > 10s 告警 |

### 9.3 Grafana Dashboard 推荐

| Dashboard | ID | 说明 |
|-----------|----|------|
| **MongoDB Overview** | `2583` | Percona MongoDB 监控面板 |
| **MongoDB Cluster** | `12090` | 副本集/分片集群视图 |

---

## 10. 注意事项与生产检查清单

### 10.1 安装前环境核查

| 检查项 | 命令 | 预期结果 |
|--------|------|---------|
| THP 已关闭 | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `[never]` |
| 文件描述符 | `ulimit -n`（mongod 用户） | ≥ 65535 |
| 防火墙端口 | `firewall-cmd --list-ports` | 包含 `27017/tcp` |
| 数据目录权限 | `ls -la /data/mongodb/` | 属主为 `mongod:mongod` |
| 时钟同步 | `timedatectl status` | NTP 已同步 |
| keyfile 一致 | 三台节点 `md5sum /etc/mongodb/keyfile` | 校验和相同 |

### 10.2 常见故障排查

#### 副本集无法选举 Primary

- **现象**：`rs.status()` 显示无 PRIMARY，或 `NotYetInitialized`
- **原因**：多数节点不可达、keyfile 不一致、网络隔离
- **排查**：检查三台节点 mongod 是否运行、27017 端口互通、keyfile 是否一致、`host` 是否可解析
- **解决**：修复网络/keyfile 后，在任意节点重新 `rs.initiate()` 或 `rs.reconfig()`

#### 从节点复制严重落后

- **现象**：`rs.printSecondaryReplicationInfo()` 显示 oplog 落后数小时
- **原因**：oplog 过小、从节点 I/O 慢、主节点写入量突增
- **解决**：增大 `oplogSizeMB` 并重启

### 10.3 安全加固建议

| 措施 | 说明 |
|------|------|
| **强密码** | 管理员密码 ≥ 16 位，含大小写+数字+特殊字符 |
| **最小权限** | 为每个应用创建独立用户，仅授予所需库的 readWrite |
| **bindIp 限制** | 仅绑定内网 IP，禁止 `0.0.0.0` |
| **TLS 加密** | 跨机房/公网传输时启用 `net.tls.mode: requireTLS` |
| **定期备份** | Crontab 定时 mongodump 或文件系统快照 |

---

## 11. 参考资料

| 资源 | 链接 |
|------|------|
| MongoDB 官方文档 | [https://www.mongodb.com/docs/](https://www.mongodb.com/docs/) |
| Replica Set 部署 | [https://www.mongodb.com/docs/manual/replication/](https://www.mongodb.com/docs/manual/replication/) |
| MongoDB 7.0 Release Notes | [https://www.mongodb.com/docs/manual/release-notes/7.0/](https://www.mongodb.com/docs/manual/release-notes/7.0/) |
| mongodb_exporter | [https://github.com/percona/mongodb_exporter](https://github.com/percona/mongodb_exporter) |
| 选型指南 | [MongoDB 集群方案选型指南](../MongoDB集群方案选型指南.md) |
