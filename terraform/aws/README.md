# Terraform AWS Infrastructure for Nomad

This directory contains Terraform configuration files to provision AWS infrastructure for a HashiCorp Nomad cluster.

## Overview

This Terraform configuration creates a complete, production-ready AWS infrastructure including:
- **VPC** with public subnet and internet gateway
- **EC2 instances** for Nomad servers and clients
- **Security groups** with appropriate firewall rules
- **SSH key pair** for secure instance access
- **IAM roles** for cloud auto-join functionality
- **Ansible inventory** file generation for configuration management

The infrastructure is designed to be:
- **Scalable**: Easily adjust cluster size via variables
- **Secure**: Configurable security groups and IAM roles
- **Automated**: Generates SSH keys and Ansible inventory
- **Cost-effective**: Uses t3.medium instances by default
- **Flexible**: Supports multiple regions and configurations

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                              │
│                      (10.0.0.0/16)                          │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Public Subnet (10.0.1.0/24)              │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │    │
│  │  │   Server 1   │  │   Server 2   │  │ Server 3 │ │    │
│  │  │    Nomad     │  │    Nomad     │  │  Nomad   │ │    │
│  │  │  t3.medium   │  │  t3.medium   │  │ t3.medium│ │    │
│  │  │  50GB gp3    │  │  50GB gp3    │  │ 50GB gp3 │ │    │
│  │  └──────────────┘  └──────────────┘  └──────────┘ │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐               │    │
│  │  │   Client 1   │  │   Client 2   │               │    │
│  │  │    Nomad     │  │    Nomad     │               │    │
│  │  │  t3.medium   │  │  t3.medium   │               │    │
│  │  │  50GB gp3    │  │  50GB gp3    │               │    │
│  │  └──────────────┘  └──────────────┘               │    │
│  │                                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Internet Gateway ──────────────────────────────────────►   │
└─────────────────────────────────────────────────────────────┘
```

## File Descriptions

### Core Configuration Files

#### main.tf
**Purpose**: Main Terraform configuration and provider setup

**Contents**:
- Terraform version requirements (>= 1.0)
- Required provider configurations:
  - AWS provider (~> 5.0)
  - Local provider (~> 2.0)
  - Null provider (~> 3.0)
  - TLS provider (~> 4.0)
- AWS provider configuration with default tags
- SSH instructions output

**Key Features**:
- Sets default tags for all AWS resources (Project, Owner, Environment, ManagedBy)
- Configures AWS region from variables
- Outputs formatted SSH commands with PEM key path

**Default Tags Applied**:
```hcl
Project    = var.project_name
Owner      = var.owner
Environment = var.environment
ManagedBy  = "Terraform"
```

---

#### variables.tf
**Purpose**: Input variable definitions with descriptions and defaults

**Variables Defined**:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `ami_owner` | string | `099720109477` | AWS account ID for Canonical (Ubuntu) |
| `ami_name_filter` | string | `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*` | AMI name pattern for Ubuntu 24.04 |
| `ami_architecture` | string | `x86_64` | CPU architecture |
| `aws_region` | string | `us-east-2` | AWS region for deployment |
| `owner` | string | `devops-team` | Owner tag value |
| `environment` | string | `dev` | Environment name (dev/staging/prod) |
| `vpc_cidr` | string | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidr` | string | `10.0.1.0/24` | Public subnet CIDR |
| `allowed_ssh_cidr` | string | `0.0.0.0/0` | CIDR allowed for SSH/UI access ⚠️ |
| `ssh_user` | string | `ubuntu` | SSH username |
| `server_count` | number | `3` | Number of server instances |
| `client_count` | number | `2` | Number of client instances |
| `server_instance_type` | string | `t3.medium` | EC2 type for servers |
| `client_instance_type` | string | `t3.medium` | EC2 type for clients |
| `project_name` | string | `nomad-consul` | Project name prefix |

**Customization**: Override defaults in `terraform.tfvars`

---

#### outputs.tf
**Purpose**: Output values after infrastructure creation

**Outputs Provided**:

| Output | Description |
|--------|-------------|
| `ami_id` | Selected AMI ID |
| `vpc_id` | Created VPC ID |
| `subnet_id` | Public subnet ID |
| `security_group_id` | Security group ID |
| `server_public_ips` | List of server public IPs |
| `server_private_ips` | List of server private IPs |
| `client_public_ips` | List of client public IPs |
| `client_private_ips` | List of client private IPs |
| `nomad_ui_urls` | URLs to access Nomad UI (port 4646) |
| `ssh_commands` | Ready-to-use SSH commands for all instances |
| `ssh_private_key_path` | Path to generated SSH key |
| `ssh_public_key` | Generated SSH public key content |
| `ssh_instructions` | Formatted SSH access instructions |

**Usage Examples**:
```bash
# View all outputs
terraform output

# View specific output
terraform output nomad_ui_urls

# Get output in JSON format
terraform output -json ssh_commands

# Use output in scripts
SERVER_IP=$(terraform output -raw server_public_ips | jq -r '.[0]')
```

---

### Resource Configuration Files

#### network.tf
**Purpose**: VPC, subnet, and security group configuration

**Resources Created**:

1. **VPC** (`aws_vpc.nomad_consul_vpc`):
   - CIDR: 10.0.0.0/16 (65,536 IP addresses)
   - DNS hostnames and support enabled
   - Tagged with project name

2. **Internet Gateway** (`aws_internet_gateway.nomad_consul_igw`):
   - Attached to VPC
   - Enables internet access for public subnet

3. **Route Table** (`aws_default_route_table.nomad_consul_route_table`):
   - Default route to internet gateway (0.0.0.0/0)
   - Public routing configuration

4. **Public Subnet** (`aws_subnet.subnet`):
   - CIDR: 10.0.1.0/24 (256 IP addresses)
   - Auto-assigns public IPs to instances
   - Uses first available availability zone
   - Associated with route table

5. **Security Group** (`aws_security_group.nomad_consul_sg`):
   
   **Ingress Rules**:
   - Port 22 (SSH): From `allowed_ssh_cidr`
   - Port 4646 (Nomad HTTP API/UI): From anywhere (0.0.0.0/0)
   - Port 4647 (Nomad RPC): Internal only
   - Port 4648 (Nomad Serf): Internal only
   - All ports: From instances in same security group (internal traffic)
   
   **Egress Rules**:
   - All traffic to anywhere (0.0.0.0/0)

**Security Considerations**:
- Consider restricting `allowed_ssh_cidr` to your IP or network
- Consider restricting Nomad UI access (port 4646) in production
- Internal cluster communication is restricted to security group members
- Use VPN or bastion host for production environments

---

#### compute.tf
**Purpose**: EC2 instance configuration and inventory generation

**Resources Created**:

1. **Server Instances** (`aws_instance.servers`):
   - Count: Configurable via `server_count` (default: 3)
   - Instance type: t3.medium (2 vCPU, 4 GB RAM)
   - AMI: Ubuntu 24.04 LTS (auto-selected)
   - Root volume: 50GB gp3 SSD
   - Tags: 
     - `Name`: `{project_name}-server-{index}`
     - `Role`: `server` (used for cloud auto-join)
     - `Hostname`: `{project_name}-server-{index}`
   - Uses generated SSH key pair
   - Placed in public subnet
   - Associated with security group

2. **Client Instances** (`aws_instance.clients`):
   - Count: Configurable via `client_count` (default: 2)
   - Instance type: t3.medium (2 vCPU, 4 GB RAM)
   - AMI: Ubuntu 24.04 LTS (auto-selected)
   - Root volume: 50GB gp3 SSD
   - Tags:
     - `Name`: `{project_name}-client-{index}`
     - `Role`: `client` (used for cloud auto-join)
     - `Hostname`: `{project_name}-client-{index}`
   - Uses generated SSH key pair
   - Placed in public subnet
   - Associated with security group

3. **Wait Resource** (`null_resource.wait_for_instances`):
   - Waits 30 seconds after instance creation
   - Ensures instances are ready before inventory generation
   - Triggers on instance ID changes

