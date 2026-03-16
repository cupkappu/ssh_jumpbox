
# 🚀 SSH Gateway

[🇨🇳 中文版 README](README_cn.md)

This project provides a Docker-based SSH jumpbox (gateway) solution with automated multi-user configuration. Designed for secure, efficient access management to internal hosts! 🔒🧑‍💻

It also supports a mobile-friendly `mosh` mode: the client uses `mosh` only for the last hop to the jumpbox, while the jumpbox keeps a persistent SSH session to the target host with `dtach + ssh`.

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
   - Copy `docker-compose.example.yaml` to `docker-compose.yaml`, or use it directly after editing values.
   - The example Compose file pulls the prebuilt image from `ghcr.io/cupkappu/ssh_jumpbox:latest`.
   ```bash
   docker-compose up -d
   ```

4. **Connect to the Jumpbox** 🕹️
   - Admin can log in via SSH password.
   - Regular users are auto-forwarded to the target host via SSH upon login.
   - Mobile users can connect with `mosh`; the jumpbox will restore the same backend SSH session on reconnect.

## 🗂️ Key Files

- `Dockerfile`: Builds the base image, installs OpenSSH, and copies the setup script. Runtime keys are mounted as volumes rather than baked into the image.
- `setup_users.sh`: Creates admin and users, configures SSH keys, and generates auto-SSH scripts for users. Interactive logins use `dtach + ssh` to keep backend sessions alive for `mosh` reconnects without adding a nested terminal multiplexer UI.
- `docker-compose.yaml`: Defines service, port mapping, and mounts for keys and public keys.
- `docker-compose.example.yaml`: Example for environment variables and user configuration, using the published GHCR image instead of a local build.

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

## 📱 MOSH Mode

Expose the standard MOSH UDP range in your Compose file:

```yaml
ports:
  - "2222:22"
  - "60000-61000:60000-61000/udp"
```

Then connect from the client with:

```bash
mosh --ssh="ssh -p 2222" host1@jumpbox.example.com
```

How it works:
- `mosh` runs only between the client and the jumpbox.
- The jumpbox starts a local `mosh-server`, then attaches the user to a persistent `dtach` session.
- That `dtach` session maintains an SSH connection from the jumpbox to the configured backend host.
- When the mobile network changes, reconnecting with `mosh` returns to the same backend shell session.

Notes:
- The jumpbox image now includes `mosh` and `dtach`.
- The backend host does not need `mosh`; it only needs SSH access from the jumpbox.
- Non-interactive SSH, SCP, SFTP, and port forwarding continue to use direct SSH proxying as before.

## 🔍 Troubleshooting

- **SCP fails with "Connection closed"**: Use `scp -O` option for legacy SCP protocol
- **Check logs**: View `/var/log/jumpbox.log` inside the container for debugging
- **Test connectivity**: SSH interactively first to verify target host accessibility

## ⚠️ Notes

- Do not commit real key files to Git; `.gitignore` protects sensitive files.
- Root login and password authentication are disabled by default; only key authentication is allowed.

## 📜 License

MIT
