# Terraform + Ansible Integration
## STAR ELZ V1 | OCI Isolated Region | Provisioning to Configuration Best Practice

> **Context:** STAR ELZ V1 Sprint 2 uses cloud-init for basic OS bootstrap (ip_forward, firewalld masquerade). This is correct for immutable, stateless configuration at launch. For ongoing OS configuration, application deployment, and post-launch management of compute instances in the isolated region, Ansible is the recommended tool. This document covers how Terraform and Ansible work together cleanly, and what the right split of responsibility is.

---

## 1. The Correct Split: Terraform vs Ansible

This is the most important design decision. Mixing responsibilities leads to brittle automation.

| Responsibility | Tool | Why |
|---|---|---|
| Provision infrastructure | Terraform | Declarative, idempotent, state-tracked, drift detection |
| Configure OS packages and services | Ansible | Procedural config management, agentless, idempotent plays |
| Deploy application binaries | Ansible | Package install, file copy, service enable/start |
| Manage firewall rules post-launch | Ansible | `firewalld` module — changes without instance replacement |
| Bootstrap immutable config at launch | cloud-init | Runs once, bakes config into the instance on first boot |
| Secret retrieval at runtime | Ansible + OCI Vault | Pull from Vault using Instance Principal — no secrets in playbooks |
| Infrastructure drift detection | Terraform plan | `terraform plan` = zero changes means infrastructure is clean |
| Configuration drift detection | Ansible check mode | `ansible-playbook --check` = reports what would change |

**Rule of thumb:**
- If it creates or destroys an OCI resource → Terraform
- If it changes something inside an OCI instance → Ansible
- If it bakes immutable, never-changes config on first boot → cloud-init

---

## 2. Why cloud-init Has Limits

cloud-init runs **once** at first boot. It is the right tool for:
- Setting kernel parameters (`sysctl`) that must be present before any service starts
- Enabling/disabling OS services that are instance-lifetime decisions
- Writing a permanent config file that never changes

It is the wrong tool for:
- Installing packages that need to be updated over time
- Configuring applications whose config changes with each deployment
- Tasks that need to run again after a patch or rebuild
- Anything that needs to be repeatable, auditable, or version-controlled across a fleet

In STAR ELZ V1 Sprint 2, cloud-init does exactly the right things:
```
sysctl net.ipv4.ip_forward=1     → immutable kernel config, set once at boot
firewall-cmd --add-masquerade    → permanent firewalld rule, set once
```
Both of these are instance-lifetime decisions. They never need to change. cloud-init is correct here.

For everything else on the OS after launch — Ansible.

---

## 3. Terraform → Ansible Handoff Pattern

### 3.1 The Pattern

```
terraform apply
    → OCI instance created, private IP assigned, SSH key baked in
    → Terraform outputs: instance_id, private_ip, compartment_id
        ↓
ansible-playbook -i inventory.oci.yml site.yml
    → OCI dynamic inventory discovers instances by compartment/tag
    → Ansible connects via Bastion (ProxyJump)
    → Plays run: package install, config files, service start
```

### 3.2 Triggering Ansible from Terraform

There are two valid approaches depending on your pipeline:

**Option A — Terraform local-exec provisioner (simple, single-operator)**

```hcl
resource "oci_core_instance" "app_server" {
  # ... instance config ...

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i ${self.private_ip}, \
        -u opc \
        --private-key ~/.ssh/id_rsa \
        --ssh-extra-args='-o ProxyJump=opc@${var.bastion_host} -o StrictHostKeyChecking=no' \
        playbooks/site.yml
    EOT
  }
}
```

Limitations: runs on the Terraform executor machine, requires Ansible installed locally, Bastion session must already exist. Acceptable for workshops and single-operator runs. Not recommended for ORM-driven pipelines.

**Option B — Separate pipeline stage (recommended for ORM + CI/CD)**

```
Stage 1: Terraform apply (ORM stack)
    → outputs.json contains instance private IPs

Stage 2: Ansible stage (separate CI/CD job or ORM custom action)
    → reads Terraform outputs
    → builds inventory
    → runs playbooks via Bastion ProxyJump
```

