#!/bin/bash
set -e

ADMIN_USER=${ADMIN_USER:-admin}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin123}
USERS=${USERS}

# 创建管理员用户（如不存在）
if ! id "$ADMIN_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$ADMIN_USER"
    echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
fi
mkdir -p /home/$ADMIN_USER/.ssh
cp /ssh/admin_authorized_keys /home/$ADMIN_USER/.ssh/authorized_keys
chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys

# 创建跳板用户（如不存在）
IFS=$'\n'
for line in $USERS; do
    IFS=';' read -r host user target_host key_path pubkey_path <<< "$line"
    
    # 创建智能跳转脚本，支持交互式登录和文件传输
    cat > /usr/local/bin/smart_jump_$host << 'SCRIPT_EOF'
#!/bin/bash
# 智能SSH跳转脚本，支持scp/sftp/rsync等文件传输工具

TARGET_USER="USER_PLACEHOLDER"
TARGET_HOST="TARGET_HOST_PLACEHOLDER"
SSH_KEY="/home/USERNAME_PLACEHOLDER/.ssh/id_rsa"

# 记录调试信息
echo "$(date): User USERNAME_PLACEHOLDER connecting" >> /var/log/jumpbox.log
echo "$(date): SSH_ORIGINAL_COMMAND: '$SSH_ORIGINAL_COMMAND'" >> /var/log/jumpbox.log

# 检查SSH连接类型
if [ -n "$SSH_ORIGINAL_COMMAND" ]; then
    # 有原始命令说明是scp/sftp/rsync等，需要代理转发
    echo "代理执行命令: $SSH_ORIGINAL_COMMAND" >&2
    echo "$(date): Proxying command to $TARGET_USER@$TARGET_HOST" >> /var/log/jumpbox.log
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" "$TARGET_USER@$TARGET_HOST" "$SSH_ORIGINAL_COMMAND"
else
    # 没有原始命令说明是交互式登录，直接跳转
    echo "正在连接到 $TARGET_USER@$TARGET_HOST..." >&2
    echo "$(date): Interactive login to $TARGET_USER@$TARGET_HOST" >> /var/log/jumpbox.log
    exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$SSH_KEY" "$TARGET_USER@$TARGET_HOST"
fi
SCRIPT_EOF

    # 替换脚本中的占位符
    sed -i "s/USER_PLACEHOLDER/$user/g" /usr/local/bin/smart_jump_$host
    sed -i "s/TARGET_HOST_PLACEHOLDER/$target_host/g" /usr/local/bin/smart_jump_$host
    sed -i "s/USERNAME_PLACEHOLDER/$host/g" /usr/local/bin/smart_jump_$host
    chmod +x /usr/local/bin/smart_jump_$host
    
    if ! id "$host" &>/dev/null; then
        # 创建用户，使用普通bash shell
        useradd -m -s /bin/bash "$host"
    fi
    
    mkdir -p /home/$host/.ssh
    cp $pubkey_path /home/$host/.ssh/authorized_keys
    cp $key_path /home/$host/.ssh/id_rsa
    chown -R $host:$host /home/$host/.ssh
    chmod 600 /home/$host/.ssh/authorized_keys /home/$host/.ssh/id_rsa
    
    # 配置SSH强制命令 - 在authorized_keys中添加command限制，但允许更多功能
    sed -i "s|^|command=\"/usr/local/bin/smart_jump_$host\",no-X11-forwarding |" /home/$host/.ssh/authorized_keys
    
    # 创建SSH配置文件示例（仅供参考）
    cat > /home/$host/ssh_config_sample << EOF
# 直接连接示例
Host $target_host
    HostName $target_host
    User $user
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# 通过跳板机连接示例 (ProxyJump)
Host $target_host-jump
    HostName $target_host
    User $user
    ProxyJump $host@jumpbox_ip:jumpbox_port
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    chown $host:$host /home/$host/ssh_config_sample
    
    echo "已配置用户 $host 智能跳转到 $user@$target_host (支持scp/sftp/rsync)"
done

sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# 检查是否已存在这些配置，避免重复添加
if ! grep -q "AllowTcpForwarding yes" /etc/ssh/sshd_config; then
    echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
fi
if ! grep -q "GatewayPorts yes" /etc/ssh/sshd_config; then
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config
fi
if ! grep -q "PermitOpen any" /etc/ssh/sshd_config; then
    echo "PermitOpen any" >> /etc/ssh/sshd_config
fi
if ! grep -q "AllowAgentForwarding yes" /etc/ssh/sshd_config; then
    echo "AllowAgentForwarding yes" >> /etc/ssh/sshd_config
fi
if ! grep -q "PermitTTY yes" /etc/ssh/sshd_config; then
    echo "PermitTTY yes" >> /etc/ssh/sshd_config
fi

# SFTP子系统通常已经默认配置，不需要重复添加
# 检查SFTP子系统是否已存在，如果不存在才添加
if ! grep -q "Subsystem.*sftp" /etc/ssh/sshd_config; then
    echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config
fi

# 检查 sshd 配置是否正确
if ! sshd -t 2>&1; then
    echo "sshd 配置检查失败，错误如下："
    sshd -t 2>&1
    exit 1
fi

# 直接启动 sshd 守护进程（前台模式）
echo "启动 SSH 服务..."
/usr/sbin/sshd -D