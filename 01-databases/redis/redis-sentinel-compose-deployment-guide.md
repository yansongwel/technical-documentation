# Redis Sentinel（Docker Compose）部署指南（带密码 + 自动故障转移 + 稳定入口）

> **适用场景**：单机 Docker 环境演练 / 中小规模生产的“非分片”高可用（主从 + Sentinel）  
> **版本**：Redis 7.2.x（LTS）  
> **特点**：Redis 主从复制 + Sentinel 自动故障转移 + HAProxy 提供固定访问入口（6379）  

---

## 1. 架构说明

该方案包含 3 类组件：

- **Redis 主从**：`redis-master`（初始主） + `redis-replica-1/2`（从）
- **Sentinel 集群**：`redis-sentinel-1/2/3`（Quorum=2）
- **HAProxy**：对外只暴露一个固定入口 `6379`，自动转发到当前主库

端口与访问方式：

- 客户端读写：连接宿主机 `6379`（HAProxy），使用密码认证
- Sentinel 查询：宿主机 `26379/26380/26381`（可选），使用同一密码认证

> 说明：Sentinel 在 Docker 内部使用固定 IP 互联（便于 Sentinel 配置要求 IP），Redis 节点不对外直接暴露端口，由 HAProxy 统一对外提供“主库入口”。

---

## 2. 目录结构

部署目录：

`01-databases/redis/compose-sentinel/`

```text
compose-sentinel/
├── .env
├── docker-compose.yml
├── config/
│   ├── redis-master.conf.template
│   ├── redis-replica.conf.template
│   ├── sentinel.conf.template
│   └── haproxy.cfg.template
└── data/
    ├── master/
    ├── replica-1/
    ├── replica-2/
    ├── sentinel-1/
    ├── sentinel-2/
    └── sentinel-3/
```

---

## 3. 部署前宿主机优化（生产建议）

> 🖥️ 执行节点：宿主机

### 3.1 内核参数

Redis 官方建议开启内存 overcommit，避免 fork（RDB/AOF rewrite/复制）在内存紧张时失败：

```bash
sudo sysctl -w vm.overcommit_memory=1
echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
```

建议提高连接队列上限（与 `tcp-backlog` 配合）：

```bash
sudo sysctl -w net.core.somaxconn=1024
echo "net.core.somaxconn=1024" | sudo tee -a /etc/sysctl.conf
```

### 3.2 禁用 THP（推荐）

THP 会增加延迟抖动，生产建议关闭：

```bash
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
```

---

## 4. 配置（必须）

编辑 [.env](file:///data/technical-documentation/01-databases/redis/compose-sentinel/.env)：

- `REDIS_PASSWORD`：必须修改
- `SENTINEL_*`：故障检测/切换参数（默认适合演练，可按业务调优）

---

## 5. 启动部署

> 🖥️ 执行节点：宿主机

```bash
cd /data/technical-documentation/01-databases/redis/compose-sentinel

mkdir -p ./data/master ./data/replica-1 ./data/replica-2 ./data/sentinel-1 ./data/sentinel-2 ./data/sentinel-3

docker compose up -d
docker compose ps
```

---

## 6. 验证与使用

### 6.1 验证固定入口（HAProxy 6379）

```bash
cd /data/technical-documentation/01-databases/redis/compose-sentinel
set -a && . ./.env && set +a

redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" PING
redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" SET hello world
redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" GET hello
```

### 6.2 验证 Sentinel

```bash
set -a && . ./.env && set +a

redis-cli -h 127.0.0.1 -p 26379 -a "$REDIS_PASSWORD" SENTINEL get-master-addr-by-name "$SENTINEL_MASTER_NAME"
redis-cli -h 127.0.0.1 -p 26379 -a "$REDIS_PASSWORD" SENTINEL slaves "$SENTINEL_MASTER_NAME"
```

---

## 7. 故障转移演练（建议至少做一次）

目标：模拟初始主库故障，验证 Sentinel 提升新主库，HAProxy 仍保持 `6379` 可写。

```bash
cd /data/technical-documentation/01-databases/redis/compose-sentinel
set -a && . ./.env && set +a

redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" SET before_failover 1

docker stop redis-master

for i in $(seq 1 40); do
  if redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" SET after_failover "$i" >/dev/null 2>&1; then
    echo "write_ok_after=${i}s"
    break
  fi
  sleep 1
done

redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" GET before_failover
redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" GET after_failover

docker start redis-master
```

---

## 8. 配置要点（生产级关键项）

### 8.1 Redis 持久化

本方案默认：

- AOF：开启（`appendonly yes`，`appendfsync everysec`）
- RDB：保留默认周期快照（便于恢复与加速重启）

配置位置：

- [redis-master.conf.template](file:///data/technical-documentation/01-databases/redis/compose-sentinel/config/redis-master.conf.template)
- [redis-replica.conf.template](file:///data/technical-documentation/01-databases/redis/compose-sentinel/config/redis-replica.conf.template)

### 8.2 密码认证

- Redis：`requirepass` + 从库 `masterauth`
- Sentinel：`requirepass`（并要求所有 Sentinel 使用同一密码，Sentinel 之间会用该密码互相认证）

### 8.3 固定入口（HAProxy）

HAProxy 通过 TCP 健康检查识别主库（AUTH → PING → INFO replication），只把当前主库标记为 UP：

- [haproxy.cfg.template](file:///data/technical-documentation/01-databases/redis/compose-sentinel/config/haproxy.cfg.template)

---

## 9. 常用运维命令

```bash
cd /data/technical-documentation/01-databases/redis/compose-sentinel
set -a && . ./.env && set +a

docker compose ps
docker compose logs -f redis-master
docker compose logs -f redis-sentinel-1
docker compose logs -f haproxy

redis-cli -h 127.0.0.1 -p 6379 -a "$REDIS_PASSWORD" INFO replication
redis-cli -h 127.0.0.1 -p 26379 -a "$REDIS_PASSWORD" SENTINEL masters
```

---

## 10. 清理与重置

```bash
cd /data/technical-documentation/01-databases/redis/compose-sentinel
docker compose down --remove-orphans
rm -rf ./data
```
