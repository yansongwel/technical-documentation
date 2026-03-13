---
title: Redis Cluster 生产级部署与运维指南
author: devinyan
updated: 2026-03-13
version: v1.0
redis_version: 8.6.1
---

> [TOC]

# Redis Cluster 生产级部署与运维指南

## 1. 简介

### 1.1 服务介绍与核心特性

Redis（Remote Dictionary Server）是高性能的内存数据结构存储系统，支持字符串、哈希、列表、集合、有序集合、位图、HyperLogLog、Stream 等数据结构。

Redis Cluster 是 Redis 官方提供的分布式方案，核心特性：

- **数据分片**：16384 个哈希槽（hash slot）自动分配到多个主节点，支持水平扩展
- **高可用**：每个主节点配备从节点，主节点故障时自动 failover
- **去中心化**：Gossip 协议实现节点间通信，无单点故障
- **线性扩展**：支持在线添加/移除节点，自动 slot 迁移
- **原子操作**：同一 slot 内支持 MULTI/EXEC 事务和 Lua 脚本

### 1.2 适用场景

| 场景 | 说明 |
|------|------|
| 高并发缓存 | 电商秒杀、热点数据缓存，QPS 10万+ |
| 会话存储 | 分布式 Session 共享，支持 TTL 自动过期 |
| 排行榜/计数器 | Sorted Set 实现实时排行，原子 INCR 计数 |
| 消息队列 | Stream 数据结构实现轻量级消息队列 |
| 分布式锁 | Redlock 算法实现跨节点分布式锁 |
| 实时数据分析 | HyperLogLog 基数统计、Bitmap 用户行为分析 |

### 1.3 架构原理图

```mermaid
graph TB
    subgraph Client["客户端层"]
        style Client fill:#e1f5fe,stroke:#0288d1
        APP["应用程序"]
        SDK["Redis SDK<br/>(支持 Cluster 协议)"]
        APP --> SDK
    end

    subgraph Cluster["Redis Cluster (6 节点)"]
        style Cluster fill:#fff3e0,stroke:#f57c00

        subgraph Master1["Master-01<br/>Slot 0-5460"]
            style Master1 fill:#c8e6c9,stroke:#388e3c
            M1["redis-server<br/>192.168.1.101:6379"]
        end
        subgraph Replica1["Replica-01"]
            style Replica1 fill:#f3e5f5,stroke:#7b1fa2
            R1["redis-server<br/>192.168.1.104:6379"]
        end

        subgraph Master2["Master-02<br/>Slot 5461-10922"]
            style Master2 fill:#c8e6c9,stroke:#388e3c
            M2["redis-server<br/>192.168.1.102:6379"]
        end
        subgraph Replica2["Replica-02"]
            style Replica2 fill:#f3e5f5,stroke:#7b1fa2
            R2["redis-server<br/>192.168.1.105:6379"]
        end

        subgraph Master3["Master-03<br/>Slot 10923-16383"]
            style Master3 fill:#c8e6c9,stroke:#388e3c
            M3["redis-server<br/>192.168.1.103:6379"]
        end
        subgraph Replica3["Replica-03"]
            style Replica3 fill:#f3e5f5,stroke:#7b1fa2
            R3["redis-server<br/>192.168.1.106:6379"]
        end

        M1 -.->|"Gossip 16379"| M2
        M2 -.->|"Gossip 16379"| M3
        M3 -.->|"Gossip 16379"| M1
        M1 -->|"主从复制"| R1
        M2 -->|"主从复制"| R2
        M3 -->|"主从复制"| R3
    end

    SDK -->|"CRC16(key) % 16384<br/>路由到对应 Master"| Cluster
```

### 1.4 版本说明

> 以下版本号均通过实际查询确认（GitHub Releases API + Docker Hub），非凭记忆填写。

| 组件 | 版本 | 兼容性 |
|------|------|--------|
| **Redis Server** | 8.6.1（2026-03 最新稳定版） | Linux x86_64 / ARM64 |
| **Redis CLI** | 随 Redis Server 一同安装 | — |
| **操作系统** | Rocky Linux 9.x / Ubuntu 22.04 LTS | 内核 ≥ 5.4 |
| **GCC**（源码编译时） | ≥ 9.0 | Rocky 9 自带 11.x |

---

## 2. 版本选择指南

### 2.1 版本对应关系表

| Redis 大版本 | 发布周期 | Cluster 支持 | 关键特性 |
|-------------|---------|-------------|---------|
| 8.x（当前） | 2025+ | 完整支持 | 新版模块系统、性能优化、hash slot 迁移增强 |
| 7.x | 2022-2025 | 完整支持 | ACL v2、Function、Sharded Pub/Sub、Multi-part AOF |
| 6.x | 2020-2022 | 完整支持 | ACL、SSL/TLS、RESP3 协议 |

### 2.2 版本决策建议

| 场景 | 建议 |
|------|------|
| **新建集群** | 直接使用 8.6.1，享受最新性能优化和安全修复 |
| **现有 7.x 集群** | 评估后滚动升级至 8.x，Redis Cluster 支持不停机升级 |
| **现有 6.x 集群** | 建议先升级至 7.x 过渡，再升级至 8.x |
| **多集群混合** | 新集群用 8.x，老集群按计划逐步升级，客户端 SDK 需兼容两个版本 |

---

## 3. 生产环境规划（高可用架构）

### 3.1 集群架构图

