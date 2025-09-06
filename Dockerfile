FROM debian:12-slim

RUN apt-get update && apt-get install -y \
    openssh-server sudo bash \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /var/run/sshd

# 拷贝配置和脚本
COPY ssh/ /ssh/
COPY keys/ /keys/
COPY setup_users.sh /usr/local/bin/setup_users.sh

RUN chmod +x /usr/local/bin/setup_users.sh \
    && chmod 600 /keys/* || true

# 默认环境变量（可在 docker-compose.yml 中覆盖）
ENV ADMIN_USER=admin
ENV ADMIN_PASSWORD=AdminPass123
ENV USERS=""

# sshd 配置
RUN sed -i "s/#*PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config && \
    sed -i "s/#*PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config && \
    echo "GatewayPorts yes" >> /etc/ssh/sshd_config

EXPOSE 22

CMD ["/bin/bash", "-c", "/usr/local/bin/setup_users.sh && exec /usr/sbin/sshd -D -e"]