This is the correct pattern for production. ORM runs Terraform. A downstream pipeline trigger (webhook, CI/CD step) kicks off Ansible using the Terraform outputs as input. The two tools remain decoupled.

### 3.3 Passing Terraform Outputs to Ansible

```bash
# After terraform apply
terraform output -json > infra.json

# Build Ansible inventory from Terraform outputs
python3 - <<EOF
import json
data = json.load(open('infra.json'))
print('[sim_fw_hub]')
print(data['hub_fw_private_ip_address']['value'])
print('[sim_fw_os]')
print(data['os_fw_private_ip_address']['value'])
EOF > inventory/hosts.ini
```

Or use the OCI dynamic inventory plugin directly (see Section 4).

---

## 4. OCI Dynamic Inventory

Ansible has a native OCI dynamic inventory plugin that discovers instances automatically by compartment, tag, or display name — no static `hosts.ini` needed.

### 4.1 inventory.oci.yml

```yaml
plugin: oracle.oci.oci
regions:
  - ap-singapore-2   # or your isolated region identifier
compartments:
  - compartment_ocid: "{{ lookup('env', 'NW_COMPARTMENT_ID') }}"
    fetch_hosts_from_subcompartments: true
filters:
  lifecycle-state: RUNNING
  freeform-tags:
    managed-by: terraform          # only TF-managed instances
hostnames:
  - private_ip                     # use private IP (no public IPs in isolated region)
compose:
  ansible_host: private_ip
  instance_id: id
  compartment_id: compartment_id
groups:
  sim_fw: "'sim-firewall' in (freeform_tags.get('resource-type', ''))"
  hub_fw: "'fw_r_elz_nw_hub_sim' in display_name"
```

Tag-based grouping means Ansible automatically knows which hosts are Sim FWs, which are app servers, which are database hosts — no manual inventory management.

### 4.2 Running with Bastion ProxyJump

```ini
# ansible.cfg
[defaults]
inventory = inventory/inventory.oci.yml
remote_user = opc
private_key_file = ~/.ssh/id_rsa

[ssh_connection]
ssh_args = -o ProxyJump="opc@{{ bastion_host }}" -o StrictHostKeyChecking=no
```

Where `bastion_host` is the Bastion endpoint hostname from:
```bash
oci bastion bastion get --bastion-id $BASTION_ID \
  --query 'data."private-endpoint-ip-address"' --raw-output
```

In isolated regions, the Bastion endpoint is a private IP within the isolated network boundary — no internet-facing hostname.

---

## 5. Ansible Roles for STAR ELZ V1

### 5.1 Recommended Role Structure

```
ansible/
├── ansible.cfg
├── inventory/
│   └── inventory.oci.yml
├── playbooks/
│   ├── site.yml              ← master playbook
│   ├── sim_fw.yml            ← Sim FW role apply
│   └── app_server.yml        ← future: Sprint 4 workloads
├── roles/
│   ├── common/               ← applied to all instances
│   │   ├── tasks/main.yml
│   │   └── handlers/main.yml
│   ├── sim_fw/               ← Sim FW specific config
│   │   ├── tasks/main.yml
│   │   └── templates/
│   │       └── firewalld-masquerade.xml.j2
│   └── app_server/           ← Sprint 4+ workload instances
│       └── tasks/main.yml
└── group_vars/
    ├── all.yml               ← vars shared across all hosts
    └── sim_fw.yml            ← Sim FW specific vars
```

### 5.2 common Role — Applied to All Instances

```yaml
# roles/common/tasks/main.yml
- name: Ensure Oracle Linux updates are applied
  ansible.builtin.dnf:
    name: "*"
    state: latest
  when: ansible_os_family == "RedHat"

- name: Ensure auditd is running
  ansible.builtin.service:
    name: auditd
    state: started
    enabled: true

- name: Set SSH hardening options
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    state: present
  loop:
    - { regexp: '^PermitRootLogin', line: 'PermitRootLogin no' }
    - { regexp: '^PasswordAuthentication', line: 'PasswordAuthentication no' }
    - { regexp: '^X11Forwarding', line: 'X11Forwarding no' }
    - { regexp: '^MaxAuthTries', line: 'MaxAuthTries 3' }
  notify: restart sshd

- name: Set kernel hardening parameters
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_set: true
    state: present
    reload: true
  loop:
    - { key: 'net.ipv4.conf.all.rp_filter', value: '1' }
    - { key: 'net.ipv4.conf.default.rp_filter', value: '1' }
    - { key: 'kernel.randomize_va_space', value: '2' }
```

