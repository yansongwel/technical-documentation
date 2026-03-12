# MongoDB 集群（Replica Set，Docker Compose）部署与验证指南（生产基线）

> **部署目标**：3 节点副本集（自动选主）+ 认证（RBAC）+ 内部密钥（keyFile）+ 生产基线配置（带注释）  
> **适用场景**：中小规模生产/测试环境的高可用副本集；不包含分片（Sharding）  
> **版本**：MongoDB 7.0（本仓库 Compose 默认）  

---

## 1. 架构与访问方式

### 1.1 架构图

```mermaid
flowchart LR
  C[应用/客户端] -->|seed list + replicaSet| RS[(Replica Set rs0)]

  subgraph RS[副本集 rs0]
    P[(Primary)]
    S1[(Secondary)]
    S2[(Secondary)]
    P -->|oplog 复制| S1
    P -->|oplog 复制| S2
  end
```

### 1.2 端口映射与访问

本方案将 3 个节点都映射到宿主机端口，便于远程客户端直连（生产可按需要只暴露部分端口）：

| 节点 | 容器 | 宿主机端口 | 容器端口 |
|---|---|---:|---:|
| 节点 1 | `mongo1` | 27017 | 27017 |
| 节点 2 | `mongo2` | 27018 | 27017 |
| 节点 3 | `mongo3` | 27019 | 27017 |

推荐连接串（远程客户端使用宿主机 IP）：

```text
mongodb://<用户名>:<密码>@<宿主机IP>:27017,<宿主机IP>:27018,<宿主机IP>:27019/<db>?replicaSet=rs0
```

示例（业务账号）：

```text
mongodb://app_user:<APP_PASSWORD>@<宿主机IP>:27017,<宿主机IP>:27018,<宿主机IP>:27019/app_db?replicaSet=rs0
```

---

## 2. 目录结构

部署目录：

`01-databases/mongodb/compose-replicaset/`

```text
compose-replicaset/
├── .env
├── docker-compose.yml
├── config/
│   ├── keyfile
│   └── mongod.conf
└── scripts/
    └── mongo1-bootstrap.sh
```

关键文件：

- Compose：[docker-compose.yml](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/docker-compose.yml)
- 环境变量（需改密码）：[.env](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/.env)
- 生产基线配置（带注释）：[mongod.conf](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/config/mongod.conf)
- 副本集初始化与建用户（仅 mongo1 执行）：[mongo1-bootstrap.sh](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/scripts/mongo1-bootstrap.sh)

---

## 3. 配置说明（必须修改）

### 3.1 修改账号密码

编辑 [.env](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/.env)：

- `MONGO_ROOT_USERNAME` / `MONGO_ROOT_PASSWORD`：管理员账号（root 角色）
- `MONGO_APP_DB` / `MONGO_APP_USERNAME` / `MONGO_APP_PASSWORD`：业务库与业务账号（readWrite 角色）

### 3.2 生成并替换 keyfile（生产必须）

当前仓库内的 [keyfile](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/config/keyfile) 仅为示例，生产务必替换成强随机内容并限制权限。

在宿主机生成示例（任选其一）：

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset

# 方式 1：openssl（推荐）
openssl rand -base64 756 > ./config/keyfile

# 方式 2：纯字母数字（也可，但强度取决于生成方式）
# tr -dc 'A-Za-z0-9' </dev/urandom | head -c 200 > ./config/keyfile

chmod 400 ./config/keyfile
```

> 说明：keyfile 用于副本集内部节点认证，三节点必须一致。

---

## 4. 生产基线配置说明（带注释）

MongoDB 配置见 [mongod.conf](file:///data/technical-documentation/01-databases/mongodb/compose-replicaset/config/mongod.conf)，要点：

- `security.authorization: enabled`：启用 RBAC
- `security.keyFile`：副本集内部认证
- `replication.replSetName` / `oplogSizeMB`：副本集与 oplog
- `storage.wiredTiger.*`：WiredTiger 缓存与压缩（按机器与业务调优）
- `operationProfiling.slowOpThresholdMs`：慢操作阈值（排障与调优常用）
- `net.maxIncomingConnections`：连接数上限（配合系统 ulimit）

---

## 5. 部署步骤（Docker Compose）

> 🖥️ 执行节点：宿主机

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset

docker compose up -d
docker compose ps
```

