# nomad-infra

Infrastructure-as-Code for deploying a HashiCorp Nomad cluster on AWS using Terraform and Ansible.

## Overview

This project provides a complete, production-ready solution for deploying HashiCorp Nomad clusters on AWS. It combines Terraform for infrastructure provisioning and Ansible for configuration management, enabling rapid deployment of secure, scalable Nomad clusters with minimal manual intervention.

### Key Features

- **Automated Infrastructure**: Terraform provisions VPC, subnets, EC2 instances, security groups, and IAM roles
- **Configuration Management**: Ansible handles Nomad installation, configuration, and service management
- **Cloud Auto-Join**: Automatic cluster member discovery using AWS tags (no hardcoded IPs)
- **TLS Security**: Automated TLS certificate generation and distribution for secure communication
- **ACL Support**: Optional Access Control List configuration for production security
- **Container Networking**: CNI plugins and Docker support for containerized workloads
- **Flexible Scaling**: Easily adjust cluster size via configuration variables
- **Idempotent Operations**: Safe to run multiple times without side effects

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
│  │  │  Nomad   │  │  Nomad   │                     │  │
│  │  │ + Docker │  │ + Docker │                     │  │
│  │  └──────────┘  └──────────┘                     │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  Internet Gateway                                       │
└─────────────────────────────────────────────────────────┘
```

### Component Overview

- **3 Server Nodes**: Form the Nomad control plane, handle scheduling and state management
- **2 Client Nodes**: Execute workloads, run Docker containers
- **VPC & Networking**: Isolated network with public subnet and internet gateway
- **Security Groups**: Firewall rules for SSH, Nomad UI/API, and internal cluster communication
- **IAM Roles**: Permissions for cloud auto-join functionality
- **TLS Certificates**: Secure communication between cluster members

## Prerequisites

### Required Tools

- **[Terraform](https://www.terraform.io/downloads.html)** >= 1.0
- **[AWS CLI](https://aws.amazon.com/cli/)** configured with appropriate credentials
- **[Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)** >= 2.9

### AWS Requirements

- AWS account with appropriate permissions
- AWS credentials configured (via `aws configure` or environment variables)
- Sufficient EC2 instance limits in target region

### Ansible Collections

Install required Ansible collections:
```bash
ansible-galaxy collection install community.crypto ansible.posix
ansible-galaxy install -r ansible/requirements.yaml
```

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cd terraform/aws
cp terraform.tfvars.example terraform.tfvars
```

Edit [`terraform.tfvars`](terraform/aws/terraform.tfvars) to set your preferences:

```hcl
aws_region       = "us-east-1"
project_name     = "nomad-cluster"
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

**Expected Duration**: ~5 minutes

**What Gets Created**:
- VPC with public subnet
- 3 server EC2 instances (t3.medium)
- 2 client EC2 instances (t3.medium)
- Security groups with firewall rules
- SSH key pair (saved to `ansible/ssh_key.pem`)
- IAM roles for cloud auto-join
- Ansible inventory file (`ansible/inventory.ini`)

### 3. Configure Nomad with Ansible

After infrastructure is provisioned, configure Nomad on all nodes:

```bash
cd ../../ansible

# Install required Ansible Galaxy roles
ansible-galaxy install -r requirements.yaml

# Test connectivity
ansible all -m ping

# Install and configure Nomad on all nodes
ansible-playbook site.yaml
```

**Expected Duration**: ~10 minutes

**What Gets Configured**:
- Base system packages and configuration
- TLS certificates for secure communication
- CNI plugins for container networking (clients only)
- Docker installation (clients only)
- Nomad v1.11.1 installation
- Nomad server cluster formation
- Nomad client registration
- Systemd service configuration

### 4. Access Your Cluster

After deployment, access the cluster:

```bash
# Get Nomad UI URLs
terraform output nomad_ui_urls

# Get SSH commands
terraform output ssh_commands

# SSH to a server
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>

# Check cluster status
nomad server members
nomad node status
```

**Nomad UI**: Navigate to `http://<server-ip>:4646` in your browser

## Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-east-2` |
| `project_name` | Project name for resource naming | `nomad-consul` |
| `owner` | Owner tag for resources | `devops-team` |
| `environment` | Environment name (dev/staging/prod) | `dev` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `subnet_cidr` | Public subnet CIDR block | `10.0.1.0/24` |
| `allowed_ssh_cidr` | CIDR allowed for SSH access | `0.0.0.0/0` ⚠️ |
| `server_count` | Number of server instances | `3` |
| `client_count` | Number of client instances | `2` |
| `server_instance_type` | EC2 instance type for servers | `t3.medium` |
| `client_instance_type` | EC2 instance type for clients | `t3.medium` |
| `ami_owner` | AWS account ID of AMI owner | `099720109477` (Canonical) |
| `ami_name_filter` | AMI name filter | `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*` |
| `ssh_user` | SSH user for instances | `ubuntu` |

