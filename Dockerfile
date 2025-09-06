FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y openssh-server sudo socat && \
    mkdir /var/run/sshd

COPY setup_users.sh /setup_users.sh
COPY ssh/ /ssh/
COPY keys/ /keys/

RUN chmod +x /setup_users.sh

CMD ["/setup_users.sh"]
