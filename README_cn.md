
# 🚀 SSH Gateway 跳板机

[🇬🇧 English README](README.md)

本项目用于搭建一个基于 Docker 的 SSH 跳板机（Jumpbox），支持多用户自动配置，安全高效。让你的运维更轻松！🔒🧑‍💻

同时支持适合移动网络场景的 `mosh` 模式：客户端只在最后一跳连接 jumpbox 时使用 `mosh`，jumpbox 内部通过 `dtach + ssh` 持续维护到后端主机的会话。

## 📁 目录结构

```
ssh_gateway/
├── docker-compose.yaml            # Docker Compose 配置文件
├── docker-compose.example.yaml    # 示例配置文件
├── Dockerfile                     # 构建 SSH 跳板机镜像
├── setup_users.sh                 # 自动创建用户和配置 SSH 的脚本
├── keys/                          # 容器连接内部服务器的私钥
│   ├── id_rsa                     # 容器默认使用的私钥
│   └── *id_rsa                    # 其他目标机器专用的私钥（例如：host_id_rsa）
├── ssh/                           # 外部用户连接容器的信任公钥
│   ├── admin_authorized_keys      # 管理员公钥（通过 ${ADMIN_USER}_authorized_keys 生成）
│   └── authorized_keys            # 普通用户公钥
└── .gitignore                     # Git 忽略文件
```

## ⚡️ 快速开始

1. **准备密钥和公钥** 🔑
   - 管理员和普通用户的公钥分别放入 `ssh/admin_authorized_keys` 和 `ssh/authorized_keys`。
   - 私钥放入 `keys/id_rsa`。

2. **配置环境变量** 🛠️
   - 在 `docker-compose.yaml` 或 `.env` 文件中设置：
     - `ADMIN_USER`：管理员用户名
     - `ADMIN_PASSWORD`：管理员密码
     - `USERS`：普通用户配置，每行格式： `host;user;host.local;/keys/id_rsa;/ssh/authorized_keys`

3. **启动服务** 🏃‍♂️
   - 可先将 `docker-compose.example.yaml` 复制为 `docker-compose.yaml`，再按需修改。
   - 示例 Compose 会直接拉取 `ghcr.io/cupkappu/ssh_jumpbox:latest`，不依赖本地构建。
```bash
docker-compose up -d
```

4. **连接跳板机** 🕹️
   - 管理员用户可通过 SSH 密码登录。
   - 普通用户登录后自动跳转到指定主机，无需手动输入 SSH 命令。
   - 移动端用户可使用 `mosh` 连接，网络切换后会自动回到同一个后端 SSH 会话。

## 🗂️ 主要文件说明

- `Dockerfile`：构建基础镜像，安装 OpenSSH，并拷贝启动脚本。运行时所需密钥通过 volume 挂载提供，而不是打进镜像。
- `setup_users.sh`：容器启动时自动创建管理员和普通用户，配置 SSH 公钥和私钥，并为普通用户生成自动 SSH 脚本。交互式登录会通过 `dtach + ssh` 保持后端会话，便于 `mosh` 断线重连，同时避免和后端已有的 `tmux` 套娃。
- `docker-compose.yaml`：定义服务、端口映射、挂载密钥和公钥目录。
- `docker-compose.example.yaml`：环境变量和用户配置示例，默认使用已发布到 GHCR 的镜像，而不是本地构建。

## 👥 用户配置说明

`USERS` 环境变量每行格式：
```
host;user;host.local;/keys/id_rsa;/ssh/authorized_keys
```
- `host`：容器内用户名
- `user`：目标主机用户名
- `host.local`：目标主机地址
- `/keys/id_rsa`：私钥路径
- `/ssh/authorized_keys`：公钥路径

## 📁 文件传输使用方法

### SCP (安全复制)
```bash
# 支持SFTP的目标主机（默认）
scp -P 2222 file.txt user@jumpbox:/remote/path

# 不支持SFTP的目标主机（使用传统SCP）
scp -P 2222 -O file.txt user@jumpbox:/remote/path
```

### SFTP
```bash
sftp -P 2222 user@jumpbox
```

**注意**: 某些目标主机可能不支持SFTP。如果SCP遇到"Connection closed"错误，请使用 `-O` 选项强制使用传统SCP协议。

## 📱 MOSH 模式

请在 Compose 中暴露标准 MOSH UDP 端口范围：

```yaml
ports:
  - "2222:22"
  - "60000-61000:60000-61000/udp"
```

客户端连接示例：

```bash
mosh --ssh="ssh -p 2222" host1@jumpbox.example.com
```

工作方式：
- `mosh` 只负责客户端到 jumpbox 的最后一跳。
- jumpbox 本地启动 `mosh-server`，随后把用户接入一个持久的 `dtach` 会话。
- 这个 `dtach` 会话内部维护着 jumpbox 到后端目标机的 SSH 连接。
- 当移动网络切换或短暂断线后，重新连上 `mosh` 就会回到同一个后端 shell。

说明：
- jumpbox 镜像已内置 `mosh` 和 `dtach`。
- 后端目标机不需要安装 `mosh`，只需要允许 jumpbox 通过 SSH 连接。
- 非交互式 SSH、SCP、SFTP 和端口转发仍然沿用原有的 SSH 代理模式。

## 🔍 故障排除

- **SCP失败并显示"Connection closed"**: 使用 `scp -O` 选项启用传统SCP协议
- **查看日志**: 在容器内查看 `/var/log/jumpbox.log` 进行调试
- **测试连接**: 先通过交互式SSH连接验证目标主机的可访问性

## ⚠️ 注意事项

- 请勿将真实密钥文件提交到 Git 仓库，`.gitignore` 已做保护。
- 默认禁止 root 登录和密码认证，仅允许密钥认证。

## 📜 License

MIT