⚠️ **Security Note**: Change `allowed_ssh_cidr` to your specific IP address or network range.

### Ansible Variables

Key variables in [`ansible/roles/nomad/defaults/main.yaml`](ansible/roles/nomad/defaults/main.yaml):

| Variable | Description | Default |
|----------|-------------|---------|
| `nomad_binary_version` | Nomad version to install | `1.11.1` |
| `nomad_server_enabled` | Enable server mode | `false` |
| `nomad_client_enabled` | Enable client mode | `false` |
| `nomad_cloud_auto_join_enabled` | Enable AWS cloud auto-join | `false` |
| `nomad_acl_enabled` | Enable ACLs | `false` |
| `nomad_log_level` | Logging level | `INFO` |

### Terraform Outputs

After deployment, the following outputs are available:

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

The security group configuration allows:

- **SSH (22)**: From `allowed_ssh_cidr` (default: 0.0.0.0/0 - **change this!**)
- **Nomad UI/API (4646)**: From anywhere (0.0.0.0/0)
- **Nomad RPC (4647)**: Internal cluster communication only
- **Nomad Serf (4648)**: Internal cluster communication only
- **Internal traffic**: All ports between cluster members
- **Egress**: All outbound traffic

**Security Recommendations**:
1. Update `allowed_ssh_cidr` to your specific IP address or corporate network range
2. Consider restricting Nomad UI access to specific IPs
3. Use a VPN or bastion host for production environments
4. Enable ACLs for production deployments
5. Implement TLS for all communications

## IAM Permissions

The infrastructure creates IAM roles with the following permissions for cloud auto-join:

- `ec2:DescribeInstances`
- `ec2:DescribeTags`
- `autoscaling:DescribeAutoScalingGroups`

These permissions enable Nomad to automatically discover cluster members using AWS tags.

**Note**: The IAM instance profile is created but not currently attached to EC2 instances. To enable cloud auto-join, add this to [`terraform/aws/compute.tf`](terraform/aws/compute.tf):

```hcl
iam_instance_profile = aws_iam_instance_profile.instance_profile.name
```

## Project Structure

```
nomad-infra/
├── README.md                           # This file
├── LICENSE                             # BSD 2-Clause License
├── .gitignore                          # Git ignore patterns
├── terraform/
│   └── aws/
│       ├── main.tf                     # Provider configuration
│       ├── variables.tf                # Variable definitions
│       ├── outputs.tf                  # Output definitions
│       ├── ami.tf                      # AMI data source
│       ├── network.tf                  # VPC, subnet, security group
│       ├── compute.tf                  # EC2 instances
│       ├── iam.tf                      # IAM roles and policies
│       ├── keypair.tf                  # SSH key generation
│       ├── inventory.tpl               # Ansible inventory template
│       ├── terraform.tfvars.example    # Example variables
│       └── README.md                   # Terraform documentation
└── ansible/
    ├── ansible.cfg                     # Ansible configuration
    ├── site.yaml                       # Main orchestration playbook
    ├── inventory.ini                   # Auto-generated by Terraform
    ├── ssh_key.pem                     # Auto-generated SSH key
    ├── requirements.yaml               # Ansible Galaxy requirements
    ├── README.md                       # Ansible documentation
    ├── PLAYBOOKS-README.md             # Detailed playbook documentation
    ├── BOOTSTRAP_ACL_EXAMPLE.md        # ACL bootstrap guide
    ├── ANSIBLE_LINT_RESULTS.md         # Linting results
    ├── nomad_acl_bootstrap.yaml        # ACL bootstrap playbook
    ├── nomad_servers.yaml              # Server configuration playbook
    ├── nomad_clients.yaml              # Client configuration playbook
    └── roles/
        ├── common/                     # Base system configuration
        │   ├── defaults/
        │   ├── tasks/
        │   └── README.md
        ├── cni/                        # CNI plugins installer
        │   ├── defaults/
        │   ├── tasks/
        │   └── README.md
        ├── hashicorp_release/          # HashiCorp binary installer
        │   ├── defaults/
        │   ├── tasks/
        │   └── README.md
        ├── helper/                     # Utility role for common tasks
        │   ├── defaults/
        │   ├── tasks/
        │   └── README.md
        ├── nomad/                      # Nomad installation & config
        │   ├── defaults/
        │   ├── handlers/
        │   ├── tasks/
        │   ├── templates/
        │   └── README.md
        └── tls/                        # TLS certificate generation
            ├── defaults/
            ├── tasks/
            └── README.md
```

## Advanced Usage

### Enable ACLs

To enable Access Control Lists for production security:

1. **Enable ACLs in playbook**:
   ```yaml
   # ansible/nomad_servers.yaml
   vars:
     nomad_acl_enabled: true
   ```

2. **Deploy with ACLs enabled**:
   ```bash
   ansible-playbook site.yaml
   ```