4. **Ansible Inventory** (`local_file.ansible_inventory`):
   - Generates `../../ansible/inventory.ini`
   - Uses `inventory.tpl` template
   - Contains server and client IPs
   - Includes SSH configuration
   - Automatically updated on infrastructure changes

**Instance Tags**: The `Role` tag is critical for cloud auto-join functionality. Nomad uses this tag to discover cluster members.

**Storage**: gp3 volumes provide better performance and cost efficiency compared to gp2.

---

#### ami.tf
**Purpose**: AMI selection using data source

**Data Source** (`data.aws_ami.chosen_ami`):
- Queries AWS for most recent Ubuntu AMI
- **Filters**:
  - Owner: Canonical (099720109477)
  - Name: Ubuntu 24.04 Noble (HVM, SSD, GP3)
  - Virtualization: HVM
  - State: Available
  - Architecture: x86_64
- **Result**: Automatically selects latest Ubuntu 24.04 LTS AMI
- **Benefits**: Always uses the latest patched version

**Why Ubuntu 24.04**:
- Long-term support (LTS) release
- 5 years of security updates
- Modern kernel and packages
- Excellent cloud support
- Wide community adoption

---

#### keypair.tf
**Purpose**: SSH key pair generation and management

**Resources Created**:

1. **Private Key** (`tls_private_key.ssh_key`):
   - Algorithm: RSA
   - Key size: 4096 bits
   - Generated by Terraform
   - Marked as sensitive

2. **AWS Key Pair** (`aws_key_pair.nomad_consul_key`):
   - Name: `{project_name}-key`
   - Uses generated public key
   - Attached to all EC2 instances
   - Registered in AWS EC2

3. **Private Key File** (`local_sensitive_file.private_key`):
   - Path: `../../ansible/ssh_key.pem`
   - Permissions: 0600 (owner read/write only)
   - Used by Ansible and SSH
   - Marked as sensitive

4. **Public Key File** (`local_file.public_key`):
   - Path: `../../ansible/ssh_key.pub`
   - For reference/backup
   - OpenSSH format

5. **Permission Enforcement** (`null_resource.fix_key_permissions`):
   - Runs `chmod 600` on private key
   - Ensures correct permissions for SSH
   - Triggers on key content changes
   - Platform-independent

**Security Best Practices**:
- Private key is marked sensitive (not shown in output)
- Restrictive file permissions (0600)
- Key is git-ignored by default
- Regenerated on each `terraform apply`
- Store securely and backup

---

#### iam.tf
**Purpose**: IAM roles and policies for cloud auto-join

**Resources Created**:

1. **Instance Profile** (`aws_iam_instance_profile.instance_profile`):
   - Name: `{project_name}-instance-profile`
   - Links IAM role to EC2 instances
   - Provides credentials to instances

2. **IAM Role** (`aws_iam_role.instance_role`):
   - Name: `{project_name}-instance-role`
   - Allows EC2 service to assume role
   - Trust policy for EC2 service

3. **IAM Policy** (`aws_iam_role_policy.auto_discover_cluster`):
   - Name: `{project_name}-auto-discover-cluster`
   - **Permissions**:
     - `ec2:DescribeInstances` - Query EC2 instances
     - `ec2:DescribeTags` - Read instance tags
     - `autoscaling:DescribeAutoScalingGroups` - Query ASG info
   - Allows instances to discover each other via AWS API
   - Minimal permissions (principle of least privilege)

**Purpose**: Enables Nomad cloud auto-join feature without hardcoded IPs.

**How It Works**:
1. Instances assume the IAM role
2. Nomad queries EC2 API for instances with specific tags
3. Servers find other servers using `Role=server` tag
4. Clients find servers using `Role=server` tag
5. No manual IP configuration needed

**Important Note**: The instance profile is created but not currently attached to instances. To enable cloud auto-join, add this to the instance resources in `compute.tf`:

```hcl
resource "aws_instance" "servers" {
  # ... other configuration ...
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
}

resource "aws_instance" "clients" {
  # ... other configuration ...
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
}
```