初始化说明：

- `mongo1` 启动时会执行 bootstrap 脚本：
  - `rs.initiate(...)` 初始化 3 节点副本集
  - 创建管理员账号（root）
  - 创建业务账号（readWrite）
- 初始化完成后，三节点进入稳定运行状态，健康检查变为 healthy

---

## 6. 验证过程（已验证）

> 说明：宿主机可能没有安装 `mongosh`，因此以下验证命令通过 `docker exec` 在容器内执行。

### 6.1 查看副本集状态

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
set -a && . ./.env && set +a

docker exec mongo1 mongosh "mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@127.0.0.1:27017/admin" --quiet \
  --eval 'rs.status().members.map(m=>({name:m.name,stateStr:m.stateStr,health:m.health}))'
```

验证输出示例（会出现 1 个 PRIMARY + 2 个 SECONDARY）：

```text
[
  { name: 'mongo1:27017', stateStr: 'SECONDARY', health: 1 },
  { name: 'mongo2:27017', stateStr: 'PRIMARY', health: 1 },
  { name: 'mongo3:27017', stateStr: 'SECONDARY', health: 1 }
]
```

### 6.2 通过 seed list 写入并读取（自动路由到 Primary）

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
set -a && . ./.env && set +a

docker exec mongo1 mongosh \
  "mongodb://$MONGO_APP_USERNAME:$MONGO_APP_PASSWORD@mongo1:27017,mongo2:27017,mongo3:27017/$MONGO_APP_DB?replicaSet=$MONGO_REPLSET_NAME" \
  --quiet --eval 'db.test.insertOne({ts:new Date(),v:"ok"}); db.test.find().sort({_id:-1}).limit(1).toArray()'
```

### 6.3 验证连接到 Secondary 可读

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
set -a && . ./.env && set +a

docker exec mongo2 mongosh \
  "mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@127.0.0.1:27017/admin?readPreference=secondaryPreferred" \
  --quiet --eval 'db.adminCommand({ping:1}).ok'
```

---

## 7. 常用运维命令

### 7.1 副本集状态与选主

```bash
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'rs.status()'
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'rs.printReplicationInfo()'
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.hello()'
```

### 7.2 用户与权限

```bash
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.getUsers()'
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.getSiblingDB("app_db").getUsers()'
```

### 7.3 基础健康检查

```bash
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.adminCommand({ping:1})'
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.serverStatus().connections'
docker exec mongo1 mongosh "mongodb://admin:<PWD>@127.0.0.1:27017/admin" --quiet --eval 'db.serverStatus().wiredTiger.cache'
```

---

## 8. 清理与重置

停止但保留数据卷：

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
docker compose down --remove-orphans
```

完全重置（删除数据卷，谨慎）：

```bash
cd /data/technical-documentation/01-databases/mongodb/compose-replicaset
docker compose down -v --remove-orphans
```

---

## 9. 生产注意事项

- 生产务必替换 `config/keyfile` 与 `.env` 的默认弱密码，并限制外部端口访问（安全组/防火墙/内网隔离）。
- 强烈建议在宿主机禁用 THP、提升 `nofile`、合理规划磁盘与监控（详见本仓库通用文档 [mongodb-deployment-guide.md](file:///data/technical-documentation/01-databases/mongodb/mongodb-deployment-guide.md)）。
- 本方案为副本集高可用，不提供分片扩展；数据量/写入量上来后再考虑 Sharding（mongos + config server + 多分片 RS）。
