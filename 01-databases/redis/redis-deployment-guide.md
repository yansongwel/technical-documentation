# Redis 生产级集群部署指南

> **版本推荐**：Redis 7.2.x（LTS）
> **更新时间**：2026-03
> **覆盖模式**：单机 → Sentinel 哨兵 → Cluster 集群（三种生产方案）

---

## 目录

1. [简介与版本选型](#1-简介与版本选型)
2. [部署模式选型](#2-部署模式选型)
3. [环境规划](#3-环境规划)
4. [安装 Redis](#4-安装-redis)
5. [方案一：Redis Sentinel 哨兵模式](#5-方案一redis-sentinel-哨兵模式)
6. [方案二：Redis Cluster 集群模式](#6-方案二redis-cluster-集群模式)
7. [生产级 redis.conf 全量配置注释](#7-生产级-redisconf-全量配置注释)
8. [性能调优](#8-性能调优)
9. [安全加固](#9-安全加固)
10. [监控接入](#10-监控接入)
11. [常用运维命令大全](#11-常用运维命令大全)
12. [常见问题排查](#12-常见问题排查)

---

## 1. 简介与版本选型

### 1.1 Redis 简介

Redis 是基于内存的高性能 **Key-Value 数据库**，支持字符串、哈希、列表、集合、有序集合、Stream 等多种数据结构，广泛用于：

- 🚀 **缓存**：减轻数据库压力，提升响应速度
- 🔒 **分布式锁**：基于 SETNX / Redlock 实现
- 📊 **计数器 / 限流**：原子操作，天然并发安全
- 📨 **消息队列**：List BLPOP / Stream（轻量级 MQ）
- 🗂 **会话存储**：Session 集中管理

### 1.2 版本选型

| 版本 | 主要特性 | 状态 | 推荐 |
|------|---------|------|------|
| Redis 5.x | Stream 数据结构引入 | EOL | ❌ 不推荐 |
| Redis 6.x | ACL 访问控制、TLS、多线程 I/O | 维护中 | ⚠️ 可用 |
| **Redis 7.0.x** | Redis Functions、Sharded Pub/Sub | 稳定 | ✅ 推荐 |
| **Redis 7.2.x** | 性能提升、LMPOP/LPOS 新命令 | **LTS** | ✅ **生产首选** |
| Redis 7.4.x | 新特性持续引入 | 最新 | ⚠️ 观望中 |

> **生产建议**：选择 **Redis 7.2.x LTS**，兼顾稳定性与现代特性。新项目不建议使用 6.x 及以下版本。

### 1.3 Redis 7.x 关键改进

```
Redis 7.0+
  ├── Redis Functions：替代 EVAL，函数持久化存储在 RDB/AOF 中
  ├── ACLv2：更精细的命令/Key 权限控制
  ├── Listpack：内存优化数据结构（替代 ziplist）
  └── Multi-Part AOF：AOF 文件拆分，减少 rewrite 开销

Redis 7.2+
  ├── LMPOP / BLMPOP：批量弹出，减少轮询
  ├── SINTERCARD：集合交集基数统计
  └── 模块 API 增强
```

---

## 2. 部署模式选型

```
┌─────────────┬──────────────────┬─────────────────┬─────────────────────┐
│  模式        │  单机 Standalone  │  Sentinel 哨兵   │  Cluster 集群        │
├─────────────┼──────────────────┼─────────────────┼─────────────────────┤
│  节点数      │  1               │  ≥3（1主2从+3哨兵）│  ≥6（3主3从）        │
│  数据量      │  < 16GB          │  < 单机内存上限   │  TB 级，自动分片      │
│  高可用      │  ❌              │  ✅ 自动故障切换  │  ✅ 自动故障切换      │
│  水平扩展    │  ❌              │  ❌ 只能垂直扩展  │  ✅ 动态加减节点      │
│  运维复杂度  │  低              │  中              │  高                  │
│  适用场景    │  开发/测试        │  中小型生产      │  大型/海量数据生产    │
└─────────────┴──────────────────┴─────────────────┴─────────────────────┘
```

**生产选型建议：**
- **数据量 < 30GB，读写分离需求** → **Sentinel**（简单可靠，运维成本低）
- **数据量 > 30GB，需水平扩展** → **Cluster**（分片存储，线性扩容）
- **极致高可用（如金融场景）** → Cluster + 同城双活

---

## 3. 环境规划

### 3.1 Sentinel 哨兵模式节点规划

```
┌────────────────────────────────────────────────────────┐
│                   客户端（通过哨兵发现主节点）              │
└─────────────────────────┬──────────────────────────────┘
                          │ 询问主节点地址
           ┌──────────────┼──────────────┐
           ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │Sentinel-1│   │Sentinel-2│   │Sentinel-3│
    │:26379    │   │:26379    │   │:26379    │
    └──────────┘   └──────────┘   └──────────┘
          │ 监控              │ 投票故障切换
          ▼                  ▼
    ┌──────────┐       ┌──────────┐   ┌──────────┐
    │ Master   │──────▶│ Slave-1  │   │ Slave-2  │
    │ :6379    │  复制  │ :6379    │   │ :6379    │
    │(读写)    │       │ (只读)   │   │ (只读)   │
    └──────────┘       └──────────┘   └──────────┘
```

| 角色 | 主机名 | IP | 端口 | 规格 |
|------|--------|----|------|------|
| Master + Sentinel | `redis-01` | `192.168.10.21` | 6379 / 26379 | 8C16G / 200G SSD |
| Slave-1 + Sentinel | `redis-02` | `192.168.10.22` | 6379 / 26379 | 8C16G / 200G SSD |
| Slave-2 + Sentinel | `redis-03` | `192.168.10.23` | 6379 / 26379 | 8C16G / 200G SSD |

### 3.2 Cluster 集群节点规划

```
                        ┌─ Slot 0-5460 ─┐
    客户端 → Smart路由   │  Master-1      │←→ Slave-1
     (redis-cli -c)    ├─ Slot 5461-10922┤
                        │  Master-2      │←→ Slave-2
                        ├─ Slot 10923-16383┤
                        │  Master-3      │←→ Slave-3
                        └───────────────┘
```

| 角色 | 主机名 | IP | 端口 | Slot 范围 |
|------|--------|----|------|-----------|
| Master-1 | `redis-01` | `192.168.10.21` | 6379 / 16379 | 0 - 5460 |
| Master-2 | `redis-02` | `192.168.10.22` | 6379 / 16379 | 5461 - 10922 |
| Master-3 | `redis-03` | `192.168.10.23` | 6379 / 16379 | 10923 - 16383 |
| Slave-1 | `redis-04` | `192.168.10.24` | 6379 / 16379 | 复制 Master-1 |
| Slave-2 | `redis-05` | `192.168.10.25` | 6379 / 16379 | 复制 Master-2 |
| Slave-3 | `redis-06` | `192.168.10.26` | 6379 / 16379 | 复制 Master-3 |

### 3.3 内存规划原则

```
节点内存规划公式：

实际可用内存 = 物理内存 × 0.7           （留 30% 给 OS、AOF rewrite 缓冲等）
maxmemory   = 实际可用内存 × 0.85       （留余量防止 OOM）

示例（16GB 物理内存）：
  实际可用 = 16GB × 0.7 = 11.2 GB
  maxmemory = 11.2 × 0.85 ≈ 9.5 GB → 建议设置 9gb 或 10gb
```

---

## 4. 安装 Redis

### 4.1 方式一：包管理器安装（所有节点执行）

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
# 通过 Remi 仓库安装 Redis 7.2
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset redis -y
dnf module enable redis:remi-7.2 -y
dnf install -y redis

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 通过官方 Redis APT 仓库安装（redislabs 官方源，版本最新）
curl -fsSL https://packages.redis.io/gpg \
    | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] \
https://packages.redis.io/deb $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/redis.list
apt-get update
apt-get install -y redis-server redis-tools
```

```bash
# ── 以下命令两个系统相同 ────────────────────────────────────────
# 验证版本
redis-server --version
# 预期：Redis server v=7.2.x ...
```

### 4.2 方式二：编译安装（推荐，版本可控）

```bash
# ── Rocky Linux 9 ──────────────────────────────────────────────
# 安装编译依赖
dnf install -y gcc make tcl systemd-devel wget

# ── Ubuntu 24.04 ───────────────────────────────────────────────
# 安装编译依赖
apt-get install -y build-essential tcl libsystemd-dev wget
```

```bash
# ── 以下步骤两个系统相同 ────────────────────────────────────────
# 下载源码（选择稳定版）
REDIS_VER=7.2.7
wget https://download.redis.io/releases/redis-${REDIS_VER}.tar.gz -O /tmp/redis-${REDIS_VER}.tar.gz
tar -xzf /tmp/redis-${REDIS_VER}.tar.gz -C /opt/
cd /opt/redis-${REDIS_VER}

# 编译（USE_SYSTEMD=yes 支持 systemd watchdog）
make USE_SYSTEMD=yes -j$(nproc)
make install PREFIX=/usr/local/redis

# 创建软链接
ln -sf /usr/local/redis/bin/redis-server   /usr/bin/redis-server
ln -sf /usr/local/redis/bin/redis-cli      /usr/bin/redis-cli
ln -sf /usr/local/redis/bin/redis-sentinel /usr/bin/redis-sentinel

redis-server --version
```

### 4.3 创建系统用户和目录

```bash
# 创建专用用户（不授予登录权限）
useradd -r -s /sbin/nologin redis

# 创建目录
mkdir -p /etc/redis
mkdir -p /var/lib/redis        # 数据目录（建议挂载 SSD 独立分区）
mkdir -p /var/log/redis        # 日志目录
mkdir -p /var/run/redis        # PID 文件目录

# 设置权限
chown -R redis:redis /var/lib/redis /var/log/redis /var/run/redis /etc/redis
chmod 750 /var/lib/redis
```

### 4.4 创建 Systemd 服务文件

```bash
cat > /etc/systemd/system/redis.service << 'EOF'
[Unit]
Description=Redis In-Memory Data Store
After=network.target
Wants=network.target

[Service]
Type=notify
ExecStart=/usr/bin/redis-server /etc/redis/redis.conf --supervised systemd
ExecStop=/usr/bin/redis-cli -a "${REDIS_PASSWORD}" shutdown nosave
ExecReload=/bin/kill -USR2 $MAINPID

# 运行用户
User=redis
Group=redis

# 重启策略：异常退出自动重启，最多 5 次
Restart=on-failure
RestartSec=5s
StartLimitIntervalSec=60
StartLimitBurst=5

# 安全加固
NoNewPrivileges=yes
PrivateTmp=yes

# 文件描述符上限
LimitNOFILE=65535

# 内存使用上限（可选防护）
# MemoryMax=12G

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
```

---

## 5. 方案一：Redis Sentinel 哨兵模式

### 5.0 哨兵模式简介

**Redis Sentinel（哨兵）** 是 Redis 官方提供的高可用方案，由独立的 Sentinel 进程集群对 Redis 主从进行监控，在主节点故障时自动完成选主和切换，无需人工干预。

**核心优势：**

| 优势 | 说明 |
|------|----- |
| 🚀 **自动故障切换** | 主节点宕机后，Sentinel 投票选出新 Master，切换时间通常 < 30 秒 |
| 📖 **读写分离** | 写请求走 Master，读请求分发到 Slave，提升读吞吐 |
| 🔍 **服务发现** | 客户端通过 Sentinel 询问当前 Master 地址，无需硬编码 IP |
| 🛠 **运维简单** | 结构清晰，3 个节点即可组成高可用集群，运维成本低 |
| 🔄 **平滑扩展只读** | 可随时横向添加 Slave 节点，提升读请求承载能力 |

**局限性：**

- ❌ **不支持数据分片**：所有数据存储在单个 Master，受单机内存上限制约
- ❌ **写入无法水平扩展**：写请求全部打到一台 Master，高并发写场景存在瓶颈
- ⚠️ **切换期间短暂不可写**：故障切换过程中（通常 10~30 秒）客户端写入会短暂报错

**适用场景：** 数据总量 < 单机内存（通常 < 50GB），读多写少，追求简单运维的中小型生产环境。

---

### 5.1 Master 节点配置（redis-01）

> 复制以下内容到 `/etc/redis/redis.conf`，Slave 节点配置见 5.2 节。

```bash
cat > /etc/redis/redis.conf << 'EOF'
# ============================================================
# Redis Master 节点生产配置
# 节点：192.168.10.21  角色：Master
# ============================================================

# ---- 网络 ----
bind 192.168.10.21 127.0.0.1   # 只监听内网 IP + 本地回环
port 6379
protected-mode yes              # 无密码时拒绝外网访问（已配置密码时不影响）
tcp-backlog 511                 # TCP 监听队列（与 somaxconn 配合）
timeout 0                       # 客户端空闲超时（0=不超时，长连接场景推荐）
tcp-keepalive 300               # TCP keepalive 心跳间隔

# ---- 认证 ----
requirepass "YourStr0ngP@ss2026"  # ⚠️ 生产必须设置强密码
masterauth "YourStr0ngP@ss2026"   # 主从同步密码（主备保持一致）

# ---- 进程 ----
daemonize no                    # 使用 systemd 管理，设为 no
supervised systemd              # 通知 systemd 启动完成
pidfile /var/run/redis/redis.pid
loglevel notice                 # 日志级别：debug/verbose/notice/warning
logfile /var/log/redis/redis.log

# ---- 数据库 ----
databases 16                    # 数据库数量（生产建议只用 db0，避免混用）
save ""                         # ⚠️ 禁用 RDB 快照（如使用 AOF 持久化）
# 或保留 RDB（与 AOF 同时开启实现双重保障）：
# save 3600 1
# save 300 100
# save 60 10000

# ---- RDB 持久化 ----
rdbcompression yes              # RDB 文件压缩（节省磁盘，轻微影响 CPU）
rdbchecksum yes                 # RDB 文件 CRC64 校验
dbfilename dump.rdb
dir /var/lib/redis              # 数据文件目录（必须是 SSD）

# ---- AOF 持久化（生产推荐开启） ----
appendonly yes                  # 开启 AOF
appendfilename "appendonly.aof" # AOF 文件名
appenddirname "aof"             # AOF 文件子目录（Redis 7.0+）

# AOF 刷盘策略（三选一）：
# always  - 每次写操作都 fsync，最安全但最慢（不推荐生产）
# everysec - 每秒 fsync 一次，最多丢失 1 秒数据（推荐）
# no      - 由 OS 决定刷盘时机，性能最好但可能丢失较多数据
appendfsync everysec

# AOF rewrite 时不 fsync（降低 rewrite 期间 IO 压力）
no-appendfsync-on-rewrite yes

# AOF 文件大小超过此比例时触发 rewrite
auto-aof-rewrite-percentage 100
# AOF 文件最小达到此大小才触发 rewrite
auto-aof-rewrite-min-size 128mb

# AOF rewrite 过程中产生的增量写入缓冲区大小（Redis 7.0+）
aof-rewrite-incremental-fsync yes

# ---- 内存 ----
maxmemory 10gb                  # ⚠️ 根据实际内存调整（见第3.3节公式）
maxmemory-policy allkeys-lru    # 内存淘汰策略（见下方说明）
# 策略说明：
# noeviction     - 内存满时拒绝写入（适合不允许丢数据场景）
# allkeys-lru    - 从所有 key 中淘汰最近最少使用（通用缓存推荐）
# volatile-lru   - 只淘汰设置了 TTL 的 key（混合场景）
# allkeys-lfu    - 按访问频率淘汰（Redis 4.0+，适合热点数据不均匀场景）
# volatile-ttl   - 优先淘汰即将过期的 key

# 内存使用报告粒度
maxmemory-samples 5

# 内存碎片整理（Redis 4.0+）
activedefrag yes
active-defrag-ignore-bytes 100mb  # 碎片超过 100MB 才整理
active-defrag-threshold-lower 10  # 碎片率超过 10% 才整理
active-defrag-threshold-upper 100 # 碎片率超过 100% 全力整理

# ---- 延迟优化 ----
lazyfree-lazy-eviction yes      # 异步淘汰（防止大 key 淘汰阻塞）
lazyfree-lazy-expire yes        # 异步过期删除
lazyfree-lazy-server-del yes    # 异步执行 DEL 命令的大 key
replica-lazy-flush yes          # 从节点异步清空数据（全量同步时）

# ---- 慢日志 ----
slowlog-log-slower-than 10000   # 记录超过 10ms 的命令（单位：微秒）
slowlog-max-len 128             # 慢日志最多保留 128 条

# ---- 客户端 ----
maxclients 10000                # 最大客户端连接数
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# ---- 主从复制 ----
repl-diskless-sync yes          # 无盘同步（直接通过网络传输 RDB，跳过磁盘 IO）
repl-diskless-sync-delay 5      # 等待 5 秒（让多个 Slave 同时发起同步请求）
repl-diskless-sync-max-replicas 0  # 0 = 无限制
repl-backlog-size 256mb         # 复制积压缓冲区（断线重连时用）
repl-backlog-ttl 3600           # 缓冲区空闲超过 1 小时则释放
repl-timeout 60                 # 复制超时（秒）
min-replicas-to-write 1         # 至少 1 个从节点同步才允许写入
min-replicas-max-lag 10         # 从节点滞后不超过 10 秒

# ---- 线程（Redis 6.0+） ----
io-threads 4                    # I/O 线程数（CPU 核数的一半，最多 8）
io-threads-do-reads yes         # 读操作也使用多线程

# ---- 其他 ----
hz 10                           # 内部定时任务频率（hz 越高 CPU 消耗越多，10 适合低延迟）
dynamic-hz yes                  # 动态调整 hz（负载高时自动提升）
aof-use-rdb-preamble yes        # AOF 文件头部使用 RDB 格式（加速加载）
cluster-enabled no              # 哨兵模式不开启 cluster
EOF
```

### 5.2 Slave 节点配置（redis-02 / redis-03）

> 在 redis-01 配置基础上，**添加以下内容**（其余保持一致，注意修改 bind IP）：

```bash
# 在 /etc/redis/redis.conf 中修改 bind，并添加：

bind 192.168.10.22 127.0.0.1   # ⚠️ 改为本机 IP

# 指向 Master 节点
replicaof 192.168.10.21 6379

# 从节点设为只读（防止误写）
replica-read-only yes

# 从节点优先级（Sentinel 选主时，数值越小越优先；0 表示永不成为主）
replica-priority 100            # redis-02: 100, redis-03: 110（值越小优先级越高）
```

### 5.3 Sentinel 配置（三台节点各一份）

```bash
# ⚠️ 各节点修改 sentinel announce-ip 为本机 IP
cat > /etc/redis/sentinel.conf << 'EOF'
# ============================================================
# Redis Sentinel 哨兵配置
# ============================================================

port 26379
daemonize no
supervised systemd
logfile /var/log/redis/sentinel.log
pidfile /var/run/redis/sentinel.pid
dir /var/lib/redis

# 声明本 Sentinel 的 IP（必须！避免 NAT/多网卡时地址错误）
sentinel announce-ip 192.168.10.21   # ⚠️ 改为各节点本机 IP
sentinel announce-port 26379

# 监控 Master（quorum=2：需要 2 个 Sentinel 同意才能触发故障切换）
sentinel monitor mymaster 192.168.10.21 6379 2

# Master 密码（与 redis.conf requirepass 一致）
sentinel auth-pass mymaster YourStr0ngP@ss2026

# Master 不可达超过此时间（毫秒）则认为主观下线（SDOWN）
sentinel down-after-milliseconds mymaster 5000

# 故障切换超时时间（毫秒）
sentinel failover-timeout mymaster 30000

# 故障切换完成后，最多同时向多少个 Slave 同步新主节点数据
# 1 = 一个一个同步（不影响服务），但同步慢
# 越大同步越快，但多个 Slave 同时离线会影响读请求
sentinel parallel-syncs mymaster 1

# GossIP：Sentinel 之间互相发现（通过 Master 中转）
sentinel deny-scripts-reconfig yes

# Sentinel 自身密码（Redis 6.2+，哨兵间通信鉴权）
requirepass YourStr0ngP@ss2026
sentinel sentinel-pass YourStr0ngP@ss2026
EOF
```

### 5.4 启动 Sentinel 集群

```bash
# 所有节点依次执行

# 1. 先启动主从 Redis
systemctl enable redis --now
systemctl status redis

# 2. 验证主从复制
redis-cli -h 192.168.10.21 -a 'YourStr0ngP@ss2026' info replication
# 预期：role:master, connected_slaves:2

# 3. 启动 Sentinel（三台节点都执行）
cat > /etc/systemd/system/redis-sentinel.service << 'EOF'
[Unit]
Description=Redis Sentinel
After=network.target redis.service

[Service]
Type=notify
ExecStart=/usr/bin/redis-sentinel /etc/redis/sentinel.conf --supervised systemd
User=redis
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable redis-sentinel --now

# 4. 验证哨兵状态
redis-cli -h 192.168.10.21 -p 26379 -a 'YourStr0ngP@ss2026' sentinel masters
# 预期输出包含：name=mymaster, status=ok, slaves=2, sentinels=3
```

---

## 6. 方案二：Redis Cluster 集群模式

### 6.0 集群模式简介

**Redis Cluster** 是 Redis 原生的分布式方案，将全部 16384 个哈希槽（Hash Slot）平均分配给多个 Master 节点，每个 Master 携带若干 Slave 副本，数据天然水平分片，突破单机内存限制。

**核心优势：**

| 优势 | 说明 |
|------|----- |
| 📦 **数据自动分片** | 16384 个 Slot 均匀分配到各 Master，每个节点只存整体数据的 1/N |
| 📈 **线性水平扩展** | 动态添加新 Master，Slot 自动迁移，读写容量同步提升 |
| 🛡 **内置高可用** | 每个 Master 配备 Slave，Master 宕机自动提升 Slave，无需 Sentinel |
| ⚡ **高并发写入** | 写请求分散到多个 Master，彻底解决单点写入瓶颈 |
| 🌐 **去中心化** | 节点间通过 Gossip 协议互通，无单点故障风险 |

**局限性：**

- ❌ **不支持跨槽多 Key 操作**：`MGET`、`MSET`、`pipeline` 中涉及不同 Slot 的 Key 会报错（可用 `{}` Hash Tag 强制同槽）
- ❌ **不支持多数据库**：Cluster 模式只有 `db0`，无法使用 `SELECT` 切库
- ⚠️ **运维复杂度高**：Slot 迁移、节点扩缩容、故障恢复流程比 Sentinel 复杂
- ⚠️ **客户端需支持 Cluster 协议**：需使用支持 MOVED/ASK 重定向的客户端库（主流语言均已支持）

**适用场景：** 数据量 > 50GB 或预期持续增长、写入 QPS 极高、需要线性扩容的大型生产环境。

---

### 6.1 修改 redis.conf 启用 Cluster

```bash
# 在各节点的 /etc/redis/redis.conf 中添加/修改以下配置：
# ⚠️ 各节点修改 bind 为本机 IP

cat >> /etc/redis/redis.conf << 'EOF'

# ============================================================
# Redis Cluster 集群配置
# ============================================================

# 启用集群模式
cluster-enabled yes

# 集群节点信息文件（自动维护，勿手动编辑）
cluster-config-file /var/lib/redis/nodes.conf

# 节点通信超时（毫秒）
cluster-node-timeout 15000

# 节点间通信端口 = Redis 端口 + 10000（此处 16379）
# 无需手动配置，Redis 自动使用

# 集群全量同步（当从节点 offset 差距太大时，强制全同步）
cluster-require-full-coverage no    # no = 部分 slot 不可用时仍提供服务（推荐）

# 允许读从节点（注意：客户端需使用 READONLY 命令）
# cluster-slave-no-failover no

# Cluster 中每个 Master 至少有 N 个有效从节点才允许写入
cluster-migration-barrier 1

EOF
```

### 6.2 创建集群

```bash
# 在任意一台节点执行
# --cluster-replicas 1 = 每个主节点分配 1 个从节点

redis-cli -a 'YourStr0ngP@ss2026' --cluster create \
    192.168.10.21:6379 \
    192.168.10.22:6379 \
    192.168.10.23:6379 \
    192.168.10.24:6379 \
    192.168.10.25:6379 \
    192.168.10.26:6379 \
    --cluster-replicas 1

# 交互式输入 yes 确认节点分配方案
```

### 6.3 验证集群状态

```bash
# 查看集群节点信息
redis-cli -a 'YourStr0ngP@ss2026' -h 192.168.10.21 cluster nodes

# 查看集群整体状态
redis-cli -a 'YourStr0ngP@ss2026' -h 192.168.10.21 cluster info
# 预期：cluster_state:ok，cluster_slots_assigned:16384

# 连接集群（-c 参数自动重定向）
redis-cli -c -a 'YourStr0ngP@ss2026' -h 192.168.10.21
```

### 6.4 集群扩容（添加新节点）

```bash
# 添加新 Master 节点
redis-cli -a 'YourStr0ngP@ss2026' --cluster add-node \
    192.168.10.27:6379 \       # 新节点
    192.168.10.21:6379          # 任意现有节点

# 为新 Master 迁移 Slot
redis-cli -a 'YourStr0ngP@ss2026' --cluster reshard 192.168.10.21:6379

# 添加 Slave 节点（复制指定 Master）
redis-cli -a 'YourStr0ngP@ss2026' --cluster add-node \
    192.168.10.28:6379 \       # 新 Slave
    192.168.10.21:6379 \       # 任意现有节点
    --cluster-slave \
    --cluster-master-id <master-node-id>   # 目标 Master 的 NodeID

# 均衡 Slot 分配
redis-cli -a 'YourStr0ngP@ss2026' --cluster rebalance \
    192.168.10.21:6379 \
    --cluster-use-empty-masters
```

---

## 7. 生产级 redis.conf 全量配置注释

> 以下为 Redis 7.2 完整关键参数说明（按分类整理）。

### 7.1 持久化策略对比

```
┌──────────────┬──────────────────────────────┬─────────────────────┐
│  策略         │  优点                         │  缺点               │
├──────────────┼──────────────────────────────┼─────────────────────┤
│  RDB 快照    │  文件紧凑，恢复快，适合备份    │  快照间隔内数据丢失   │
│  AOF 日志    │  最多丢失 1 秒数据（everysec）  │  文件大，恢复慢      │
│  RDB + AOF  │  兼顾速度与安全（推荐生产）    │  磁盘占用最多        │
│  不持久化    │  性能最优                      │  重启数据全丢        │
└──────────────┴──────────────────────────────┴─────────────────────┘

生产推荐：AOF（everysec）+ RDB（save 3600 1）双重保障
```

### 7.2 内存淘汰策略选型

```bash
# 根据业务场景选择：
maxmemory-policy allkeys-lru      # 纯缓存（所有 key 均可淘汰）
maxmemory-policy volatile-lru     # 混合场景（只淘汰过期 key）
maxmemory-policy noeviction       # 持久化数据不允许淘汰（写满报错）
maxmemory-policy allkeys-lfu      # 热点数据不均匀（LFU 比 LRU 更精准）
```

---

## 8. 性能调优

### 8.1 系统内核参数

```bash
cat > /etc/sysctl.d/99-redis.conf << 'EOF'
# ============================================================
# Redis 专项内核参数调优
# ============================================================

# 关闭透明大页（THP）会导致 Redis 内存抖动和高延迟！
# 通过 rc.local 禁用（sysctl 不能直接控制）

# TCP 全连接队列（防止高并发时 accept 队列溢出）
net.core.somaxconn = 65535

# TCP SYN 队列
net.ipv4.tcp_max_syn_backlog = 65535

# 开启 TCP 端口复用
net.ipv4.tcp_tw_reuse = 1

# 本地端口范围（客户端连接需要大量源端口）
net.ipv4.ip_local_port_range = 1024 65535

# 内存过量提交（Redis 在 fork 时需要内存）
# 0=只有足够内存才允许申请, 1=无限制（允许 fork 正确工作）
vm.overcommit_memory = 1

# swappiness：减少 swap 使用（0 = 最大限度避免 swap）
vm.swappiness = 1
EOF

sysctl -p /etc/sysctl.d/99-redis.conf

# 禁用透明大页（THP）- 永久生效
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" > /sys/kernel/mm/transparent_hugepage/defrag

# 写入 rc.local 开机自动执行
cat >> /etc/rc.d/rc.local << 'EOF'
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
echo "never" > /sys/kernel/mm/transparent_hugepage/defrag
EOF
chmod +x /etc/rc.d/rc.local
```

### 8.2 文件描述符限制

```bash
cat > /etc/security/limits.d/redis.conf << 'EOF'
redis    soft    nofile    65535
redis    hard    nofile    65535
EOF
```

### 8.3 磁盘 I/O 调优

```bash
# 查看挂载 Redis 数据目录的磁盘设备
df -h /var/lib/redis
# 假设设备为 sdb

# 设置 I/O 调度器为 deadline（SSD 推荐）或 mq-deadline
echo "mq-deadline" > /sys/block/sdb/queue/scheduler

# 关闭磁盘预读（随机读多时减少预读可降低延迟）
blockdev --setra 512 /dev/sdb    # 512 = 256KB 预读（按需调整）
```

---

## 9. 安全加固

```bash
# ---- ACL 访问控制（Redis 6.0+）----
# 创建只读用户
redis-cli -a 'YourStr0ngP@ss2026' ACL SETUSER readonly on >ReadOnlyPass@2026 ~* &* +@read

# 创建应用用户（限制命令范围）
redis-cli -a 'YourStr0ngP@ss2026' ACL SETUSER appuser on >AppP@ss2026 \
    ~app:* \                    # 只能访问以 app: 开头的 key
    +GET +SET +DEL +EXPIRE +TTL +EXISTS +MGET +MSET

# 禁用危险命令（在 redis.conf 中配置）
# rename-command FLUSHALL ""      # 禁用 FLUSHALL
# rename-command FLUSHDB  ""      # 禁用 FLUSHDB
# rename-command CONFIG   ""      # 禁用 CONFIG（或重命名为随机字符串）
# rename-command DEBUG    ""      # 禁用 DEBUG
# rename-command KEYS     ""      # 禁用 KEYS（高危，应使用 SCAN 代替）
# rename-command SHUTDOWN "REDIS_SHUTDOWN_QW7X"  # 重命名而非禁用

# ---- 网络隔离 ----
# 配置 firewalld，只允许内网 IP 访问 Redis 端口
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.10.0/24" port protocol="tcp" port="6379" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.10.0/24" port protocol="tcp" port="26379" accept'
firewall-cmd --reload
```

---

## 10. 监控接入

### 10.1 redis_exporter 接入 Prometheus

```bash
# 下载 redis_exporter
curl -LO https://github.com/oliver006/redis_exporter/releases/latest/download/redis_exporter-v1.63.0.linux-amd64.tar.gz
tar -xzf redis_exporter-*.tar.gz

# 启动 exporter
./redis_exporter \
    --redis.addr redis://192.168.10.21:6379 \
    --redis.password 'YourStr0ngP@ss2026' \
    --web.listen-address 0.0.0.0:9121 &

# prometheus.yml 配置
# - job_name: 'redis'
#   static_configs:
#     - targets:
#       - '192.168.10.21:9121'
#       - '192.168.10.22:9121'
#       - '192.168.10.23:9121'
```

### 10.2 关键监控指标

```
关键 Prometheus 指标：
─────────────────────────────────────────────────────────────
redis_up                                  # 节点是否存活
redis_connected_clients                   # 当前连接数（告警：> maxclients × 0.8）
redis_memory_used_bytes                   # 内存使用量
redis_memory_max_bytes                    # maxmemory 设置值
redis_keyspace_hits_total                 # 缓存命中次数
redis_keyspace_misses_total               # 缓存未命中次数
rate(redis_commands_processed_total[1m])  # QPS
redis_slowlog_length                      # 慢查询积压数量（告警：> 0）
redis_master_repl_offset - redis_slave_repl_offset  # 主从复制延迟（字节）
redis_sentinel_masters                    # Sentinel 管理的 Master 数（Sentinel 模式）
redis_cluster_state                       # 集群状态（Cluster 模式，1=ok）
─────────────────────────────────────────────────────────────
```

---

## 11. 常用运维命令大全

### 11.1 连接与认证

```bash
# 基本连接
redis-cli -h 192.168.10.21 -p 6379 -a 'YourStr0ngP@ss2026'

# 连接 Cluster（自动重定向）
redis-cli -c -h 192.168.10.21 -p 6379 -a 'YourStr0ngP@ss2026'

# 指定数据库（Cluster 模式只有 db0）
redis-cli -h 192.168.10.21 -p 6379 -a 'YourStr0ngP@ss2026' -n 1

# 测试连通性
redis-cli -h 192.168.10.21 PING       # 返回 PONG
```

### 11.2 服务器信息

```bash
# 查看所有服务器信息（分区块输出）
redis-cli -h 192.168.10.21 -a 'xxx' info

# 查看特定信息块
redis-cli -h 192.168.10.21 -a 'xxx' info server       # 服务器版本、启动时间等
redis-cli -h 192.168.10.21 -a 'xxx' info clients      # 客户端连接统计
redis-cli -h 192.168.10.21 -a 'xxx' info memory       # 内存使用详情
redis-cli -h 192.168.10.21 -a 'xxx' info stats        # 命令统计、hit/miss
redis-cli -h 192.168.10.21 -a 'xxx' info replication  # 主从复制状态
redis-cli -h 192.168.10.21 -a 'xxx' info persistence  # RDB/AOF 持久化状态
redis-cli -h 192.168.10.21 -a 'xxx' info keyspace     # 各数据库 key 数量
redis-cli -h 192.168.10.21 -a 'xxx' info cpu          # CPU 使用率
```

### 11.3 实时监控

```bash
# 实时监控 QPS（每秒刷新）
redis-cli -h 192.168.10.21 -a 'xxx' --stat

# 实时监控内存、clients、hit/miss 等关键指标（间隔 1 秒）
redis-cli -h 192.168.10.21 -a 'xxx' --stat -i 1

# 实时查看所有执行的命令（调试用，生产慎用：影响性能）
redis-cli -h 192.168.10.21 -a 'xxx' monitor

# 实时显示 BigKey 扫描结果
redis-cli -h 192.168.10.21 -a 'xxx' --bigkeys

# 实时显示热点 Key（Redis 4.0+，需开启 maxmemory-policy=lfu）
redis-cli -h 192.168.10.21 -a 'xxx' --hotkeys
```

### 11.4 慢日志管理

```bash
# 查看慢日志（最近 N 条）
redis-cli -h 192.168.10.21 -a 'xxx' slowlog get 20

# 查看慢日志条数
redis-cli -h 192.168.10.21 -a 'xxx' slowlog len

# 清空慢日志
redis-cli -h 192.168.10.21 -a 'xxx' slowlog reset

# 修改慢日志阈值（10000 微秒 = 10ms）
redis-cli -h 192.168.10.21 -a 'xxx' config set slowlog-log-slower-than 10000
```

### 11.5 Key 管理

```bash
# ⚠️ 生产禁用 KEYS，使用 SCAN 代替（KEYS 会阻塞 Redis）
# SCAN 迭代（cursor 从 0 开始，返回 0 则结束）
redis-cli -h 192.168.10.21 -a 'xxx' scan 0 match "app:user:*" count 100

# 查询 Key 信息
redis-cli -h 192.168.10.21 -a 'xxx' type mykey        # 查看类型
redis-cli -h 192.168.10.21 -a 'xxx' ttl  mykey        # 查看剩余过期时间（秒）
redis-cli -h 192.168.10.21 -a 'xxx' pttl mykey        # 剩余过期时间（毫秒）
redis-cli -h 192.168.10.21 -a 'xxx' object encoding mykey  # 查看内部编码
redis-cli -h 192.168.10.21 -a 'xxx' object idletime mykey  # 查看空闲时间

# object freq mykey（LFU 策略下查看访问频率）
redis-cli -h 192.168.10.21 -a 'xxx' object freq mykey

# 统计各数据库 Key 数量
redis-cli -h 192.168.10.21 -a 'xxx' info keyspace

# 批量删除 Key（使用 SCAN + UNLINK 异步删除，不阻塞）
redis-cli -h 192.168.10.21 -a 'xxx' --scan --pattern "tmp:*" | \
    xargs -L 100 redis-cli -h 192.168.10.21 -a 'xxx' unlink
```

### 11.6 内存分析

```bash
# 内存整体分布
redis-cli -h 192.168.10.21 -a 'xxx' memory doctor    # 内存诊断（给出优化建议）
redis-cli -h 192.168.10.21 -a 'xxx' memory stats     # 详细内存统计

# 查询单个 Key 占用内存
redis-cli -h 192.168.10.21 -a 'xxx' memory usage mykey
redis-cli -h 192.168.10.21 -a 'xxx' memory usage mykey samples 5  # 抽样精度

# 大 Key 扫描（⚠️ 对生产有轻微影响，低峰期执行）
redis-cli -h 192.168.10.21 -a 'xxx' --bigkeys

# 内存碎片整理（手动触发）
redis-cli -h 192.168.10.21 -a 'xxx' memory purge
```

### 11.7 主从 & 哨兵运维

```bash
# 查看主从复制状态
redis-cli -h 192.168.10.21 -a 'xxx' info replication

# 手动触发主从切换（在哨兵节点执行）
redis-cli -h 192.168.10.21 -p 26379 -a 'xxx' sentinel failover mymaster

# 查看哨兵监控的 Master 信息
redis-cli -h 192.168.10.21 -p 26379 -a 'xxx' sentinel masters
redis-cli -h 192.168.10.21 -p 26379 -a 'xxx' sentinel slaves mymaster
redis-cli -h 192.168.10.21 -p 26379 -a 'xxx' sentinel sentinels mymaster

# 查询当前 Master 地址（客户端初始化时调用此命令）
redis-cli -h 192.168.10.21 -p 26379 -a 'xxx' sentinel get-master-addr-by-name mymaster

# 主动将某从节点提升为 Master
redis-cli -h 192.168.10.22 -p 6379 -a 'xxx' replicaof no one   # 解除复制
```

### 11.8 Cluster 集群运维

```bash
# 查看集群状态
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster info
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster nodes

# 查看 Slot 分配
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster slots
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster shards   # Redis 7.0+

# 检查集群健康状态（全面诊断）
redis-cli -a 'xxx' --cluster check 192.168.10.21:6379

# 修复集群（处理 slot 缺失等问题）
redis-cli -a 'xxx' --cluster fix 192.168.10.21:6379

# 手动触发 Slot 迁移
redis-cli -a 'xxx' --cluster reshard 192.168.10.21:6379

# 均衡节点负载
redis-cli -a 'xxx' --cluster rebalance 192.168.10.21:6379

# 删除节点（必须先迁出所有 Slot）
redis-cli -a 'xxx' --cluster del-node 192.168.10.21:6379 <node-id>
```

### 11.9 持久化运维

```bash
# 手动触发 RDB 快照（后台异步，不阻塞）
redis-cli -h 192.168.10.21 -a 'xxx' bgsave

# 查看上次 BGSAVE 状态
redis-cli -h 192.168.10.21 -a 'xxx' lastsave        # 返回时间戳
redis-cli -h 192.168.10.21 -a 'xxx' info persistence  # 查看详细状态

# 手动触发 AOF rewrite（后台异步）
redis-cli -h 192.168.10.21 -a 'xxx' bgrewriteaof

# 查看 AOF 状态
redis-cli -h 192.168.10.21 -a 'xxx' info persistence | grep aof

# 校验 AOF 文件完整性
redis-check-aof /var/lib/redis/aof/appendonly.aof
# 修复损坏的 AOF 文件（谨慎：会截断末尾不完整命令）
redis-check-aof --fix /var/lib/redis/aof/appendonly.aof

# 校验 RDB 文件
redis-check-rdb /var/lib/redis/dump.rdb
```

### 11.10 配置热更新

```bash
# 查看当前配置
redis-cli -h 192.168.10.21 -a 'xxx' config get maxmemory
redis-cli -h 192.168.10.21 -a 'xxx' config get "*"                # 查看所有配置

# 动态修改配置（无需重启）
redis-cli -h 192.168.10.21 -a 'xxx' config set maxmemory 12gb
redis-cli -h 192.168.10.21 -a 'xxx' config set slowlog-log-slower-than 5000
redis-cli -h 192.168.10.21 -a 'xxx' config set hz 20

# 将运行时配置写回 redis.conf（持久化修改）
redis-cli -h 192.168.10.21 -a 'xxx' config rewrite

# 重置统计信息
redis-cli -h 192.168.10.21 -a 'xxx' config resetstat
```

### 11.11 调试与诊断

```bash
# 延迟诊断（测量 Redis 延迟，运行 15 秒）
redis-cli -h 192.168.10.21 -a 'xxx' --latency -i 1

# 延迟历史（100 秒内的最大延迟）
redis-cli -h 192.168.10.21 -a 'xxx' --latency-history -i 1

# 延迟分布（百分位统计）
redis-cli -h 192.168.10.21 -a 'xxx' --latency-dist

# 检查 DEBUG SLEEP（模拟阻塞，测试客户端超时处理，⚠️ 测试环境使用）
redis-cli -h 192.168.10.21 -a 'xxx' debug sleep 0

# 查看当前执行时间最长的命令
redis-cli -h 192.168.10.21 -a 'xxx' command info get set

# 压力测试（生产环境慎用）
redis-benchmark -h 192.168.10.21 -a 'xxx' -n 100000 -c 50 -q
```

### 11.12 优雅关闭与重启

```bash
# 优雅关闭（先持久化再退出）
redis-cli -h 192.168.10.21 -a 'xxx' shutdown save    # 关闭前 BGSAVE
# redis-cli -h 192.168.10.21 -a 'xxx' shutdown nosave  # 关闭不保存（⚠️ 慎用）

# 通过 systemd 管理（推荐）
systemctl stop redis
systemctl start redis
systemctl restart redis
systemctl reload redis    # 重新加载配置（触发 CONFIG REWRITE）

# 查看 Redis 日志
tail -f /var/log/redis/redis.log
journalctl -u redis -n 100 --no-pager
```

---

## 12. 常见问题排查

### 12.1 内存 OOM / 连续写入失败

```bash
# 查看内存淘汰状态
redis-cli -h 192.168.10.21 -a 'xxx' info stats | grep evicted_keys
# 如 evicted_keys 持续增长，说明内存已满在淘汰

# 检查当前内存使用
redis-cli -h 192.168.10.21 -a 'xxx' info memory | grep -E "used_memory_human|maxmemory_human"

# 紧急扩容（临时调大 maxmemory）
redis-cli -h 192.168.10.21 -a 'xxx' config set maxmemory 14gb
```

### 12.2 主从复制延迟过大

```bash
# 查看复制偏移量差值
redis-cli -h 192.168.10.21 -a 'xxx' info replication | grep -E "master_repl_offset|slave_repl_offset"

# 查看复制积压缓冲区
redis-cli -h 192.168.10.21 -a 'xxx' info replication | grep repl_backlog

# 检查从节点网络
redis-cli -h 192.168.10.22 -a 'xxx' info replication | grep master_link_status
# 正常：master_link_status:up
# 异常：master_link_status:down → 检查网络、防火墙
```

### 12.3 阻塞命令导致高延迟

```bash
# 查看慢查询
redis-cli -h 192.168.10.21 -a 'xxx' slowlog get 10

# 查找大 Key（可能是 HGETALL 大 Hash、SMEMBERS 大 Set 等）
redis-cli -h 192.168.10.21 -a 'xxx' --bigkeys

# 找到大 Key 后，评估是否可以拆分或异步处理
```

### 12.4 连接数异常（连接池泄漏）

```bash
# 查看客户端列表
redis-cli -h 192.168.10.21 -a 'xxx' client list

# 按 idle 时间排序（找出长时间空闲的连接）
redis-cli -h 192.168.10.21 -a 'xxx' client list | sort -t= -k6 -rn | head -20

# 强制关闭某个客户端（使用 client id）
redis-cli -h 192.168.10.21 -a 'xxx' client kill id 1234

# 关闭所有空闲超过 300 秒的连接
redis-cli -h 192.168.10.21 -a 'xxx' client no-evict on
```

### 12.5 Cluster 脑裂

```bash
# 检查集群节点状态（是否有 fail 标记）
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster nodes | grep fail

# 检查集群是否可写
redis-cli -c -h 192.168.10.21 -a 'xxx' cluster info | grep cluster_state
# ok = 正常；fail = 集群故障

# 修复集群
redis-cli -a 'xxx' --cluster fix 192.168.10.21:6379
```

---

## 13. Docker Compose 快速部署（测试 / 开发专用）

> ## ⚠️ 重要声明
>
> **以下 Docker Compose 方案仅用于本地开发和功能测试，严禁用于生产环境！**
>
> **原因：**
> - 容器网络延迟高，不适合 Redis 哨兵/集群心跳检测
> - 数据卷默认无持久化策略，容器删除后数据丢失
> - 无内核参数优化（THP、vm.overcommit_memory 等）
> - 无 ACL / TLS / 安全加固
> - 单机伪集群，无法验证真实的网络分区场景

---

### 13.1 方案一：Sentinel 哨兵模式（1主2从+3哨兵）

**目录结构：**

```
redis-sentinel/
├── docker-compose.yml
├── redis-master.conf
├── redis-slave.conf
└── sentinel.conf
```

**Step 1：创建目录和配置文件**

```bash
mkdir -p ~/redis-sentinel && cd ~/redis-sentinel

# Master / Slave 配置（⚠️ 此处无密码，仅测试用）
cat > redis-master.conf << 'EOF'
port 6379
bind 0.0.0.0
protected-mode no
appendonly yes
EOF

cat > redis-slave.conf << 'EOF'
port 6379
bind 0.0.0.0
protected-mode no
appendonly yes
# 指向 master 容器（使用 docker-compose service name）
replicaof redis-master 6379
EOF

# Sentinel 配置（三个哨兵共用同一模板，docker-compose 挂载时各自独立）
cat > sentinel.conf << 'EOF'
port 26379
bind 0.0.0.0
protected-mode no
# 监控 master 容器（docker-compose service name）
sentinel monitor mymaster redis-master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 30000
sentinel parallel-syncs mymaster 1
EOF
```

**Step 2：docker-compose.yml**

```yaml
# ============================================================
# Redis Sentinel 测试环境（1主 + 2从 + 3哨兵）
# ⚠️ 仅用于开发/测试，禁止用于生产！
# ============================================================
version: '3.8'

services:

  # ----------- Redis Master -----------
  redis-master:
    image: redis:7.2-alpine
    container_name: redis-master
    ports:
      - "6379:6379"
    volumes:
      - ./redis-master.conf:/etc/redis/redis.conf
      - redis-master-data:/data
    command: redis-server /etc/redis/redis.conf
    networks:
      - redis-net
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  # ----------- Redis Slave 1 -----------
  redis-slave1:
    image: redis:7.2-alpine
    container_name: redis-slave1
    ports:
      - "6380:6379"
    volumes:
      - ./redis-slave.conf:/etc/redis/redis.conf
      - redis-slave1-data:/data
    command: redis-server /etc/redis/redis.conf
    networks:
      - redis-net
    depends_on:
      redis-master:
        condition: service_healthy
    restart: unless-stopped

  # ----------- Redis Slave 2 -----------
  redis-slave2:
    image: redis:7.2-alpine
    container_name: redis-slave2
    ports:
      - "6381:6379"
    volumes:
      - ./redis-slave.conf:/etc/redis/redis.conf
      - redis-slave2-data:/data
    command: redis-server /etc/redis/redis.conf
    networks:
      - redis-net
    depends_on:
      redis-master:
        condition: service_healthy
    restart: unless-stopped

  # ----------- Sentinel 1 -----------
  sentinel1:
    image: redis:7.2-alpine
    container_name: redis-sentinel1
    ports:
      - "26379:26379"
    volumes:
      - ./sentinel.conf:/etc/redis/sentinel.conf
    command: redis-sentinel /etc/redis/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master
      - redis-slave1
      - redis-slave2
    restart: unless-stopped

  # ----------- Sentinel 2 -----------
  sentinel2:
    image: redis:7.2-alpine
    container_name: redis-sentinel2
    ports:
      - "26380:26379"
    volumes:
      - ./sentinel.conf:/etc/redis/sentinel.conf
    command: redis-sentinel /etc/redis/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master
    restart: unless-stopped

  # ----------- Sentinel 3 -----------
  sentinel3:
    image: redis:7.2-alpine
    container_name: redis-sentinel3
    ports:
      - "26381:26379"
    volumes:
      - ./sentinel.conf:/etc/redis/sentinel.conf
    command: redis-sentinel /etc/redis/sentinel.conf
    networks:
      - redis-net
    depends_on:
      - redis-master
    restart: unless-stopped

volumes:
  redis-master-data:
  redis-slave1-data:
  redis-slave2-data:

networks:
  redis-net:
    driver: bridge
```

**Step 3：启动与验证**

```bash
# 启动
docker compose up -d

# 查看容器状态
docker compose ps

# 验证主从复制
docker exec redis-master redis-cli info replication
# 预期：role:master, connected_slaves:2

# 查询哨兵状态
docker exec redis-sentinel1 redis-cli -p 26379 sentinel masters
# 预期：name=mymaster, status=ok

# 模拟 Master 故障，验证自动切换
docker stop redis-master
# 等待约 10 秒后查看哨兵日志
docker logs redis-sentinel1 | tail -30
# 预期看到 +switch-master 字样

# 恢复 Master
docker start redis-master

# 停止并清理
docker compose down -v   # -v 同时删除数据卷
```

**客户端连接（测试用）：**

```python
# Python 示例（使用 redis-py）
import redis
from redis.sentinel import Sentinel

sentinel = Sentinel(
    [('127.0.0.1', 26379), ('127.0.0.1', 26380), ('127.0.0.1', 26381)],
    socket_timeout=0.1
)
master = sentinel.master_for('mymaster', socket_timeout=0.1)
slave  = sentinel.slave_for('mymaster', socket_timeout=0.1)
master.set('key', 'value')
print(slave.get('key'))   # b'value'
```

---

### 13.2 方案二：Redis Cluster 集群模式（3主 + 3从）

> Redis Cluster 需要节点间跨容器直接通信，使用 `--net=host` 或固定容器 IP 才能正常工作。
> 以下方案使用 `bitnami/redis-cluster` 镜像，它封装了集群初始化逻辑，最简单开箱即用。

**docker-compose.yml**

```yaml
# ============================================================
# Redis Cluster 测试环境（3主 + 3从，共 6 节点）
# 使用 bitnami/redis-cluster 镜像（内置自动集群初始化）
# ⚠️ 仅用于开发/测试，禁止用于生产！
# ============================================================
version: '3.8'

services:

  redis-node-1: &redis-cluster-node
    image: bitnami/redis-cluster:7.2
    container_name: redis-node-1
    environment:
      - REDIS_PASSWORD=TestCluster2026       # 测试密码（生产须强密码）
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-1
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7001:6379"
    volumes:
      - redis-cluster-1:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.11

  redis-node-2:
    <<: *redis-cluster-node
    container_name: redis-node-2
    environment:
      - REDIS_PASSWORD=TestCluster2026
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-2
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7002:6379"
    volumes:
      - redis-cluster-2:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.12

  redis-node-3:
    <<: *redis-cluster-node
    container_name: redis-node-3
    environment:
      - REDIS_PASSWORD=TestCluster2026
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-3
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7003:6379"
    volumes:
      - redis-cluster-3:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.13

  redis-node-4:
    <<: *redis-cluster-node
    container_name: redis-node-4
    environment:
      - REDIS_PASSWORD=TestCluster2026
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-4
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7004:6379"
    volumes:
      - redis-cluster-4:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.14

  redis-node-5:
    <<: *redis-cluster-node
    container_name: redis-node-5
    environment:
      - REDIS_PASSWORD=TestCluster2026
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-5
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7005:6379"
    volumes:
      - redis-cluster-5:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.15

  redis-node-6:
    <<: *redis-cluster-node
    container_name: redis-node-6
    environment:
      - REDIS_PASSWORD=TestCluster2026
      - REDIS_NODES=redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5 redis-node-6
      - REDIS_CLUSTER_ANNOUNCE_HOSTNAME=redis-node-6
      # 最后一个节点触发集群初始化
      - REDIS_CLUSTER_CREATOR=yes
      - REDIS_PORT_NUMBER=6379
    ports:
      - "7006:6379"
    volumes:
      - redis-cluster-6:/bitnami/redis/data
    networks:
      redis-cluster-net:
        ipv4_address: 172.28.0.16
    depends_on:
      - redis-node-1
      - redis-node-2
      - redis-node-3
      - redis-node-4
      - redis-node-5

volumes:
  redis-cluster-1:
  redis-cluster-2:
  redis-cluster-3:
  redis-cluster-4:
  redis-cluster-5:
  redis-cluster-6:

networks:
  redis-cluster-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/24
```

**启动与验证**

```bash
# 启动（等待约 30 秒让集群初始化完成）
docker compose up -d

# 等待 node-6 完成初始化（观察日志）
docker logs -f redis-node-6 | grep -E "cluster|Cluster"
# 看到 Cluster state changed to ok 即成功

# 验证集群状态
docker exec redis-node-1 redis-cli -a TestCluster2026 -p 6379 cluster info
# 预期：cluster_state:ok, cluster_slots_assigned:16384

# 查看节点分布
docker exec redis-node-1 redis-cli -a TestCluster2026 -p 6379 cluster nodes

# 测试写入（-c 自动重定向到正确 Slot 的节点）
docker exec redis-node-1 redis-cli -c -a TestCluster2026 -p 6379 set testkey hello
docker exec redis-node-1 redis-cli -c -a TestCluster2026 -p 6379 get testkey

# 外部连接（从宿主机访问）
redis-cli -c -h 127.0.0.1 -p 7001 -a TestCluster2026

# 停止并清理
docker compose down -v
```

**客户端连接（测试用）：**

```python
# Python 示例（使用 redis-py cluster 模式）
from redis.cluster import RedisCluster

rc = RedisCluster(
    host="127.0.0.1",
    port=7001,
    password="TestCluster2026",
    decode_responses=True
)
rc.set("{user}:1001", "Alice")
print(rc.get("{user}:1001"))   # Alice
```

---

## 附录：运维快查卡片

```
┌──────────────────────────────────────────────────────────────┐
│                  Redis 生产运维快查                             │
├─────────────────────────┬────────────────────────────────────┤
│  检查服务健康            │  redis-cli PING                     │
│  实时 QPS 监控           │  redis-cli --stat                   │
│  内存诊断               │  redis-cli memory doctor            │
│  慢日志                 │  redis-cli slowlog get 20           │
│  大 Key 扫描            │  redis-cli --bigkeys                │
│  主从状态               │  redis-cli info replication         │
│  哨兵状态               │  redis-cli -p 26379 sentinel masters│
│  集群状态               │  redis-cli cluster info             │
│  集群检查               │  redis-cli --cluster check <ip:port>│
│  手动主从切换            │  sentinel failover mymaster         │
│  触发 RDB 备份           │  redis-cli bgsave                  │
│  触发 AOF 重写           │  redis-cli bgrewriteaof            │
│  动态修改配置            │  redis-cli config set <key> <val>  │
│  持久化配置              │  redis-cli config rewrite           │
│  延迟测量               │  redis-cli --latency               │
│  禁用命令               │  redis.conf: rename-command X ""   │
└─────────────────────────┴────────────────────────────────────┘
```
