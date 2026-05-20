# Nomad ACL Bootstrap Example

This guide demonstrates how to bootstrap the Nomad ACL system using the `nomad_acl_bootstrap.yaml` playbook.

## Prerequisites

1. Nomad cluster deployed and running
2. ACLs enabled in Nomad configuration (`nomad_acl_enabled: true`)
3. Ansible inventory configured

## Step 1: Enable ACLs in Playbook

Edit your server playbook to enable ACLs:

```yaml
# playbooks/nomad_servers.yaml
- role: nomad
  vars:
    nomad_acl_enabled: true
    nomad_server_enabled: true
    nomad_server_bootstrap_expect: 3
```

## Step 2: Deploy Cluster with ACLs Enabled

```bash
cd ansible
ansible-playbook playbooks/nomad_servers.yaml
ansible-playbook playbooks/nomad_clients.yaml
```

## Step 3: Bootstrap ACL System

Run the bootstrap playbook:

```bash
ansible-playbook playbooks/nomad_acl_bootstrap.yaml
```

### Expected Output

```
TASK [Display bootstrap success message] ***************************************
ok: [server-1] => {
    "msg": [
        "==========================================",
        "NOMAD ACL BOOTSTRAP SUCCESSFUL",
        "==========================================",
        "",
        "Secret ID: 12345678-1234-1234-1234-123456789abc",
        "",
        "Token files saved to:",
        "  - /path/to/ansible/nomad_bootstrap_token.txt (full details)",
        "  - /path/to/ansible/nomad_bootstrap_secret_id.txt (token only)",
        "",
        "IMPORTANT: Save these tokens securely!",
        "They provide full administrative access to your Nomad cluster.",
        "",
        "To use the token:",
        "  export NOMAD_TOKEN=12345678-1234-1234-1234-123456789abc",
        "",
        "=========================================="
    ]
}
```

## Step 4: Use the Bootstrap Token

### Option A: Export as Environment Variable

```bash
export NOMAD_TOKEN=$(cat ansible/nomad_bootstrap_secret_id.txt)
nomad status
nomad node status
```

### Option B: Use with Individual Commands

```bash
nomad status -token=$(cat ansible/nomad_bootstrap_secret_id.txt)
```

### Option C: Configure Nomad CLI

Create `~/.nomad` file:

```hcl
address = "http://your-server-ip:4646"
token   = "12345678-1234-1234-1234-123456789abc"
```

## Step 5: Create Additional ACL Tokens

Once bootstrapped, create tokens for different use cases:

### Create a Read-Only Token

```bash
# Create policy file
cat > readonly-policy.hcl <<EOF
namespace "default" {
  policy = "read"
}
EOF

# Create the policy
nomad acl policy apply readonly-policy readonly-policy.hcl

# Create a token with the policy
nomad acl token create -name="readonly-token" -policy=readonly-policy
```

### Create a Developer Token

```bash
# Create policy file
cat > developer-policy.hcl <<EOF
namespace "default" {
  policy = "write"
}
EOF

# Create the policy
nomad acl policy apply developer-policy developer-policy.hcl

# Create a token with the policy
nomad acl token create -name="developer-token" -policy=developer-policy
```

## Token Files

After bootstrap, you'll have two files:

### 1. nomad_bootstrap_token.txt (Full Details)

```
Nomad ACL Bootstrap Token
=========================
Generated: 2024-01-15T10:30:00Z

Accessor ID  = 12345678-1234-1234-1234-123456789abc
Secret ID    = 12345678-1234-1234-1234-123456789abc
Name         = Bootstrap Token
Type         = management
Global       = true
Create Time  = 2024-01-15 10:30:00 +0000 UTC
Expiry Time  = <none>

Quick Reference
===============
Secret ID: 12345678-1234-1234-1234-123456789abc

Usage
=====
Export the token:
  export NOMAD_TOKEN=12345678-1234-1234-1234-123456789abc

Or use with commands:
  nomad status -token=12345678-1234-1234-1234-123456789abc
```

### 2. nomad_bootstrap_secret_id.txt (Token Only)

```
12345678-1234-1234-1234-123456789abc
```

## Troubleshooting

### ACL System Already Bootstrapped

If you run the playbook again, you'll see:

```
TASK [Display already bootstrapped message with token] *************************
ok: [server-1] => {
    "msg": [
        "==========================================",
        "ACL SYSTEM ALREADY BOOTSTRAPPED",
        "==========================================",
        "",
        "The ACL system was previously bootstrapped.",
        "",
        "Existing token found:",
        "  Secret ID: 12345678-1234-1234-1234-123456789abc",
        "",
        "Token files location:",
        "  - /path/to/ansible/nomad_bootstrap_token.txt",
        "  - /path/to/ansible/nomad_bootstrap_secret_id.txt",
        "",
        "=========================================="
    ]
}
```

### Lost Bootstrap Token

If you lose the bootstrap token and the ACL system is already bootstrapped:

1. **Option 1**: Use an existing management token to create a new one
2. **Option 2**: Reset the ACL system (requires cluster restart):
   ```bash
   # Stop all Nomad servers
   ansible servers -m service -a "name=nomad state=stopped" -b
   
   # Remove ACL state
   ansible servers -m file -a "path=/opt/nomad/data/server/raft/raft.db state=absent" -b
   
   # Restart servers
   ansible-playbook playbooks/nomad_servers.yaml
   
   # Bootstrap again
   ansible-playbook playbooks/nomad_acl_bootstrap.yaml
   ```

### ACLs Not Enabled

If ACLs are not enabled in the Nomad configuration:

```
TASK [Handle other bootstrap errors] *******************************************
fatal: [server-1]: FAILED! => {
    "msg": "Failed to bootstrap Nomad ACL system.\n\nError: ACL support disabled\n\nCommon issues:\n- ACLs may not be enabled in Nomad configuration\n- Nomad may not be fully started\n- Network connectivity issues\n\nCheck Nomad logs: sudo journalctl -u nomad -n 50"
}
```

**Solution**: Enable ACLs in your playbook and redeploy:

```yaml
- role: nomad
  vars:
    nomad_acl_enabled: true
```

## Security Best Practices

1. **Secure Token Storage**:
   - Keep token files in a secure location
   - Use a secrets manager (Vault, AWS Secrets Manager, etc.)
   - Never commit tokens to version control

2. **Principle of Least Privilege**:
   - Don't use the bootstrap token for day-to-day operations
   - Create specific tokens with limited permissions
   - Rotate tokens regularly

3. **Token Expiration**:
   - Consider setting TTLs on tokens
   - Implement token rotation policies

4. **Audit Logging**:
   - Enable audit logging in Nomad
   - Monitor token usage
   - Review access patterns regularly

## Next Steps

1. Create ACL policies for different roles
2. Generate tokens for applications and users
3. Configure Nomad CLI with appropriate tokens
4. Set up token rotation procedures
5. Implement monitoring and alerting for ACL events

## References

- [Nomad ACL System Documentation](https://developer.hashicorp.com/nomad/docs/configuration/acl)
- [Nomad ACL Policies](https://developer.hashicorp.com/nomad/docs/other-specifications/acl-policy)
- [Nomad ACL Tokens](https://developer.hashicorp.com/nomad/docs/commands/acl/token)