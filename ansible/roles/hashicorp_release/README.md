# HashiCorp Release Role

## Description

A generic role for downloading and installing HashiCorp products (Nomad, Consul, Vault, etc.) from official HashiCorp releases. This role handles version management, binary installation, and upgrade scenarios.

## Features

- Downloads HashiCorp binaries from releases.hashicorp.com
- Supports version checking and upgrades
- Handles architecture detection automatically
- Idempotent - only downloads if version changes
- Installs to standard system paths

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `hashicorp_release_product_name` | string | `""` | Product name (e.g., "nomad", "consul") |
| `hashicorp_release_product_version` | string | `""` | Version to install (e.g., "1.11.1") |
| `hashicorp_release_product_install_dir` | string | `/usr/local/bin` | Installation directory |
| `hashicorp_release_architecture` | string | `amd64` | System architecture |

### Computed Variables

The role automatically computes:
- `hashicorp_release_zip_url`: Download URL based on product, version, and architecture

## Usage

### In Playbooks

This role is used **indirectly** through the nomad role, which includes it to install the Nomad binary.

**Nomad Role** (`roles/nomad/tasks/main.yaml`):
```yaml
- name: Install Nomad binary
  ansible.builtin.include_role:
    name: hashicorp_release
  vars:
    hashicorp_release_product_name: "nomad"
    hashicorp_release_product_version: "{{ nomad_binary_version }}"
```

### Direct Usage Example

```yaml
- hosts: servers
  roles:
    - role: hashicorp_release
      vars:
        hashicorp_release_product_name: "nomad"
        hashicorp_release_product_version: "1.11.1"
```

### Installing Multiple Products

```yaml
- hosts: servers
  tasks:
    - name: Install Nomad
      ansible.builtin.include_role:
        name: hashicorp_release
      vars:
        hashicorp_release_product_name: "nomad"
        hashicorp_release_product_version: "1.11.1"
    
    - name: Install Consul
      ansible.builtin.include_role:
        name: hashicorp_release
      vars:
        hashicorp_release_product_name: "consul"
        hashicorp_release_product_version: "1.22.7"
```

## Supported Products

This role can install any HashiCorp product available at releases.hashicorp.com:
- Nomad
- Consul
- Vault
- Terraform
- Packer
- Waypoint
- Boundary

## Version Management

The role checks if the binary exists and compares versions:
- If binary doesn't exist → downloads and installs
- If version matches → skips download
- If version differs → downloads and upgrades

## Architecture Support

Automatically detects system architecture:
- `amd64` (x86_64)
- `arm64` (aarch64)
- `arm` (armv7l)

## Download Process

1. Checks if binary exists at install path
2. Checks installed version (if exists)
3. Downloads ZIP file to `/tmp/` if needed
4. Extracts binary to install directory
5. Sets executable permissions (0755)
6. Removes temporary ZIP file

## Dependencies

None - this is a standalone utility role

## Example Scenarios

### Upgrade Nomad

```yaml
- hosts: all
  roles:
    - role: hashicorp_release
      vars:
        hashicorp_release_product_name: "nomad"
        hashicorp_release_product_version: "1.12.0"  # New version
```

### Install Specific Architecture

```yaml
- hosts: arm_servers
  roles:
    - role: hashicorp_release
      vars:
        hashicorp_release_product_name: "nomad"
        hashicorp_release_product_version: "1.11.1"
        hashicorp_release_architecture: "arm64"
```

## Notes

- **No Checksum Verification**: This role does not verify checksums (removed for simplicity)
- **Internet Required**: Needs access to releases.hashicorp.com
- **Root Permissions**: Requires sudo/become for installation to `/usr/local/bin`
- **Idempotent**: Safe to run multiple times

## Troubleshooting

### Download Fails
```bash
# Check internet connectivity
curl -I https://releases.hashicorp.com

# Verify URL format
echo "https://releases.hashicorp.com/nomad/1.11.1/nomad_1.11.1_linux_amd64.zip"
```

### Version Not Updating
```bash
# Check current version
nomad version

# Manually remove binary to force reinstall
sudo rm /usr/local/bin/nomad
```

### Permission Denied
```bash
# Ensure role runs with become: true
# Or check install directory permissions
ls -la /usr/local/bin/
```

## Security Considerations

- Downloads over HTTPS
- No checksum verification (consider adding for production)
- Installs with root permissions
- Binary is world-executable (0755)

## Author

Created for nomad-infra project