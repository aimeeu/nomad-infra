# nomad_consul Role

Configures the Consul ACL resources required for Nomad to integrate with Consul
using **Nomad Workload Identities** (the modern approach introduced in Nomad 1.7
and the only supported approach from Nomad 1.10 onward).

## What this role does

1. Creates a Consul ACL policy for Nomad **server** agents (`nomad-server-policy`)
2. Creates a Consul ACL policy for Nomad **client** agents (`nomad-client-policy`)
3. Creates a Consul ACL token for Nomad server agents and saves the SecretID locally
4. Creates a Consul ACL token for Nomad client agents and saves the SecretID locally
5. Creates a Consul JWT **auth method** (`nomad-workloads`) that accepts Nomad workload identity JWTs
6. Creates a Consul **binding rule** that maps service workload identities to a Consul service identity
7. Creates a Consul ACL policy for Nomad task workload identities (`nomad-tasks-policy`)
8. Creates a Consul ACL **role** (`nomad-tasks-default`) for tasks in the Nomad `default` namespace
9. Creates a Consul **binding rule** that maps task workload identities to the `nomad-tasks-default` role

All operations are guarded by a sentinel file and run exactly once per cluster.

## Prerequisites

- Consul cluster deployed and healthy (`consul_servers.yaml` + `consul_clients.yaml`)
- Consul ACL bootstrapped (`consul_acl_bootstrap.yaml`)
- `consul-bootstrap-secret-id.txt` present in `{{ playbook_dir }}`
- The Nomad cluster must be deployed and running (its JWKS endpoint must be
  reachable by Consul servers for the JWT auth method to work)

## Local output files

After a successful run the following files are written to the Ansible control
machine (mode `0600`):

| File | Contents |
|------|----------|
| `nomad-consul-server-token-output.txt` | Full `consul acl token create` output for the Nomad server token |
| `nomad-consul-server-secret-id.txt` | SecretID only — consumed by `consul_nomad_integration.yaml` |
| `nomad-consul-client-token-output.txt` | Full `consul acl token create` output for the Nomad client token |
| `nomad-consul-client-secret-id.txt` | SecretID only — consumed by `consul_nomad_integration.yaml` |

These files contain sensitive credentials. They are git-ignored by default; do
not commit them.

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nomad_consul_http_addr` | `http://127.0.0.1:8500` | Consul HTTP API address |
| `nomad_consul_bin_path` | `/usr/local/bin/consul` | Path to Consul binary |
| `nomad_consul_bootstrap_secret_id_file` | `{{ playbook_dir }}/consul-bootstrap-secret-id.txt` | Local file with Consul bootstrap SecretID |
| `nomad_consul_jwks_url` | First server HTTP address on port 4646 | JWKS URL Consul servers use to validate Nomad JWTs |
| `nomad_consul_auth_method_name` | `nomad-workloads` | Consul JWT auth method name |
| `nomad_consul_tasks_role_name` | `nomad-tasks-default` | Consul ACL role for Nomad tasks in the default namespace |

See [`defaults/main.yaml`](defaults/main.yaml) for the full variable reference.

## Architecture

```
Nomad Workload (task or service)
        │
        │  JWT (signed by Nomad)
        ▼
Consul JWT Auth Method  ◄── JWKS URL ──► Nomad /.well-known/jwks.json
        │
        ├── "nomad_service" in JWT  ──►  Binding Rule  ──►  Service Identity
        │                                                    (register/manage service)
        │
        └── "nomad_service" NOT in JWT ─► Binding Rule  ──►  Role: nomad-tasks-default
                                                              (read services / KV)
```

## References

- [Integrate Consul ACL](https://developer.hashicorp.com/nomad/docs/secure/acl/consul)
- [Configure Consul ACL with Nomad Workload Identities](https://developer.hashicorp.com/nomad/tutorials/integrate-consul/consul-acl)