```mermaid
graph LR
    subgraph AZ1["可用区 A / 机架 A"]
        style AZ1 fill:#e8f5e9,stroke:#4caf50
        M1["Master-01<br/>192.168.1.101<br/>Slot 0-5460"]
        R2["Replica-02<br/>192.168.1.105<br/>(Master-02 的从)"]
    end

    subgraph AZ2["可用区 B / 机架 B"]
        style AZ2 fill:#e3f2fd,stroke:#2196f3
        M2["Master-02<br/>192.168.1.102<br/>Slot 5461-10922"]
        R3["Replica-03<br/>192.168.1.106<br/>(Master-03 的从)"]
    end

    subgraph AZ3["可用区 C / 机架 C"]
        style AZ3 fill:#fce4ec,stroke:#e91e63
        M3["Master-03<br/>192.168.1.103<br/>Slot 10923-16383"]
        R1["Replica-01<br/>192.168.1.104<br/>(Master-01 的从)"]
    end

    M1 -->|"复制"| R1
    M2 -->|"复制"| R2
    M3 -->|"复制"| R3
```

> ⚠️ **关键设计**：主从节点必须分布在不同可用区/机架，确保单个可用区故障时集群仍可用。上图中 Master-01 在 AZ-A，其 Replica-01 在 AZ-C，以此类推。

### 3.2 节点角色与配置要求

| 角色 | 数量 | 最低配置 | 推荐配置 | 说明 |
|------|------|---------|---------|------|
| Master | 3 | 4C 8G 100G SSD | 8C 16G 500G NVMe SSD | 承载读写，内存按数据量 × 2 预留 |
| Replica | 3 | 4C 8G 100G SSD | 8C 16G 500G NVMe SSD | 故障接管 + 读分离 |

> ⚠️ **内存规划**：`maxmemory` 设置为物理内存的 **60%-75%**，预留空间给 RDB/AOF 重写、fork 子进程、操作系统缓存。例如 16G 物理内存建议 `maxmemory 10gb`。

### 3.3 网络与端口规划

| 源 | 目标端口 | 协议 | 用途 |
|----|---------|------|------|
| 客户端 → Redis 节点 | 6379/tcp | RESP | Redis 数据读写 |
| Redis 节点 ↔ Redis 节点 | 16379/tcp | Gossip (二进制) | 集群总线：节点发现、故障检测、slot 迁移 |
| 运维机 → Redis 节点 | 6379/tcp | RESP | redis-cli 管理 |
| Prometheus → Redis 节点 | 9121/tcp | HTTP | redis_exporter 指标采集（可选） |

> ⚠️ 集群总线端口 = 数据端口 + 10000（默认 6379 + 10000 = 16379），防火墙必须同时放行两个端口。

---

## 4. 生产环境部署

### 4.1 前置准备（所有节点）

> 🖥️ **执行节点：所有节点（6 台）**

#### 4.1.1 系统优化

```bash
# ── 内核参数优化 ──────────────────────────
cat > /etc/sysctl.d/99-redis.conf << 'EOF'
# Redis 生产环境内核参数
vm.overcommit_memory = 1          # ★ Redis BGSAVE 必须，允许 fork 时 overcommit
vm.swappiness = 1                 # 尽量避免使用 swap（设为 0 在某些内核版本可能导致 OOM killer 误杀）
net.core.somaxconn = 65535        # ★ 监听队列上限，需 ≥ Redis tcp-backlog
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_fin_timeout = 15
EOF

sysctl -p /etc/sysctl.d/99-redis.conf
```

```bash
# ── 关闭 Transparent Huge Pages（THP）──────
# ★ Redis 强烈建议关闭 THP，否则 fork 时延迟和内存占用显著增加
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=redis.service

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

sysctl vm.overcommit_memory
# 预期输出：vm.overcommit_memory = 1
```

```bash
# ── 文件描述符限制 ──────────────────────────
cat > /etc/security/limits.d/99-redis.conf << 'EOF'
redis soft nofile 65535
redis hard nofile 65535
redis soft nproc 65535
redis hard nproc 65535
EOF
```

#### 4.1.2 创建 Redis 用户与目录

```bash
id -u redis &>/dev/null || useradd -r -s /sbin/nologin -d /opt/redis redis

mkdir -p /opt/redis/{bin,conf,data,logs,run}
chown -R redis:redis /opt/redis
```

#### 4.1.3 防火墙配置

```bash
# ── Rocky Linux 9（firewalld）──────────────
firewall-cmd --permanent --add-port=6379/tcp
firewall-cmd --permanent --add-port=16379/tcp
firewall-cmd --reload

# ✅ 验证
firewall-cmd --list-ports
# 预期输出包含：6379/tcp 16379/tcp

# ── Ubuntu 22.04（ufw）────────────────────
# ufw allow 6379/tcp
# ufw allow 16379/tcp
# ufw reload
```

> 📌 注意：云主机（阿里云/AWS/腾讯云）通常在安全组中配置端口规则，无需操作 firewalld/ufw。

### 4.2 部署步骤

> 🖥️ **执行节点：所有节点（6 台）**

#### 4.2.1 安装 Redis 8.6.1（源码编译）

```bash
# ── Rocky Linux 9 ──────────────────────────
dnf install -y gcc make jemalloc-devel systemd-devel

# ── Ubuntu 22.04（差异）────────────────────
# apt-get update && apt-get install -y build-essential libjemalloc-dev libsystemd-dev
```

