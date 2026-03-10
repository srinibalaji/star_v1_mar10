# STAR Enterprise Landing Zone (ELZ) V1

**Private · Sovereign Cloud · OCI Infrastructure-as-Code**

Terraform IaC for the STAR ELZ V1 — a sovereign OCI deployment covering IAM, networking, security, and monitoring in a hub-and-spoke architecture.

**Region:** ap-singapore-2 · **CIS Level:** 1 · **Architecture:** Hub-and-Spoke via DRG · **State of Record:** `sprint_state_ledger.json`

---

## Sprint Schedule

| Sprint | Scope | Dates | Status |
|---|---|---|---|
| Sprint 1 | IAM — Compartments, Groups, Policies, Tags | 24–27 Feb 2026 | ✅ Complete |
| Sprint 2 | Networking — VCN, Subnet, DRG, Routing, Sim FW, Bastion | 2–7 Mar 2026 | ✅ Code complete — rerun **9 Mar AM** |
| Sprint 3 | Security — Forced Inspection, SGW, NSGs, Cloud Guard, Vault, Logging, VSS, Certs | 9–10 Mar 2026 | 🔄 Code complete — apply **9 Mar PM** |
| Sprint 4 | Compute — AD Bridge, DNS, Hello World, E2E Validation | 13–18 Mar 2026 | ⏳ Not started |

**9 March plan:**

1. Sprint 2 rerun (AM) — firewalld cloud-init, PORT_FORWARDING Bastion, SSH keys on instances. TC-07 to TC-19.
2. Sprint 1 IAM patch — 10 new policy statements for Sprint 3. Zero destroys.
3. Sprint 3 apply (PM) — forced inspection, security services, observability. TC-20 to TC-42.

---

## Getting Started — Reading Order

Each sprint README is self-contained. Read your sprint README, then your team file — that's enough to start coding.

### Sprint 1 → Sprint 2 → Sprint 3 path:

| Step | File | What You'll Learn | Time |
|---|---|---|---|
| 1 | This file (`README.md`) | Repo layout, team assignments, sprint schedule | 5 min |
| 2 | `sprint1/README.md` | IAM scope, issue list, file map, TC-01 to TC-06b, handoff checklist | 10 min |
| 3 | `sprint1/locals.tf` | Compartment, group, and policy name constants | 5 min |
| 4 | Your team file: `sprint1/iam_*_teamN.tf` | Your compartments, groups, policy statements | 5 min |
| 5 | `sprint2/README.md` | Networking topology, two-phase apply, TC-07 to TC-19 | 15 min |
| 6 | `sprint2/locals.tf` | Networking name constants, DNS labels, CIDR plan, phase2 gate, firewalld cloud-init | 5 min |
| 7 | Your team file: `sprint2/nw_teamN.tf` | Your VCN, subnet, DRG attachment, route table, security list, Sim FW | 10 min |
| 8 | `sprint3/README.md` | Security topology, forced inspection, issue list, TC-20 to TC-42 | 15 min |
| 9 | `sprint3/locals.tf` | Security resource name constants (NSG, flow log, Vault, Cloud Guard) | 5 min |
| 10 | Your team file: `sprint3/sec_teamN.tf` | Your NSGs, flow logs, Bastion sessions, security services | 10 min |

**Total onboarding: ~85 minutes to full context across all three sprints.**

Supplemental docs (optional):

| File | What It Covers |
|---|---|
| `docs/ARCHITECT_RUNBOOK.md` | Deployment script with CLI commands |
| `docs/HANDOFF.md` | Sprint boundary requirements |
| `docs/SPRINT1_RETRO_QA.md` | Naming convention rationale, architecture QA |
| `docs/SPRINT1_IAM_PATCH_FOR_S3.md` | 10 policy statements to add before Sprint 3 apply |
| `sprint_state_ledger.json` | TC status tracking, resource inventory, architecture gaps |

**Key principle:** All resource names live in `locals.tf` — never hardcode a `display_name` string in your team file.

---

## Team Structure

### Sprint 1 — IAM (complete)

Pre-sprint: Cloud Guard provisioned by Oracle (23 Feb, manual, tenancy-level).

