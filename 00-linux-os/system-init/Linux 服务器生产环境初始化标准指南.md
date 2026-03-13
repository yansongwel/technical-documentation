# Linux 服务器生产环境初始化标准指南
本文档定义了 Linux 服务器（以 CentOS 7/8, Rocky Linux 为主）上线前的标准化初始化流程。通过执行本流程，确保服务器在性能、安全性和可维护性方面达到生产环境要求。

## 1. 初始化架构全景图
<!-- 这是一个文本绘图，源码为：graph TD
    Start((开始)) --> BaseInfo[基础信息配置]
    BaseInfo --> |主机名/DNS/YUM源| PkgInstall[基础软件安装]
    PkgInstall --> |vim/wget/net-tools| SysOpt[系统内核优化]
    SysOpt --> |sysctl/limits| SecHardening[安全加固]
    SecHardening --> |SSH/SELinux/User| Firewall[防火墙配置]
    Firewall --> |iptables/firewalld| TimeSync[时间同步]
    TimeSync --> |Chrony/NTP| Audit[审计与日志]
    Audit --> End((完成))

    subgraph "性能优化 (Performance)"
    SysOpt
    TimeSync
    end

    subgraph "安全加固 (Security)"
    SecHardening
    Firewall
    Audit
    end

    style Start fill:#f9f,stroke:#333,stroke-width:2px
    style End fill:#f9f,stroke:#333,stroke-width:2px -->