```bash
cd /tmp
[ -f redis-8.6.1.tar.gz ] || wget -O redis-8.6.1.tar.gz "https://download.redis.io/releases/redis-8.6.1.tar.gz"
tar xzf redis-8.6.1.tar.gz
cd redis-8.6.1

make -j$(nproc) USE_SYSTEMD=yes BUILD_TLS=yes
make install PREFIX=/opt/redis

chown -R redis:redis /opt/redis/bin/
```

```bash
# ✅ 验证
/opt/redis/bin/redis-server --version
# 预期输出：Redis server v=8.6.1 ...

/opt/redis/bin/redis-cli --version
# 预期输出：redis-cli 8.6.1
```

```bash
# 清理编译临时文件
rm -rf /tmp/redis-8.6.1 /tmp/redis-8.6.1.tar.gz
```

#### 4.2.2 配置文件

> 🖥️ **执行节点：每个节点分别配置（修改 bind IP 和 cluster-announce-ip）**

以 Master-01（192.168.1.101）为例，其他节点替换对应 IP：

```bash
cat > /opt/redis/conf/redis.conf << 'EOF'
# ━━━━━━━━━━━━━━━━ 网络 ━━━━━━━━━━━━━━━━
bind 192.168.1.101 127.0.0.1    # ★ ← 根据本节点实际 IP 修改
port 6379
protected-mode yes
tcp-backlog 511                  # 需配合 net.core.somaxconn ≥ 511
timeout 300                      # 空闲客户端超时断开（秒），0 为不断开
tcp-keepalive 60                 # TCP keepalive 探测间隔

# ━━━━━━━━━━━━━━━━ 通用 ━━━━━━━━━━━━━━━━
daemonize no                     # systemd 管理，不使用 daemon 模式
pidfile /opt/redis/run/redis_6379.pid
loglevel notice
logfile /opt/redis/logs/redis.log
databases 16

# ━━━━━━━━━━━━━━━━ 安全 ━━━━━━━━━━━━━━━━
requirepass YourStr0ngP@ssw0rd!  # ★ ← 根据实际环境修改，生产必须设置强密码
masterauth YourStr0ngP@ssw0rd!   # ★ ← 与 requirepass 保持一致，集群节点间认证

# ━━━━━━━━━━━━━━━━ 内存 ━━━━━━━━━━━━━━━━
maxmemory 10gb                   # ★ ← 根据物理内存调整，建议为物理内存的 60%-75%
                                 # ⚠️ 16G 物理内存建议 10gb，32G 建议 20gb-24gb
maxmemory-policy allkeys-lru     # 内存满时淘汰策略
                                 # ⚠️ 纯缓存场景用 allkeys-lru
                                 # ⚠️ 有持久化需求用 volatile-lru（仅淘汰设置了 TTL 的 key）

# ━━━━━━━━━━━━━━━━ RDB 持久化 ━━━━━━━━━━━━━━━━
save 3600 1                      # 3600 秒内至少 1 次写入则触发 RDB
save 300 100                     # 300 秒内至少 100 次写入
save 60 10000                    # 60 秒内至少 10000 次写入
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /opt/redis/data              # ★ ← 数据目录，建议挂载独立 SSD 磁盘

# ━━━━━━━━━━━━━━━━ AOF 持久化 ━━━━━━━━━━━━━━━━
appendonly yes                   # ★ 生产环境必须开启 AOF
appendfilename "appendonly.aof"
appendfsync everysec             # 每秒刷盘，兼顾性能与数据安全
                                 # ⚠️ 对数据丢失零容忍用 always（性能下降明显）
auto-aof-rewrite-percentage 100  # AOF 文件增长 100% 时触发重写
auto-aof-rewrite-min-size 64mb   # AOF 文件最小 64MB 才触发重写
aof-use-rdb-preamble yes         # 混合持久化：AOF 重写时使用 RDB 格式前缀，加速加载

# ━━━━━━━━━━━━━━━━ 主从复制 ━━━━━━━━━━━━━━━━
replica-serve-stale-data yes     # 从节点在同步中断时仍响应读请求（返回旧数据）
replica-read-only yes            # 从节点只读
repl-diskless-sync yes           # 无盘复制：主节点直接通过 socket 发送 RDB 给从节点
repl-diskless-sync-delay 5       # 无盘复制延迟 5 秒，等待更多从节点连接
repl-backlog-size 256mb          # ★ 复制积压缓冲区，网络抖动时避免全量同步
                                 # ⚠️ 写入量大的场景建议 512mb 或更大
repl-backlog-ttl 3600            # 积压缓冲区保留时间

# ━━━━━━━━━━━━━━━━ Lazy Free ━━━━━━━━━━━━━━━━
lazyfree-lazy-eviction yes       # 内存淘汰时异步释放
lazyfree-lazy-expire yes         # key 过期时异步释放
lazyfree-lazy-server-del yes     # DEL 命令改为异步 UNLINK
replica-lazy-flush yes           # 从节点全量同步前异步清空数据

# ━━━━━━━━━━━━━━━━ 性能调优 ━━━━━━━━━━━━━━━━
hz 10                            # 内部定时任务频率（默认 10，高并发场景可调至 100）
dynamic-hz yes                   # 根据客户端连接数动态调整 hz
io-threads 4                     # ★ ← 多线程 I/O，建议设为 CPU 核数的 1/2 到 2/3
                                 # ⚠️ 4 核设 2-3，8 核设 4-6，仅加速网络 I/O，命令执行仍单线程
io-threads-do-reads yes          # 读操作也使用多线程

# ━━━━━━━━━━━━━━━━ Cluster ━━━━━━━━━━━━━━━━
cluster-enabled yes
cluster-config-file /opt/redis/data/nodes-6379.conf
cluster-node-timeout 15000       # ★ 节点超时判定（毫秒），生产建议 15000
                                 # ⚠️ 过小会导致网络抖动时误判故障
cluster-announce-ip 192.168.1.101  # ★ ← 根据本节点实际 IP 修改
cluster-announce-port 6379
cluster-announce-bus-port 16379
cluster-require-full-coverage yes  # 任一 slot 不可用时整个集群拒绝写入
                                   # ⚠️ 设为 no 则部分 slot 不可用时其余 slot 仍可读写
cluster-allow-reads-when-down no   # 集群 down 时是否允许读

# ━━━━━━━━━━━━━━━━ 慢查询日志 ━━━━━━━━━━━━━━━━
slowlog-log-slower-than 10000    # 超过 10ms 的命令记入慢查询日志
slowlog-max-len 1024             # 慢查询日志最多保留 1024 条

# ━━━━━━━━━━━━━━━━ 客户端限制 ━━━━━━━━━━━━━━━━
maxclients 10000                 # 最大客户端连接数
EOF

chown redis:redis /opt/redis/conf/redis.conf
chmod 640 /opt/redis/conf/redis.conf
```

