# Copyright (c) 2023, 2025, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl/
# STAR ELZ V1 — sprint2
#
# =============================================================================
# IAM SPRINT 1 CARRY-FORWARD REFERENCE — READ ONLY
# =============================================================================
# ██████████████████████████████████████████████████████████████████████████
# ██  DO NOT MODIFY THIS FILE. DO NOT ADD RESOURCES HERE.                 ██
# ██  Sprint 1 IAM resources (compartments, groups, policies, tags)       ██
# ██  exist in the Sprint 1 Terraform state and are NOT re-provisioned     ██
# ██  in Sprint 2. They are referenced only via variables_iam.tf.          ██
# ██████████████████████████████████████████████████████████████████████████
#
# SPRINT 1 RESOURCES (exist in sprint1 ORM stack state):
#   Compartments (10 TF-managed at C1 level):
#     C1_R_ELZ_NW, C1_R_ELZ_SEC, C1_R_ELZ_SOC, C1_R_ELZ_OPS
#     C1_R_ELZ_CSVCS, C1_R_ELZ_DEVT_CSVCS
#     C1_OS_ELZ_NW, C1_SS_ELZ_NW, C1_TS_ELZ_NW, C1_DEVT_ELZ_NW
#
#   Groups (10 TF-managed):
#     UG_ELZ_NW, UG_ELZ_SEC, UG_ELZ_SOC, UG_ELZ_OPS
#     UG_ELZ_CSVCS, UG_DEVT_CSVCS
#     UG_OS_ELZ_NW, UG_SS_ELZ_NW, UG_TS_ELZ_NW, UG_DEVT_ELZ_NW
#
#   Policies (11 policy objects):
#   SIM policies are Sprint 4 scope — not in sprint1 state.
#     UG_ELZ_NW-Policy, UG_ELZ_SEC-Policy, UG_ELZ_SOC-Policy,
#     UG_ELZ_OPS-Policy, UG_ELZ_CSVCS-Policy, OCI-SERVICES-Policy,
#     UG_OS_ELZ_NW-Policy, UG_SS_ELZ_NW-Policy, UG_TS_ELZ_NW-Policy, UG_DEVT_ELZ_NW-Policy
#     UG_DEVT_CSVCS-Policy
#
#   Tag Namespace + Tags (C0 level):
#     C0-star-elz-v1 namespace
#     Tags: Environment, Owner, ManagedBy, CostCenter (is_cost_tracking=true), DataClassification
#     Tag Default: DataClassification = Official-Closed (auto-applied, CIS 3.2)
#     Tag Default: CreatedBy (CIS 3.2)
#
# HOW SPRINT 2 REFERENCES SPRINT 1 COMPARTMENTS:
#   Paste OCIDs from Sprint 1 outputs into ORM Variables (Sprint 2 stack)
#   or into terraform.tfvars:
#
#   terraform output -json > sprint1_outputs.json  (run in sprint1 directory)
#
#   Then set in sprint2 terraform.tfvars:
#     nw_compartment_id   = "ocid1.compartment.oc1..aaa..."  # C1_R_ELZ_NW
#     os_compartment_id   = "ocid1.compartment.oc1..aaa..."  # C1_OS_ELZ_NW
#     ts_compartment_id   = "ocid1.compartment.oc1..aaa..."  # C1_TS_ELZ_NW
#     ss_compartment_id   = "ocid1.compartment.oc1..aaa..."  # C1_SS_ELZ_NW
#     devt_compartment_id = "ocid1.compartment.oc1..aaa..."  # C1_DEVT_ELZ_NW
#     (+ 5 more — see variables_iam.tf)
#
# MODULE VERSIONS (sprint1 state):
#   github.com/oci-landing-zones/terraform-oci-modules-iam//compartments?ref=v0.3.1
#   github.com/oci-landing-zones/terraform-oci-modules-iam//groups?ref=v0.3.1
#   github.com/oci-landing-zones/terraform-oci-modules-iam//policies?ref=v0.3.1
# =============================================================================

# This file intentionally contains no Terraform resources.
# It exists solely as architecture documentation and onboarding reference.
