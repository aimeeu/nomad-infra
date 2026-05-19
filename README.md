# nomad-infra

Infrastructure-as-Code for deploying a HashiCorp Nomad cluster on AWS using Terraform and Ansible.

## Overview

This project provisions and configures a complete Nomad cluster on AWS with:
- 3 server nodes (running Nomad in server mode)
- 2 client nodes (running Nomad clients)
- Automated SSH key generation
- Cloud auto-join configuration using AWS tags
- Ansible inventory generation for configuration management
- Automated Nomad installation and configuration via Ansible

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      AWS VPC                            │
│                   (10.0.0.0/16)                         │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Public Subnet (10.0.1.0/24)              │  │
│  │                                                  │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │
│  │  │ Server 1 │  │ Server 2 │  │ Server 3 │      │  │
│  │  │  Nomad   │  │  Nomad   │  │  Nomad   │      │  │
│  │  │  Server  │  │  Server  │  │  Server  │      │  │
│  │  └──────────┘  └──────────┘  └──────────┘      │  │
│  │                                                  │  │
│  │  ┌──────────┐  ┌──────────┐                     │  │
│  │  │ Client 1 │  │ Client 2 │                     │  │
│  │  │ Nomad    │  │ Nomad    │                     │  │
│  │  └──────────┘  └──────────┘                     │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Internet Gateway                                       │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (optional, for configuration management)

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to set your preferences:

```hcl
aws_region       = "us-east-1"
project_name     = "nomad-consul"
owner            = "your-name"
environment      = "dev"
allowed_ssh_cidr = "YOUR_IP/32"  # Restrict SSH access to your IP
server_count     = 3
client_count     = 2
```

### 2. Deploy Infrastructure

```bash
cd terraform/aws

# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

### 3. Access Your Cluster

After deployment, Terraform outputs will provide:

```bash
# SSH commands for each instance
terraform output ssh_commands

# Consul UI URLs (one per server)
terraform output consul_ui_urls

# Nomad UI URLs (one per server)
terraform output nomad_ui_urls
```

Example SSH access:
```bash
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>
```

### 4. Configure Nomad with Ansible

An Ansible inventory file is automatically generated at `ansible/inventory.ini`. Use the provided playbooks to install and configure Nomad:

```bash
cd ../../ansible

# Test connectivity
ansible all -m ping

# Install and configure Nomad on all nodes
ansible-playbook site.yaml

# Or configure servers and clients separately
ansible-playbook playbooks/nomad_servers.yaml
ansible-playbook playbooks/nomad_clients.yaml
```

The Ansible playbooks will:
- Install required system packages
- Download and install Nomad v1.11.1
- Configure Nomad servers with cloud auto-join
- Configure Nomad clients to connect to servers
- Set up systemd services
- Start and enable Nomad services

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-east-2` |
| `project_name` | Project name for resource naming | `nomad-consul` |
| `owner` | Owner tag for resources | `devops-team` |
| `environment` | Environment name (dev/staging/prod) | `dev` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `subnet_cidr` | Public subnet CIDR block | `10.0.1.0/24` |
| `allowed_ssh_cidr` | CIDR allowed for SSH access | `0.0.0.0/0` |
| `server_count` | Number of server instances | `3` |
| `client_count` | Number of client instances | `2` |
| `server_instance_type` | EC2 instance type for servers | `t3.medium` |
| `client_instance_type` | EC2 instance type for clients | `t3.medium` |
| `ami_owner` | AWS account ID of AMI owner | `099720109477` (Canonical) |
| `ami_name_filter` | AMI name filter | `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*` |
| `ssh_user` | SSH user for instances | `ubuntu` |

### Outputs

The following outputs are available after deployment:

