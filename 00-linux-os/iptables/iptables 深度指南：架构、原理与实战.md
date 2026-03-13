# iptables 深度指南：架构、原理与实战
本文档详细解析 Linux 内核防火墙 `iptables` 的核心架构、数据包流转原理、命令详解及生产环境最佳实践。

## 1. 核心架构理论：四表五链
`iptables` 实际上是 Linux 内核 Netfilter 模块的用户空间管理工具。其核心概念可以概括为"四表五链"。

### 1.1 五链 (Chains)
"链"是规则的容器，代表数据包在内核流转的不同阶段（Hook Points）。

+ **PREROUTING**: 数据包进入网卡后，进行路由判断之前。
+ **INPUT**: 数据包经过路由判断，目的地是本机。
+ **FORWARD**: 数据包经过路由判断，目的地不是本机，需要转发。
+ **OUTPUT**: 数据包由本机进程产生，准备发出。
+ **POSTROUTING**: 数据包即将离开网卡前（路由判断之后）。

### 1.2 四表 (Tables)
"表"是功能的集合，决定了可以执行哪些动作。优先级从高到低如下：

1. **raw**: 状态跟踪（Connection Tracking）之前的处理，常用于免除状态跟踪 (`NOTRACK`)。
2. **mangle**: 修改数据包头部信息（TTL, TOS, Mark等）。
3. **nat**: 网络地址转换（SNAT, DNAT, 端口转发）。
4. **filter**: **(默认表)** 包过滤，决定放行 (`ACCEPT`)、丢弃 (`DROP`) 或拒绝 (`REJECT`)。

### 1.3 表与链的对应关系
并不是所有的链都包含所有的表。

| 链 (Chain) | 包含的表 (Table) - 按执行顺序 |
| :--- | :--- |
| **PREROUTING** | raw -> mangle -> nat |
| **INPUT** | mangle -> filter |
| **FORWARD** | mangle -> filter |
| **OUTPUT** | raw -> mangle -> nat -> filter |
| **POSTROUTING** | mangle -> nat |


---

## 2. 数据包流转流程 (Packet Flow)
理解数据包流向是配置 iptables 的基础。

### 2.1 流程图 (Mermaid)
<!-- 这是一个文本绘图，源码为：graph TD
    Ingress[数据包进入网卡] --> PreRouting{PREROUTING 链}
    
    PreRouting --> RoutingDecision[路由判断]
    
    RoutingDecision -- 目的地是本机 --> Input{INPUT 链}
    Input --> LocalProcess[本机进程处理]
    
    RoutingDecision -- 目的地非本机 --> Forward{FORWARD 链}
    Forward --> PostRouting{POSTROUTING 链}
    
    LocalProcess -- 本机发送数据 --> Output{OUTPUT 链}
    Output --> RoutingDecisionOut[路由判断]
    RoutingDecisionOut --> PostRouting
    
    PostRouting --> Egress[数据包离开网卡]

    subgraph "Filter Table (防火墙核心)"
    Input
    Forward
    Output
    end

    subgraph "NAT Table (地址转换)"
    PreRouting
    PostRouting
    Output
    end -->
