# Terraform Pipeline Quality Gates — STAR ELZ V1

Toolchain for validating, linting, security-scanning, and integration-testing Terraform code before it reaches OCI Resource Manager in an isolated/sovereign region deployment.

---

## Tool Stack Summary

| Tool | Purpose | When it runs |
|------|---------|-------------|
| `terraform fmt` | Format check | Pre-commit, CI |
| `terraform validate` | Syntax + schema validation | CI |
| `tflint` (OCI ruleset) | OCI-specific lint rules | CI |
| `checkov` | Security policy scan (CIS OCI) | CI |
| `terragrunt` | DRY config, remote state, sprint layering | Local + CI |
| `terratest` | Integration tests against live OCI | Post-apply gate |

---

## 1 — Terraform Native (always first)

Run these before anything else. They are fast, free, and catch 80% of issues.

```bash
# Format — fails if any file needs reformatting
terraform fmt -check -recursive

# Validate — catches undeclared variables, bad references, type errors
# Requires terraform init to have run first
terraform init -backend=false
terraform validate
```

**ORM note:** ORM runs `validate` internally before plan. Catching it locally first avoids a round-trip to the cloud.

---

## 2 — tflint with OCI Ruleset

tflint catches OCI-specific issues that `terraform validate` misses — invalid shapes, unsupported regions, deprecated resource arguments.

### Install

```bash
# macOS
brew install tflint

# Linux / Cloud Shell
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

### Configure — `.tflint.hcl` (add to repo root)

```hcl
plugin "oci" {
  enabled = true
  version = "0.1.0"
  source  = "github.com/terraform-linters/tflint-ruleset-oci"
}

# Enforce naming conventions
rule "terraform_naming_convention" {
  enabled = true
}

# Warn on deprecated syntax
rule "terraform_deprecated_interpolation" {
  enabled = true
}
```

### Run

```bash
tflint --init        # downloads OCI plugin (once)
tflint --recursive   # lint all .tf files
```

### Key OCI rules it enforces
- Invalid `shape` values for compute instances
- Missing required arguments on `oci_core_vcn`, `oci_identity_policy`
- Deprecated resource types replaced in newer OCI provider versions

---

## 3 — Checkov (CIS OCI Benchmark)

Checkov maps directly to CIS OCI Benchmark v1.2 — the same standard referenced in your `cis_level` variable. It will flag misconfigurations before they reach the tenancy.

### Install

```bash
pip install checkov
```

### Run

```bash
# Scan all Terraform in sprint1/
checkov -d sprint1/ --framework terraform

# Run only CIS OCI checks
checkov -d sprint1/ --framework terraform --check CKV_OCI

# Output as JUnit XML for CI integration
checkov -d sprint1/ --framework terraform --output junitxml > checkov-results.xml
```

### Checks relevant to STAR ELZ

| Check ID | Description |
|----------|-------------|
| `CKV_OCI_1` | Security list allows unrestricted ingress (0.0.0.0/0) |
| `CKV_OCI_2` | VCN has no security list attached |
| `CKV_OCI_3` | Object Storage bucket is public |
| `CKV_OCI_13` | Compartment has no tag defaults |
| `CKV_OCI_18` | KMS key rotation not enabled |
| `CKV_OCI_20` | Cloud Guard not enabled |

### Suppress known false positives inline

```hcl
resource "oci_core_security_list" "hub" {
  # checkov:skip=CKV_OCI_1:Hub FW subnet intentionally allows internal VCN CIDR only
  ...
}
```

---

## 4 — Terragrunt (DRY Config + Sprint Layering)

Terragrunt solves two problems for STAR ELZ:
1. Each sprint is a separate Terraform root — but they share variables (tenancy OCID, region, service label)
2. Remote state needs to be stored in OCI Object Storage, not locally

### Directory structure with Terragrunt

```
star/
├── terragrunt.hcl          ← root config: shared inputs + remote state
├── sprint1/
│   ├── terragrunt.hcl      ← inherits root, adds sprint1-specific inputs
│   └── *.tf
├── sprint2/
│   ├── terragrunt.hcl
│   └── *.tf
```

### Root `terragrunt.hcl`

```hcl
# Root terragrunt.hcl — shared across all sprints

remote_state {
  backend = "http"

  config = {
    # OCI Object Storage pre-authenticated request URL
    # Create a PAR in OCI Console → Object Storage → your-tfstate-bucket
    address        = "https://objectstorage.ap-singapore-2.oraclecloud.com/p/<PAR>/n/<namespace>/b/tfstate/o/${path_relative_to_include()}/terraform.tfstate"
    update_method  = "PUT"
    lock_address   = "https://objectstorage.ap-singapore-2.oraclecloud.com/p/<PAR>/n/<namespace>/b/tfstate/o/${path_relative_to_include()}.lock"
    unlock_address = "https://objectstorage.ap-singapore-2.oraclecloud.com/p/<PAR>/n/<namespace>/b/tfstate/o/${path_relative_to_include()}.lock"
  }
}

