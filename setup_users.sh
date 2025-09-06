#!/bin/bash
set -e

# ============= 管理员账号 =============
# 管理员账号禁止登录 shell，只允许密钥操作
useradd -m -s /usr/sbin/nologin "$ADMIN_USER"
echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
mkdir -p /home/$ADMIN_USER/.ssh

if [ -f "/ssh/${ADMIN_USER}_authorized_keys" ]; then
    cat "/ssh/${ADMIN_USER}_authorized_keys" > /home/$ADMIN_USER/.ssh/authorized_keys
fi

chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
chmod 700 /home/$ADMIN_USER/.ssh || true
chmod 600 /home/$ADMIN_USER/.ssh/* || true

# ============= 普通跳板用户 =============
for entry in $USERS; do
    IFS=";" read -r username ruser rhost keyfile authkeys <<<"$entry"

    # 建用户，shell 用默认 bash
    useradd -m -s /bin/bash "$username"
    mkdir -p /home/$username/.ssh

    # 配置外部登录的 authorized_keys
    if [ -n "$authkeys" ] && [ -f "$authkeys" ]; then
        cat "$authkeys" > /home/$username/.ssh/authorized_keys
    fi

    # 拷贝目标服务器连接用的私钥
    cp "$keyfile" /home/$username/id_rsa
    chmod 600 /home/$username/id_rsa
    chown -R $username:$username /home/$username

    # 自动执行 ssh 的 shell 脚本，支持 ssh 协议族透传
    cat > /home/$username/autossh.sh <<EOS
#!/bin/bash
if [ -n "\$SSH_ORIGINAL_COMMAND" ]; then
    # 非交互模式（如 scp/sftp/rsync）
    exec ssh -i ~/id_rsa -o StrictHostKeyChecking=no $ruser@$rhost "\$SSH_ORIGINAL_COMMAND"
else
    # 交互模式
    exec ssh -i ~/id_rsa -o StrictHostKeyChecking=no $ruser@$rhost
fi
EOS

    chmod +x /home/$username/autossh.sh
done

# 自动写入 sshd_config 的 Match+ForceCommand 配置（仅限容器初始化时）
JUMP_USERS=""
for entry in $USERS; do
    IFS=";" read -r username ruser rhost keyfile authkeys <<<"$entry"
    JUMP_USERS+="$username,"
done
JUMP_USERS=${JUMP_USERS%,} # 去掉最后一个逗号

if ! grep -q "ForceCommand" /etc/ssh/sshd_config; then
    echo "Match User $JUMP_USERS" >> /etc/ssh/sshd_config
    echo "    ForceCommand /home/%u/autossh.sh" >> /etc/ssh/sshd_config
fi