![](https://cdn.nlark.com/yuque/__mermaid_v3/4da8e46a4cf6858180969812e5fbb0d8.svg)

### 2.2 关键路径说明
1. **入站流量 (访问本机服务)**:  
`PREROUTING` -> `INPUT` -> `本机进程`
    - _防火墙主要在 INPUT 链做控制。_
2. **转发流量 (路由器/网关模式)**:  
`PREROUTING` -> `FORWARD` -> `POSTROUTING`
    - _防火墙主要在 FORWARD 链做控制。_
3. **出站流量 (本机访问外部)**:  
`OUTPUT` -> `POSTROUTING`
    - _防火墙主要在 OUTPUT 链做控制（通常默认放行）。_

---

## 3. 命令详解与语法
基本语法结构：  
`iptables [-t 表名] <操作命令> [链名] [匹配条件] [-j 动作]`

+ 如果不指定 `-t`，默认为 `filter` 表。

### 3.1 常用操作命令
| 参数 | 全称 | 说明 |
| :--- | :--- | :--- |
| `-L` | `--list` | 列出规则 |
| `-n` | `--numeric` | 以数字形式显示 IP 和端口（不进行 DNS 解析，**快**） |
| `-v` | `--verbose` | 显示详细信息（包计数、字节数、接口等） |
| `--line-numbers` |  | 显示规则行号（删除规则时很有用） |
| `-A` | `--append` | 在链的**末尾**追加规则 |
| `-I` | `--insert` | 在链的**开头**（或指定位置）插入规则 |
| `-D` | `--delete` | 删除规则（按内容或行号） |
| `-F` | `--flush` | 清空链中的所有规则 |
| `-P` | `--policy` | 设置链的**默认策略** (ACCEPT/DROP) |
| `-Z` | `--zero` | 计数器清零 |


### 3.2 常用匹配条件
+ **协议**: `-p tcp`, `-p udp`, `-p icmp`, `-p all`
+ **源地址**: `-s 192.168.1.0/24`, `-s 1.1.1.1`
+ **目的地址**: `-d 10.0.0.1`
+ **端口** (需配合 `-p`): `--dport 80` (目标端口), `--sport 1024:` (源端口范围)
+ **接口**: `-i eth0` (进入接口), `-o eth1` (流出接口)
+ **状态** (核心): `-m state --state ESTABLISHED,RELATED`
    - `NEW`: 新连接
    - `ESTABLISHED`: 已建立的连接（双向通信的关键）
    - `RELATED`: 相关联的连接（如 FTP 数据连接）
    - `INVALID`: 无效包

### 3.3 常用动作 (Target)
+ **ACCEPT**: 允许通过。
+ **DROP**: 直接丢弃（对方无感知，超时）。
+ **REJECT**: 拒绝并回送错误信息（对方收到 Connection refused）。
+ **SNAT**: 源地址转换（用于上网）。
+ **DNAT**: 目标地址转换（用于端口映射）。
+ **MASQUERADE**: 动态 SNAT（用于动态 IP 上网）。
+ **LOG**: 记录日志（不中断匹配，继续下一条）。

---

## 4. 实战配置场景
### 4.1 场景一：主机防火墙初始化（白名单模式）
这是最安全的配置方式：默认拒绝所有，仅放行已知。

```bash
# 1. 清空现有规则
iptables -F
iptables -X
iptables -Z

# 2. 允许本地回环接口 (必须，否则本机服务可能异常)
iptables -A INPUT -i lo -j ACCEPT

# 3. 允许已建立的连接 (核心：允许本机发起的连接收到回包)
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 4. 允许 SSH (22端口)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 5. 允许 Web 服务 (80, 443)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# 6. 允许 ICMP (Ping) - 可选
iptables -A INPUT -p icmp -j ACCEPT

# 7. 设置默认策略为 DROP (最后执行，防止把自己锁外面)
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

### 4.2 场景二：黑名单屏蔽
```bash
# 屏蔽特定 IP
iptables -I INPUT -s 123.123.123.123 -j DROP

# 屏蔽特定网段
iptables -I INPUT -s 10.0.0.0/8 -j DROP

# 屏蔽特定 MAC 地址
iptables -A INPUT -m mac --mac-source 00:11:22:33:44:55 -j DROP
```

### 4.3 场景三：端口转发 (DNAT)
将访问本机 `8080` 端口的流量转发到内网服务器 `192.168.1.100:80`。  
_前提：开启内核转发 _`echo 1 > /proc/sys/net/ipv4/ip_forward`

```bash
# 1. DNAT 规则 (PREROUTING 链)
# 当 TCP 数据包访问本机 8080 时，修改目标 IP 为 192.168.1.100:80
iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 192.168.1.100:80

# 2. 允许转发 (FORWARD 链)
# 允许经过本机转发到 192.168.1.100:80 的流量
iptables -A FORWARD -p tcp -d 192.168.1.100 --dport 80 -j ACCEPT

# 3. SNAT (如果是回流或同网段访问，可能还需要 SNAT，视网络架构而定)
```

### 4.4 场景四：网关共享上网 (SNAT/Masquerade)
内网机器通过本机 eth0 接口上网。

```bash
# 如果出口 IP 是固定的 (如 1.2.3.4)
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j SNAT --to-source 1.2.3.4

# 如果出口 IP 是动态的 (如 ADSL)
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE
```

---

## 5. 规则维护与持久化
iptables 命令配置是**即时生效但临时**的，重启后会丢失。

### 5.1 CentOS 7+ (使用 iptables-services)
虽然 CentOS 7 默认使用 firewalld，但也可以切回 iptables。

```bash
# 安装 iptables 服务
yum install iptables-services

# 停止 firewalld
systemctl stop firewalld
systemctl disable firewalld

# 启动 iptables
systemctl start iptables
systemctl enable iptables

# 保存当前规则到 /etc/sysconfig/iptables
service iptables save
```

### 5.2 Ubuntu / Debian
Ubuntu 默认没有持久化服务，需要安装 `iptables-persistent`。

```bash
apt install iptables-persistent

# 保存规则
netfilter-persistent save

# 或者手动导出导入
iptables-save > /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4
```

### 5.3 调试技巧
如果发现规则不生效，可以使用 `LOG` 目标进行调试。

```bash
# 记录被 DROP 的包的前 5 个，日志前缀为 "IPTables-Dropped: "
iptables -A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4
```

日志通常记录在 `/var/log/messages` 或 `/var/log/syslog`。