inputs = {
  tenancy_ocid  = get_env("OCI_TENANCY_OCID")
  region        = "ap-singapore-2"
  service_label = "c1"
  cis_level     = "1"
}
```

### Sprint-level `terragrunt.hcl`

```hcl
# sprint1/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  deployment_identifier = get_env("DEPLOYMENT_ID")  # e.g. AMIT, DYLAN
}
```

### Run

```bash
# Plan sprint1 only
cd sprint1
terragrunt plan

# Apply all sprints in order (respects dependencies)
terragrunt run-all apply --terragrunt-working-dir .
```

**ORM compatibility:** Terragrunt is for local dev and CI. ORM still uses the raw `.tf` files directly — terragrunt is not needed there.

---

## 5 — Terratest (Integration Testing)

Terratest runs real Terraform against OCI, verifies the output, then destroys. Use it on a dedicated test tenancy or with a short-lived `deployment_identifier` (e.g. `TEST`) to keep resources isolated.

### Install

```bash
# Requires Go 1.21+
go mod init star-elz-tests
go get github.com/gruntwork-io/terratest/modules/terraform
go get github.com/gruntwork-io/terratest/modules/oci  # OCI helpers
```

### Example test — Sprint 1 compartment validation

```go
// tests/sprint1_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestSprint1Compartments(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../sprint1",
        Vars: map[string]interface{}{
            "tenancy_ocid":          os.Getenv("OCI_TENANCY_OCID"),
            "region":                "ap-singapore-2",
            "service_label":         "c1",
            "cis_level":             "1",
            "deployment_identifier": "TEST",
            "enable_cloud_guard":    false,
        },
    }

    // Destroy after test completes
    defer terraform.Destroy(t, opts)

    terraform.InitAndApply(t, opts)

    // Assert enclosing compartment was created
    enclosingName := terraform.Output(t, opts, "enclosing_compartment_name")
    assert.Equal(t, "TEST_AD_LZ_Dev", enclosingName)

    // Assert tag namespace was created
    tagNamespace := terraform.Output(t, opts, "tag_namespace_name")
    assert.Equal(t, "c1-elz-v1", tagNamespace)
}
```

### Run

```bash
cd tests
go test -v -timeout 30m -run TestSprint1Compartments
```

---

## 6 — GitHub Actions CI Pipeline

Combines all tools into a single pipeline triggered on PR to `main`.

### `.github/workflows/terraform-ci.yml`

```yaml
name: Terraform CI

on:
  pull_request:
    branches: [main]
    paths:
      - 'sprint1/**'
      - 'sprint2/**'

jobs:
  validate:
    name: Format · Validate · Lint · Scan
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.x

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init (no backend)
        run: terraform init -backend=false
        working-directory: sprint1

      - name: Terraform Validate
        run: terraform validate
        working-directory: sprint1

      - name: Setup tflint
        uses: terraform-linters/setup-tflint@v4

      - name: tflint Init
        run: tflint --init

      - name: tflint Run
        run: tflint --recursive

      - name: Checkov Scan
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: sprint1
          framework: terraform
          check: CKV_OCI
          soft_fail: false   # fail the PR if CIS OCI checks fail
          output_format: cli
```

### Gate summary

```
PR raised
  │
  ├── terraform fmt      → fail if unformatted
  ├── terraform validate → fail if invalid syntax
  ├── tflint             → fail if OCI rule violations
  └── checkov            → fail if CIS OCI policy violations
  │
  ▼
PR approved + merged to main
  │
  └── ORM stack (GitHub source) auto-detects new commit → manual Plan + Apply
```

---

## Isolated Region Considerations

| Concern | Mitigation |
|---------|-----------|
| GitHub Actions cannot reach `ap-singapore-2` directly | Run CI on public GitHub for static checks only (fmt, validate, lint, checkov). Never run `terraform apply` from GitHub Actions against the isolated region. |
| tflint OCI plugin downloads from GitHub | Run `tflint --init` once in a network-connected environment, cache the plugin binary in the repo or an internal artifact store. |
| Checkov policy updates | Pin checkov version (`pip install checkov==3.x.x`) to avoid unexpected rule additions breaking the pipeline. |
| Remote state in OCI Object Storage | Use a Pre-Authenticated Request (PAR) URL with write scope. Rotate PAR every 90 days aligned with PAT rotation. |
| Terratest against isolated tenancy | Use a separate `TEST` deployment identifier. Set a short TTL policy on the test compartment so resources are auto-deleted if `terraform destroy` fails. |

---

## Quick Reference — Run Order

```bash
# 1. Before committing
terraform fmt -recursive
terraform validate

# 2. Before raising PR
tflint --recursive
checkov -d sprint1/ --framework terraform --check CKV_OCI

# 3. Local end-to-end (optional, requires OCI credentials)
cd sprint1
terragrunt plan

# 4. Integration test (test tenancy only)
cd tests
go test -v -timeout 30m
```

---

*Tools version pinning: Terraform ≥ 1.3, tflint ≥ 0.50, checkov ≥ 3.0, terragrunt ≥ 0.55, Go ≥ 1.21*