---

### Template Files

#### inventory.tpl
**Purpose**: Jinja2 template for Ansible inventory generation

**Generated Content**:
- `[servers]` group with server IPs and hostnames
- `[clients]` group with client IPs and hostnames
- SSH configuration (user, key path)
- Host variables (public and private IPs)

**Template Variables**:
- `servers` - List of server instances
- `clients` - List of client instances
- `ssh_user` - SSH username
- `ssh_key_path` - Path to SSH private key

**Output**: `../../ansible/inventory.ini`

**Example Generated Inventory**:
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

---

### Configuration Files

#### terraform.tfvars.example
**Purpose**: Example variable values for customization

**Usage**:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Contains**: Example values for all configurable variables

---

#### terraform.tfvars
**Purpose**: Actual variable values (gitignored)

**Contains**: Your customized values for variables

**Security**: This file is gitignored to prevent committing sensitive data

---

## Usage

### Prerequisites

1. **AWS Credentials**: Configure AWS CLI or set environment variables:
   ```bash
   # Option 1: AWS CLI
   aws configure
   
   # Option 2: Environment variables
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-2"
   
   # Option 3: AWS Profile
   export AWS_PROFILE="your-profile-name"
   ```

2. **Terraform**: Install Terraform >= 1.0
   ```bash
   # Verify installation
   terraform version
   
   # Should show: Terraform v1.x.x or higher
   ```

3. **Permissions**: Ensure your AWS credentials have permissions to create:
   - VPC and networking resources
   - EC2 instances
   - Security groups
   - IAM roles and policies
   - Key pairs

### Deployment Steps

#### 1. Initialize Terraform

```bash
cd terraform/aws
terraform init
```

**What This Does**:
- Downloads required providers (AWS, Local, Null, TLS)
- Initializes backend (local by default)
- Prepares working directory

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...
Terraform has been successfully initialized!
```

---

#### 2. Customize Variables (Optional)

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Example Customizations**:
```hcl
# Change region
aws_region = "us-west-2"

# Scale cluster
server_count = 5
client_count = 3

# Restrict SSH access
allowed_ssh_cidr = "203.0.113.0/24"  # Your IP range

# Change project name
project_name = "my-nomad-cluster"

# Use larger instances
server_instance_type = "t3.large"
client_instance_type = "t3.large"

# Set owner
owner = "john-doe"
environment = "production"
```

---

#### 3. Plan Infrastructure

```bash
terraform plan
```

**What This Does**:
- Validates configuration
- Shows what will be created/changed/destroyed
- Estimates resource count
- No actual changes made

**Review the Plan**:
- 3 server instances
- 2 client instances
- VPC and networking components
- Security groups
- SSH key pair
- IAM roles
- Ansible inventory file

**Expected Resource Count**: ~15-20 resources

---

#### 4. Apply Configuration

```bash
terraform apply
```

**What This Does**:
- Creates all AWS resources
- Generates SSH key pair
- Creates Ansible inventory file
- Displays outputs

**Duration**: ~5 minutes

**Confirmation**: Type `yes` when prompted

**What Gets Created**:
- VPC (10.0.0.0/16)
- Public subnet (10.0.1.0/24)
- Internet gateway
- Route table
- Security group
- 3 server EC2 instances (t3.medium, 50GB)
- 2 client EC2 instances (t3.medium, 50GB)
- IAM role and instance profile
- SSH key pair
- `../../ansible/ssh_key.pem` (private key)
- `../../ansible/ssh_key.pub` (public key)
- `../../ansible/inventory.ini` (Ansible inventory)

---

#### 5. View Outputs

```bash
# View all outputs
terraform output

# View specific outputs
terraform output nomad_ui_urls
terraform output ssh_instructions
terraform output server_public_ips

# Get output in JSON format
terraform output -json ssh_commands | jq

# Save output to file
terraform output ssh_commands > ssh_commands.txt
```

**Key Outputs**:
- Nomad UI URLs for accessing the web interface
- SSH commands for connecting to instances
- Public and private IPs for all instances
- Path to SSH private key

---

#### 6. SSH to Instances

Use the commands from `ssh_instructions` output:

```bash
# SSH to a server
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>