![](https://cdn.nlark.com/yuque/__mermaid_v3/98bbc5bbb6c313239d035809dd86faf6.svg)

---

## 2. 详细优化项说明
### 2.1 基础配置与软件源
+ **主机名规范**：设置符合业务含义的主机名（如 `web-prod-01`）。
+ **YUM/DNF 源优化**：
    - 备份默认 repo 文件。
    - 替换为阿里云 (Aliyun) 或清华大学 (Tsinghua) 镜像源，加速软件包下载。
    - 安装 `epel-release` 扩展源。
+ **常用工具安装**：
    - `vim`, `wget`, `curl`, `git`, `unzip`, `lrzsz` (文件传输)
    - `net-tools` (ifconfig/netstat), `sysstat` (sar/iostat), `iotop`, `iftop`
    - `bash-completion` (命令自动补全)

### 手动配置脚本示例
```bash
cat > setup_base.sh << 'EOF'
#!/bin/bash
# 备份并配置 YUM 源 (以 Rocky Linux 为例，其他系统请参考 init_server.sh)
if grep -q "Rocky Linux" /etc/redhat-release; then
    shopt -s nullglob
    repo_files=(/etc/yum.repos.d/Rocky-*.repo /etc/yum.repos.d/rocky-*.repo)
    shopt -u nullglob
    for file in "${repo_files[@]}"; do
        [ -f "$file" ] || continue
        cp "$file" "${file}.bak"
        sed -i 's|^mirrorlist=|#mirrorlist=|g' "$file"
        sed -i 's|^#\?\s*baseurl=|baseurl=|g' "$file"
        sed -i 's|http://dl.rockylinux.org/\$contentdir|https://mirrors.aliyun.com/rockylinux|g' "$file"
        sed -i 's|http://dl.rockylinux.org/pub/rocky|https://mirrors.aliyun.com/rockylinux|g' "$file"
    done
fi
yum clean all && yum makecache

# 安装常用工具
yum install -y vim wget curl git unzip zip lrzsz net-tools sysstat iotop iftop htop tree bash-completion telnet
EOF
bash setup_base.sh
```

### 2.2 系统 Limits 限制优化
Linux 默认的文件打开数（Open Files）通常为 1024，对于高并发服务（如 Nginx, MySQL, Java 应用）远远不够，容易导致 `Too many open files` 错误。

**配置文件**: `/etc/security/limits.conf`

**推荐配置**:

```nginx
* soft nofile 655350
* hard nofile 655350
* soft nproc  655350
* hard nproc  655350
```

+ `nofile`: 单个进程允许打开的最大文件句柄数。
+ `nproc`: 单个用户允许创建的最大进程数。

### 2.3 内核参数优化 (Sysctl)
针对高并发网络环境进行 TCP 协议栈优化。

**配置文件**: `/etc/sysctl.conf`

**核心优化项**:

+ **开启 IP 转发** (`net.ipv4.ip_forward = 1`): 容器化/网关场景必备。
+ **TIME_WAIT 优化**:
    - `net.ipv4.tcp_tw_reuse = 1`: 允许将 TIME-WAIT sockets 重新用于新的 TCP 连接。
    - `net.ipv4.tcp_fin_timeout = 30`: 缩短保持在 FIN-WAIT-2 状态的时间。
+ **连接队列**:
    - `net.core.somaxconn = 65535`: 增加监听队列上限。
    - `net.ipv4.tcp_max_syn_backlog = 65535`: 增加 SYN 队列上限。
+ **TCP 缓冲区**: 增大收发缓冲区大小，提升吞吐量。
+ **Conntrack 表**: 增大连接跟踪表大小，防止丢包 (`net.netfilter.nf_conntrack_max`).

### 手动配置脚本示例
```bash
cat > setup_sysctl.sh << 'EOF'
#!/bin/bash
# 配置内核参数
cat > /etc/sysctl.d/99-server-init.conf <<SYSCTL
# Network Forwarding
net.ipv4.ip_forward = 1
# TCP Optimization
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_syncookies = 1
# Buffer Sizes
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
SYSCTL

# 应用配置
sysctl -p /etc/sysctl.d/99-server-init.conf
EOF
bash setup_sysctl.sh
```

### 2.4 SSH 服务安全加固
SSH 是服务器的大门，必须严防死守。

**配置文件**: `/etc/ssh/sshd_config`

**关键动作**:

1. **禁止 Root 直接登录** (`PermitRootLogin no`): 强制使用普通用户登录后 `sudo`，审计更清晰。
2. **修改默认端口** (`Port 22022`): 避开 99% 的自动化扫描脚本（建议值，具体看规范）。
3. **密钥登录配置**:
    - 如果不存在 SSH 密钥，脚本会自动生成 (`/root/.ssh/id_rsa`)。
    - 自动将公钥添加到 `authorized_keys`。
    - 建议下载私钥后，**禁止密码登录** (`PasswordAuthentication no`)。
4. **禁止空密码** (`PermitEmptyPasswords no`).
5. **DNS 解析关闭** (`UseDNS no`): 加速 SSH 登录连接速度。

### 手动配置脚本示例
```bash
cat > secure_ssh.sh << 'EOF'
#!/bin/bash
SSH_PORT=22022

# 1. 升级 OpenSSH 避免版本兼容问题
yum install -y openssh-server

# 2. 生成 SSH 密钥 (如果不存在)
if [ ! -f /root/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

# 3. 备份并修改 sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# 修改端口
if grep -q "^#Port" /etc/ssh/sshd_config; then
    sed -i "s/^#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
elif grep -q "^Port" /etc/ssh/sshd_config; then
    sed -i "s/^Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
fi
# 允许 Root 登录 (防止未创建用户导致无法登录)
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
# 禁止 Root 登录 (请在创建普通用户后手动执行)
# sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
# sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
# 关闭 DNS
sed -i 's/^#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/^UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

echo "配置完成。请手动验证密钥登录后再重启 sshd 服务 (systemctl restart sshd)。"
EOF
bash secure_ssh.sh
```

### 2.5 防火墙配置 (Iptables)
根据前序文档 [iptables_detailed_guide.md](../firewall/iptables_detailed_guide.md) 进行配置。

+ **策略**: 默认拒绝所有 (`DROP`)，白名单放行。
+ **必要端口**: SSH (新端口), HTTP/HTTPS, 监控端口 (Node Exporter 9100)。
+ **状态检测**: 允许 `ESTABLISHED`, `RELATED` 连接。

### 2.6 其他优化
+ **关闭 SELinux**:
    - 虽然 SELinux 安全性高，但配置复杂且易导致应用权限问题。生产环境通常选择关闭 (`disabled`)，依靠防火墙和应用自身权限控制。
+ **时间同步 (Chrony)**:
    - 确保服务器时间精确，避免日志混乱和分布式系统故障。配置阿里云 NTP 服务器。
+ **命令审计**:
    - 优化 `HISTTIMEFORMAT`，在 `history` 命令中显示执行时间。

### 手动配置脚本示例
```bash
cat > setup_other.sh << 'EOF'
#!/bin/bash
# 1. 关闭 SELinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0

# 2. 配置时间同步 (Chrony)
yum install -y chrony
NTP_SERVER="ntp.aliyun.com"
# 仅保留目标 Server
sed -i "/$NTP_SERVER/!s/^server/#server/" /etc/chrony.conf
if ! grep -q "server $NTP_SERVER" /etc/chrony.conf; then
    echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
fi
sed -i "s/^#server $NTP_SERVER/server $NTP_SERVER/" /etc/chrony.conf
systemctl enable chronyd
systemctl restart chronyd
chronyc sources
EOF
bash setup_other.sh
```

### 2.7 用户创建与权限配置
为了安全起见，建议创建一个具有 `sudo` 权限的普通用户进行日常运维，并禁用 `root` 远程登录。

**关键步骤说明：**

1. **创建用户**：新建普通用户。
2. **赋予权限**：将用户加入 `wheel` 组以获取 sudo 权限。
3. **密钥登录**：为新用户配置 SSH 密钥对。
4. **验证测试**：**必须**先验证新用户能登录且能执行 sudo 命令。
5. **禁用 Root**：最后才在 sshd 配置中禁用 root 登录。

```bash
cat > setup_user.sh << 'EOF'
#!/bin/bash

# --- 配置 ---
NEW_USER="devops"               # 自定义用户名
NEW_PASS="P@ssw0rd_DevOps_2024" # 自定义密码 (建议执行脚本前修改此处)

# 1. 创建用户并授权
if id "$NEW_USER" &>/dev/null; then
    echo "Info: 用户 $NEW_USER 已存在"
else
    useradd -m -s /bin/bash "$NEW_USER"
    echo "$NEW_USER:$NEW_PASS" | chpasswd
    echo "Info: 用户 $NEW_USER 创建成功"
fi

# 添加到 wheel 组 (CentOS/Rocky 默认 sudo 组)
usermod -aG wheel "$NEW_USER"
echo "Info: 用户 $NEW_USER 已添加到 wheel 组 (sudo 权限)"

# 2. 为新用户生成 SSH 密钥
USER_HOME="/home/$NEW_USER"
SSH_DIR="$USER_HOME/.ssh"

if [ ! -f "$SSH_DIR/id_rsa" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    # 生成密钥对
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -C "$NEW_USER@$(hostname)"
    
    # 配置公钥
    cat "$SSH_DIR/id_rsa.pub" >> "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/authorized_keys"
    
    # 修正权限 (确保属于新用户)
    chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
    
    echo "Info: SSH 密钥已生成"
    echo "      私钥路径: $SSH_DIR/id_rsa"
else
    echo "Info: SSH 密钥已存在，跳过生成"
fi

echo "========================================================"
echo "后续操作指南："
echo "1. 下载私钥:cat $SSH_DIR/id_rsa"
echo "2. 验证登录: 使用新用户 $NEW_USER 登录"
echo "3. 验证权限: 登录后执行 'sudo ls' 确保无需 root 密码或输入用户密码即可执行"
echo "4. 禁用 Root: 验证成功后，手动修改 /etc/ssh/sshd_config 中 PermitRootLogin no 并重启 sshd"
echo "========================================================"
EOF
bash setup_user.sh
```

---

## 3. 自动化初始化脚本
本脚本集成了上述所有优化项，支持交互式菜单选择执行，也支持一键全量初始化。

### 使用说明
1. 保存脚本为 `init_server.sh`。
2. 赋予执行权限: `chmod +x init_server.sh`。
3. 以 root 身份运行: `./init_server.sh`。

### 脚本内容
```bash
#!/bin/bash
#
# Server Initialization Script for CentOS 7/8, Rocky Linux
# Author: DevOps Team
# Date: 2026-01-29
# Description: Automated system initialization including Repo, Tools, Limits, Sysctl, SSH, Iptables.

# --- Global Variables ---
SSH_PORT=22022
NTP_SERVER="ntp.aliyun.com"
LOG_FILE="/var/log/server_init.log"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

info() {
    log "${GREEN}[INFO] $1${NC}"
}

warn() {
    log "${YELLOW}[WARN] $1${NC}"
}

error() {
    log "${RED}[ERROR] $1${NC}"
}

check_success() {
    if [ $? -eq 0 ]; then
        info "Step Success: $1"
    else
        error "Step Failed: $1"
        return 1
    fi
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root."
        exit 1
    fi
}

# Safe backup function: Only backs up if backup doesn't exist (preserves original state)
backup_file() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        if [ ! -f "${file_path}.bak" ]; then
            cp "$file_path" "${file_path}.bak"
            info "Backed up $file_path to ${file_path}.bak"
        else
            info "Backup for $file_path already exists. Skipping backup to preserve original state."
        fi
    fi
}

# --- 1. System Info & Repo ---
func_system_repo() {
    info "Configuring System Repos..."
    
    # 1. Check/Create Backup Directory
    if [ ! -d /etc/yum.repos.d/backup ]; then
        mkdir -p /etc/yum.repos.d/backup
        # Safe backup: Copy instead of Move
        cp /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/ 2>/dev/null
        info "Backed up existing repos to /etc/yum.repos.d/backup/"
    fi

    # 2. Recovery Check: If /etc/yum.repos.d is empty (e.g., previous run failed), restore from backup
    if [ -z "$(ls -A /etc/yum.repos.d/*.repo 2>/dev/null)" ]; then
        warn "No repo files found in /etc/yum.repos.d/, attempting to restore from backup..."
        cp /etc/yum.repos.d/backup/*.repo /etc/yum.repos.d/ 2>/dev/null
    fi

    # 3. OS Specific Logic
    # Check OS version
    if grep -q "CentOS Linux release 7" /etc/redhat-release; then
        # CentOS 7: Download new files (Remove old ones first to avoid conflicts)
        rm -f /etc/yum.repos.d/*.repo
        curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo && \
        curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo
        check_success "Download CentOS 7 Repos"
        
    elif grep -q "CentOS Linux release 8" /etc/redhat-release; then
         # CentOS 8: Robust Loop-based replacement
         info "Configuring CentOS 8 Repos..."
         for file in /etc/yum.repos.d/CentOS-*.repo; do
             [ -f "$file" ] || continue
             
             backup_file "$file"
             
             sed -i 's|^mirrorlist=|#mirrorlist=|g' "$file"
             sed -i 's|^#baseurl=http://mirror.centos.org/$contentdir|baseurl=https://mirrors.aliyun.com/centos|g' "$file"
         done
         check_success "Update CentOS 8 Repos"

    elif grep -q "Rocky Linux" /etc/redhat-release; then
         # Rocky Linux: Robust replacement (Handle Rocky-*.repo and rocky-*.repo)
         info "Configuring Rocky Linux Repos..."
         # Enable nullglob to handle case where no files match one pattern
         shopt -s nullglob
         repo_files=(/etc/yum.repos.d/Rocky-*.repo /etc/yum.repos.d/rocky-*.repo)
         shopt -u nullglob

         for file in "${repo_files[@]}"; do
             [ -f "$file" ] || continue
             
             backup_file "$file"
             
             # 1. Comment out mirrorlist
             sed -i 's|^mirrorlist=|#mirrorlist=|g' "$file"
             
             # 2. Uncomment baseurl (handles #baseurl=... or # baseurl=...)
             sed -i 's|^#\?\s*baseurl=|baseurl=|g' "$file"
             
             # 3. Replace upstream domain with Aliyun
             # Pattern matches standard Rocky URL structure: http://dl.rockylinux.org/$contentdir
             sed -i 's|http://dl.rockylinux.org/\$contentdir|https://mirrors.aliyun.com/rockylinux|g' "$file"
             # Also match 'pub/rocky' which some repos might use
             sed -i 's|http://dl.rockylinux.org/pub/rocky|https://mirrors.aliyun.com/rockylinux|g' "$file"
         done
         check_success "Update Rocky Linux Repos"
    else
        warn "Unsupported OS version for automatic repo replacement. Skipping."
    fi

    yum clean all
    yum makecache
    check_success "Yum Makecache"
    info "Repo configuration completed."
}

# --- 2. Install Base Packages ---
func_install_tools() {
    info "Installing base packages..."
    yum install -y vim wget curl git unzip zip lrzsz net-tools sysstat iotop iftop htop tree bash-completion telnet
    check_success "Install Base Packages"
    info "Base packages installed."
}

# --- 3. Time Sync ---
func_time_sync() {
    info "Configuring Time Sync (Chrony)..."
    yum install -y chrony
    
    # Backup config
    backup_file "/etc/chrony.conf"
    
    # Idempotent: Comment out all servers EXCEPT our target server
    # This prevents commenting out our own server on re-runs
    sed -i "/$NTP_SERVER/!s/^server/#server/" /etc/chrony.conf
    
    # Idempotent append: Only add if not present
    if ! grep -q "server $NTP_SERVER" /etc/chrony.conf; then
        echo "server $NTP_SERVER iburst" >> /etc/chrony.conf
    fi
    
    # Ensure our server line is uncommented (in case it was previously commented)
    sed -i "s/^#server $NTP_SERVER/server $NTP_SERVER/" /etc/chrony.conf
    
    systemctl enable chronyd
    systemctl restart chronyd
    
    # Sync immediately
    chronyc sources
    check_success "Configure Time Sync"
    info "Time sync configured."
}

# --- 4. System Limits ---
func_limits() {
    info "Optimizing System Limits..."
    cat > /etc/security/limits.d/20-nproc.conf <<EOF
*          soft    nproc     655350
root       soft    nproc     unlimited
EOF

    if ! grep -q "soft nofile 655350" /etc/security/limits.conf; then
        cat >> /etc/security/limits.conf <<EOF
* soft nofile 655350
* hard nofile 655350
* soft nproc  655350
* hard nproc  655350
EOF
    fi
    check_success "Optimize System Limits"
    info "Limits optimized. (Re-login required to take effect)"
}

# --- 5. Kernel Sysctl ---
func_sysctl() {
    info "Optimizing Kernel Parameters..."
    
    # Use sysctl.d if available for cleaner config
    if [ -d "/etc/sysctl.d" ]; then
        cat > /etc/sysctl.d/99-server-init.conf <<EOF
# Network Forwarding
net.ipv4.ip_forward = 1

# TCP Optimization
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_syncookies = 1

# Buffer Sizes
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
        sysctl -p /etc/sysctl.d/99-server-init.conf
    else
        # Fallback for older systems: modify sysctl.conf
        backup_file "/etc/sysctl.conf"
        
        # We append only if not present (simple check, or just append since we want these values)
        # To avoid duplicates, we can check for a marker, or just accept that cat >> might duplicate if run blindly.
        # Better: use grep checks for critical keys or just warn.
        # For simplicity in fallback mode, we'll append but add a header check.
        
        if ! grep -q "# Server Init Optimization" /etc/sysctl.conf; then
            cat >> /etc/sysctl.conf <<EOF

# Server Init Optimization
net.ipv4.ip_forward = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_syncookies = 1
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
        fi
        sysctl -p
    fi
    
    check_success "Apply Kernel Parameters"
    info "Kernel parameters applied."
}

# --- 6. SSH Hardening ---
func_setup_user() {
    info "Setting up sudo user..."
    local NEW_USER="devops"
    local NEW_PASS="P@ssw0rd_DevOps_2024"
    if id "$NEW_USER" &>/dev/null; then
        info "User $NEW_USER already exists"
    else
        useradd -m -s /bin/bash "$NEW_USER"
        echo "$NEW_USER:$NEW_PASS" | chpasswd
        info "User $NEW_USER created"
    fi
    if id -nG "$NEW_USER" | grep -qw wheel; then
        info "User $NEW_USER already in wheel group"
    else
        usermod -aG wheel "$NEW_USER"
        info "User $NEW_USER added to wheel group"
    fi
    local SSH_DIR="/home/$NEW_USER/.ssh"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    if [ ! -f "$SSH_DIR/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -C "$NEW_USER@$(hostname)"
        cat "$SSH_DIR/id_rsa.pub" >> "$SSH_DIR/authorized_keys"
        chmod 600 "$SSH_DIR/authorized_keys"
        info "SSH keys generated for $NEW_USER"
    else
        info "SSH keys already exist for $NEW_USER"
    fi
    chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
    info "Private key path: $SSH_DIR/id_rsa"
}
func_ssh_harden() {
    info "Hardening SSH Configuration..."

    # --- SAFETY CHECK: User & Keys ---
    info "Checking for sudo user with SSH keys..."
    # Get users in wheel group
    SUDO_USERS=$(grep '^wheel:' /etc/group | cut -d: -f4 | tr ',' ' ')
    VALID_USER_FOUND=0
    
    for user in $SUDO_USERS; do
        # Skip empty or root
        if [ -z "$user" ] || [ "$user" == "root" ]; then continue; fi
        
        # Check for authorized_keys
        if [ -f "/home/$user/.ssh/authorized_keys" ]; then
            VALID_USER_FOUND=1
            info "Found sudo user with SSH keys: $user"
            break
        fi
    done
    
    if [ $VALID_USER_FOUND -eq 0 ]; then
        error "SAFETY CHECK FAILED: No sudo user with SSH keys found in 'wheel' group."
        warn "Disabling Root Login without a valid sudo user will LOCK YOU OUT."
        warn "Please execute the 'setup_user.sh' script to create a user (e.g., devops) first."
        warn "Skipping SSH Hardening."
        return 1
    fi
    # ---------------------------------
    
    # Ensure OpenSSH is up-to-date to avoid OpenSSL version mismatch
    info "Updating OpenSSH server to ensure compatibility..."
    yum install -y openssh-server

    # Ensure SSH keys exist (Auto-generate if missing)
    if [ ! -f /root/.ssh/id_rsa ]; then
        info "Generating SSH keys for root..."
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
        cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        info "SSH keys generated. Private key: /root/.ssh/id_rsa"
    else
        info "SSH keys already exist. Skipping generation."
    fi

    backup_file "/etc/ssh/sshd_config"
    
    # Configure Port
    if grep -q "^#Port" /etc/ssh/sshd_config; then
        sed -i "s/^#Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    elif grep -q "^Port" /etc/ssh/sshd_config; then
        sed -i "s/^Port.*/Port $SSH_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    fi

    # Disable Root Login
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

    # Disable Password Auth (Caution: Ensure keys are set up!)
    # sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    # Keeping Password Auth enabled for initial setup safety, user should disable manually after key verification
    warn "PasswordAuthentication NOT disabled automatically to prevent lockout. Please verify SSH keys first."

    # Disable DNS
    sed -i 's/^#UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
    sed -i 's/^UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

    # Add port to firewall (firewalld example, but we might switch to iptables)
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port=${SSH_PORT}/tcp
        firewall-cmd --reload
    fi
    
    check_success "Harden SSH Configuration"
    info "SSH Config updated. Port: $SSH_PORT. Root Login: Disabled."
    warn "Please restart sshd manually after verifying connectivity: systemctl restart sshd"
}

# --- 7. Disable SELinux ---
func_disable_selinux() {
    info "Disabling SELinux..."
    sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
    setenforce 0
    check_success "Disable SELinux"
    info "SELinux disabled."
}

# --- 8. Iptables Setup ---
func_iptables_setup() {
    info "Setting up Iptables..."
    
    # Stop firewalld
    systemctl stop firewalld
    systemctl disable firewalld
    
    # Install iptables-services
    yum install -y iptables-services
    
    # Flush existing rules
    iptables -F
    iptables -X
    iptables -Z
    
    # Default Policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Established
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # SSH (New Port)
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
    # SSH (Old Port - temporary for current session)
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # ICMP
    iptables -A INPUT -p icmp -j ACCEPT
    
    # Save
    service iptables save
    systemctl enable iptables
    systemctl start iptables
    
    check_success "Setup Iptables"
    info "Iptables configured and started."
}

# --- Main Menu ---
show_menu() {
    echo -e "\n${GREEN}=== Linux Server Initialization Script ===${NC}"
    echo "1. Configure System Repos"
    echo "2. Install Base Tools"
    echo "3. Configure Time Sync (Chrony)"
    echo "4. Optimize System Limits"
    echo "5. Optimize Kernel (Sysctl)"
    echo "6. Setup Sudo User (devops)"
    echo "7. Harden SSH (Port $SSH_PORT, No Root)"
    echo "8. Disable SELinux"
    echo "9. Setup Iptables Firewall"
    echo "10. [Auto] Run All Tasks"
    echo "0. Exit"
    echo -n "Please enter your choice [0-10]: "
}

check_root

while true; do
    show_menu
    read choice
    case $choice in
        1) func_system_repo ;;
        2) func_install_tools ;;
        3) func_time_sync ;;
        4) func_limits ;;
        5) func_sysctl ;;
        6) func_setup_user ;;
        7) func_ssh_harden ;;
        8) func_disable_selinux ;;
        9) func_iptables_setup ;;
        10) 
            func_system_repo
            func_install_tools
            func_time_sync
            func_limits
            func_sysctl
            func_setup_user
            func_disable_selinux
            func_ssh_harden
            func_iptables_setup
            info "All initialization tasks completed."
            ;;
        0) exit 0 ;;
        *) echo "Invalid choice." ;;
    esac
    echo "Press Enter to continue..."
    read
done
```