3. **Bootstrap ACL system**:
   ```bash
   ansible-playbook nomad_acl_bootstrap.yaml
   ```

4. **Use the bootstrap token**:
   ```bash
   export NOMAD_TOKEN=$(cat ansible/nomad_bootstrap_secret_id.txt)
   nomad status
   ```

See [`ansible/BOOTSTRAP_ACL_EXAMPLE.md`](ansible/BOOTSTRAP_ACL_EXAMPLE.md) for detailed instructions.

### Scale the Cluster

To add more nodes:

```bash
# Update terraform.tfvars
echo 'client_count = 5' >> terraform/aws/terraform.tfvars

# Apply changes
cd terraform/aws
terraform apply

# Configure new nodes
cd ../../ansible
ansible-playbook nomad_clients.yaml
```

### Upgrade Nomad

To upgrade to a newer Nomad version:

```bash
# Update version in ansible/roles/nomad/defaults/main.yaml
nomad_binary_version: "1.12.0"

# Re-run Ansible playbooks
ansible-playbook site.yaml
```

### Deploy a Test Job

After cluster is running, deploy a sample job:

```bash
# Create a simple job file
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
```

## Cleanup

To destroy all resources:

```bash
cd terraform/aws
terraform destroy
```

**Warning**: This will permanently delete all resources created by Terraform, including:
- All EC2 instances
- VPC and networking components
- Security groups
- IAM roles
- SSH key pairs

**Important**: Backup any important data before destroying resources.

## Troubleshooting

### Common Issues

#### 1. SSH Permission Denied

**Problem**: Cannot SSH to instances

**Solution**:
```bash
chmod 600 ansible/ssh_key.pem
ssh -i ansible/ssh_key.pem ubuntu@<server-ip>
```

#### 2. Ansible Connection Timeout

**Problem**: Ansible cannot connect to instances

**Solution**:
```bash
# Verify instances are running
terraform output server_public_ips

# Test SSH connectivity
ssh -i ansible/ssh_key.pem ubuntu@<server-ip>

# Check security group allows SSH from your IP
```

#### 3. Nomad Service Not Starting

**Problem**: Nomad service fails to start

**Solution**:
```bash
# Check service status
ansible all -b -m systemd -a "name=nomad state=status"

# View logs
ansible all -b -a "journalctl -u nomad -n 50"

# Validate configuration
ansible all -a "nomad config validate /etc/nomad.d/nomad.hcl"
```

#### 4. Clients Not Connecting to Servers

**Problem**: Client nodes don't appear in cluster

**Solution**:
```bash
# Check cloud auto-join configuration
ansible clients -a "nomad agent-info | grep servers"

# Verify network connectivity
ansible clients -a "telnet <server-ip> 4647"

# Check IAM instance profile is attached
```

#### 5. Docker Not Working on Clients

**Problem**: Cannot run Docker jobs

**Solution**:
```bash
# Verify Docker is installed
ansible clients -a "docker ps"

# Check Docker driver in Nomad
ansible clients -a "nomad node status -self | grep docker"

# Restart Nomad service
ansible clients -b -m systemd -a "name=nomad state=restarted"
```

### Getting Help

- Check the detailed documentation in each subdirectory
- Review Nomad logs: `journalctl -u nomad -f`
- Consult [HashiCorp Nomad Documentation](https://www.nomadproject.io/docs)
- Open an issue in the project repository

## Documentation

- **[Terraform AWS README](terraform/aws/README.md)** - Detailed Terraform configuration documentation
- **[Ansible README](ansible/README.md)** - Ansible configuration and usage guide
- **[Playbooks README](ansible/PLAYBOOKS-README.md)** - Comprehensive playbook documentation
- **[ACL Bootstrap Guide](ansible/BOOTSTRAP_ACL_EXAMPLE.md)** - Step-by-step ACL setup
- **Role Documentation** - Individual README files in each role directory

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. Test changes in a separate environment
2. Update documentation for any new features
3. Follow existing code style and conventions
4. Add comments for complex logic
5. Update README files as needed

## License

BSD 2-Clause License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2026, Aimee Ukasick

## Resources

### HashiCorp Documentation
- [Nomad Documentation](https://www.nomadproject.io/docs)
- [Nomad Cloud Auto-Join](https://developer.hashicorp.com/nomad/docs/configuration/server_join)
- [Nomad ACL System](https://developer.hashicorp.com/nomad/docs/configuration/acl)
- [Nomad Job Specification](https://developer.hashicorp.com/nomad/docs/job-specification)

### AWS Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)

### Ansible Documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Ansible Galaxy](https://galaxy.ansible.com/)

## Acknowledgments

This project uses:
- HashiCorp Nomad for workload orchestration
- Terraform for infrastructure provisioning
- Ansible for configuration management
- AWS for cloud infrastructure
- Ubuntu 24.04 LTS as the base operating system