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
    if ! id "$host" &>/dev/null; then
        useradd -m -s /bin/bash "$host"
    fi
    mkdir -p /home/$host/.ssh
    cp $pubkey_path /home/$host/.ssh/authorized_keys
    cp $key_path /home/$host/.ssh/id_rsa
    chown -R $host:$host /home/$host/.ssh
    chmod 600 /home/$host/.ssh/authorized_keys /home/$host/.ssh/id_rsa
    echo "Host $target_host\n    HostName $target_host\n    User $user\n    IdentityFile ~/.ssh/id_rsa\n    ProxyJump $host@jumpbox_ip:jumpbox_port" > /home/$host/ssh_config_sample
done

sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
echo "GatewayPorts yes" >> /etc/ssh/sshd_config
echo "PermitOpen any" >> /etc/ssh/sshd_config

service ssh restart
exec /usr/sbin/sshd -D
