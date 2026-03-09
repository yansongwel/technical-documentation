# Sealos 命令行详解手册

**版本**：v5.1.1  
**适用对象**：运维工程师、SRE  
**最后更新**：2026-03-09

本文档详细解析 Sealos CLI 的核心命令，按功能分类整理，涵盖集群管理、节点管理、远程操作及容器镜像管理等常用场景。

---

## 1. 集群管理 (Cluster Management)

### `sealos run`
**功能**：一键运行云原生应用或部署 Kubernetes 集群。这是 Sealos 最核心的命令，支持从零构建集群或在现有集群上安装应用。

**语法**：
```bash
sealos run [image1] [image2] ... [flags]
```

**常用参数**：
*   `--masters`: 指定 Master 节点 IP 列表（逗号分隔）。
*   `--nodes`: 指定 Worker 节点 IP 列表（逗号分隔）。
*   `--passwd`: SSH 登录密码（所有节点需一致）。
*   `--pk`: 指定 SSH 私钥路径（默认 `~/.ssh/id_rsa`）。
*   `--single`: 单机模式运行（Master/Worker 合并，去除资源限制）。
*   `--env`: 设置环境变量，如 `-e key=value`。

**示例**：
```bash
# 部署一个 3 Master + 3 Worker 的高可用集群
sealos run labring/kubernetes:v1.28.0 labring/helm:v3.12.0 labring/calico:v3.26.1 \
  --masters 10.0.0.11,10.0.0.12,10.0.0.13 \
  --nodes 10.0.0.21,10.0.0.22,10.0.0.23 \
  --passwd 'password'
```

### `sealos apply`
**功能**：基于 `Clusterfile` 配置文件运行集群镜像。适用于复杂配置场景或 GitOps 流程。

**语法**：
```bash
sealos apply -f Clusterfile
```

**示例**：
```bash
sealos apply -f Clusterfile
```

### `sealos reset`
**功能**：重置集群，清理所有 Sealos 安装的组件和数据。**危险操作，请谨慎使用！**

**语法**：
```bash
sealos reset [flags]
```

**常用参数**：
*   `--force`: 强制重置，不进行确认提示。

**示例**：
```bash
# 卸载整个集群
sealos reset --force
```

### `sealos status`
**功能**：查看 Sealos 集群的当前状态。

**示例**：
```bash
sealos status
```

### `sealos cert`
**功能**：更新 Kubernetes API Server 的证书（通常用于证书过期续签）。

**示例**：
```bash
sealos cert renew
```

---

## 2. 节点管理 (Node Management)

### `sealos add`
**功能**：向现有集群添加 Master 或 Worker 节点。

**语法**：
```bash
sealos add [flags]
```

**常用参数**：
*   `--masters`: 新增的 Master 节点 IP。
*   `--nodes`: 新增的 Worker 节点 IP。
*   `--passwd` / `--pk`: 新节点的 SSH 凭证。

**示例**：
```bash
# 扩容一个 Worker 节点
sealos add --nodes 10.0.0.24 --passwd 'password'

# 扩容一个 Master 节点
sealos add --masters 10.0.0.14 --passwd 'password'
```

### `sealos delete`
**功能**：从集群中移除节点。

**语法**：
```bash
sealos delete [flags]
```

**常用参数**：
*   `--masters`: 要移除的 Master 节点 IP。
*   `--nodes`: 要移除的 Worker 节点 IP。

**示例**：
```bash
# 缩容节点
sealos delete --nodes 10.0.0.24
```

---

## 3. 远程操作 (Remote Operation)

Sealos 提供了类似 Ansible 的远程执行能力，无需配置 inventory，直接复用集群节点信息。

### `sealos exec`
**功能**：在指定角色的节点上并发执行 Shell 命令。

**语法**：
```bash
sealos exec -r [role] [command]
```

**常用参数**：
*   `-r, --roles`: 指定执行的角色（master, node, 或 all）。
*   `--ips`: 指定具体的 IP 列表。

**示例**：
```bash
# 在所有 Master 节点查看内核版本
sealos exec -r master "uname -a"

# 在所有节点清理缓存
sealos exec -r all "sync && echo 3 > /proc/sys/vm/drop_caches"
```

### `sealos scp`
**功能**：将本地文件复制到远程节点。

**语法**：
```bash
sealos scp -r [role] [src] [dst]
```

**示例**：
```bash
# 分发 hosts 文件到所有节点
sealos scp -r all /etc/hosts /etc/hosts
```

---

## 4. 容器与镜像管理 (Container and Image)

Sealos 内置了完整的 OCI 镜像构建与管理能力（基于 Buildah），无需依赖 Docker。

### `sealos images`
**功能**：列出本地存储的镜像。

**示例**：
```bash
sealos images
```

### `sealos pull` / `sealos push`
**功能**：从镜像仓库拉取或推送镜像。

**示例**：
```bash
sealos pull labring/kubernetes:v1.28.0
sealos push my-registry.com/my-image:latest
```

### `sealos load` / `sealos save`
**功能**：导入/导出镜像归档文件（离线交付必备）。

**示例**：
```bash
# 导出镜像
sealos save -o kubernetes.tar labring/kubernetes:v1.28.0

# 导入镜像（在离线环境）
sealos load -i kubernetes.tar
```

### `sealos login` / `sealos logout`
**功能**：登录/登出容器镜像仓库。

**示例**：
```bash
sealos login registry.cn-shanghai.aliyuncs.com -u username -p password
```

### `sealos build`
**功能**：根据 `Kubefile` (类似 Dockerfile) 构建集群镜像。

**示例**：
```bash
sealos build -t my-k8s-image:v1.0 .
```

### `sealos tag`
**功能**：为本地镜像打标签。

**示例**：
```bash
sealos tag labring/kubernetes:v1.28.0 my-repo/k8s:v1.28.0
```

### `sealos rmi`
**功能**：删除本地镜像。

**示例**：
```bash
sealos rmi labring/kubernetes:v1.28.0
```

---

## 5. 辅助工具 (Other Commands)

### `sealos gen`
**功能**：生成默认的 `Clusterfile` 配置模板。

**示例**：
```bash
# 生成配置并保存到文件
sealos gen labring/kubernetes:v1.28.0 \
  --masters 10.0.0.11 \
  --nodes 10.0.0.21 > Clusterfile
```

### `sealos version`
**功能**：查看 Sealos 版本信息。

### `sealos completion`
**功能**：生成 Shell 自动补全脚本。

**示例**：
```bash
source <(sealos completion bash)
```

---

## 6. 实验性命令 (Experimental)

### `sealos registry`
**功能**：管理内置的镜像仓库服务（通常由 Sealos 自动管理，手动操作较少）。
