# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "nomad_consul_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name  = "${var.project_name}-key"
    Owner = var.owner
  }
}

# Save private key locally for Ansible
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/../../ansible/ssh_key.pem"
  file_permission = "0600"
}

# Save public key locally for reference
resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/../../ansible/ssh_key.pub"
}