### 5.3 sim_fw Role — Replaces / Validates cloud-init

```yaml
# roles/sim_fw/tasks/main.yml
- name: Confirm ip_forward is set (set by cloud-init, verify here)
  ansible.posix.sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    state: present
    sysctl_set: true
    reload: true

- name: Confirm firewalld masquerade is permanent
  ansible.posix.firewalld:
    masquerade: true
    state: enabled
    permanent: true
    immediate: true
    zone: public

- name: Confirm firewalld SSH is open
  ansible.posix.firewalld:
    service: ssh
    state: enabled
    permanent: true
    immediate: true

- name: Confirm firewalld ICMP is allowed
  ansible.posix.firewalld:
    icmp_block_inversion: false
    state: present
    permanent: true

- name: Verify IP forwarding is active
  ansible.builtin.command: sysctl net.ipv4.ip_forward
  register: ipfwd_check
  changed_when: false

- name: Assert IP forwarding is on
  ansible.builtin.assert:
    that: "'net.ipv4.ip_forward = 1' in ipfwd_check.stdout"
    fail_msg: "IP forwarding is NOT enabled — check cloud-init log"
    success_msg: "IP forwarding confirmed active"
```

This role does two things: ensures cloud-init config is correct (idempotent re-run), and validates state so you have Ansible as a config drift detector alongside Terraform as an infra drift detector.

### 5.4 Pulling Secrets from OCI Vault at Runtime

```yaml
# In a role that needs a database password or service credential
- name: Retrieve DB password from OCI Vault
  ansible.builtin.command: >
    oci secrets secret-bundle get
    --secret-id {{ db_password_secret_ocid }}
    --auth instance_principal
    --query 'data."secret-bundle-content".content'
    --raw-output
  register: db_secret_b64
  no_log: true

- name: Decode secret
  ansible.builtin.set_fact:
    db_password: "{{ db_secret_b64.stdout | b64decode }}"
  no_log: true
```

`no_log: true` prevents the secret from appearing in Ansible output or logs. The instance authenticates to Vault using Instance Principal — no API key, no password needed. This requires the Dynamic Group + IAM policy from the SSH doc Section 4.1.

---

## 6. Replacing cloud-init with Ansible — When to Do It

For STAR ELZ V1 the current cloud-init is correct and should stay. The question of when to move to Ansible is:

| Trigger | Action |
|---|---|
| Config that changes after launch | Move to Ansible — cloud-init only runs once |
| Fleet of 3+ instances with same config | Ansible — easier to manage consistency |
| Config that needs audit trail | Ansible — git-versioned playbooks + Ansible Tower/AWX logs every run |
| Sprint 4+ workload VMs | Start with Ansible from day one — no cloud-init except kernel and firewall |
| Sim FW instances (STAR ELZ V1) | Keep cloud-init for ip_forward and masquerade — add Ansible for OS hardening, patching, validation |

**The practical STAR ELZ V1 pattern:**
```
cloud-init:   ip_forward=1, firewalld masquerade   ← runs once at boot, never changes
Ansible:      OS hardening, patching, SSH config,   ← runs on demand, repeatable
              firewall rule validation, app config
```

---

## 7. Ansible in an OCI Isolated Region — Pipeline Options

### Option A — Jump Host Pattern (Recommended)

A dedicated management instance in the Hub MGMT subnet acts as the Ansible control node:

```
Admin workstation
    → Bastion (PORT_FORWARDING)
        → Ansible control node (hub_mgmt subnet, 10.0.1.x)
            → Target instances via SSH (within VCN)
```