- `ami_id` - AMI ID used for instances
- `vpc_id` - VPC ID
- `subnet_id` - Subnet ID
- `security_group_id` - Security group ID
- `server_public_ips` - Public IPs of server instances
- `server_private_ips` - Private IPs of server instances
- `client_public_ips` - Public IPs of client instances
- `client_private_ips` - Private IPs of client instances
- `nomad_ui_urls` - URLs to access Nomad UI (http://server-ip:4646)
- `ssh_commands` - SSH commands for all instances
- `ssh_private_key_path` - Path to generated SSH private key

## Network Security

The security group allows:

- **SSH (22)**: From `allowed_ssh_cidr` (default: 0.0.0.0/0 - **change this!**)
- **Nomad UI/API (4646)**: From anywhere (0.0.0.0/0)
- **Internal traffic**: All ports between cluster members
- **Egress**: All outbound traffic

**Security Recommendation**: Update `allowed_ssh_cidr` to your specific IP address or corporate network range.

## IAM Permissions

The infrastructure creates IAM roles with the following permissions for cloud auto-join:

- `ec2:DescribeInstances`
- `ec2:DescribeTags`
- `autoscaling:DescribeAutoScalingGroups`

These permissions enable Nomad to automatically discover cluster members using AWS tags.

## File Structure

```
nomad-infra/
├── README.md
├── LICENSE
├── .gitignore
├── terraform/
│   └── aws/
│       ├── main.tf              # Provider configuration
│       ├── variables.tf         # Variable definitions
│       ├── outputs.tf           # Output definitions
│       ├── ami.tf               # AMI data source
│       ├── network.tf           # VPC, subnet, security group
│       ├── compute.tf           # EC2 instances
│       ├── iam.tf               # IAM roles and policies
│       ├── keypair.tf           # SSH key generation
│       ├── inventory.tpl        # Ansible inventory template
│       └── terraform.tfvars.example
└── ansible/
    ├── ansible.cfg              # Ansible configuration
    ├── site.yaml                # Main playbook
    ├── playbooks/
    │   ├── nomad_servers.yaml   # Server configuration
    │   └── nomad_clients.yaml   # Client configuration
    └── roles/
        ├── common/              # Base system configuration
        ├── hashicorp_release/   # HashiCorp binary installer
        └── nomad/               # Nomad installation & config
```

## Cleanup

To destroy all resources:

```bash
cd terraform/aws
terraform destroy
```

**Warning**: This will permanently delete all resources created by Terraform.

## Ansible Configuration

### Roles

The project includes three Ansible roles:

1. **common**: Base system configuration
   - Installs required packages (jq, net-tools, ntp, unzip, curl, wget)
   - Configures NTP
   - Sets hostname

2. **hashicorp_release**: Generic HashiCorp product installer
   - Downloads and installs HashiCorp binaries
   - Supports version checking and upgrades
   - Handles architecture detection

3. **nomad**: Nomad installation and configuration
   - Installs Nomad v1.11.1
   - Creates configuration directories
   - Generates Nomad configuration from templates
   - Sets up systemd service
   - Supports both server and client modes
   - Configures cloud auto-join for AWS

### Playbooks

- **site.yaml**: Main playbook that orchestrates the entire cluster configuration
- **playbooks/nomad_servers.yaml**: Configures Nomad servers with cloud auto-join
- **playbooks/nomad_clients.yaml**: Configures Nomad clients to connect to servers

### Configuration Variables

Key variables in [`ansible/roles/nomad/defaults/main.yaml`](ansible/roles/nomad/defaults/main.yaml):

| Variable | Description | Default |
|----------|-------------|---------|
| `nomad_binary_version` | Nomad version to install | `1.11.1` |
| `nomad_server_enabled` | Enable server mode | `false` |
| `nomad_client_enabled` | Enable client mode | `false` |
| `nomad_cloud_auto_join_enabled` | Enable AWS cloud auto-join | `false` |
| `nomad_acl_enabled` | Enable ACLs | `false` |
| `nomad_log_level` | Logging level | `INFO` |

### Running Playbooks

```bash
# Configure entire cluster
ansible-playbook site.yaml

# Configure only servers
ansible-playbook playbooks/nomad_servers.yaml

# Configure only clients
ansible-playbook playbooks/nomad_clients.yaml

# Check Nomad status
ansible servers -a "nomad server members"
ansible clients -a "nomad node status"
```

## Next Steps

After deployment and configuration:

1. **Verify cluster status**:
   ```bash
   nomad server members
   nomad node status
   ```

2. **Access Nomad UI**: Navigate to any server's IP on port 4646
   ```
   http://<server-ip>:4646
   ```

3. **Bootstrap ACLs** (optional, for production):
   ```bash
   nomad acl bootstrap
   ```

4. **Deploy your first job**:
   ```bash
   nomad job run example.nomad
   ```

5. **Set up monitoring** with Prometheus/Grafana
6. **Configure TLS** for secure communication

## Known Issues

- The IAM instance profile created in [`iam.tf`](terraform/aws/iam.tf) is not currently attached to EC2 instances. To enable cloud auto-join, add `iam_instance_profile = aws_iam_instance_profile.instance_profile.name` to the instance resources in [`compute.tf`](terraform/aws/compute.tf).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

BSD 2-Clause License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2026, Aimee Ukasick

## Resources

- [HashiCorp Nomad Documentation](https://www.nomadproject.io/docs)
- [Nomad Cloud Auto-Join](https://developer.hashicorp.com/nomad/docs/configuration/server_join)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)