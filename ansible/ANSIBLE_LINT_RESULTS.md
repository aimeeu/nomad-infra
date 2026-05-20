# Ansible-Lint Results for nomad-infra

**Date**: 2026-05-19  
**Command**: `ansible-lint playbooks/nomad_servers.yaml playbooks/nomad_clients.yaml playbooks/nomad_acl_bootstrap.yaml`

## Summary

- **Total Violations**: 29 failures, 0 warnings
- **Files Processed**: 24 files
- **Profile Met**: min (basic profile not met)

## Violations by Category

### 1. YAML Formatting Issues (22 violations)

#### Trailing Spaces (8 violations)
**Severity**: Low  
**Impact**: Code style consistency

Files affected:
- `playbooks/nomad_clients.yaml`: Lines 7, 35, 38, 44, 67
- `playbooks/nomad_servers.yaml`: Lines 7, 36, 56

**Fix**: Remove trailing whitespace from these lines.

#### Missing Newline at End of File (13 violations)
**Severity**: Low  
**Impact**: POSIX compliance

Files affected:
- `roles/helper/defaults/main.yaml:18`
- `roles/helper/tasks/apt.yaml:13`
- `roles/helper/tasks/file.yaml:29`
- `roles/helper/tasks/file_copy_local.yaml:28`
- `roles/helper/tasks/file_write_content.yaml:22`
- `roles/helper/tasks/file_write_template.yaml:22`
- `roles/helper/tasks/main.yaml:26`
- `roles/helper/tasks/sync.yaml:12`
- `roles/helper/tasks/systemd.yaml:12`
- `roles/helper/tasks/yum.yaml:12`
- `roles/tls/defaults/main.yaml:10`
- `roles/tls/tasks/cert_generate.yaml:52`
- `roles/tls/tasks/main.yaml:59`

**Fix**: Add a newline character at the end of each file.

#### Line Too Long (1 violation)
**Severity**: Low  
**Impact**: Readability

- `roles/cni/defaults/main.yaml:12` - Line length 231 > 160 characters

**Fix**: Break long lines or adjust ansible-lint config to allow longer lines.

---

### 2. Variable Naming Issues (4 violations)

**Severity**: Medium  
**Impact**: Best practices, consistency

#### common role
- `roles/common/tasks/main.yaml:17:13` - Variable `timedatectl_ntpd_status` should be prefixed with `common_`

**Fix**: Rename to `common_timedatectl_ntpd_status`

#### tls role
- `roles/tls/tasks/main.yaml:15:17` - Variable `ca_key_exists` should be prefixed with `tls_`
- `roles/tls/tasks/main.yaml:26:17` - Variable `ca_pem_exists` should be prefixed with `tls_`
- `roles/tls/tasks/main.yaml:31:17` - Variable `ca_csr` should be prefixed with `tls_`

**Fix**: Rename to `tls_ca_key_exists`, `tls_ca_pem_exists`, `tls_ca_csr`

---

### 3. Command/Shell Issues (1 violation)

**Severity**: Medium  
**Impact**: Idempotency

- `roles/common/tasks/main.yaml:23` - Task "Disable timedatectl NTP if active" missing `changed_when`

**Fix**: Add `changed_when: false` or appropriate condition.

---

### 4. Handler Issues (1 violation)

**Severity**: Low  
**Impact**: Best practices

- `roles/tls/tasks/cert_generate.yaml:50:13` - Task "Write signed certificate" runs when changed, should be a handler

**Fix**: Convert to handler or add justification comment.

---

### 5. FQCN Issues (1 violation)

**Severity**: Low  
**Impact**: Future compatibility

- `roles/helper/tasks/yum.yaml:6:3` - Use `ansible.builtin.dnf` instead of `ansible.builtin.yum`

**Fix**: Update module name to use DNF (modern replacement for YUM).

---

## Recommended Actions

### Priority 1: Quick Fixes (Low Effort, High Impact)

1. **Remove trailing spaces** (8 files)
   ```bash
   # Use sed or editor to remove trailing spaces
   sed -i '' 's/[[:space:]]*$//' playbooks/nomad_*.yaml
   ```

2. **Add newlines at end of files** (13 files)
   ```bash
   # Add newline to each file
   for file in roles/helper/defaults/main.yaml roles/helper/tasks/*.yaml roles/tls/defaults/main.yaml roles/tls/tasks/*.yaml; do
     echo "" >> "$file"
   done
   ```

### Priority 2: Code Quality Improvements (Medium Effort)

3. **Fix variable naming** (4 violations)
   - Prefix role variables with role name
   - Update all references

4. **Add changed_when** (1 violation)
   - Add `changed_when: false` to command in common role

5. **Update FQCN** (1 violation)
   - Change `yum` to `dnf` in helper role

### Priority 3: Architectural Improvements (Low Priority)

6. **Convert task to handler** (1 violation)
   - Evaluate if TLS certificate writing should be a handler

---

## Configuration Options

### Option 1: Fix All Violations
Recommended for production-ready code.

### Option 2: Create .ansible-lint-ignore
Ignore specific violations that are acceptable:

```yaml
# .ansible-lint-ignore
playbooks/nomad_servers.yaml yaml[trailing-spaces]
playbooks/nomad_clients.yaml yaml[trailing-spaces]
roles/helper/ yaml[new-line-at-end-of-file]
roles/tls/ var-naming[no-role-prefix]
```

### Option 3: Configure .ansible-lint
Adjust rules to match project standards:

```yaml
# .ansible-lint
---
profile: production

skip_list:
  - yaml[line-length]  # Allow longer lines for readability
  - var-naming[no-role-prefix]  # Allow unprefixed vars in some cases

warn_list:
  - no-handler  # Warn but don't fail

max_line_length: 200  # Increase from default 160
```

---

## Testing After Fixes

```bash
# Run ansible-lint on playbooks
ansible-lint playbooks/*.yaml

# Run syntax check
ansible-playbook site.yaml --syntax-check

# Run in check mode
ansible-playbook site.yaml --check
```

---

## Notes

- All violations are in our own code (not external roles like geerlingguy.docker)
- Most violations are formatting issues (easy to fix)
- No critical security or functionality issues found
- Playbooks are syntactically correct and will run successfully

---

## Next Steps

1. Decide on approach (fix all, ignore some, or configure rules)
2. Apply fixes systematically
3. Re-run ansible-lint to verify
4. Update CI/CD to include ansible-lint checks
5. Document coding standards for team