> ⚠️ **每个节点必须修改的参数**：
> - `bind` — 本节点 IP
> - `cluster-announce-ip` — 本节点 IP
> - 其余参数 6 个节点保持一致

#### 4.2.3 Systemd 服务文件

> 🖥️ **执行节点：所有节点（6 台）**

```bash
cat > /etc/systemd/system/redis.service << 'EOF'
[Unit]
Description=Redis 8.6.1 Cluster Node
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=redis
Group=redis
ExecStart=/opt/redis/bin/redis-server /opt/redis/conf/redis.conf
ExecStop=/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! shutdown  # ★ ← 密码与配置文件一致
Restart=always
RestartSec=5
LimitNOFILE=65535
LimitNPROC=65535
TimeoutStartSec=30
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis.service
```

```bash
# ✅ 验证
systemctl status redis.service
# 预期输出：Active: active (running)

/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! PING
# 预期输出：PONG
```

### 4.3 集群初始化与配置

> 🖥️ **执行节点：任意一台 Master 节点（如 Master-01）**

确认 6 个节点全部启动后，执行集群创建命令：

```bash
/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! --cluster create \
  192.168.1.101:6379 \
  192.168.1.102:6379 \
  192.168.1.103:6379 \
  192.168.1.104:6379 \
  192.168.1.105:6379 \
  192.168.1.106:6379 \
  --cluster-replicas 1
```

> ⚠️ `--cluster-replicas 1` 表示每个主节点分配 1 个从节点。Redis 会自动将前 3 个节点设为 Master，后 3 个设为 Replica。确认 slot 分配方案后输入 `yes`。

预期输出关键信息：

```
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
...
[OK] All nodes agree about slots configuration.
[OK] All 16384 slots covered.
```

> ⚠️ **跨机架部署注意**：默认分配可能将主从放在同一机架。创建集群后，使用 `CLUSTER REPLICATE` 手动调整主从关系，确保主从分布在不同可用区。

### 4.4 安装验证

> 🖥️ **执行节点：任意一台节点**

```bash
# ✅ 验证集群状态
/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! CLUSTER INFO
# 预期输出关键行：
# cluster_state:ok
# cluster_slots_assigned:16384
# cluster_slots_ok:16384
# cluster_known_nodes:6
# cluster_size:3
```

```bash
# ✅ 验证节点列表
/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! CLUSTER NODES
# 预期输出：3 个 master + 3 个 slave，所有节点状态为 connected
```

```bash
# ✅ 验证读写
/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! -c SET test:key "hello-cluster"
# 预期输出：OK（可能带 -> Redirected to slot [xxxx] 提示，属正常）

/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! -c GET test:key
# 预期输出：hello-cluster
```

```bash
# ✅ 验证集群完整性检查
/opt/redis/bin/redis-cli -a YourStr0ngP@ssw0rd! --cluster check 192.168.1.101:6379
# 预期输出：
# [OK] All nodes agree about slots configuration.
# [OK] All 16384 slots covered.
```

---

## 5. 关键参数配置说明

### 5.1 核心配置文件详解

完整配置文件已在 4.2.2 节提供（含逐行注释），此处仅对关键参数分类汇总。

| 分类 | 参数 | 推荐值 | 说明 |
|------|------|--------|------|
| **内存** | `maxmemory` | 物理内存 60%-75% | ★ 必须设置，否则无限增长直到 OOM |
| **内存** | `maxmemory-policy` | `allkeys-lru` | 纯缓存用 allkeys-lru，有持久化需求用 volatile-lru |
| **持久化** | `appendonly` | `yes` | ★ 生产必须开启 AOF |
| **持久化** | `appendfsync` | `everysec` | 兼顾性能与安全 |
| **持久化** | `aof-use-rdb-preamble` | `yes` | 混合持久化，加速重启加载 |
| **复制** | `repl-backlog-size` | `256mb` | ★ 写入量大时调至 512mb+ |
| **复制** | `repl-diskless-sync` | `yes` | 减少磁盘 I/O |
| **Cluster** | `cluster-node-timeout` | `15000` | 生产建议 15s，过小易误判 |
| **性能** | `io-threads` | CPU 核数 ÷ 2 | ★ 多线程 I/O，显著提升网络吞吐 |
| **性能** | `hz` | `10` | 高并发场景可调至 100 |
| **Lazy Free** | `lazyfree-lazy-*` | 全部 `yes` | 避免大 key 删除阻塞主线程 |
| **安全** | `requirepass` | 强密码 | ★ 生产必须设置 |
| **安全** | `protected-mode` | `yes` | 配合 bind 限制访问来源 |

