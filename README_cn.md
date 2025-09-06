
# 🚀 SSH Gateway 跳板机

[🇬🇧 English README](README.md)

本项目用于搭建一个基于 Docker 的 SSH 跳板机（Jumpbox），支持多用户自动配置，安全高效。让你的运维更轻松！🔒🧑‍💻

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
```bash
docker-compose up -d
```

4. **连接跳板机** 🕹️
   - 管理员用户可通过 SSH 密码登录。
   - 普通用户登录后自动跳转到指定主机，无需手动输入 SSH 命令。

## 🗂️ 主要文件说明

- `Dockerfile`：构建基础镜像，安装 OpenSSH，拷贝密钥和配置脚本。
- `setup_users.sh`：容器启动时自动创建管理员和普通用户，配置 SSH 公钥和私钥，并为普通用户生成自动 SSH 脚本。
- `docker-compose.yaml`：定义服务、端口映射、挂载密钥和公钥目录。
- `docker-compose.example.yaml`：环境变量和用户配置示例。

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

## ⚠️ 注意事项

- 请勿将真实密钥文件提交到 Git 仓库，`.gitignore` 已做保护。
- 默认禁止 root 登录和密码认证，仅允许密钥认证。

## 📜 License

MIT
