# Nomad Infrastructure Playbooks

This directory contains Ansible playbooks for configuring HashiCorp Nomad servers and clients on AWS infrastructure.

## Overview

The playbooks in this directory are designed to work with infrastructure provisioned by Terraform (located in `../../terraform/aws/`). They configure Nomad clusters with TLS security, cloud auto-join, and all necessary dependencies.

## Playbooks

### 1. nomad_servers.yaml

**Purpose**: Configures Nomad server nodes that form the control plane of the cluster.

**Target Hosts**: `servers` group from inventory

**What It Does**:
1. **Pre-tasks**:
   - Generates TLS certificates (CA and server certificates) on localhost
   - Certificates stored in `ansible/.tls/`

2. **Roles Applied**:
   - **common**: Sets up base system (hostname, packages, NTP)
   - **helper**: 
     - Installs development tools (build-essential, git)
     - Installs utilities (jq, net-tools, unzip, nano)
     - Distributes TLS certificates to `/etc/nomad.d/.tls/`
   - **nomad**: 
     - Installs Nomad v1.11.1
     - Configures server mode
     - Enables cloud auto-join for AWS
     - Sets up systemd service

3. **Post-tasks**:
   - Waits for Nomad to be ready (port 4646)
   - Displays server cluster members

**Configuration**:
```yaml
nomad_server_enabled: true
nomad_server_bootstrap_expect: 3  # Number of servers
nomad_client_enabled: false
nomad_cloud_auto_join_enabled: true
nomad_acl_enabled: false  # Can be enabled for production
```

**Usage**:
```bash
ansible-playbook playbooks/nomad_servers.yaml
```

**Expected Outcome**:
- 3 Nomad servers running and clustered
- TLS certificates installed
- Cloud auto-join configured
- Servers ready to accept client connections

---

### 2. nomad_clients.yaml

**Purpose**: Configures Nomad client nodes that run workloads.

**Target Hosts**: `clients` group from inventory

**What It Does**:
1. **Pre-tasks**:
   - Generates TLS certificates (CA and client certificates) on localhost
   - Certificates stored in `ansible/.tls/`

2. **Roles Applied**:
   - **common**: Sets up base system (hostname, packages, NTP)
   - **cni**: Installs Container Network Interface plugins (Ubuntu only)
   - **geerlingguy.docker**: Installs Docker CE for container workloads
   - **helper**:
     - Installs development tools (build-essential, git)
     - Installs utilities (jq, net-tools, unzip)
     - Configures bridge kernel module for container networking
     - Distributes TLS certificates to `/etc/nomad.d/.tls/`
   - **nomad**:
     - Installs Nomad v1.11.1
     - Configures client mode
     - Enables Docker driver
     - Enables cloud auto-join to find servers
     - Sets up systemd service

3. **Post-tasks**:
   - Waits for Nomad to be ready (port 4646)
   - Displays node status

**Configuration**:
```yaml
nomad_server_enabled: false
nomad_client_enabled: true
nomad_cloud_auto_join_enabled: true
nomad_acl_enabled: false  # Can be enabled for production
```

**Usage**:
```bash
ansible-playbook playbooks/nomad_clients.yaml
```

**Expected Outcome**:
- 2 Nomad clients running
- Docker installed and configured
- CNI plugins installed
- TLS certificates installed
- Clients connected to server cluster
- Ready to run workloads

---

### 3. nomad_acl_bootstrap.yaml

**Purpose**: Bootstraps the Nomad ACL system and securely saves the management token.

**Target Hosts**: `servers[0]` (first server only)

**What It Does**:
1. **Verification**:
   - Checks if Nomad is running on port 4646
   - Fails if Nomad is not accessible

2. **Bootstrap Process**:
   - Runs `nomad acl bootstrap` command
   - Handles three scenarios:
     - **Success**: Saves token and displays it
     - **Already Bootstrapped**: Shows existing token if available
     - **Error**: Displays error message with troubleshooting tips

3. **Token Management**:
   - Saves full bootstrap output to `ansible/nomad_bootstrap_token.txt`
   - Saves Secret ID only to `ansible/nomad_bootstrap_secret_id.txt`
   - Sets file permissions to 0600 (owner read/write only)
   - Displays token in console output

**Prerequisites**:
- Nomad cluster must be deployed and running
- ACLs must be enabled in Nomad configuration (`nomad_acl_enabled: true`)
- Run this playbook AFTER deploying servers

**Usage**:
```bash
ansible-playbook playbooks/nomad_acl_bootstrap.yaml
```

**Expected Outcome**:
- ACL system bootstrapped
- Management token saved locally in two files:
  - `ansible/nomad_bootstrap_token.txt` (full details)
  - `ansible/nomad_bootstrap_secret_id.txt` (token only)
- Token displayed in console output

**Using the Bootstrap Token**:
```bash
# Export the token for CLI use
export NOMAD_TOKEN=$(cat ansible/nomad_bootstrap_secret_id.txt)

# Or use directly with commands
nomad status -token=$(cat ansible/nomad_bootstrap_secret_id.txt)

# Verify ACL system
nomad acl token self
```