### 5.2 生产环境推荐调优参数

#### 内存相关

```bash
# 查看当前内存使用
redis-cli -a YourStr0ngP@ssw0rd! INFO memory
# 关注指标：
# used_memory_human      — 已使用内存
# maxmemory_human        — 最大内存限制
# mem_fragmentation_ratio — 内存碎片率（正常范围 1.0-1.5，>1.5 需关注）
```

> ⚠️ 当 `mem_fragmentation_ratio` > 1.5 时，说明内存碎片严重，可通过 `MEMORY PURGE` 手动释放，或配置 `activedefrag yes` 开启自动碎片整理。

#### 网络相关

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `tcp-backlog` | `511` | 需配合内核 `net.core.somaxconn` ≥ 511 |
| `timeout` | `300` | 空闲连接超时，防止连接泄漏 |
| `tcp-keepalive` | `60` | 检测死连接 |
| `maxclients` | `10000` | 根据业务并发量调整 |

#### 持久化相关

| 场景 | RDB | AOF | 说明 |
|------|-----|-----|------|
| 纯缓存（可丢数据） | 开启 | 关闭 | 仅用 RDB 做冷备份 |
| 缓存 + 数据安全 | 开启 | everysec | ★ 推荐方案，最多丢失 1 秒数据 |
| 金融/交易场景 | 开启 | always | 零数据丢失，性能下降约 50% |

---

## 6. 快速体验部署（开发 / 测试环境）

> ⚠️ **本章方案仅适用于开发/测试环境，严禁用于生产。** 使用 Docker Compose 在单机模拟 6 节点 Redis Cluster，便于快速验证和学习。

### 6.1 快速启动方案选型

Redis Cluster 强依赖多节点集群模式，选择 Docker Compose 在单机启动 6 个容器模拟 3 主 3 从集群。

### 6.2 快速启动步骤与验证

```bash
mkdir -p /tmp/redis-cluster-test
```

```bash
cat > /tmp/redis-cluster-test/docker-compose.yml << 'DEOF'
services:
  redis-node-1:
    image: redis:8.6.1
    container_name: redis-test-1
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.11
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.11
    volumes:
      - data1:/data

  redis-node-2:
    image: redis:8.6.1
    container_name: redis-test-2
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.12
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.12
    volumes:
      - data2:/data

  redis-node-3:
    image: redis:8.6.1
    container_name: redis-test-3
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.13
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.13
    volumes:
      - data3:/data

  redis-node-4:
    image: redis:8.6.1
    container_name: redis-test-4
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.14
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.14
    volumes:
      - data4:/data

  redis-node-5:
    image: redis:8.6.1
    container_name: redis-test-5
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.15
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.15
    volumes:
      - data5:/data

  redis-node-6:
    image: redis:8.6.1
    container_name: redis-test-6
    command: >
      redis-server
      --port 6379
      --cluster-enabled yes
      --cluster-config-file nodes.conf
      --cluster-node-timeout 5000
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
      --requirepass TestPass123
      --masterauth TestPass123
      --protected-mode no
      --cluster-announce-ip 172.28.0.16
      --cluster-announce-port 6379
      --cluster-announce-bus-port 16379
    networks:
      redis-net:
        ipv4_address: 172.28.0.16
    volumes:
      - data6:/data

networks:
  redis-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/24

volumes:
  data1:
  data2:
  data3:
  data4:
  data5:
  data6:
DEOF
```

```bash
# 启动集群
cd /tmp/redis-cluster-test
docker compose up -d

# 等待所有节点就绪
sleep 5

# 创建集群
docker exec redis-test-1 redis-cli -a TestPass123 --cluster create \
  172.28.0.11:6379 172.28.0.12:6379 172.28.0.13:6379 \
  172.28.0.14:6379 172.28.0.15:6379 172.28.0.16:6379 \
  --cluster-replicas 1 --cluster-yes
```

```bash
# ✅ 验证
docker exec redis-test-1 redis-cli -a TestPass123 CLUSTER INFO
# 预期输出：cluster_state:ok, cluster_slots_ok:16384, cluster_known_nodes:6

docker exec redis-test-1 redis-cli -a TestPass123 -c SET hello world
# 预期输出：OK

docker exec redis-test-1 redis-cli -a TestPass123 -c GET hello
# 预期输出：world
```

### 6.3 停止与清理

```bash
cd /tmp/redis-cluster-test
docker compose down -v
rm -rf /tmp/redis-cluster-test/
docker system prune -f
```

---

## 7. 日常运维操作

### 7.1 常用管理命令

#### 集群状态检查

```bash
# 集群整体状态
redis-cli -a YourStr0ngP@ssw0rd! CLUSTER INFO

# 节点列表（含角色、slot 分配、连接状态）
redis-cli -a YourStr0ngP@ssw0rd! CLUSTER NODES

# 集群完整性检查（slot 覆盖、节点一致性）
redis-cli -a YourStr0ngP@ssw0rd! --cluster check 192.168.1.101:6379

# 集群概览（各节点 key 数量和 slot 分布）
redis-cli -a YourStr0ngP@ssw0rd! --cluster info 192.168.1.101:6379
```

#### 内存与性能监控

