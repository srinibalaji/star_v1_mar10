# ORM & GitHub Integration Setup

Each participant does this setup individually on their own OCI account.  
All accounts are tenancy admins — no additional IAM policy is required.

---

## Step 1 — GitHub Personal Access Token (each person)

1. Log into **your own GitHub account**
2. **Settings → Developer settings → Personal access tokens → Tokens (classic)**
3. **Generate new token (classic)**
4. Name: `OCI-ORM-ELZ` / Expiration: 90 days / Scope: check **`repo`**
5. **Copy the token immediately — you cannot view it again**

---

## Step 2 — Create Configuration Source Provider (each person)

OCI Console → **Developer Services → Resource Manager → Configuration Source Providers → Create**

| Field | Value |
|-------|-------|
| Name | `GitHub-ELZ-Repo` |
| Compartment | your assigned compartment (e.g. `C1_R_ELZ_OPS`) |
| Type | GitHub |
| Server URL | `https://github.com/` |
| Personal Access Token | paste your token from Step 1 |

Click **Create**.

> Each person creates their own provider using their own PAT. Do not share tokens.

---

## Step 3 — Create ORM Stack (each person)

OCI Console → **Developer Services → Resource Manager → Stacks → Create Stack**

Select **Source code control system**, then:

| Field | Value |
|-------|-------|
| Source Provider | `GitHub-ELZ-Repo` |
| Repository | your forked repo (e.g. `your-github-username/star`) |
| Branch | your team branch (see table below) |
| Working Directory | your sprint folder (e.g. `sprint1`) |

### Team Branch Reference

| Team | Members | Branch | Working Directory |
|------|---------|--------|-------------------|
| Team 1 | 4 people | `sprint1/iam-compartments-team1` | `sprint1` |
| Team 2 | 4 people | `sprint1/iam-policies-team2` | `sprint1` |
| Team 3 | 4 people | `sprint1/tagging-team3` | `sprint1` |
| Team 4 | 4 people | `sprint1/github-cicd-team4` | `sprint1` |

Click **Next → Create**.

---

## Step 4 — Plan then Apply

1. Stack → **Terraform Actions → Plan** — confirm `X to add, 0 to destroy`
2. Stack → **Terraform Actions → Apply → Automatically Approve**

After apply, use **Run Drift Detection** to confirm live state matches Terraform state.

---

## Notes

- Each person has their own stack — changes to one person's stack do not affect others
- The `deployment_identifier` variable isolates each person's resources (e.g. `AMIT`)
- If your PAT expires, update it in your Configuration Source Provider — the stack itself does not need to be recreated