# SSH with verbose output
ssh -v -i ../../ansible/ssh_key.pem ubuntu@<server-ip>

# SSH and run a command
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip> "uname -a"
```

---

### Post-Deployment

After infrastructure is created:

1. **Configure with Ansible**:
   ```bash
   cd ../../ansible
   ansible-galaxy collection install community.crypto ansible.posix
   ansible-galaxy install -r requirements.yaml
   ansible-playbook site.yaml
   ```

2. **Access Nomad UI**:
   ```
   http://<server-ip>:4646
   ```

3. **Verify Cluster**:
   ```bash
   ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>
   nomad server members
   nomad node status
   ```

---

## Customization Examples

### Change Instance Types

```hcl
# terraform.tfvars
server_instance_type = "t3.large"   # 2 vCPU, 8 GB RAM
client_instance_type = "t3.xlarge"  # 4 vCPU, 16 GB RAM
```

**Available Instance Types**:
- `t3.micro` - 2 vCPU, 1 GB RAM (testing only)
- `t3.small` - 2 vCPU, 2 GB RAM (light workloads)
- `t3.medium` - 2 vCPU, 4 GB RAM (default)
- `t3.large` - 2 vCPU, 8 GB RAM (moderate workloads)
- `t3.xlarge` - 4 vCPU, 16 GB RAM (heavy workloads)
- `t3.2xlarge` - 8 vCPU, 32 GB RAM (very heavy workloads)

### Increase Cluster Size

```hcl
# terraform.tfvars
server_count = 5   # Recommended: odd numbers (3, 5, 7)
client_count = 10  # Scale as needed
```

**Server Count Recommendations**:
- **3 servers**: Development/testing
- **5 servers**: Production (recommended)
- **7 servers**: Large production deployments

### Change Region

```hcl
# terraform.tfvars
aws_region = "eu-west-1"  # Ireland
# or
aws_region = "ap-southeast-1"  # Singapore
# or
aws_region = "us-west-2"  # Oregon
```

### Restrict SSH Access

```hcl
# terraform.tfvars
allowed_ssh_cidr = "203.0.113.0/24"  # Your office network
# or
allowed_ssh_cidr = "203.0.113.42/32"  # Single IP
```

**Security Best Practice**: Always restrict SSH access to known IPs.

### Use Different Ubuntu Version

```hcl
# terraform.tfvars
ami_name_filter = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
```

### Customize VPC CIDR

```hcl
# terraform.tfvars
vpc_cidr = "172.16.0.0/16"
subnet_cidr = "172.16.1.0/24"
```

---

## Cost Estimation

### Default Configuration (us-east-2)

| Resource | Quantity | Type | Monthly Cost (approx) |
|----------|----------|------|----------------------|
| Server Instances | 3 | t3.medium | ~$100 |
| Client Instances | 2 | t3.medium | ~$67 |
| EBS Volumes | 5 | 50GB gp3 | ~$20 |
| Data Transfer | - | Varies | ~$10 |
| **Total** | | | **~$197/month** |

**Notes**:
- Costs vary by region
- Data transfer costs depend on usage
- Stopped instances still incur EBS costs
- Use AWS Cost Calculator for accurate estimates

### Cost Optimization Strategies

1. **Use Spot Instances** (up to 90% savings):
   ```hcl
   resource "aws_instance" "clients" {
     # ... other configuration ...
     instance_market_options {
       market_type = "spot"
       spot_options {
         max_price = "0.05"  # Maximum price per hour
       }
     }
   }
   ```

2. **Use Smaller Instances** for dev/test:
   ```hcl
   server_instance_type = "t3.small"
   client_instance_type = "t3.small"
   ```

3. **Reduce Cluster Size**:
   ```hcl
   server_count = 1  # Single server for testing
   client_count = 1  # Single client for testing
   ```

4. **Stop When Not in Use**:
   ```bash
   # Stop instances
   aws ec2 stop-instances --instance-ids $(terraform output -json server_instance_ids | jq -r '.[]')
   
   # Start instances
   aws ec2 start-instances --instance-ids $(terraform output -json server_instance_ids | jq -r '.[]')
   ```

5. **Use Reserved Instances** for production (up to 75% savings)

6. **Destroy When Not Needed**:
   ```bash
   terraform destroy
   ```

---

## Maintenance

### Update Infrastructure

```bash
# Modify variables or configuration
nano terraform.tfvars

