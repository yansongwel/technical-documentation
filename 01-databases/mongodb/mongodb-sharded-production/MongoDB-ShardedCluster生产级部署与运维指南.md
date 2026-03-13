---

## title: MongoDB-ShardedCluster 生产级部署与运维指南
author: devinyan
updated: 2026-03-13
version: v0.1
middleware_version: 7.0.30
cluster_mode: Sharded Cluster
verified: false

> [TOC]

# MongoDB-ShardedCluster 生产级部署与运维指南

> ⚠️ **文档状态**：本文档待独立 Docker 伪集群验证后补充完整内容。分片集群部署复杂度高（最少 13 节点），建议先参考 [MongoDB 集群方案选型指南](../MongoDB集群方案选型指南.md) 确认是否需分片。临时可参考项目内 [mongodb-deployment-guide.md](../mongodb-deployment-guide.md) 第 6～7 节的分片集群部署步骤。

## 1. 简介

### 1.1 服务介绍与核心特性

Sharded Cluster（分片集群）是 MongoDB 的水平扩展方案，由以下组件构成：

- **mongos**：查询路由器，应用连接入口，无状态可水平扩展
- **Config Server**：3 节点副本集，存储集群元数据与分片配置
- **Shard**：每个分片为 3 节点副本集，存储数据子集

### 1.2 适用场景


| 场景   | 说明                |
| ---- | ----------------- |
| 大数据量 | 单机磁盘/内存无法承载，需水平分片 |
| 高并发写 | 单主写入瓶颈，需多分片分散写入   |
| 线性扩展 | 随业务增长动态添加分片       |


### 1.3 最低节点规划


| 组件              | 数量        | 端口    |
| --------------- | --------- | ----- |
| Config Server   | 3         | 27019 |
| Shard（每分片 3 节点） | 3 × 3 = 9 | 27018 |
| mongos          | 1～3       | 27017 |


**合计**：至少 13 节点。

---

## 2. 部署文档索引

完整分片集群部署步骤、分片键设计、均衡策略等待验证后补充。临时参考：

- [mongodb-deployment-guide.md 第 6～7 节](../mongodb-deployment-guide.md)
- [MongoDB 官方分片集群部署](https://www.mongodb.com/docs/manual/tutorial/deploy-shard-cluster/)

---

## 3. 参考资料


| 资源                      | 链接                                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| MongoDB Sharded Cluster | [https://www.mongodb.com/docs/manual/sharding/](https://www.mongodb.com/docs/manual/sharding/)    |
| 选型指南                    | [MongoDB 集群方案选型指南](../MongoDB集群方案选型指南.md)                                                         |
| Replica Set 部署          | [MongoDB-ReplicaSet 生产级部署与运维指南](../mongodb-replicaset-production/MongoDB-ReplicaSet生产级部署与运维指南.md) |