The Ansible control node:
- Has Instance Principal for OCI API access (no API keys)
- Has access to Object Storage bucket containing playbooks
- Runs `ansible-playbook` locally within the VCN — no Bastion needed for spoke instances (DRG provides connectivity)
- Playbooks stored in versioned Object Storage bucket — pulled before each run

```bash
# On the Ansible control node — pull latest playbooks before run
oci os object bulk-download \
  --bucket-name bkt_r_elz_ansible \
  --dest-dir /opt/ansible/playbooks \
  --auth instance_principal

# Run playbook
ansible-playbook -i inventory/inventory.oci.yml playbooks/site.yml
```

### Option B — ORM + Terraform null_resource (Workshop Only)

For the workshop where ORM runs Terraform and you want a simple post-apply config step, use `null_resource` with `local-exec` provisioner to kick off Ansible from the ORM runner. This requires Ansible installed on the ORM worker node. Acceptable for POC — not recommended for production.

### Option C — Ansible Automation Platform (AAP)

For production, Oracle partners with Red Hat Ansible Automation Platform. AAP can be deployed on OCI compute in the isolated region and provides:
- Centralised job scheduling and audit logging
- Role-based access control for who can run which playbooks
- Workflow templates (Terraform stage → Ansible stage → test stage)
- Credential management (wraps OCI Vault)
- Git-integrated playbook versioning

---

## 8. STAR ELZ V1 Next Steps — Sprint 4 Compute

When Sprint 4 deploys actual workload compute instances in spoke compartments, the recommended approach:

**Step 1 — Terraform provisions the instance**
- Instance created in OS/TS/SS spoke compartment
- Tagged with `resource-type`, `environment`, `managed-by`
- cloud-init: minimal — only kernel params and firewalld rules if the instance is a gateway
- For regular app servers: cloud-init does nothing beyond setting hostname

**Step 2 — Ansible dynamic inventory picks it up automatically**
- New instance matches OCI dynamic inventory filter (tag: `managed-by = terraform`, lifecycle: RUNNING)
- Automatically added to the correct Ansible group (by tag or display name pattern)

**Step 3 — Ansible baseline play runs**
- `common` role: OS hardening, sshd config, kernel params, auditd
- `app_server` role: install required packages, write app config, start services
- Secrets pulled from OCI Vault using Instance Principal — no plaintext credentials anywhere

**Step 4 — Ongoing**
- Patch run: weekly Ansible play applies OS patches (dnf update)
- Config validation: daily Ansible check mode confirms no drift from baseline
- Terraform plan: confirms no infra drift
- VSS scan: weekly CVE check, results in Cloud Guard

---

## 9. Validation Checklist (Post-Ansible Run)

After running Ansible against Sim FW instances in Sprint 2/3:

- [ ] `sysctl net.ipv4.ip_forward` returns `1` on all Sim FW instances
- [ ] `firewall-cmd --list-all` shows `masquerade: yes` on all Sim FW instances
- [ ] `sshd_config` has `PermitRootLogin no` and `PasswordAuthentication no`
- [ ] `auditd` is running and enabled
- [ ] No package updates pending (`dnf check-update` returns 0)
- [ ] Ansible check mode (`--check`) returns 0 changed tasks — no drift from baseline
- [ ] VSS scan shows no critical CVEs on all instances

---

## References

- Oracle OCI Dynamic Inventory plugin: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/ansibleSDK.htm
- Terraform provisioner local-exec: https://developer.hashicorp.com/terraform/language/resources/provisioners/local-exec
- Ansible OCI modules collection: https://galaxy.ansible.com/oracle/oci
- Oracle A-Team: Terraform + Ansible pattern on OCI: https://www.ateam-oracle.com/post/infrastructure-as-code-on-oci-terraform-ansible
- Oracle A-Team: Using Instance Principal with Ansible: https://www.ateam-oracle.com/post/ansible-and-oci-instance-principal
- Ansible Automation Platform on OCI: https://www.oracle.com/cloud/red-hat-ansible-automation-platform/
- Red Hat Ansible best practices: https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html
- Terraform null_resource provisioner patterns: https://developer.hashicorp.com/terraform/language/resources/provisioners/null_resource