# Preview changes
terraform plan

# Apply changes
terraform apply
```

**Terraform will**:
- Show what will change
- Preserve existing resources when possible
- Update only what changed

### Add More Clients

```bash
# Update variable
echo 'client_count = 5' >> terraform.tfvars

# Apply changes
terraform apply

# Configure new clients with Ansible
cd ../../ansible
ansible-playbook nomad_clients.yaml
```

### Upgrade Instance Types

```bash
# Update terraform.tfvars
server_instance_type = "t3.large"

# Apply (will recreate instances)
terraform apply
```

**Warning**: Changing instance types requires instance recreation (downtime).

### Destroy Infrastructure

```bash
terraform destroy
```

**What Gets Deleted**:
- All EC2 instances
- VPC and networking
- Security groups
- IAM roles
- SSH key pairs (AWS only, local files remain)

**Warning**: This is permanent. Backup important data first.

**Data Loss**:
- All Nomad state
- All running jobs
- All data on instances

### State Management

Terraform state is stored locally in `terraform.tfstate`. For team collaboration:

#### Option 1: S3 Backend

```hcl
# main.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "nomad-infra/terraform.tfstate"
    region = "us-east-2"
    
    # Optional: Enable state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Benefits**:
- Shared state across team
- State locking prevents conflicts
- Versioning and backup
- Encryption at rest

#### Option 2: Terraform Cloud

```hcl
# main.tf
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "nomad-infra"
    }
  }
}
```

**Benefits**:
- Remote state management
- Collaboration features
- Run history
- Cost estimation
- Policy as code

---

## Troubleshooting

### Duplicate Key Pair Error

**Issue**: `InvalidKeyPair.Duplicate: The keypair already exists`

**Cause**: An AWS key pair with the same name already exists

**Solutions**:

1. **Delete the existing key pair** (if not in use):
   ```bash
   aws ec2 delete-key-pair --key-name nomad-consul-key
   terraform apply
   ```

2. **Import the existing key pair**:
   ```bash
   terraform import aws_key_pair.nomad_consul_key nomad-consul-key
   ```

3. **Change the project name**:
   ```hcl
   # terraform.tfvars
   project_name = "nomad-consul-v2"
   ```

---

### SSH Permission Denied

**Issue**: `Permission denied (publickey)`

**Solutions**:

```bash
# Fix key permissions
chmod 600 ../../ansible/ssh_key.pem

# Verify key
ls -la ../../ansible/ssh_key.pem  # Should show -rw-------

# Test SSH
ssh -i ../../ansible/ssh_key.pem ubuntu@<ip>

# Use verbose mode for debugging
ssh -v -i ../../ansible/ssh_key.pem ubuntu@<ip>
```

---

### Instances Not Created

**Issue**: `Error launching source instance`

**Possible Causes & Solutions**:

1. **Invalid AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Insufficient permissions**:
   - Check IAM permissions
   - Ensure user can create EC2 instances

3. **Region capacity issues**:
   - Try different availability zone
   - Try different region
   - Try different instance type

4. **Service quotas exceeded**:
   - Check AWS Service Quotas console
   - Request limit increase

---

### AMI Not Found

**Issue**: `No AMI found matching criteria`

**Solutions**:

1. **Verify region supports Ubuntu 24.04**:
   ```bash
   aws ec2 describe-images \
     --owners 099720109477 \
     --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
     --region us-east-2
   ```

2. **Use different AMI filter**:
   ```hcl
   ami_name_filter = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
   ```

