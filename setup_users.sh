#!/bin/bash
set -e

# 创建管理员账号
useradd -m -s /bin/bash "$ADMIN_USER"
echo "$ADMIN_USER:$ADMIN_PASSWORD" | chpasswd
mkdir -p /home/$ADMIN_USER/.ssh

if [ -f "/ssh/${ADMIN_USER}_authorized_keys" ]; then
    cat "/ssh/${ADMIN_USER}_authorized_keys" > /home/$ADMIN_USER/.ssh/authorized_keys
fi

chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
chmod 700 /home/$ADMIN_USER/.ssh || true
chmod 600 /home/$ADMIN_USER/.ssh/* || true

# 普通跳板用户
for entry in $USERS; do
    IFS=";" read -r username ruser rhost keyfile authkeys <<<"$entry"

    useradd -m "$username"
    mkdir -p /home/$username/.ssh

    if [ -n "$authkeys" ] && [ -f "$authkeys" ]; then
        cat "$authkeys" > /home/$username/.ssh/authorized_keys
    fi

    cp "$keyfile" /home/$username/id_rsa
    chmod 600 /home/$username/id_rsa
    chown -R $username:$username /home/$username

    # 自动执行 ssh 的 shell 脚本
    echo "#!/bin/bash" > /home/$username/autossh.sh
    echo "exec ssh -i ~/id_rsa -o StrictHostKeyChecking=no $ruser@$rhost" >> /home/$username/autossh.sh
    chmod +x /home/$username/autossh.sh

    usermod -s /home/$username/autossh.sh $username
done
