# Terraform AWS Infrastructure for Nomad/Consul

This directory contains Terraform configuration files to provision AWS infrastructure for a HashiCorp Nomad and Consul cluster.

## Overview

This Terraform configuration creates a complete AWS infrastructure including:
- VPC with public subnet
- EC2 instances for Nomad/Consul servers and clients
- Security groups with appropriate firewall rules
- SSH key pair for instance access
- IAM roles for cloud auto-join
- Ansible inventory file generation

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
│  │  │ Nomad+Consul │  │ Nomad+Consul │  │Nomad+Consul│    │
│  │  │  t3.medium   │  │  t3.medium   │  │ t3.medium│ │    │
│  │  └──────────────┘  └──────────────┘  └──────────┘ │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐               │    │
│  │  │   Client 1   │  │   Client 2   │               │    │
│  │  │    Nomad     │  │    Nomad     │               │    │
│  │  │  t3.medium   │  │  t3.medium   │               │    │
│  │  └──────────────┘  └──────────────┘               │    │
│  │                                                     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  Internet Gateway ──────────────────────────────────────►   │
└─────────────────────────────────────────────────────────────┘
```

## File Descriptions

### Core Configuration Files

#### [`main.tf`](main.tf)
**Purpose**: Main Terraform configuration and provider setup

**Contents**:
- Terraform version requirements (>= 1.0)
- Required provider configurations:
  - AWS provider (~> 5.0)
  - Local provider (~> 2.0)
  - Null provider (~> 3.0)
  - TLS provider (~> 4.0)
- AWS provider configuration with default tags
- SSH instructions output showing how to connect to instances

**Key Features**:
- Sets default tags for all AWS resources (Project, Owner, Environment, ManagedBy)
- Configures AWS region from variables
- Outputs formatted SSH commands with PEM key path

---

#### [`variables.tf`](variables.tf)
**Purpose**: Input variable definitions

**Variables Defined**:

| Variable | Default | Description |
|----------|---------|-------------|
| `ami_owner` | `099720109477` | AWS account ID for Canonical (Ubuntu) |
| `ami_name_filter` | `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*` | AMI name pattern |
| `ami_architecture` | `x86_64` | CPU architecture |
| `aws_region` | `us-east-2` | AWS region for deployment |
| `owner` | `devops-team` | Owner tag value |
| `environment` | `dev` | Environment name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidr` | `10.0.1.0/24` | Public subnet CIDR |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR allowed for SSH/UI access |
| `ssh_user` | `ubuntu` | SSH username |
| `server_count` | `3` | Number of server instances |
| `client_count` | `2` | Number of client instances |
| `server_instance_type` | `t3.medium` | EC2 type for servers |
| `client_instance_type` | `t3.medium` | EC2 type for clients |
| `project_name` | `nomad-consul` | Project name prefix |

**Customization**: Override defaults in `terraform.tfvars`

---

#### [`outputs.tf`](outputs.tf)
**Purpose**: Output values after infrastructure creation

**Outputs Provided**:
- `ami_id`: Selected AMI ID
- `vpc_id`: Created VPC ID
- `subnet_id`: Public subnet ID
- `security_group_id`: Security group ID
- `server_public_ips`: List of server public IPs
- `server_private_ips`: List of server private IPs
- `client_public_ips`: List of client public IPs
- `client_private_ips`: List of client private IPs
- `consul_ui_urls`: URLs to access Consul UI (port 8500)
- `nomad_ui_urls`: URLs to access Nomad UI (port 4646)
- `ssh_commands`: Ready-to-use SSH commands for all instances
- `ssh_private_key_path`: Path to generated SSH key
- `ssh_public_key`: Generated SSH public key content

**Usage**:
```bash
terraform output nomad_ui_urls
terraform output -json ssh_commands
```

---

### Resource Configuration Files

#### [`network.tf`](network.tf)
**Purpose**: VPC, subnet, and security group configuration

**Resources Created**:

1. **VPC** (`aws_vpc.nomad_consul_vpc`):
   - CIDR: 10.0.0.0/16
   - DNS hostnames and support enabled
   - Tagged with project name

2. **Internet Gateway** (`aws_internet_gateway.nomad_consul_igw`):
   - Attached to VPC
   - Enables internet access

3. **Route Table** (`aws_default_route_table.nomad_consul_route_table`):
   - Default route to internet gateway (0.0.0.0/0)
   - Public routing

4. **Public Subnet** (`aws_subnet.subnet`):
   - CIDR: 10.0.1.0/24
   - Auto-assigns public IPs
   - Uses first available AZ

5. **Security Group** (`aws_security_group.nomad_consul_sg`):
   - **Ingress Rules**:
     - Port 22 (SSH): From `allowed_ssh_cidr`
     - Port 8500 (Consul UI/API): From anywhere
     - Port 4646 (Nomad UI/API): From anywhere
     - All ports: From instances in same security group (internal traffic)
   - **Egress Rules**:
     - All traffic to anywhere (0.0.0.0/0)

**Security Note**: Consider restricting `allowed_ssh_cidr` and UI access in production.

---

#### [`compute.tf`](compute.tf)
**Purpose**: EC2 instance configuration

**Resources Created**:

1. **Server Instances** (`aws_instance.servers`):
   - Count: 3 (configurable via `server_count`)
   - Instance type: t3.medium
   - Root volume: 50GB gp3
   - Tags: Role=server, Hostname set
   - Uses generated SSH key pair

2. **Client Instances** (`aws_instance.clients`):
   - Count: 2 (configurable via `client_count`)
   - Instance type: t3.medium
   - Root volume: 50GB gp3
   - Tags: Role=client, Hostname set
   - Uses generated SSH key pair

3. **Wait Resource** (`null_resource.wait_for_instances`):
   - Waits 30 seconds after instance creation
   - Ensures instances are ready before inventory generation

4. **Ansible Inventory** (`local_file.ansible_inventory`):
   - Generates `../../ansible/inventory.ini`
   - Uses `inventory.tpl` template
   - Contains server and client IPs
   - Includes SSH configuration

**Instance Tags**: Used for cloud auto-join (Role=server/client)

---

#### [`ami.tf`](ami.tf)
**Purpose**: AMI selection using data source

**Data Source** (`data.aws_ami.chosen_ami`):
- Queries AWS for most recent Ubuntu AMI
- Filters:
  - Owner: Canonical (099720109477)
  - Name: Ubuntu 24.04 Noble (HVM, SSD, GP3)
  - Virtualization: HVM
  - State: Available
  - Architecture: x86_64

**Result**: Automatically selects latest Ubuntu 24.04 LTS AMI

---

#### [`keypair.tf`](keypair.tf)
**Purpose**: SSH key pair generation and management

**Resources Created**:

1. **Private Key** (`tls_private_key.ssh_key`):
   - Algorithm: RSA
   - Key size: 4096 bits
   - Generated by Terraform

2. **AWS Key Pair** (`aws_key_pair.nomad_consul_key`):
   - Name: `{project_name}-key`
   - Uses generated public key
   - Attached to all EC2 instances

3. **Private Key File** (`local_sensitive_file.private_key`):
   - Path: `../../ansible/ssh_key.pem`
   - Permissions: 0600 (owner read/write only)
   - Used by Ansible and SSH

4. **Public Key File** (`local_file.public_key`):
   - Path: `../../ansible/ssh_key.pub`
   - For reference/backup

5. **Permission Enforcement** (`null_resource.fix_key_permissions`):
   - Runs `chmod 600` on private key
   - Ensures correct permissions for SSH
   - Triggers on key content changes

**Security**: Private key is marked sensitive and has restricted permissions.

---

#### [`iam.tf`](iam.tf)
**Purpose**: IAM roles and policies for cloud auto-join

**Resources Created**:

1. **Instance Profile** (`aws_iam_instance_profile.instance_profile`):
   - Attached to EC2 instances
   - Links to IAM role

