# Vagrant 生产级使用指南

> **适用场景**：本文面向 Windows 宿主机（128G 内存），通过 Vagrant + VirtualBox 快速启动 Linux 虚拟机集群，用于验证中间件部署文档（Kubernetes、Elasticsearch、MongoDB、Rook 等）的配置正确性与流程完整性。

---

## 目录

1. [简介](#1-简介)
2. [安装与环境准备](#2-安装与环境准备)
3. [核心概念](#3-核心概念)
4. [Box 管理](#4-box-管理)
5. [常用命令速查](#5-常用命令速查)
6. [Vagrantfile 配置详解](#6-vagrantfile-配置详解)
7. [网络配置](#7-网络配置)
8. [磁盘配置](#8-磁盘配置)
9. [Provisioning 自动化配置](#9-provisioning-自动化配置)
10. [多机集群配置](#10-多机集群配置)
11. [共享目录](#11-共享目录)
12. [快照管理](#12-快照管理)
13. [常见问题排查](#13-常见问题排查)
14. [最佳实践](#14-最佳实践)
15. [存储位置配置（防止占用 C 盘）](#15-存储位置配置防止占用-c-盘)

---

## 1. 简介

**Vagrant** 是 HashiCorp 出品的虚拟机自动化管理工具，通过一个 `Vagrantfile` 文本文件定义虚拟机的全部配置（OS、CPU、内存、网络、磁盘、初始化脚本），实现"代码即基础设施（IaC）"。

| 对比项 | Vagrant | 直接用 VirtualBox GUI |
|--------|---------|----------------------|
| 机器定义 | Vagrantfile (代码) | 手动点击 |
| 可重复性 | ✅ 完全一致 | ❌ 容易出错 |
| 多机批量 | ✅ 循环/矩阵 | ❌ 极其繁琐 |
| 快照回滚 | ✅ 命令行 | ✅ GUI |
| 版本管理 | ✅ Git 管理 | ❌ |

---

## 2. 安装与环境准备

### 2.1 安装 VirtualBox

前往官网下载安装：https://www.virtualbox.org/wiki/Downloads

> ⚠️ 建议使用 VirtualBox 7.x。安装时需要**重启系统**。

### 2.2 安装 Vagrant

官方下载地址（Windows）：https://developer.hashicorp.com/vagrant/install#windows

```powershell
# 方式一：winget（推荐）
winget install HashiCorp.Vagrant

# 方式二：Chocolatey
choco install vagrant

# 验证安装
vagrant --version
```

### 2.3 安装 vagrant-disksize 插件（磁盘管理必需）

```powershell
# 安装磁盘扩展插件（支持 :disk 配置块）
vagrant plugin install vagrant-disksize

# 查看已安装插件
vagrant plugin list
```

### 2.4 目录结构约定

```
15-iac/vagrant/
├── Vagrant使用指南.md          # 本文件
└── 启动示例文件/
    ├── Vagrantfile_Rocky9      # Rocky Linux 9 集群配置
    └── Vagrantfile_Ubuntu24    # Ubuntu 24.04 集群配置
```

**如何使用自定义文件名启动（无需重命名为 Vagrantfile）**

Vagrant 默认在当前目录寻找名为 `Vagrantfile`（无扩展名）的文件。如果文件名不同，可通过 `VAGRANT_VAGRANTFILE` 环境变量指定：

```powershell
# 方式一：在当前会话中设置临时环境变量（推荐）
$env:VAGRANT_VAGRANTFILE = "Vagrantfile_Rocky9"
vagrant up

# 方式二：内联单条命令执行（不污染后续会话）
$env:VAGRANT_VAGRANTFILE="Vagrantfile_Rocky9"; vagrant up

# 清除临时环境变量
$env:VAGRANT_VAGRANTFILE = $null
```

> 💡 **推荐工作方式**：为每种当前使用的场景建一个小目录，将示例文件复制到小目录并命名为 `Vagrantfile`，囧就其次用环境变量指定。

### 2.5 控制存储位置（防止占用 C 盘）⭐

> ⚠️ **强烈建议在首次使用前完成此配置**，Vagrant Box 和 VirtualBox 虚拟机默认都写入 C 盘，一套 5 节点集群轻松占用 100GB+ 的 C 盘空间。

#### Vagrant Box 存储位置

Vagrant Box 默认存储路径：`C:\Users\<用户名>\.vagrant.d\`

**修改方法：设置 `VAGRANT_HOME` 环境变量**

```powershell
# 以管理员模式打开 PowerShell，永久设置系统环境变量
[System.Environment]::SetEnvironmentVariable("VAGRANT_HOME", "D:\VM\vagrant.d", "Machine")

# 验证设置是否生效（需重开 PowerShell 窗口）
echo $env:VAGRANT_HOME
# 预期输出：D:\VM\vagrant.d
```

或通过 GUI 设置：**系统属性 → 高级 → 环境变量 → 系统变量 → 新建**

| 变量名 | 变量值 |
|--------|--------|
| `VAGRANT_HOME` | `D:\VM\vagrant.d` |

> ⚠️ 设置后需要**关闭并重新打开 PowerShell 窗口**才能生效。如果之前已有 Box，需将 `C:\Users\<用户名>\.vagrant.d\boxes\` 目录整体移动到新路径。

#### VirtualBox 虚拟机磁盘存储位置

VirtualBox 默认虚拟机路径：`C:\Users\<用户名>\VirtualBox VMs\`

**修改方法：VBoxManage 命令（推荐）**

```powershell
# 修改 VirtualBox 默认虚拟机存储目录（需要 VirtualBox 已安装）
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" setproperty machinefolder "D:\VM\VirtualBox VMs"

# 验证修改结果
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" list systemproperties | findstr "Default machine folder"
# 预期输出：Default machine folder:          D:\VM\VirtualBox VMs
```

或通过 GUI 设置：**VirtualBox → 文件 → 偏好设置 → 常规 → 默认虚拟机文件夹**

#### 推荐 D 盘目录规划

```
D:\VM\
├── vagrant.d\              # ← VAGRANT_HOME，Box 镜像解压后存放处（几GB~几十GB/个）
│   └── boxes\
│       ├── rocky9\
│       └── ubuntu24\
├── box\                    # ← 原始 .box 安装包（可选保留，用于重新 add）
│   ├── generic-rocky9.box
│   └── ubuntu-24.04-x86_64.box
└── VirtualBox VMs\         # ← 虚拟机运行时磁盘 .vdi 存放处（每台虚拟机 40GB+）
    ├── k8s-node1\
    ├── k8s-node2\
    └── ...
```

> 💡 完成上述配置后，执行 `vagrant up` 产生的所有数据将全部写入 D 盘。

---

## 3. 核心概念

| 概念 | 说明 |
|------|------|
| **Box** | 预打包的虚拟机镜像（类似 Docker Image），可来自 Vagrant Cloud 或本地 `.box` 文件 |
| **Vagrantfile** | 使用 Ruby DSL 编写的虚拟机配置文件，定义所有虚拟机参数 |
| **Provider** | 虚拟化后端，默认 VirtualBox，也支持 VMware、Hyper-V、libvirt 等 |
| **Provisioner** | 虚拟机启动后自动执行的初始化脚本，支持 Shell、Ansible、Chef 等 |
| **Snapshot** | 虚拟机某一时刻的快照，可随时回滚 |

---

## 4. Box 管理

### 4.1 从网络添加 Box

```powershell
# 从 Vagrant Cloud 添加 Box（需要网络）
vagrant box add generic/rocky9
vagrant box add ubuntu/jammy64

# 指定 Box 版本
vagrant box add generic/rocky9 --box-version 4.3.12
```

### 4.2 从本地 .box 文件添加（离线/内网推荐）

```powershell
# 添加本地 Box，指定名称
vagrant box add rocky9 file://D:\VM\box\generic-rocky9.box
vagrant box add ubuntu24 file://D:\VM\box\ubuntu-24.04-x86_64.box

# 验证添加成功
vagrant box list
```

### 4.3 Box 管理命令

```powershell
# 查看所有已安装的 Box
vagrant box list

# 更新 Box
vagrant box update --box generic/rocky9

# 删除 Box
vagrant box remove rocky9

# 修剪旧版本 Box
vagrant box prune
```

---

## 5. 常用命令速查

### 5.1 虚拟机生命周期

**▶ 指定自定义文件名（文件名不是 Vagrantfile 时）**

```powershell
# 通过 VAGRANT_VAGRANTFILE 环境变量指定文件名
# ─── 方式一：先设置变量，后续所有 vagrant 命令都生效（当前 PowerShell 会话有效）
$env:VAGRANT_VAGRANTFILE = "Vagrantfile_Rocky9"
vagrant up

# ─── 方式二：单条命令内联（只影响这一条命令）
$env:VAGRANT_VAGRANTFILE="Vagrantfile_Rocky9"; vagrant up
$env:VAGRANT_VAGRANTFILE="Vagrantfile_Rocky9"; vagrant halt
$env:VAGRANT_VAGRANTFILE="Vagrantfile_Rocky9"; vagrant ssh k8s-node1

# ─── 清除变量（恢复默认查找 Vagrantfile）
$env:VAGRANT_VAGRANTFILE = $null
```

> ⚠️ `VAGRANT_VAGRANTFILE` 指定的是**文件名**（不含路径），Vagrant 仍然在当前目录下查找该文件。使用时需先 `cd` 到文件所在目录。

---

**▶ 常规生命周期命令**

```powershell
# ─── 在 Vagrantfile 所在目录执行以下命令 ───────────────────

# 启动所有虚拟机（首次会下载/注册 Box，时间较长）
vagrant up

# 启动指定虚拟机
vagrant up k8s-node1

# 关机（类似 shutdown）
vagrant halt
vagrant halt k8s-node1

# 删除虚拟机（彻底销毁，慎用！）
vagrant destroy
vagrant destroy k8s-node1       # 指定机器
vagrant destroy --force         # 不询问确认

# 重启虚拟机
vagrant reload
vagrant reload k8s-node1

# 重新执行 Provisioning 脚本（不重建虚拟机）
vagrant provision
vagrant provision k8s-node1

# 重启并重新执行 Provisioning
vagrant reload --provision
```

### 5.2 SSH 连接

```powershell
# SSH 进入默认虚拟机
vagrant ssh

# SSH 进入指定虚拟机
vagrant ssh k8s-node1

# 查看 SSH 连接信息（IP、端口、私钥路径等）
vagrant ssh-config
vagrant ssh-config k8s-node1

# 使用原生 ssh 命令连接（配合 ssh-config 输出）
# vagrant ssh-config k8s-node1 >> ~/.ssh/config
```

### 5.3 状态查看

```powershell
# 查看当前目录所有虚拟机状态
vagrant status

# 查看全局所有 Vagrant 管理的虚拟机
vagrant global-status

# 清理无效的全局状态记录
vagrant global-status --prune
```

### 5.4 快照管理

```powershell
# 创建快照（命名为 before-install）
vagrant snapshot save k8s-node1 before-install

# 列出所有快照
vagrant snapshot list
vagrant snapshot list k8s-node1

# 恢复快照
vagrant snapshot restore k8s-node1 before-install

# 删除快照
vagrant snapshot delete k8s-node1 before-install

# 快速保存/恢复（push/pop 堆栈式，无需命名）
vagrant snapshot push         # 保存
vagrant snapshot pop          # 恢复到上一个快照
```

### 5.5 共享文件夹

```powershell
# 挂载共享文件夹（如果自动挂载失败）
vagrant mount
```

### 5.6 Box 操作（再回顾）

```powershell
vagrant box list              # 列出所有 Box
vagrant box add <名称> <URL>   # 添加 Box
vagrant box remove <名称>     # 删除 Box
vagrant box update            # 更新 Box
```

---

## 6. Vagrantfile 配置详解

Vagrantfile 使用 Ruby 语法，以下为关键配置项说明：

### 6.1 配置版本

```ruby
Vagrant.configure("2") do |config|
  # "2" 是 Vagrant 配置 API 版本，目前固定为 "2"，不要修改
end
```

### 6.2 Box 配置

```ruby
# 指定 Box 名称（来自 vagrant box list 中的已安装 Box）
config.vm.box = "rocky9"

# 指定 Box 来源（本地文件路径）
config.vm.box_url = "file://D:\\VM\\box\\generic-rocky9.box"

# 或指定 Vagrant Cloud 上的 Box 版本
config.vm.box_version = "4.3.12"

# 禁用 Box 版本更新检查（离线环境推荐）
config.vm.box_check_update = false
```

### 6.3 主机名

```ruby
config.vm.hostname = "my-server"
```

### 6.4 VirtualBox Provider 配置

```ruby
config.vm.provider "virtualbox" do |v|
  v.name   = "my-server"      # VirtualBox 中显示的名称
  v.memory = 4096             # 内存，单位 MB（4096 = 4GB）
  v.cpus   = 4                # CPU 核数
  v.gui    = false            # 是否显示 VirtualBox 窗口（默认 false = 无头模式）

  # 自定义 VBoxManage 参数
  v.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]  # 图形控制器
  v.customize ["modifyvm", :id, "--vram", "16"]                    # 显存 16MB
  v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]     # DNS 解析优化
  v.customize ["modifyvm", :id, "--ioapic", "on"]                  # 启用 I/O APIC（多 CPU 必需）
  v.customize ["modifyvm", :id, "--paravirtprovider", "kvm"]       # 半虚拟化接口（Linux 推荐）
end
```

---

## 7. 网络配置

Vagrant 提供三种网络模式：

### 7.1 端口转发（Port Forwarding）

```ruby
# 将 Host 的 8080 端口映射到虚拟机的 80 端口
node.vm.network "forwarded_port", guest: 80, host: 8080

# 指定协议（默认 TCP）
node.vm.network "forwarded_port", guest: 53, host: 5353, protocol: "udp"
```

### 7.2 私有网络（Host-Only，★ 最常用）

```ruby
# 静态 IP（节点间通信首选）
node.vm.network "private_network", ip: "192.168.33.10", netmask: "255.255.255.0"

# 动态 IP（DHCP）
node.vm.network "private_network", type: "dhcp"
```

> ✅ **多机 Kubernetes / 中间件集群验证首选此模式**。Host 和虚拟机在同一 Host-Only 网段，虚拟机之间可互相访问，宿主机也可访问虚拟机，但外网无法直接访问。

### 7.3 桥接网络（Bridged，等同于物理机连局域网）

```ruby
# 自动选择桥接网卡
node.vm.network "public_network"

# 指定桥接网卡名称（⚠️ 必须与 Windows 上的网卡名完全一致）
node.vm.network "public_network", ip: "192.168.1.100", bridge: "Intel(R) I211 Gigabit Network Connection"

# 查看 Windows 上的网卡名称（在 PowerShell 执行）
# Get-NetAdapter | Select-Object Name, InterfaceDescription
```

---

## 8. 磁盘配置

> ⚠️ 需要安装 `vagrant-disksize` 插件，或 Vagrant >= 2.3 内置磁盘管理（需要 experimental 特性）。

```ruby
# ─── 方式一：vagrant-disksize 插件（旧方式，兼容性好）───────
config.disksize.size = "40GB"    # 仅能修改主磁盘大小

# ─── 方式二：Vagrant 2.3+ 原生磁盘管理（推荐）───────────────
# 修改主磁盘大小（primary: true）
node.vm.disk :disk, size: "40GB", primary: true

# 新增附加磁盘（模拟 SSD/HDD 等用于 Ceph/Rook 测试）
node.vm.disk :disk, size: "50GB", name: "osd_disk_1"
node.vm.disk :disk, size: "50GB", name: "osd_disk_2"
node.vm.disk :disk, size: "50GB", name: "osd_disk_3"
```

**磁盘新增后，在虚拟机内操作**：

```bash
# 查看所有磁盘
lsblk

# 对新磁盘分区（以 /dev/sdb 为例）
fdisk /dev/sdb

# 格式化
mkfs.ext4 /dev/sdb1

# 挂载
mount /dev/sdb1 /data
```

---

## 9. Provisioning 自动化配置

Provisioning 在 `vagrant up` 或 `vagrant provision` 时自动执行，用于虚拟机初始化配置。

### 9.1 Inline Shell（最简单）

```ruby
config.vm.provision "shell", inline: <<-SHELL
  echo "==> 系统初始化"
  dnf update -y
  timedatectl set-timezone Asia/Shanghai
SHELL
```

### 9.2 外部脚本文件

```ruby
# 执行外部脚本（路径相对于 Vagrantfile）
config.vm.provision "shell", path: "scripts/init.sh"

# 传递参数
config.vm.provision "shell", path: "scripts/init.sh", args: ["node1", "master"]
```

### 9.3 Run 时机控制

```ruby
# 只在首次 vagrant up 时执行（默认行为）
config.vm.provision "shell", run: "once", inline: "echo first boot"

# 每次 vagrant up / reload 都执行
config.vm.provision "shell", run: "always", inline: "echo every boot"

# 只在 vagrant provision 显式调用时执行
config.vm.provision "shell", run: "never", inline: "echo manual only"
```

### 9.4 特权模式（权限控制）

```ruby
# 默认以 root 执行（privileged: true）
config.vm.provision "shell", privileged: true, inline: "dnf install -y vim"

# 以 vagrant 普通用户执行
config.vm.provision "shell", privileged: false, inline: "echo $HOME"
```

---

## 10. 多机集群配置

### 10.1 批量定义（循环，★ 核心技巧）

```ruby
# 自定义每个节点规格
NODES = [
  { name: "master-01", ip: "192.168.33.10", memory: 8192, cpus: 4 },
  { name: "master-02", ip: "192.168.33.11", memory: 8192, cpus: 4 },
  { name: "worker-01", ip: "192.168.33.20", memory: 16384, cpus: 8 },
  { name: "worker-02", ip: "192.168.33.21", memory: 16384, cpus: 8 },
]

Vagrant.configure("2") do |config|
  config.vm.box = "rocky9"

  NODES.each do |node_cfg|
    config.vm.define node_cfg[:name] do |node|
      node.vm.hostname = node_cfg[:name]
      node.vm.network "private_network", ip: node_cfg[:ip]

      node.vm.provider "virtualbox" do |v|
        v.name   = node_cfg[:name]
        v.memory = node_cfg[:memory]
        v.cpus   = node_cfg[:cpus]
      end
    end
  end
end
```

### 10.2 只启动/操作指定节点

```powershell
# 只启动 master-01
vagrant up master-01

# 只 SSH 进入 worker-01
vagrant ssh worker-01

# 只销毁 worker-02
vagrant destroy worker-02 --force
```

---

## 11. 共享目录

```ruby
# 挂载 Windows 目录到虚拟机
config.vm.synced_folder "C:\\Users\\yourname\\project", "/home/vagrant/project"

# 禁用某个共享目录
config.vm.synced_folder ".", "/vagrant", disabled: true

# 使用 rsync 同步（性能更好，但单向同步）
config.vm.synced_folder ".", "/vagrant", type: "rsync",
  rsync__exclude: [".git/", "node_modules/"]
```

---

## 12. 快照管理

快照用于在关键操作（安装中间件）前保存虚拟机状态，失败后快速回滚：

```powershell
# 在安装 Kubernetes 前创建快照
vagrant snapshot save k8s-node1 "before-k8s-install"

# 安装失败，快速回滚
vagrant snapshot restore k8s-node1 "before-k8s-install"

# 查看快照列表
vagrant snapshot list k8s-node1

# 删除不需要的快照（释放磁盘）
vagrant snapshot delete k8s-node1 "before-k8s-install"
```

**推荐工作流**：
```
vagrant up → 快照(base) → 安装中间件 → 快照(after-install) → 验证文档
                ↑                              ↑
             失败回滚                        验证失败回滚
```

---

## 13. 常见问题排查

### 问题 1：VirtualBox 和 Hyper-V 冲突

```powershell
# 症状：vagrant up 报错 "VT-x is not available"
# 解决：以管理员模式运行 PowerShell 禁用 Hyper-V
bcdedit /set hypervisorlaunchtype off
# 重启后生效
```

### 问题 2：磁盘扩展不生效

```bash
# 在虚拟机内执行，手动扩展分区
# 查看当前分区
df -h
lsblk

# 扩展 LVM（Rocky Linux 默认使用 LVM）
pvresize /dev/sda3
lvextend -l +100%FREE /dev/mapper/rl-root
xfs_growfs /
```

### 问题 3：SSH 连接超时

```powershell
# 检查 vagrant ssh-config 输出中的 HostKey
vagrant ssh-config k8s-node1

# 强制重新生成 SSH key
vagrant ssh --no-tty k8s-node1 -- "ls -la"

# 清理 known_hosts
# 删除 %USERPROFILE%\.vagrant.d 中的缓存
```

### 问题 4：共享目录挂载失败（VirtualBox Guest Additions 版本不匹配）

```powershell
# 安装 vagrant-vbguest 插件自动更新 Guest Additions
vagrant plugin install vagrant-vbguest

# 禁用 Guest Additions 版本检查（如果暂时不需要共享目录）
# 在 Vagrantfile 中添加：
# config.vbguest.auto_update = false
```

### 问题 5：Box 下载超时（离线环境）

```powershell
# 将已下载的 .box 文件手动添加
vagrant box add rocky9 file://D:\VM\box\generic-rocky9.box --force
```

### 问题 6：IP 地址冲突

```
# 现象：vagrant up 报 "Another process is using the network adapter"
# 解决：修改 Vagrantfile 中的 IP 段，避免与现有 Host-Only 网络冲突
# 查看现有 Host-Only 网络：
# VirtualBox → File → Host Network Manager
```

---

## 14. 最佳实践

### 14.1 Windows 宿主机（128G 内存）资源规划参考

| 场景 | 虚拟机数量 | 单机内存 | 单机 CPU | 总消耗 |
|------|-----------|----------|----------|--------|
| K8s 3 Master + 3 Worker | 6台 | 8G + 16G | 4C + 8C | ~72G / ~48C |
| Elasticsearch 3节点 | 3台 | 16G | 8C | ~48G / ~24C |
| MongoDB 副本集 3节点 | 3台 | 8G | 4C | ~24G / ~12C |
| Rook-Ceph 3节点 | 3台 | 16G + 附加磁盘 | 8C | ~48G / ~24C |

> **Windows 建议**：宿主机为 Vagrant 至少保留 16G，即实际可分配约 112G。可同时跑多套环境。

### 14.2 Vagrantfile 管理建议

1. 每个项目/中间件单独一个目录和 `Vagrantfile`
2. 使用 Git 管理所有 `Vagrantfile`
3. 敏感信息（密码）使用**环境变量**传入，不要硬编码
4. 在 Provisioning 脚本中添加**幂等性检查**（判断是否已安装再执行）

```ruby
# 读取环境变量中的密码
root_password = ENV.fetch("VM_ROOT_PASSWORD", "Chang3Me!")
```

### 14.3 节省磁盘空间

```powershell
# 1. 压缩 VirtualBox 虚拟磁盘（先在 Linux 虚拟机内零填充，再在宿主机压缩）
# 步骤一：虚拟机内执行（清空空闲块）
# dd if=/dev/zero of=/EMPTY bs=1M; rm -f /EMPTY; sync

# 步骤二：关闭虚拟机后在宿主机执行（压缩 .vdi 文件）
# "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" modifymedium disk "D:\VM\VirtualBox VMs\k8s-node1\k8s-node1.vdi" --compact

# 2. 删除不再需要的 Box（Box 文件本身也占较大空间）
vagrant box remove rocky9

# 3. 修剪旧版本 Box（保留最新版，删除历史版本）
vagrant box prune
```

> ⚠️ 防止 C 盘爆满的根本方案请参考 [第 2.5 节](#25-控制存储位置防止占用-c-盘)。

---

## 15. 存储位置配置（防止占用 C 盘）

> 本节内容已在 [2.5 节](#25-控制存储位置防止占用-c-盘) 中详细说明，请参考该节进行配置。

**快速操作汇总**：

```powershell
# ─── 步骤一：迁移 Vagrant Box 存储（管理员 PowerShell）───────────────────
[System.Environment]::SetEnvironmentVariable("VAGRANT_HOME", "D:\VM\vagrant.d", "Machine")

# ─── 步骤二：迁移 VirtualBox VM 存储目录 ────────────────────────────────
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" setproperty machinefolder "D:\VM\VirtualBox VMs"

# ─── 步骤三：验证 ─────────────────────────────────────────────────────────
# 重开 PowerShell 后执行
echo $env:VAGRANT_HOME
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" list systemproperties | findstr "Default machine folder"
```

---

## 参考资料

- [Vagrant 官方文档](https://developer.hashicorp.com/vagrant/docs)
- [Vagrant 官方命令参考](https://developer.hashicorp.com/vagrant/docs/cli)
- [Vagrant Cloud Box 搜索](https://app.vagrantup.com/boxes/search)
- [VirtualBox 下载](https://www.virtualbox.org/wiki/Downloads)
