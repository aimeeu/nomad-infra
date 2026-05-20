# Nomad Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying a complete Nomad cluster on AWS using Terraform and Ansible.

## Overview

The deployment process consists of two main phases:
1. **Infrastructure Provisioning** (Terraform) - Creates AWS resources
2. **Configuration Management** (Ansible) - Installs and configures Nomad

**Total Deployment Time**: ~15-20 minutes

## Prerequisites

Before starting, ensure you have:

### Required Tools

- **Terraform** >= 1.0
  ```bash
  terraform version
  ```

- **Ansible** >= 2.9
  ```bash
  ansible --version
  ```

- **AWS CLI** configured
  ```bash
  aws sts get-caller-identity
  ```

- **Python 3** with pip
  ```bash
  python3 --version
  ```

### AWS Requirements

- AWS account with appropriate permissions
- AWS credentials configured (see [AWS Configuration](#aws-configuration))
- Sufficient EC2 instance limits in target region

### Install Ansible Dependencies

```bash
# Install required Ansible collections and roles
cd ansible
ansible-galaxy install -r requirements.yaml
```

## AWS Configuration

Choose one of the following methods to configure AWS credentials:

### Option 1: AWS CLI (Recommended)

```bash
aws configure
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-2)
- Default output format (json)

### Option 2: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-2"
```

### Option 3: AWS Profile

```bash
export AWS_PROFILE="your-profile-name"
```

### Verify Configuration

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

## Phase 1: Infrastructure Provisioning with Terraform

### Step 1: Navigate to Terraform Directory

```bash
cd terraform/aws
```

### Step 2: Customize Variables (Optional)

Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize your deployment:

```hcl
# AWS Configuration
aws_region       = "us-east-2"
project_name     = "nomad-consul"
owner            = "your-name"
environment      = "dev"

# Network Configuration
vpc_cidr         = "10.0.0.0/16"
subnet_cidr      = "10.0.1.0/24"

# Security Configuration
allowed_ssh_cidr = "YOUR_IP/32"  # ⚠️ IMPORTANT: Restrict to your IP

# Cluster Configuration
server_count     = 3  # Recommended: 3, 5, or 7 (odd numbers)
client_count     = 2  # Scale as needed

# Instance Configuration
server_instance_type = "t3.medium"  # 2 vCPU, 4 GB RAM
client_instance_type = "t3.medium"  # 2 vCPU, 4 GB RAM
```

**Security Note**: Always restrict `allowed_ssh_cidr` to your specific IP address or network range.

### Step 3: Initialize Terraform

```bash
terraform init
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

**What This Does**:
- Downloads required providers (AWS, Local, Null, TLS)
- Initializes backend (local by default)
- Prepares working directory

### Step 4: Review the Execution Plan

```bash
terraform plan
```

**What to Review**:
- Number of resources to be created (~15-20 resources)
- Instance types and counts
- Network configuration
- Security group rules

**Expected Resource Count**: 
```
Plan: 18 to add, 0 to change, 0 to destroy.
```

### Step 5: Apply the Configuration

```bash
terraform apply
```

**Confirmation**: Type `yes` when prompted

**Duration**: ~5 minutes

**What Gets Created**:
- ✓ VPC (10.0.0.0/16)
- ✓ Public subnet (10.0.1.0/24)
- ✓ Internet gateway
- ✓ Route table
- ✓ Security group with firewall rules
- ✓ 3 server EC2 instances (t3.medium, 50GB gp3)
- ✓ 2 client EC2 instances (t3.medium, 50GB gp3)
- ✓ IAM role and instance profile
- ✓ SSH key pair
- ✓ `../../ansible/ssh_key.pem` (private key)
- ✓ `../../ansible/ssh_key.pub` (public key)
- ✓ `../../ansible/inventory.ini` (Ansible inventory)

### Step 6: View Outputs

```bash
# View all outputs
terraform output

# View specific outputs
terraform output nomad_ui_urls
terraform output ssh_commands
terraform output server_public_ips
```

**Save Important Information**:
```bash
# Save SSH commands
terraform output -raw ssh_instructions > ../../ssh_commands.txt

# Save Nomad UI URLs
terraform output -json nomad_ui_urls > ../../nomad_urls.json
```

### Step 7: Verify Infrastructure

```bash
# Check instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=nomad-consul" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]' \
  --output table

# Test SSH connectivity
ssh -i ../../ansible/ssh_key.pem ubuntu@$(terraform output -raw server_public_ips | jq -r '.[0]')
```

**Expected**: You should be able to SSH into the server successfully.

## Phase 2: Configuration Management with Ansible

### Step 1: Navigate to Ansible Directory

```bash
cd ../../ansible
```

### Step 2: Verify Inventory File

The inventory file was automatically generated by Terraform:

```bash
cat inventory.ini
```

**Expected Content**:
```ini
[servers]
nomad-consul-server-1 ansible_host=54.123.45.67 private_ip=10.0.1.10
nomad-consul-server-2 ansible_host=54.123.45.68 private_ip=10.0.1.11
nomad-consul-server-3 ansible_host=54.123.45.69 private_ip=10.0.1.12

[clients]
nomad-consul-client-1 ansible_host=54.123.45.70 private_ip=10.0.1.20
nomad-consul-client-2 ansible_host=54.123.45.71 private_ip=10.0.1.21

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=ssh_key.pem
ansible_python_interpreter=/usr/bin/python3
```

### Step 3: Test Ansible Connectivity

```bash
ansible all -m ping
```

**Expected Output**:
```
nomad-consul-server-1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
nomad-consul-server-2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
...
```

**If Connection Fails**:
```bash
# Check SSH key permissions
chmod 600 ssh_key.pem

# Test SSH manually
ssh -i ssh_key.pem ubuntu@<server-ip>

# Use verbose mode
ansible all -m ping -vvv
```

### Step 4: Install Required Ansible Dependencies

```bash
# Install Ansible collections
ansible-galaxy collection install community.crypto ansible.posix

# Install external roles
ansible-galaxy install -r requirements.yaml
```

**Expected Output**:
```
Starting galaxy collection install process
Process install dependency map
Starting collection install process
Installing 'community.crypto:2.x.x' to '~/.ansible/collections/ansible_collections/community/crypto'
Installing 'ansible.posix:1.x.x' to '~/.ansible/collections/ansible_collections/ansible/posix'

Starting galaxy role install process
- downloading role 'docker', owned by geerlingguy
- extracting geerlingguy.docker to ~/.ansible/roles/geerlingguy.docker
```

### Step 5: Run the Main Playbook

```bash
ansible-playbook site.yaml
```

**Duration**: ~10 minutes

**What This Does**:

#### On All Nodes:
1. ✓ Installs base system packages (jq, net-tools, ntp, unzip, curl, wget)
2. ✓ Configures NTP for time synchronization
3. ✓ Sets hostnames based on inventory

#### On Servers:
4. ✓ Generates TLS certificates (CA and server certificates)
5. ✓ Distributes TLS certificates to `/etc/nomad.d/.tls/`
6. ✓ Installs Nomad v2.0.0
7. ✓ Configures Nomad in server mode
8. ✓ Enables cloud auto-join for AWS
9. ✓ Sets up systemd service
10. ✓ Starts Nomad service

#### On Clients:
11. ✓ Generates TLS certificates (CA and client certificates)
12. ✓ Installs CNI plugins v1.9.0 (Ubuntu only)
13. ✓ Installs Docker CE
14. ✓ Configures bridge kernel module
15. ✓ Distributes TLS certificates
16. ✓ Installs Nomad v2.0.0
17. ✓ Configures Nomad in client mode
18. ✓ Enables Docker driver
19. ✓ Enables cloud auto-join to find servers
20. ✓ Sets up systemd service
21. ✓ Starts Nomad service

**Expected Final Output**:
```
PLAY RECAP *********************************************************************
nomad-consul-server-1      : ok=25   changed=15   unreachable=0    failed=0
nomad-consul-server-2      : ok=25   changed=15   unreachable=0    failed=0
nomad-consul-server-3      : ok=25   changed=15   unreachable=0    failed=0
nomad-consul-client-1      : ok=30   changed=20   unreachable=0    failed=0
nomad-consul-client-2      : ok=30   changed=20   unreachable=0    failed=0
```

### Step 6: Verify Nomad Installation

#### Check Service Status

```bash
# Check Nomad service on all hosts
ansible all -b -m systemd -a "name=nomad state=status"
```

#### Verify Cluster Formation

SSH to a server and check cluster status:

```bash
# SSH to first server
ssh -i ssh_key.pem ubuntu@$(cd ../terraform/aws && terraform output -raw server_public_ips | jq -r '.[0]')

# Check server members
nomad server members

# Expected output:
# Name                      Address      Port  Status  Leader  Raft Version  Build  Datacenter  Region
# nomad-consul-server-1.dc1  10.0.1.10    4648  alive   true    3             2.0.0  dc1         global
# nomad-consul-server-2.dc1  10.0.1.11    4648  alive   false   3             2.0.0  dc1         global
# nomad-consul-server-3.dc1  10.0.1.12    4648  alive   false   3             2.0.0  dc1         global

# Check client nodes
nomad node status

# Expected output:
# ID        Node Class   DC   Drain  Eligibility  Status
# abc123    <none>       dc1  false  eligible     ready
# def456    <none>       dc1  false  eligible     ready

# Check Nomad version
nomad version

# Expected output:
# Nomad v2.0.0
```

## Post-Deployment Verification

### 1. Access Nomad UI

Open your browser and navigate to any server's IP on port 4646:

```
http://<server-ip>:4646
```

**What You Should See**:
- Nomad dashboard
- 3 servers in the cluster
- 2 client nodes ready
- No jobs running (yet)

### 2. Deploy a Test Job

Create a simple test job:

```bash
cat > example.nomad <<EOF
job "example" {
  datacenters = ["dc1"]
  type = "service"

  group "web" {
    count = 3

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }

    network {
      port "http" {
        to = 80
      }
    }
  }
}
EOF

# Deploy the job
nomad job run example.nomad

# Check job status
nomad job status example

# View allocations
nomad alloc status <allocation-id>
```

### 3. Verify Docker on Clients

```bash
# Check Docker is running
ansible clients -a "docker ps"

# Check Docker version
ansible clients -a "docker version"
```

### 4. Check Logs

```bash
# View Nomad logs on servers
ansible servers -b -a "journalctl -u nomad -n 50"

# View Nomad logs on clients
ansible clients -b -a "journalctl -u nomad -n 50"

# Follow logs in real-time
ssh -i ssh_key.pem ubuntu@<server-ip>
sudo journalctl -u nomad -f
```

## Optional: Enable ACLs

For production deployments, enable Access Control Lists:

### Step 1: Enable ACLs in Configuration

Edit `ansible/nomad_servers.yaml` and `ansible/nomad_clients.yaml`:

```yaml
vars:
  nomad_acl_enabled: true
```

### Step 2: Redeploy with ACLs

```bash
cd ansible
ansible-playbook site.yaml
```

### Step 3: Bootstrap ACL System

```bash
ansible-playbook nomad_acl_bootstrap.yaml
```

**Output Files**:
- `nomad_bootstrap_token.txt` - Full bootstrap details
- `nomad_bootstrap_secret_id.txt` - Token only

### Step 4: Use the Bootstrap Token

```bash
# Export token
export NOMAD_TOKEN=$(cat nomad_bootstrap_secret_id.txt)

# Verify ACL system
nomad acl token self

# Use token with commands
nomad status -token=$(cat nomad_bootstrap_secret_id.txt)
```

See [BOOTSTRAP_ACL_EXAMPLE.md](ansible/BOOTSTRAP_ACL_EXAMPLE.md) for detailed instructions.

## Troubleshooting

### Terraform Issues

#### Issue: Duplicate Key Pair Error

**Error**: `InvalidKeyPair.Duplicate: The keypair already exists`

**Solution**:
```bash
# Delete existing key pair
aws ec2 delete-key-pair --key-name nomad-consul-key

# Or change project name
echo 'project_name = "nomad-consul-v2"' >> terraform.tfvars
```

#### Issue: Insufficient Instance Capacity

**Error**: `InsufficientInstanceCapacity`

**Solution**:
- Wait a few minutes and retry
- Try different availability zone
- Try different instance type (t3a.medium)

### Ansible Issues

#### Issue: SSH Connection Timeout

**Error**: `Failed to connect to the host via ssh`

**Solution**:
```bash
# Check SSH key permissions
chmod 600 ansible/ssh_key.pem

# Verify instances are running
cd terraform/aws
terraform output server_public_ips

# Test SSH manually
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>
```

#### Issue: Nomad Service Not Starting

**Error**: Service fails to start

**Solution**:
```bash
# Check service status
ansible all -b -m systemd -a "name=nomad"

# View logs
ansible all -b -a "journalctl -u nomad -n 100"

# Validate configuration
ansible all -a "nomad config validate /etc/nomad.d/nomad.hcl"
```

#### Issue: Clients Not Connecting

**Error**: Clients don't appear in cluster

**Solution**:
```bash
# Check cloud auto-join logs
ansible clients -b -a "journalctl -u nomad | grep 'auto-join'"

# Verify network connectivity
ansible clients -a "telnet <server-ip> 4647"

# Check security group allows internal traffic
```

## Cleanup

### Destroy All Resources

When you're done with the cluster:

```bash
cd terraform/aws
terraform destroy
```

**Confirmation**: Type `yes` when prompted

**What Gets Deleted**:
- All EC2 instances
- VPC and networking components
- Security groups
- IAM roles
- SSH key pairs (AWS only, local files remain)

**Warning**: This is permanent. Backup important data first.

### Partial Cleanup

To keep infrastructure but stop instances:

```bash
# Stop instances (still incurs EBS costs)
aws ec2 stop-instances --instance-ids $(terraform output -json server_instance_ids | jq -r '.[]')

# Start instances later
aws ec2 start-instances --instance-ids $(terraform output -json server_instance_ids | jq -r '.[]')
```

## Cost Estimation

### Default Configuration (us-east-2)

| Resource | Quantity | Type | Monthly Cost |
|----------|----------|------|--------------|
| Server Instances | 3 | t3.medium | ~$100 |
| Client Instances | 2 | t3.medium | ~$67 |
| EBS Volumes | 5 | 50GB gp3 | ~$20 |
| Data Transfer | - | Varies | ~$10 |
| **Total** | | | **~$197/month** |

### Cost Optimization

1. **Use Spot Instances**: Up to 90% savings
2. **Smaller Instances**: Use t3.small for dev/test
3. **Fewer Instances**: Reduce counts for testing
4. **Stop When Not in Use**: `terraform destroy` when not needed

## Next Steps

After successful deployment:

1. **Deploy Applications**: Start deploying your workloads
2. **Set Up Monitoring**: Configure Prometheus/Grafana
3. **Enable ACLs**: Secure your cluster for production
4. **Configure TLS**: Enable encrypted communication
5. **Backup Strategy**: Implement backup procedures
6. **Documentation**: Document your specific configurations

## Additional Resources

- [Main Project README](README.md)
- [Ansible Configuration](ansible/README.md)
- [Terraform AWS Configuration](terraform/aws/README.md)
- [ACL Bootstrap Guide](ansible/BOOTSTRAP_ACL_EXAMPLE.md)
- [Security Group Management](ansible/README-SECURITY-GROUP.md)
- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions:
1. Check the troubleshooting sections in this guide
2. Review the detailed documentation in each subdirectory
3. Consult [HashiCorp Nomad Documentation](https://www.nomadproject.io/docs)
4. Open an issue in the project repository

## License

BSD 2-Clause License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2026, Aimee Ukasick