```bash
# 内存使用详情
redis-cli -a YourStr0ngP@ssw0rd! INFO memory
# 关注：used_memory_human, maxmemory_human, mem_fragmentation_ratio

# 单个 key 内存占用
redis-cli -a YourStr0ngP@ssw0rd! -c MEMORY USAGE <key>

# 内存诊断
redis-cli -a YourStr0ngP@ssw0rd! MEMORY DOCTOR

# 慢查询日志
redis-cli -a YourStr0ngP@ssw0rd! SLOWLOG GET 10
redis-cli -a YourStr0ngP@ssw0rd! SLOWLOG LEN
redis-cli -a YourStr0ngP@ssw0rd! SLOWLOG RESET

# 实时命令监控（调试用，生产慎用）
redis-cli -a YourStr0ngP@ssw0rd! MONITOR

# 延迟诊断
redis-cli -a YourStr0ngP@ssw0rd! LATENCY LATEST

# 客户端连接列表
redis-cli -a YourStr0ngP@ssw0rd! CLIENT LIST

# 服务器统计
redis-cli -a YourStr0ngP@ssw0rd! INFO stats
# 关注：instantaneous_ops_per_sec, keyspace_hits, keyspace_misses
```

#### 数据操作

```bash
# Cluster 模式下必须加 -c 参数
redis-cli -a YourStr0ngP@ssw0rd! -c SET key value
redis-cli -a YourStr0ngP@ssw0rd! -c GET key
redis-cli -a YourStr0ngP@ssw0rd! -c DEL key

# 查看 key 所在 slot
redis-cli -a YourStr0ngP@ssw0rd! CLUSTER KEYSLOT <key>

# 查看某个 slot 中的 key 数量
redis-cli -a YourStr0ngP@ssw0rd! CLUSTER COUNTKEYSINSLOT <slot>

# 扫描 key（生产环境禁止使用 KEYS *，使用 SCAN 替代）
redis-cli -a YourStr0ngP@ssw0rd! SCAN 0 MATCH "prefix:*" COUNT 100

# 查看 key 编码类型
redis-cli -a YourStr0ngP@ssw0rd! -c OBJECT ENCODING <key>

# 当前节点 key 数量
redis-cli -a YourStr0ngP@ssw0rd! DBSIZE
```

#### 配置热更新

```bash
# 在线修改配置（无需重启）
redis-cli -a YourStr0ngP@ssw0rd! CONFIG SET maxmemory 12gb
redis-cli -a YourStr0ngP@ssw0rd! CONFIG SET hz 100

# 将当前运行配置持久化到配置文件
redis-cli -a YourStr0ngP@ssw0rd! CONFIG REWRITE

# 查看当前配置值
redis-cli -a YourStr0ngP@ssw0rd! CONFIG GET maxmemory
redis-cli -a YourStr0ngP@ssw0rd! CONFIG GET "save"
```

#### ACL 用户管理

```bash
# 查看所有用户
redis-cli -a YourStr0ngP@ssw0rd! ACL LIST

# 查看当前用户
redis-cli -a YourStr0ngP@ssw0rd! ACL WHOAMI

# 创建只读用户（仅允许 GET/MGET/SCAN 等读命令）
redis-cli -a YourStr0ngP@ssw0rd! ACL SETUSER readonly on '>ReadOnlyP@ss' ~* +@read

# 创建应用用户（允许读写，禁止管理命令）
redis-cli -a YourStr0ngP@ssw0rd! ACL SETUSER appuser on '>AppP@ss2026' ~app:* +@read +@write +@string +@hash +@list +@set +@sortedset -@admin -@dangerous

# 持久化 ACL 配置
redis-cli -a YourStr0ngP@ssw0rd! ACL SAVE
```

### 7.2 备份与恢复

#### RDB 备份

```bash
# 触发后台 RDB 快照
redis-cli -a YourStr0ngP@ssw0rd! BGSAVE

# 查看最后一次 RDB 保存时间
redis-cli -a YourStr0ngP@ssw0rd! LASTSAVE

# 查看持久化状态
redis-cli -a YourStr0ngP@ssw0rd! INFO persistence
# 关注：rdb_last_bgsave_status:ok, rdb_last_save_time

# 备份 RDB 文件（在所有节点执行）
cp /opt/redis/data/dump.rdb /backup/redis/dump-$(date +%Y%m%d%H%M%S).rdb
```

#### AOF 备份

```bash
# 手动触发 AOF 重写
redis-cli -a YourStr0ngP@ssw0rd! BGREWRITEAOF

# 备份 AOF 文件
cp -r /opt/redis/data/appendonlydir/ /backup/redis/aof-$(date +%Y%m%d%H%M%S)/
```

#### 恢复流程

```
1. 停止 Redis 服务
2. 将备份的 RDB/AOF 文件复制到 /opt/redis/data/
3. 确保文件权限为 redis:redis
4. 启动 Redis 服务（优先加载 AOF，若 AOF 不存在则加载 RDB）
```

### 7.3 集群扩缩容

#### 扩容（添加节点）

```bash
# 添加新的 Master 节点
redis-cli -a YourStr0ngP@ssw0rd! --cluster add-node \
  192.168.1.107:6379 192.168.1.101:6379

# 为新 Master 分配 slot（从现有节点迁移）
redis-cli -a YourStr0ngP@ssw0rd! --cluster reshard 192.168.1.101:6379 \
  --cluster-from <source-node-id> \
  --cluster-to <new-node-id> \
  --cluster-slots 4096 \
  --cluster-yes

# 添加新的 Replica 节点
redis-cli -a YourStr0ngP@ssw0rd! --cluster add-node \
  192.168.1.108:6379 192.168.1.101:6379 \
  --cluster-slave --cluster-master-id <master-node-id>
```

