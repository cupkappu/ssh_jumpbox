
# 🚀 SSH Gateway

[🇨🇳 中文版 README](README_cn.md)

This project provides a Docker-based SSH jumpbox (gateway) solution with automated multi-user configuration. Designed for secure, efficient access management to internal hosts! 🔒🧑‍💻

## 📁 Directory Structure

```
ssh_gateway/
├── docker-compose.yaml            # Docker Compose configuration
├── docker-compose.example.yaml    # Example configuration
├── Dockerfile                     # Build the SSH jumpbox image
├── setup_users.sh                 # Script for automatic user and SSH setup
├── keys/                          # Private keys for the container to connect to internal servers
│   ├── id_rsa                     # Default private key used by the container
│   └── *_id_rsa                   # Additional private keys for different target machines (e.g., host_id_rsa)
├── ssh/                           # Trusted public keys for external users to connect to the container
│   ├── admin_authorized_keys      # Public key for admin user (generated as ${ADMIN_USER}_authorized_keys)
│   └── *_authorized_keys          # Public keys for regular users
└── .gitignore                     # Git ignore file
```

## ⚡️ Quick Start

1. **Prepare Keys** 🔑
   - Place admin and user public keys in `ssh/admin_authorized_keys` and `ssh/authorized_keys` respectively.
   - Place the private key in `keys/id_rsa`.

2. **Configure Environment Variables** 🛠️
   - Set in `docker-compose.yaml` or `.env`:
     - `ADMIN_USER`: Admin username
     - `ADMIN_PASSWORD`: Admin password
     - `USERS`: User configuration, each line format:
       `host;user;host.local;/keys/id_rsa;/ssh/authorized_keys`

3. **Start the Service** 🏃‍♂️
   ```bash
   docker-compose up -d
   ```

4. **Connect to the Jumpbox** 🕹️
   - Admin can log in via SSH password.
   - Regular users are auto-forwarded to the target host via SSH upon login.

## 🗂️ Key Files

- `Dockerfile`: Builds the base image, installs OpenSSH, copies keys and setup script.
- `setup_users.sh`: Creates admin and users, configures SSH keys, and generates auto-SSH scripts for users.
- `docker-compose.yaml`: Defines service, port mapping, and mounts for keys and public keys.
- `docker-compose.example.yaml`: Example for environment variables and user configuration.

## 👥 User Configuration Format

Each line in the `USERS` environment variable:
```
host;user;host.local;/keys/id_rsa;/ssh/authorized_keys
```
- `host`: Username inside the container
- `user`: Target host username
- `host.local`: Target host address
- `/keys/id_rsa`: Private key path
- `/ssh/authorized_keys`: Public key path

## 📁 File Transfer Usage

### SCP (Secure Copy)
```bash
# For hosts with SFTP support (default)
scp -P 2222 file.txt user@jumpbox:/remote/path

# For hosts without SFTP support (use legacy SCP)
scp -P 2222 -O file.txt user@jumpbox:/remote/path
```

### SFTP
```bash
sftp -P 2222 user@jumpbox
```

**Note**: Some target hosts may not support SFTP. If you encounter "Connection closed" errors with SCP, use the `-O` option to force legacy SCP protocol.

## 🔍 Troubleshooting

- **SCP fails with "Connection closed"**: Use `scp -O` option for legacy SCP protocol
- **Check logs**: View `/var/log/jumpbox.log` inside the container for debugging
- **Test connectivity**: SSH interactively first to verify target host accessibility

## ⚠️ Notes

- Do not commit real key files to Git; `.gitignore` protects sensitive files.
- Root login and password authentication are disabled by default; only key authentication is allowed.

## 📜 License

MIT