2. **IAM Role** (`aws_iam_role.instance_role`):
   - Allows EC2 service to assume role
   - Used for cloud auto-join

3. **IAM Policy** (`aws_iam_role_policy.auto_discover_cluster`):
   - Permissions:
     - `ec2:DescribeInstances`
     - `ec2:DescribeTags`
     - `autoscaling:DescribeAutoScalingGroups`
   - Allows instances to discover each other via AWS API

**Purpose**: Enables Nomad/Consul cloud auto-join feature without hardcoded IPs.

**Note**: Instance profile is created but not currently attached to instances. To enable cloud auto-join, add to `compute.tf`:
```hcl
iam_instance_profile = aws_iam_instance_profile.instance_profile.name
```

---

### Template Files

#### [`inventory.tpl`](inventory.tpl)
**Purpose**: Jinja2 template for Ansible inventory generation

**Generated Content**:
- `[servers]` group with server IPs
- `[clients]` group with client IPs
- SSH configuration (user, key path)
- Host variables (public and private IPs)

**Output**: `../../ansible/inventory.ini`

---

### Configuration Files

#### [`terraform.tfvars.example`](terraform.tfvars.example)
**Purpose**: Example variable values

**Usage**:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

#### [`terraform.tfvars`](terraform.tfvars)
**Purpose**: Actual variable values (gitignored)

**Contains**: Your customized values for variables

---

## Usage

### Prerequisites

1. **AWS Credentials**: Configure AWS CLI or set environment variables:
   ```bash
   export AWS_ACCESS_KEY_ID="your-access-key"
   export AWS_SECRET_ACCESS_KEY="your-secret-key"
   export AWS_DEFAULT_REGION="us-east-2"
   ```

2. **Terraform**: Install Terraform >= 1.0
   ```bash
   terraform version
   ```

### Deployment Steps

#### 1. Initialize Terraform

```bash
cd terraform/aws
terraform init
```

This downloads required providers (AWS, Local, Null, TLS).

#### 2. Customize Variables (Optional)

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Example customizations:
```hcl
aws_region = "us-west-2"
server_count = 5
client_count = 3
allowed_ssh_cidr = "203.0.113.0/24"  # Your IP range
project_name = "my-nomad-cluster"
```

#### 3. Plan Infrastructure

```bash
terraform plan
```

Review the planned changes:
- 3 server instances
- 2 client instances
- VPC and networking
- Security groups
- SSH key pair
- IAM roles

#### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm. This creates:
- All AWS resources (~5 minutes)
- SSH key pair in `../../ansible/ssh_key.pem`
- Ansible inventory in `../../ansible/inventory.ini`

#### 5. View Outputs

```bash
# All outputs
terraform output

# Specific output
terraform output nomad_ui_urls
terraform output ssh_instructions

# JSON format
terraform output -json ssh_commands
```

#### 6. SSH to Instances

Use the commands from `ssh_instructions` output:
```bash
ssh -i ../../ansible/ssh_key.pem ubuntu@<server-ip>
```

### Post-Deployment

After infrastructure is created:

1. **Configure with Ansible**:
   ```bash
   cd ../../ansible
   ansible-playbook site.yaml
   ```

2. **Access Nomad UI**:
   ```
   http://<server-ip>:4646
   ```

3. **Access Consul UI**:
   ```
   http://<server-ip>:8500
   ```

---

## Customization Examples

### Change Instance Types

```hcl
# terraform.tfvars
server_instance_type = "t3.large"
client_instance_type = "t3.xlarge"
```

### Increase Cluster Size

```hcl
# terraform.tfvars
server_count = 5
client_count = 10
```

### Change Region

```hcl
# terraform.tfvars
aws_region = "eu-west-1"
```

### Restrict SSH Access

```hcl
# terraform.tfvars
allowed_ssh_cidr = "203.0.113.0/24"  # Your office IP range
```

### Use Different Ubuntu Version