**Important Notes**:
- The bootstrap token provides **full administrative access** to the cluster
- Store the token files securely (they are git-ignored by default)
- The bootstrap operation can only be performed once per cluster
- If you lose the token, you must reset the ACL system (requires cluster restart)

---

## Complete Deployment Workflow

### Prerequisites

1. **Terraform Infrastructure**:
   ```bash
   cd ../../terraform/aws
   terraform init
   terraform apply
   ```
   This creates:
   - AWS VPC and networking
   - EC2 instances (3 servers, 2 clients)
   - Security groups
   - SSH key pair
   - Ansible inventory file

2. **Ansible Requirements**:
   ```bash
   cd ../../ansible
   ansible-galaxy install -r requirements.yaml
   ansible-galaxy collection install -r requirements.yaml
   ```

### Deployment Options

#### Option 1: Deploy Everything (Recommended)

Use the main site playbook:
```bash
cd ../../ansible
ansible-playbook site.yaml
```

This runs both server and client playbooks in sequence.

#### Option 2: Deploy Separately

Deploy servers first, then clients:
```bash
cd ../../ansible
ansible-playbook playbooks/nomad_servers.yaml
ansible-playbook playbooks/nomad_clients.yaml
```

#### Option 3: Deploy Only Servers

For a server-only cluster:
```bash
cd ../../ansible
ansible-playbook playbooks/nomad_servers.yaml
```

#### Option 4: Deploy Only Clients

To add clients to an existing cluster:
```bash
cd ../../ansible
ansible-playbook playbooks/nomad_clients.yaml
```

### Verification

After deployment, verify the cluster:

```bash
# SSH to a server
ssh -i ../ansible/ssh_key.pem ubuntu@<server-ip>

# Check server members
nomad server members

# Check client nodes
nomad node status

# Check cluster info
nomad status
```

## Playbook Variables

### Common Variables (Both Playbooks)

| Variable | Default | Description |
|----------|---------|-------------|
| `nomad_log_level` | `INFO` | Logging level (DEBUG, INFO, WARN, ERROR) |
| `nomad_enable_debug` | `false` | Enable debug mode |
| `nomad_acl_enabled` | `false` | Enable ACL system |
| `nomad_cloud_auto_join_enabled` | `true` | Enable AWS cloud auto-join |
| `nomad_cloud_auto_join_tag_key` | `Role` | AWS tag key for discovery |
| `nomad_cloud_auto_join_tag_value` | `server` | AWS tag value for discovery |

### Server-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nomad_server_enabled` | `true` | Enable server mode |
| `nomad_server_bootstrap_expect` | `3` | Expected number of servers |
| `nomad_client_enabled` | `false` | Disable client mode |

### Client-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nomad_server_enabled` | `false` | Disable server mode |
| `nomad_client_enabled` | `true` | Enable client mode |

## TLS Certificates

Both playbooks generate and distribute TLS certificates:

### Certificate Generation (Pre-tasks)
- Runs on localhost (Ansible control machine)
- Creates CA certificate and private key
- Generates individual certificates for each node
- Stores in `ansible/.tls/`

### Certificate Distribution (Helper Role)
- Copies CA certificate to all nodes
- Copies node-specific certificates
- Sets appropriate permissions (0600 for keys, 0644 for certs)
- Installs to `/etc/nomad.d/.tls/`

### Certificate Files
```
ansible/.tls/
├── ca.pem                    # CA certificate
├── ca-key.pem                # CA private key
├── server-1.pem              # Server certificates
├── server-1-key.pem
├── client-1.pem              # Client certificates
└── client-1-key.pem
```

## Cloud Auto-Join

Both playbooks configure AWS cloud auto-join:

**How It Works**:
- Nomad queries AWS EC2 API for instances with specific tags
- Servers find other servers using `Role=server` tag
- Clients find servers using `Role=server` tag
- No manual IP configuration needed

**Requirements**:
- IAM instance profile with EC2 describe permissions
- Instances tagged with `Role=server` or `Role=client`
- Network connectivity between instances

**Note**: The Terraform configuration creates IAM roles but doesn't attach them to instances. To enable cloud auto-join, add this to `terraform/aws/compute.tf`:
```hcl
iam_instance_profile = aws_iam_instance_profile.instance_profile.name
```

## Customization

### Change Nomad Version

Edit `ansible/roles/nomad/defaults/main.yaml`:
```yaml
nomad_binary_version: "1.12.0"  # Update version
```

### Enable ACLs

Add to playbook vars:
```yaml
vars:
  nomad_acl_enabled: true
```

Then bootstrap ACLs after deployment:
```bash
ansible-playbook playbooks/nomad_acl_bootstrap.yaml
```

The bootstrap token will be saved to:
- `ansible/nomad_bootstrap_token.txt` (full details)
- `ansible/nomad_bootstrap_secret_id.txt` (token only)

### Change Log Level