| # | Task | Team | File | Date |
|---|---|---|---|---|
| S1-T1 | NW + SEC compartments | T1 | `iam_cmps_team1.tf` | 24 Feb |
| S1-T2 | SOC + OPS compartments | T2 | `iam_cmps_team2.tf` | 24 Feb |
| S1-T3 | CSVCS + DEVT_CSVCS compartments | T3 | `iam_cmps_team3.tf` | 24 Feb |
| S1-T4 | OS + SS + TS + DEVT spoke compartments | T4 | `iam_cmps_team4.tf` | 24 Feb |
| S1-T4 | MANUAL: C1_SIM_EXT, C1_SIM_CHILD, UG_SIM_EXT, UG_SIM_CHILD | T4 | Console | 24 Feb |
| S1-T1–T4 | 2 IAM groups each | T1–T4 | `iam_groups_teamN.tf` | 25 Feb |
| S1-T1–T4 | Policy statements each | T1–T4 | `iam_policies_teamN.tf` | 25 Feb |
| S1-T3 | ELZ tag namespace + 5 tags | T3 | `mon_tags.tf` | 25 Feb |

10 TF-managed compartments, 10 TF-managed groups, 11 policies, 1 tag namespace + 5 tags. 2 manual compartments + 2 manual groups via Console.

**Gate:** TC-01 through TC-06b all PASS.

### Sprint 2 — Networking (35 resources)

| # | Task | Team | File | Resource |
|---|---|---|---|---|
| S2-T1 | OS: VCN + Subnet + RT + SL + Sim FW | T1 | `nw_team1.tf` | `vcn_os_elz_nw` (10.1.0.0/24) |
| S2-T2 | TS: VCN + Subnet + RT + SL + Sim FW | T2 | `nw_team2.tf` | `vcn_ts_elz_nw` (10.3.0.0/24) |
| S2-T3 | SS+DEVT: VCNs + Subnets + RTs + SLs + Sim FW (SS) | T3 | `nw_team3.tf` | `vcn_ss/devt_elz_nw` |
| S2-T4 | Hub: VCN + Subnets + DRGs + RTs + SLs + Sim FW + Bastion | T4 | `nw_team4.tf` | `vcn_r_elz_nw` (10.0.0.0/16) |

Two-phase apply. Phase 1 gate: TC-07, TC-08. Phase 2 gate: TC-09 through TC-19.

**Key design:** firewalld masquerade (native to OL8, zero outbound deps). PORT_FORWARDING Bastion sessions (no Cloud Agent dependency). SSH public key in instance metadata. No SGW in Sprint 2 — moved to Sprint 3 Hub-only.

### Sprint 3 — Security (59 resources)

| # | Task | Team | File |
|---|---|---|---|
| S3-T1 | Bastion (OS), NSGs (Hub FW + OS), flow logs (2), VSS, SCH | T1 | `sec_team1.tf` |
| S3-T2 | Bastion (TS), NSGs (MGMT + TS + SS + DEVT), flow logs (4), Cert Authority | T2 | `sec_team2.tf` |
| S3-T3 | Log group, bucket, notifications, events, alarm, Vault/KMS, SSH Vault secret, Cloud Guard, Security Zones | T3 | `sec_team3.tf` + `sec_team3_security.tf` |
| S3-T4 | Forced inspection routing, SGW (Hub only), DRG route tables, VCN ingress RT, DRG attachment management | T4 | `sec_team4.tf` |

Single-phase apply. Pre-apply: Sprint 1 IAM patch (10 statements). Gate: TC-20 through TC-42.

**Key design:** Hub-only SGW (spokes route via DRG → Hub FW → SGW — all traffic inspectable). Custom DRG route tables replace full-mesh with forced inspection. PORT_FORWARDING Bastion sessions (same key as Sprint 2). VSS behind `enable_vss` flag.

---

## Repository Structure

