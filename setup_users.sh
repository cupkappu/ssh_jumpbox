#!/bin/bash
set -e

# ============= 管理员账号 =============
# 管理员账号禁止交互式 shell，只能靠 key 登录容器（做管理用）
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

    # 创建普通用户（默认 shell 先设成 bash，后面再改成自动跳板脚本）
    useradd -m -s /bin/bash "$username"
    mkdir -p /home/$username/.ssh

    # 外部登录用的公钥
    if [ -n "$authkeys" ] && [ -f "$authkeys" ]; then
        cat "$authkeys" > /home/$username/.ssh/authorized_keys
    fi

    # 私钥：连接目标机器时用
    cp "$keyfile" /home/$username/id_rsa
    chmod 600 /home/$username/id_rsa
    chown -R $username:$username /home/$username

    # 生成自动跳板脚本
    cat > /home/$username/autossh.sh <<EOS
#!/bin/bash
# 自动透传 ssh/scp/sftp/rsync
if [ -n "\$SSH_ORIGINAL_COMMAND" ]; then
    # 非交互模式（scp/sftp/rsync）
    exec ssh -i ~/id_rsa -o StrictHostKeyChecking=no $ruser@$rhost "\$SSH_ORIGINAL_COMMAND"
else
    # 交互模式
    exec ssh -i ~/id_rsa -o StrictHostKeyChecking=no $ruser@$rhost
fi
EOS

    chmod +x /home/$username/autossh.sh
    chown $username:$username /home/$username/autossh.sh

    # 修改用户登录 shell → 自动跳板脚本
    usermod -s /home/$username/autossh.sh $username
done