Add to playbook vars:
```yaml
vars:
  nomad_log_level: "DEBUG"
  nomad_enable_debug: true
```

### Add Custom Packages

Add to helper role vars:
```yaml
- role: helper
  vars:
    helper_apt_packages:
      - jq
      - htop
      - your-package
```

## Troubleshooting

### Playbook Fails on TLS Generation

**Issue**: `community.crypto` collection not installed

**Solution**:
```bash
ansible-galaxy collection install community.crypto
```

### Servers Not Forming Cluster

**Issue**: Cloud auto-join not working

**Solution**:
1. Check IAM instance profile is attached
2. Verify AWS tags on instances
3. Check security group allows internal traffic
4. View Nomad logs: `sudo journalctl -u nomad -f`

### Clients Not Connecting

**Issue**: Clients can't find servers

**Solution**:
1. Verify cloud auto-join configuration
2. Check network connectivity: `telnet <server-ip> 4647`
3. Verify security group rules
4. Check Nomad logs on client

### Docker Not Working

**Issue**: Docker driver not available

**Solution**:
1. Verify Docker is installed: `docker ps`
2. Check user is in docker group: `groups ubuntu`
3. Restart Nomad: `sudo systemctl restart nomad`

### CNI Plugins Missing

**Issue**: Bridge networking not working

**Solution**:
1. Verify CNI plugins: `ls -la /opt/cni/bin/`
2. Check kernel module: `lsmod | grep bridge`
3. Verify sysctl settings: `sysctl net.bridge.bridge-nf-call-iptables`

## Security Considerations

1. **TLS Certificates**: Generated but not yet configured in Nomad (requires additional configuration)
2. **ACLs**: Disabled by default (enable for production)
3. **SSH Keys**: Private key stored in `ansible/ssh_key.pem` (keep secure)
4. **Security Groups**: Configure `allowed_ssh_cidr` in Terraform to restrict access

---

## Consul Playbooks

### consul_servers.yaml

**Purpose**: Installs Docker and configures Consul v2.0.1 server agents on the `[servers]` group.

**Target Hosts**: `servers`

**Roles Applied**:
- **common** — sets hostname, packages, NTP
- **geerlingguy.docker** — installs Docker CE (required before Consul)
- **helper** — installs `jq`, `net-tools`, `unzip`, `curl`
- **consul** — installs Consul binary, writes config, starts systemd service

**Key Vars**:
```yaml
consul_server_enabled: true
consul_server_bootstrap_expect: "{{ groups['servers'] | length }}"
consul_cloud_auto_join_enabled: true   # uses AutoJoinRole EC2 tag
consul_ui_enabled: true
```

**Usage**:
```bash
ansible-playbook -i inventory.ini consul_servers.yaml
```

### consul_clients.yaml

**Purpose**: Installs Docker and configures Consul v2.0.1 client agents on the `[clients]` group.

**Target Hosts**: `clients`

**Run after** `consul_servers.yaml` so servers are healthy before clients join.

**Usage**:
```bash
ansible-playbook -i inventory.ini consul_clients.yaml
```

### Running both via site.yaml

`site.yaml` now runs Consul before Nomad:
1. `consul_servers.yaml`
2. `consul_clients.yaml`
3. `nomad_servers.yaml`
4. `nomad_clients.yaml`

### Verify Consul cluster

```bash
ssh -i ssh_key.pem ubuntu@<server-ip>
consul members
# Expect 3 servers (alive) + 2 clients (alive)
```

### Consul UI

Available at `http://<server-public-ip>:8500/ui` after deployment.

### Customise Consul

| Variable | File | Description |
|---|---|---|
| `consul_binary_version` | `roles/consul/defaults/main.yaml` | Consul version to install |
| `consul_acl_enabled` | playbook vars | Enable ACLs (off by default) |
| `consul_tls_enabled` | playbook vars | Enable TLS (off by default) |
| `consul_gossip_encryption_enabled` | playbook vars | Enable gossip encryption |
| `consul_gossip_encryption_key` | playbook vars | Key from `consul keygen` |

See [roles/consul/README.md](roles/consul/README.md) for the full variable reference.
5. **IAM Permissions**: Minimal permissions for cloud auto-join

## Next Steps

After successful deployment:

1. **Bootstrap ACLs** (if enabled):
   ```bash
   ansible-playbook playbooks/nomad_acl_bootstrap.yaml
   ```
   
   The management token will be saved locally and displayed in the output.

2. **Deploy a Test Job**:
   ```bash
   nomad job run example.nomad
   ```

3. **Access Nomad UI**:
   ```
   http://<server-ip>:4646
   ```

4. **Set Up Monitoring**: Configure Prometheus to scrape metrics from `:4646/v1/metrics`

5. **Configure TLS**: Update Nomad configuration to use generated certificates

## Related Documentation

- [Main Project README](../../README.md)
- [Ansible README](../README.md)
- [Terraform Configuration](../../terraform/aws/)
- [Role Documentation](../roles/)

## Author

Created for nomad-infra project