```
star/
├── README.md                          ← This file
├── sprint_state_ledger.json           ← Source of truth: resources, TCs, gaps
├── .gitignore
│
├── docs/
│   ├── ARCHITECT_RUNBOOK.md
│   ├── HANDOFF.md
│   ├── SPRINT1_RETRO_QA.md
│   └── SPRINT1_IAM_PATCH_FOR_S3.md   ← 10 IAM statements for Sprint 3
│
├── sprint1/                           ← IAM — compartments, groups, policies, tags
│   ├── locals.tf
│   ├── iam_cmps_team[1-4].tf
│   ├── iam_groups_team[1-4].tf
│   ├── iam_policies_team[1-4].tf
│   ├── mon_tags.tf
│   ├── schema.yaml
│   └── terraform.tfvars.template
│
├── sprint2/                           ← Networking — hub-and-spoke topology
│   ├── locals.tf                      (names, CIDRs, phase2 gate, firewalld cloud-init)
│   ├── nw_main.tf                     (tag merge locals)
│   ├── nw_team[1-4].tf               (VCN/subnet/DRG/RT/SL/SimFW per team)
│   ├── iam_sprint1_ref.tf            (Sprint 1 reference — no resources)
│   ├── data_sources.tf
│   ├── variables_general.tf           (includes ssh_public_key)
│   ├── variables_iam.tf
│   ├── variables_net.tf               (bastion_client_cidr = 10.0.0.0/8)
│   ├── outputs.tf                     (22 OCIDs for Sprint 3 handover)
│   ├── schema.yaml
│   └── terraform.tfvars.template
│
└── sprint3/                           ← Security — forced inspection, observability
    ├── locals.tf                      (security resource names — NSG, flow log, Vault, CG)
    ├── sec_team1.tf                   (T1: Bastion OS, NSGs, flow logs, VSS, SCH)
    ├── sec_team2.tf                   (T2: Bastion TS, NSGs, flow logs, Cert Authority)
    ├── sec_team3.tf                   (T3: log group, bucket, notifications, events, alarm)
    ├── sec_team3_security.tf          (T3: Vault/KMS, SSH Vault secret, Cloud Guard, Security Zones)
    ├── sec_team4.tf                   (T4: DRG routing, SGW Hub-only, forced inspection)
    ├── s2_sprint2_ref.tf              (Sprint 2 IAM/NW cross-reference — no resources)
    ├── data_sources.tf
    ├── variables_general.tf           (includes ssh_public_key, enable_vss)
    ├── variables_iam.tf
    ├── variables_net.tf
    ├── variables_s2_ref.tf            (21 Sprint 2 OCIDs)
    ├── outputs.tf
    ├── schema.yaml
    ├── SPRINT1_IAM_PATCH_FOR_S3.md
    └── terraform.tfvars.template
```

---

## State of Record

`sprint_state_ledger.json` is the single source of truth. It contains all compartments, groups, policies, VCNs, DRGs, subnets, CIDRs, test cases (TC-01 to TC-42), and architecture gaps.

Update `test_cases[].status` to PASS/FAIL as validations complete.

---

## Workflow

**ORM Apply is collective** — one shared stack per sprint, one Apply for all teams.

| Action | Who | How Often |
|---|---|---|
| Write your team file, push PR | Each team member | Daily |
| `terraform fmt` + `terraform validate` | Each team member | Before every PR |
| ORM Plan (preview only) | Any team member | Anytime — read-only |
| ORM Apply | Oracle / Architect only | Once per phase |
| TC validation | All teams | Immediately after Apply |

---

## Deployment

Sprints deploy via OCI Resource Manager (ORM). Each sprint directory is a standalone ORM stack.

- **Sprint 1:** Single Plan → Apply. See `sprint1/README.md`.
- **Sprint 2:** Two Plan → Apply runs (Phase 1 + Phase 2). See `sprint2/README.md`.
- **Sprint 3:** Single Plan → Apply. Pre-apply: Sprint 1 IAM patch. See `sprint3/README.md`.

> **Never commit `terraform.tfvars`** — it contains OCIDs and credentials.
> **Never push directly to `main`** — always use a PR.
> **State of record:** `sprint_state_ledger.json` — keep it updated.
> **All resource display names** are defined in `locals.tf`.

---

**Repository owner:** Oracle and STAR Team