#### 缩容（移除节点）

```bash
# 先迁移 slot 到其他节点
redis-cli -a YourStr0ngP@ssw0rd! --cluster reshard 192.168.1.101:6379 \
  --cluster-from <removing-node-id> \
  --cluster-to <target-node-id> \
  --cluster-slots <slot-count> \
  --cluster-yes

# 移除节点
redis-cli -a YourStr0ngP@ssw0rd! --cluster del-node \
  192.168.1.101:6379 <removing-node-id>
```

#### Slot 均衡

```bash
# 自动均衡 slot 分布
redis-cli -a YourStr0ngP@ssw0rd! --cluster rebalance 192.168.1.101:6379 \
  --cluster-threshold 2
```

### 7.4 版本升级

#### 滚动升级步骤（不停机）

```
1. 先升级所有 Replica 节点（逐个操作）：
   a. 停止 Replica 的 Redis 服务
   b. 替换 redis-server 二进制文件
   c. 启动服务，确认自动重新加入集群

2. 逐个升级 Master 节点：
   a. 在目标 Master 的 Replica 上执行 CLUSTER FAILOVER（Replica 提升为 Master）
   b. 停止原 Master（现在已降为 Replica）的 Redis 服务
   c. 替换二进制文件，启动服务
   d. 确认节点重新加入集群
```

```bash
# 在 Replica 上执行手动 failover
redis-cli -a YourStr0ngP@ssw0rd! -h <replica-ip> -p 6379 CLUSTER FAILOVER

# 确认 failover 完成
redis-cli -a YourStr0ngP@ssw0rd! CLUSTER NODES
```

#### 回滚方案

```
1. 停止已升级节点的 Redis 服务
2. 将二进制文件替换回旧版本
3. 启动服务（Redis 向下兼容 RDB/AOF 格式）
4. 若 RDB/AOF 格式不兼容（跨大版本），需从备份恢复
```

> ⚠️ 升级前务必对所有节点执行 `BGSAVE` 并备份 RDB 文件。

---

## 8. 使用手册（数据库专项）

### 8.1 连接与认证

```bash
# 单节点连接
redis-cli -h 192.168.1.101 -p 6379 -a YourStr0ngP@ssw0rd!

# Cluster 模式连接（自动跟随 MOVED 重定向）
redis-cli -h 192.168.1.101 -p 6379 -a YourStr0ngP@ssw0rd! -c

# 使用 ACL 用户连接
redis-cli -h 192.168.1.101 -p 6379 --user appuser --pass AppP@ss2026 -c
```

### 8.2 数据类型操作

```bash
# String
SET user:1001:name "张三" EX 3600    # 设置值，3600 秒过期
GET user:1001:name
MSET k1 v1 k2 v2 k3 v3             # 批量设置（需在同一 slot，可用 hash tag）
INCR counter:page_view              # 原子自增

# Hash
HSET user:1001 name "张三" age 30 city "北京"
HGET user:1001 name
HGETALL user:1001

# List
LPUSH queue:tasks "task1" "task2"
RPOP queue:tasks
LRANGE queue:tasks 0 -1

# Set
SADD tags:article:1 "redis" "database" "nosql"
SMEMBERS tags:article:1
SINTER tags:article:1 tags:article:2   # 交集

# Sorted Set
ZADD leaderboard 100 "player1" 200 "player2" 150 "player3"
ZREVRANGE leaderboard 0 9 WITHSCORES   # Top 10
ZRANK leaderboard "player1"

# Stream
XADD mystream '*' field1 value1 field2 value2
XLEN mystream
XRANGE mystream - + COUNT 10
```

> ⚠️ **Cluster 模式下的多 key 操作**：`MSET`、`MGET`、`SUNION` 等多 key 命令要求所有 key 在同一 slot。使用 **Hash Tag** `{tag}` 强制路由：`SET {user:1001}:name "张三"` 和 `SET {user:1001}:age 30` 会被路由到同一 slot。

### 8.3 用户与权限管理

```bash
# 查看所有 ACL 用户
ACL LIST

# 创建用户
ACL SETUSER monitor on '>MonitorP@ss' ~* +info +cluster|info +cluster|nodes +slowlog|get +client|list -@all

# 删除用户
ACL DELUSER <username>

# 持久化 ACL
ACL SAVE

# 查看 ACL 日志（记录被拒绝的命令）
ACL LOG 10
ACL LOG RESET
```

### 8.4 性能查询与慢查询分析

```bash
# 慢查询日志
SLOWLOG GET 20                    # 获取最近 20 条慢查询
SLOWLOG LEN                       # 慢查询日志条数
SLOWLOG RESET                     # 清空慢查询日志

# 实时延迟监控
redis-cli --latency -h 192.168.1.101 -p 6379 -a YourStr0ngP@ssw0rd!
# 输出：min: 0, max: 1, avg: 0.50 (100 samples)

# 延迟历史
redis-cli --latency-history -h 192.168.1.101 -p 6379 -a YourStr0ngP@ssw0rd!

# 内置延迟诊断
LATENCY LATEST
LATENCY HISTORY <event>

# 大 key 扫描
redis-cli -h 192.168.1.101 -p 6379 -a YourStr0ngP@ssw0rd! --bigkeys
```

### 8.5 主从/集群状态监控命令

