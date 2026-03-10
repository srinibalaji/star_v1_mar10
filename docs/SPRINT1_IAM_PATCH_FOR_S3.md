# ─────────────────────────────────────────────────────────────
# STAR ELZ V1 — Sprint 1 IAM Patch for Sprint 3
# File: SPRINT1_IAM_PATCH_FOR_S3.md
#
# Apply BEFORE Sprint 3 ORM apply by re-running Sprint 1 ORM.
# 10 statements total: 5 in UG_ELZ_NW-Policy, 4 in UG_ELZ_SEC-Policy, 1 service policy.
# Additive only — zero destroys.
# ─────────────────────────────────────────────────────────────

## When to Apply

Sprint 3 day — FIRST action before any Sprint 3 ORM apply.
Re-run Sprint 1 ORM Plan → Apply. 10 new statements, zero destroys.

## Required Policy Additions

### UG_ELZ_NW-Policy (5 statements)

```hcl
"allow group UG_ELZ_NW to manage bastion-family in compartment C1_R_ELZ_NW"
"allow group UG_ELZ_NW to read instance-agent-plugins in compartment C1_OS_ELZ_NW"
"allow group UG_ELZ_NW to read instance-agent-plugins in compartment C1_TS_ELZ_NW"
"allow group UG_ELZ_NW to read instance-family in compartment C1_OS_ELZ_NW"
"allow group UG_ELZ_NW to read instance-family in compartment C1_TS_ELZ_NW"
```

Why: Bastion sessions targeting spoke Sim FWs need `manage bastion-family`
in the compartment where the Bastion service lives (C1_R_ELZ_NW), plus
`read instance-agent-plugins` and `read instance-family` in the target
instance compartments.

### UG_ELZ_SEC-Policy (4 statements)

```hcl
"allow group UG_ELZ_SEC to manage security-zone in compartment C1_R_ELZ_SEC"
"allow group UG_ELZ_SEC to manage security-zone in compartment C1_R_ELZ_NW"
"allow group UG_ELZ_SEC to manage vss-family in compartment C1_R_ELZ_SEC"
"allow group UG_ELZ_SEC to manage certificate-authority-family in compartment C1_R_ELZ_SEC"
```

Why: Security Zones span SEC + NW compartments. VSS scan recipe lives in SEC,
targets NW instances. Certificate Authority in SEC compartment.

### Service Policy (SCH needs cross-service access)

```hcl
"allow any-user to manage objects in compartment C1_R_ELZ_SEC where all {request.principal.type='serviceconnector'}"
```

Why: Service Connector Hub writes flow logs to Object Storage bucket in SEC compartment.
This uses `any-user` with principal type constraint — standard OCI pattern for SCH.

## Verification After Apply

```bash
# Check statement count increased
oci iam policy list --compartment-id $TENANCY_ID --all \
  --query "data[?name=='UG_ELZ_NW-Policy'].statements | [0] | length(@)"
# Expected: previous count + 5

oci iam policy list --compartment-id $TENANCY_ID --all \
  --query "data[?name=='UG_ELZ_SEC-Policy'].statements | [0] | length(@)"
# Expected: previous count + 4
```

## Sprint 1 ↔ Sprint 3 Resource Matrix

| Sprint 3 Resource | OCI Verb | Compartment | Policy | Status |
|---|---|---|---|---|
| DRG route tables (2) | manage drgs | C1_R_ELZ_NW | UG_ELZ_NW | ✅ |
| VCN ingress RT | manage virtual-network-family | C1_R_ELZ_NW | UG_ELZ_NW | ✅ |
| Hub FW RT (import) | manage virtual-network-family | C1_R_ELZ_NW | UG_ELZ_NW | ✅ |
| DRG attachment mgmt (5) | manage drgs | C1_R_ELZ_NW | UG_ELZ_NW | ✅ |
| NSGs (6) | manage virtual-network-family | C1_R_ELZ_NW + spokes | UG_ELZ_NW + UG_*_ELZ_NW | ✅ |
| Bastion sessions (2) | manage bastion-family | C1_R_ELZ_NW | **Patch** | ⚡ |
| Flow logs (6) | manage log-groups | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Log group | manage log-groups | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Object Storage bucket | manage objects | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Notification topic | manage ons-topics | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Events rule | manage cloudevents-rules | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Monitoring alarm | manage alarms | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Vault + Master Key | manage vaults + keys | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Cloud Guard recipes + target | manage cloud-guard-family | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
| Security Zones (2) | manage security-zone | C1_R_ELZ_SEC + NW | **Patch** | ⚡ |
| VSS recipe + target | manage vss-family | C1_R_ELZ_SEC | **Patch** | ⚡ |
| Certificate Authority | manage certificate-authority-family | C1_R_ELZ_SEC | **Patch** | ⚡ |
| Service Connector Hub | manage serviceconnectors | C1_R_ELZ_SEC | UG_ELZ_SEC | ✅ |