3. **Specify AMI ID directly**:
   ```hcl
   # In compute.tf
   ami = "ami-0c55b159cbfafe1f0"  # Replace with valid AMI ID
   ```

---

### VPC Limit Reached

**Issue**: `VpcLimitExceeded`

**Solutions**:

1. **Delete unused VPCs**:
   ```bash
   aws ec2 describe-vpcs
   aws ec2 delete-vpc --vpc-id vpc-xxxxx
   ```

2. **Request limit increase**:
   - AWS Console → Service Quotas
   - Request VPC limit increase

---

### Terraform State Locked

**Issue**: `Error acquiring the state lock`

**Cause**: Another Terraform process is running or crashed

**Solution**:

```bash
# View lock info
terraform force-unlock <lock-id>

# Force unlock (use carefully)
terraform force-unlock -force <lock-id>
```

**Warning**: Only force unlock if you're certain no other process is running.

---

### Insufficient Instance Capacity

**Issue**: `InsufficientInstanceCapacity`

**Solutions**:

1. **Try different availability zone**:
   - Terraform will retry automatically
   - Or specify different AZ

2. **Try different instance type**:
   ```hcl
   server_instance_type = "t3a.medium"  # AMD-based alternative
   ```

3. **Wait and retry**:
   ```bash
   terraform apply
   ```

---

## Security Best Practices

### 1. Restrict SSH Access

```hcl
# terraform.tfvars
allowed_ssh_cidr = "YOUR_IP/32"  # Single IP
# or
allowed_ssh_cidr = "YOUR_NETWORK/24"  # Network range
```

**Never use**: `0.0.0.0/0` in production

### 2. Use Private Subnets

For production, place clients in private subnets:

```hcl
# Add private subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.nomad_consul_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
}

# Use NAT gateway for outbound traffic
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet.id
}
```

### 3. Enable VPC Flow Logs

```hcl
resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.nomad_consul_vpc.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

### 4. Use Secrets Manager

Store sensitive data in AWS Secrets Manager:

```hcl
resource "aws_secretsmanager_secret" "nomad_token" {
  name = "${var.project_name}-nomad-token"
}
```

### 5. Enable CloudTrail

Monitor AWS API calls:

```hcl
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
}
```

### 6. Implement Least Privilege IAM

Review and minimize IAM permissions:
- Only grant necessary permissions
- Use IAM roles instead of access keys
- Enable MFA for console access
- Rotate credentials regularly

### 7. Enable Encryption

```hcl
# Encrypt EBS volumes
resource "aws_instance" "servers" {
  # ... other configuration ...
  root_block_device {
    encrypted = true
    kms_key_id = aws_kms_key.ebs.arn
  }
}
```

### 8. Regular Updates

- Keep AMIs updated
- Apply security patches
- Update Terraform providers
- Review security groups regularly

---

## Integration with Ansible

This Terraform configuration automatically generates an Ansible inventory file.

**Location**: `../../ansible/inventory.ini`

**Format**:
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

**Usage**:
```bash
cd ../../ansible
ansible-playbook site.yaml
```

**Benefits**:
- No manual inventory management
- Always up-to-date with infrastructure
- Includes all necessary connection details
- Ready to use immediately after `terraform apply`

---

## Related Documentation

- [Main Project README](../../README.md)
- [Ansible Configuration](../../ansible/README.md)
- [Ansible Playbooks](../../ansible/PLAYBOOKS-README.md)
- [Nomad Documentation](https://developer.hashicorp.com/nomad/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Contributing

When modifying this configuration:

1. **Test changes** in a separate workspace or account
2. **Update documentation** for any new resources
3. **Document variables** in `variables.tf` with descriptions
4. **Add outputs** for new resources in `outputs.tf`
5. **Update cost estimates** if adding expensive resources
6. **Follow naming conventions** for consistency
7. **Use tags** for all resources
8. **Run `terraform fmt`** before committing
9. **Run `terraform validate`** to check syntax

---

## License

This configuration is part of the nomad-infra project.

BSD 2-Clause License - see [LICENSE](../../LICENSE) file for details.

Copyright (c) 2026, Aimee Ukasick