```bash
# 复制状态
INFO replication
# 关注：role, connected_slaves, slave0:state=online

# 集群状态
CLUSTER INFO
# 关注：cluster_state:ok, cluster_slots_ok:16384

# 节点详情
CLUSTER NODES

# 当前节点 ID
CLUSTER MYID

# Slot 分布
CLUSTER SLOTS
```

### 8.6 生产常见故障处理命令

```bash
# 节点标记为 FAILING（手动触发故障转移）
CLUSTER FAILOVER                  # 在 Replica 上执行，安全提升为 Master
CLUSTER FAILOVER FORCE            # 强制 failover（Master 不可达时使用）
CLUSTER FAILOVER TAKEOVER         # 最后手段，不经过集群共识直接接管

# 修复集群（slot 迁移中断后的清理）
redis-cli -a YourStr0ngP@ssw0rd! --cluster fix 192.168.1.101:6379

# 重置节点（将节点从集群中移除，慎用）
CLUSTER RESET SOFT                # 软重置：清除 slot 和已知节点，保留数据
CLUSTER RESET HARD                # 硬重置：清除所有集群信息和数据

# 忘记节点（从集群中移除已下线节点的记录）
CLUSTER FORGET <node-id>          # 需在所有存活节点上执行
```

---

## 9. 注意事项与生产检查清单

### 9.1 安装前环境核查

| 检查项 | 命令 | 预期结果 |
|--------|------|---------|
| THP 已关闭 | `cat /sys/kernel/mm/transparent_hugepage/enabled` | `[never]` |
| overcommit_memory | `sysctl vm.overcommit_memory` | `= 1` |
| somaxconn | `sysctl net.core.somaxconn` | `≥ 65535` |
| 文件描述符 | `ulimit -n` | `≥ 65535` |
| 防火墙端口 | `firewall-cmd --list-ports` | 包含 `6379/tcp 16379/tcp` |
| 数据目录权限 | `ls -la /opt/redis/data/` | 属主为 `redis:redis` |
| 时钟同步 | `timedatectl status` | NTP 已同步 |

### 9.2 常见故障排查

#### 集群状态异常（cluster_state:fail）

- **现象**：`CLUSTER INFO` 返回 `cluster_state:fail`
- **原因**：有 slot 未被覆盖（Master 宕机且无可用 Replica）
- **排查步骤**：
  1. `CLUSTER NODES` 查看哪些节点状态为 `fail`
  2. 检查对应节点是否可达（网络/进程）
  3. 检查该 Master 的 Replica 是否存在
- **解决方案**：
  - 恢复故障节点，或在存活 Replica 上执行 `CLUSTER FAILOVER FORCE`
  - 若无 Replica，需添加新节点并手动分配 slot

#### 内存使用过高

- **现象**：`used_memory` 接近 `maxmemory`，开始触发淘汰
- **原因**：数据量增长超预期 / 大 key / 内存碎片
- **排查步骤**：
  1. `redis-cli --bigkeys` 扫描大 key
  2. `INFO memory` 查看 `mem_fragmentation_ratio`
  3. `MEMORY USAGE <key>` 检查可疑 key
- **解决方案**：
  - 清理过期/无用 key
  - 碎片率高时执行 `MEMORY PURGE` 或开启 `activedefrag`
  - 扩容集群节点

#### 主从复制中断

- **现象**：Replica 状态显示 `master_link_status:down`
- **原因**：网络中断 / `repl-backlog-size` 不足导致全量同步失败
- **排查步骤**：
  1. 检查 Master 和 Replica 之间网络连通性
  2. `INFO replication` 查看 `master_link_down_since_seconds`
  3. 检查 Redis 日志 `/opt/redis/logs/redis.log`
- **解决方案**：
  - 修复网络问题后 Replica 会自动重连
  - 若频繁全量同步，增大 `repl-backlog-size`

### 9.3 安全加固建议

| 措施 | 说明 |
|------|------|
| **设置强密码** | `requirepass` + `masterauth`，长度 ≥ 16 位，含大小写+数字+特殊字符 |
| **ACL 最小权限** | 为每个应用创建独立用户，仅授予所需命令和 key 模式权限 |
| **bind 限制** | 仅绑定内网 IP，禁止绑定 `0.0.0.0` |
| **禁用危险命令** | `rename-command FLUSHALL ""` / `rename-command FLUSHDB ""` / `rename-command KEYS ""` |
| **网络隔离** | Redis 部署在内网，通过防火墙/安全组限制访问来源 |
| **TLS 加密** | 跨机房/公网传输时启用 TLS（编译时需 `BUILD_TLS=yes`） |
| **定期审计** | 定期检查 `ACL LOG`、`SLOWLOG`、客户端连接列表 |

---

## 10. 参考资料

| 资源 | 链接 |
|------|------|
| Redis 官方文档 | [https://redis.io/docs/](https://redis.io/docs/) |
| Redis Cluster 规范 | [https://redis.io/docs/reference/cluster-spec/](https://redis.io/docs/reference/cluster-spec/) |
| Redis GitHub 仓库 | [https://github.com/redis/redis](https://github.com/redis/redis) |
| Redis 8.6.1 Release Notes | [https://github.com/redis/redis/releases/tag/8.6.1](https://github.com/redis/redis/releases/tag/8.6.1) |
| Redis 源码下载 | [https://download.redis.io/releases/redis-8.6.1.tar.gz](https://download.redis.io/releases/redis-8.6.1.tar.gz) |
| Docker Hub Redis | [https://hub.docker.com/_/redis](https://hub.docker.com/_/redis) |