```hcl
# terraform.tfvars
ami_name_filter = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
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

**Note**: Costs vary by region and usage. Use AWS Cost Calculator for accurate estimates.

### Cost Optimization

1. **Use Spot Instances**: Add to instance configuration:
   ```hcl
   instance_market_options {
     market_type = "spot"
   }
   ```

2. **Smaller Instances**: Use t3.small for dev/test
3. **Fewer Instances**: Reduce server_count and client_count
4. **Stop When Not in Use**: `terraform destroy` when not needed

---

## Maintenance

### Update Infrastructure

```bash
# Modify variables or configuration
nano terraform.tfvars

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### Add More Clients

```bash
# Update variable
echo 'client_count = 5' >> terraform.tfvars

# Apply
terraform apply
```

### Destroy Infrastructure

```bash
terraform destroy
```

**Warning**: This deletes all resources and data. Backup important data first.

### State Management

Terraform state is stored locally in `terraform.tfstate`. For team collaboration, consider:

1. **S3 Backend**:
   ```hcl
   terraform {
     backend "s3" {
       bucket = "my-terraform-state"
       key    = "nomad-infra/terraform.tfstate"
       region = "us-east-2"
     }
   }
   ```

2. **Terraform Cloud**: Use Terraform Cloud for remote state and collaboration

---

## Troubleshooting

### SSH Permission Denied

**Issue**: `Permission denied (publickey)`

**Solution**:
```bash
chmod 600 ../../ansible/ssh_key.pem
ssh -i ../../ansible/ssh_key.pem ubuntu@<ip>
```

### Instances Not Created

**Issue**: `Error launching source instance`

**Solutions**:
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region has capacity for instance type
- Check service quotas in AWS console

### AMI Not Found

**Issue**: `No AMI found matching criteria`

**Solutions**:
- Verify region supports Ubuntu 24.04
- Check `ami_name_filter` in variables
- Try different AMI filter

### VPC Limit Reached

**Issue**: `VpcLimitExceeded`

**Solution**:
- Delete unused VPCs in AWS console
- Request limit increase from AWS support

### Terraform State Locked

**Issue**: `Error acquiring the state lock`

**Solution**:
```bash
# Force unlock (use carefully)
terraform force-unlock <lock-id>
```

---

## Security Best Practices

1. **Restrict SSH Access**:
   ```hcl
   allowed_ssh_cidr = "YOUR_IP/32"
   ```

2. **Use Private Subnets**: For production, place clients in private subnets

3. **Enable VPC Flow Logs**: Monitor network traffic

4. **Rotate SSH Keys**: Regenerate keys periodically

5. **Enable CloudTrail**: Audit AWS API calls

6. **Use Secrets Manager**: Store sensitive data in AWS Secrets Manager

7. **Enable MFA**: Require MFA for AWS console access

8. **Regular Updates**: Keep AMIs and software updated

---

## Integration with Ansible

This Terraform configuration automatically generates an Ansible inventory file:

**Location**: `../../ansible/inventory.ini`

**Format**:
```ini
[servers]
nomad-consul-server-1 ansible_host=54.123.45.67 private_ip=10.0.1.10

[clients]
nomad-consul-client-1 ansible_host=54.123.45.70 private_ip=10.0.1.20

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=ssh_key.pem
```

**Usage**:
```bash
cd ../../ansible
ansible-playbook site.yaml
```

---

## Related Documentation

- [Main Project README](../../README.md)
- [Ansible Configuration](../../ansible/README.md)
- [Ansible Playbooks](../../ansible/playbooks/README.md)
- [Nomad Documentation](https://developer.hashicorp.com/nomad/docs)
- [Consul Documentation](https://developer.hashicorp.com/consul/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Contributing

When modifying this configuration:

1. Test changes in a separate workspace
2. Update this README with any new resources
3. Document new variables in `variables.tf`
4. Add outputs for new resources in `outputs.tf`
5. Update cost estimates if adding expensive resources

---

## License

This configuration is part of the nomad-infra project.