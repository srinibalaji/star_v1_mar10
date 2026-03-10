# OCI Cloud Guard — CNAPP, CSPM & CWPP Capabilities
## STAR ELZ V1 | OCI Isolated Region | Security Reference

> **Context:** This document is written for the STAR ELZ V1 deployment running on an OCI Isolated Region (air-gapped, sovereign). All capabilities described are available in OCI Isolated Regions, which deliver the same 150+ OCI services as public commercial regions.

---

## 1. What Cloud Guard Is

Oracle Cloud Guard is OCI's native, **free** cloud security service. It functions as the central detection and response engine across a tenancy — aggregating audit events, configuration state, activity logs, and vulnerability data from across OCI services into a single posture management plane.

Cloud Guard has evolved from a CSPM point tool into a full **CNAPP (Cloud-Native Application Protection Platform)** by integrating:

| Capability | CNAPP Pillar | OCI Service |
|---|---|---|
| Resource misconfiguration detection | CSPM | Cloud Guard Configuration Detector |
| User and API activity threat detection | CDR / Threat Detection | Cloud Guard Activity + Threat Detector |
| Host vulnerability and CVE scanning | CWPP | Vulnerability Scanning Service (VSS) |
| Container image vulnerability scanning | CWPP | VSS + OCI Registry (OCIR) |
| CIS Benchmark compliance checks | CSPM | VSS CIS Benchmark Scan |
| Automated remediation | SOAR | Cloud Guard Responder Recipes |
| Preventive enforcement | Security Zones | OCI Security Zones |
| Network traffic visibility | Network Security | VCN Flow Logs + OCI Logging |
| Log aggregation and SIEM forwarding | Observability | Service Connector Hub + OCI Streaming |

---

## 2. CSPM — Cloud Security Posture Management

### 2.1 Configuration Detector Recipes

Cloud Guard's Configuration Detector continuously scans OCI resource configuration state and flags deviations from security best practice. It covers:

- **Identity and Access:** IAM users without MFA, overly permissive policies, API keys not rotated, credentials older than thresholds
- **Network:** Public subnets, security lists with open ingress (0.0.0.0/0), missing VCN flow logs, public load balancers without WAF
- **Storage:** Public Object Storage buckets, unencrypted boot volumes, unencrypted block volumes, buckets without versioning
- **Database:** Databases not encrypted with customer-managed keys, public DB endpoints, missing audit policies
- **Compute:** Instances with public IPs, instances not running latest OS patches (via VSS integration)
- **Logging and Audit:** Tenancy audit logging not enabled, log retention below threshold

Rules are evaluated continuously. New rules added by Oracle to managed recipes are automatically inherited by all cloned (user-managed) recipes — customers always get the latest detection coverage without manual intervention.

### 2.2 CIS OCI Foundations Benchmark Alignment

Cloud Guard Configuration Detector rules are mapped to the **CIS Oracle Cloud Infrastructure Foundations Benchmark**. The current version is v3.0 (February 2025); STAR ELZ V1 targets v1.3 compliance as a baseline.

CIS controls covered by Cloud Guard include:

| CIS Section | Control Example | Cloud Guard Detector |
|---|---|---|
| 1. Identity and Access Management | 1.1 — Avoid use of root/tenancy admin | Activity Detector: root API calls |
| 1. IAM | 1.7 — MFA for all local users | Config Detector: user without MFA |
| 1. IAM | 1.8 — API key rotation | Config Detector: API key age |
| 2. Networking | 2.1 — No unrestricted ingress on SSH/RDP | Config Detector: security list open port |
| 2. Networking | 2.5 — VCN flow logs enabled | Config Detector: missing flow log |
| 3. Logging and Monitoring | 3.1 — Audit log enabled | Config Detector: audit disabled |
| 3. Logging | 3.17 — Notification on identity changes | Config + Events: IAM change events |
| 4. Object Storage | 4.1 — No public buckets | Config Detector: public bucket |
| 5. Database | 5.1 — Encrypt data at rest | Config Detector: unencrypted DB |
| 6. Compute | 6.x — Regular vulnerability scanning | VSS Detector: CVE findings |

> **Important for isolated region:** Oracle's CIS compliance script (CIS Security Software Certified for CIS OCI v3.0) runs against tenancy configuration independently of Cloud Guard and produces CSV/Excel reports. For historical trending in an air-gapped environment, export results to OCI Log Analytics hosted within the isolated region.

### 2.3 Security Zones — Preventive Enforcement

Security Zones enforce policy **before** a non-compliant resource is created, not after. They sit alongside Cloud Guard as the preventive layer — Cloud Guard is detective, Security Zones are preventive.

STAR ELZ V1 deploys two Security Zones in Sprint 3:

| Zone | Compartment | Policies Enforced |
|---|---|---|
| `sz_r_elz_sec` | C1_R_ELZ_SEC | No public buckets, boot volumes must use Vault key, block volumes must use Vault key, databases must use Vault key |
| `sz_r_elz_nw` | C1_R_ELZ_NW | No public subnets, no Internet Gateways, no public IPs on VNICs |

Any API call (Console, CLI, Terraform, SDK) that would violate a zone policy is rejected at the OCI API layer with HTTP 409 Conflict. This means misconfiguration cannot be created regardless of user intent or automation error.

---

## 3. CWPP — Cloud Workload Protection Platform

### 3.1 Vulnerability Scanning Service (VSS)

VSS is OCI's native host and container vulnerability scanner. It is **free for all OCI customers** and operates via the Oracle Cloud Agent plugin installed on each compute instance.

**What VSS scans:**

| Scan Type | What It Checks | Source Feed |
|---|---|---|
| Host vulnerability scan | Installed OS packages vs known CVEs | NVD (National Vulnerability Database) + RedHat OVAL |
| Port scan | Open ports on public IPs | Direct probe |
| CIS Benchmark scan | OS configuration against CIS Benchmark | CIS published benchmarks |
| Container image scan | Vulnerable packages in OCI Registry (OCIR) images | CVE databases |

**CIS Benchmark scan levels available in VSS:**

| Level | Threshold for Critical/High |
|---|---|
| STRICT | >20% of CIS benchmark items fail → Critical |
| MEDIUM | >40% fail → High |
| LIGHTWEIGHT | >80% fail → High |
| NONE | Disabled |

**Scan schedule:** Configurable. Default in STAR ELZ V1 is weekly (Sunday). Daily is supported.

**VSS → Cloud Guard integration:** VSS findings are automatically forwarded to Cloud Guard as problems. The Cloud Guard Configuration Detector includes VSS-specific rules:
- Host has critical/high CVEs
- Host has open unexpected ports
- Container image in OCIR has vulnerabilities
- CIS Benchmark compliance failure

Cloud Guard can then trigger Responder Recipes to alert or auto-remediate based on VSS findings.

### 3.2 Cloud Guard Threat Detector — MITRE ATT&CK Aligned

The Threat Detector (separate from Configuration and Activity detectors) continuously profiles resource behaviour and detects anomalies. It is aligned to the **MITRE ATT&CK framework**, tracking techniques including:

- Impossible Travel (user authenticates from two geographically distant IPs within a short time window)
- Password Spraying (repeated authentication failures across accounts)
- Credential exfiltration patterns
- Unusual API call sequences indicative of lateral movement
- Rogue user behaviour scoring (composite risk score across multiple detectors)

Sightings (individual anomalous events) are correlated and scored to produce Cloud Guard Problems with full attack progression evidence. This functions as cloud-native **CDR (Cloud Detection and Response)**.

### 3.3 Cloud Guard Instance Security

Cloud Guard Instance Security (GA) extends CWPP coverage to compute instance runtime, adding:
- OS-level configuration drift detection
- Runtime security configuration monitoring
- Integration with VSS findings for unified instance risk view

### 3.4 Container Security Configuration

Cloud Guard now includes Container Security Configuration for OKE (Container Engine for Kubernetes) environments, covering:
- Container runtime configuration checks
- Kubernetes security policy compliance
- Container image vulnerability surfacing from OCIR scans

---

## 4. SBOM and Software Supply Chain

OCI does not currently publish a native SBOM (Software Bill of Materials) generation service as a standalone product within Cloud Guard or VSS. What is available:

| Capability | How |
|---|---|
| Package inventory per host | VSS agent enumerates all installed packages and versions per compute instance — effectively a runtime package manifest |
| Container image layer analysis | VSS container scanner identifies vulnerable packages within OCIR image layers |
| CVE-to-package mapping | VSS links each CVE finding to the specific package name and version |
| Patch guidance | Each VSS finding links to the NVD entry with remediation guidance |

For formal SBOM output (SPDX or CycloneDX format), customers should integrate third-party SBOM tooling (e.g. Syft, Grype) at the CI/CD pipeline stage. Within an isolated region this tooling runs on-premises without any external dependency.

---

## 5. Activity Detection and Shadow IT / Shadow Data

### 5.1 Activity Detector

Cloud Guard's Activity Detector monitors OCI Audit events (all API calls in the tenancy) for suspicious patterns:

- IAM users created or deleted outside of approved change windows
- Credentials (API keys, auth tokens, SMTP passwords) created unexpectedly
- Policy statements modified or deleted
- DRG, VCN, route table, or security list changes (directly relevant to STAR ELZ V1 network)
- Bucket access policy changes
- Instance launches in unexpected compartments or regions

### 5.2 Shadow IT Detection

Within an OCI isolated region, shadow IT refers to resources created outside of the approved Terraform-managed compartment structure. Cloud Guard detects:

- Resources created in compartments not covered by Security Zones
- Resources with unexpected tags (missing `managed-by = terraform` freeform tag used in STAR ELZ V1)
- Compute instances launched without SSH key restrictions
- Networking resources created directly via Console bypassing ORM pipeline

Cloud Guard targets can be scoped to the full tenancy root compartment so no resource escapes detection, including resources created manually by console users.

### 5.3 Data Security — OCI Data Safe Integration

For database workloads, Cloud Guard integrates with **OCI Data Safe**, which provides:
- Sensitive data discovery (shadow data) in Oracle Databases
- Data masking
- User activity auditing at the database layer
- Security assessment against CIS Database benchmark

This is relevant for STAR ELZ V1 future sprints when Oracle Database workloads are deployed in spoke compartments.

---

## 6. Network Security Visibility — VCN Flow Logs

VCN Flow Logs capture per-packet metadata for all traffic traversing OCI subnet boundaries. In STAR ELZ V1 Sprint 3, six flow logs are enabled:

| Flow Log | Subnet | What It Proves |
|---|---|---|
| `fl_r_elz_nw_fw` | Hub FW subnet | Spoke-to-spoke traffic transiting the Hub FW (forced inspection proof) |
| `fl_r_elz_nw_mgmt` | Hub MGMT subnet | Bastion session traffic |
| `fl_os_elz_nw_app` | OS app subnet | Workload ingress/egress |
| `fl_ts_elz_nw_app` | TS app subnet | Workload ingress/egress |
| `fl_ss_elz_nw_app` | SS app subnet | Workload ingress/egress |
| `fl_devt_elz_nw_app` | DEVT app subnet | Dev/test ingress/egress |

**What flow log fields capture:** source IP, destination IP, source port, destination port, protocol, action (ACCEPT/REJECT), bytes transferred, packets, start and end time.

**What they prove for CNAPP:** The Hub FW flow log is the forensic proof that forced inspection is working — spoke-to-spoke traffic (e.g. OS→TS) must appear in the Hub FW subnet flow log after Sprint 3 T4 apply. If it does not, routing is broken.

**Threat Intelligence Enrichment:** Via OCI Logging Analytics, VCN Flow Logs can be enriched with geo-location data and threat intelligence feeds to automatically flag known-malicious IP addresses in traffic.

---

## 7. Log Monitoring and Observability

### 7.1 Log Sources in STAR ELZ V1

| Log Type | Source | Retention | Purpose |
|---|---|---|---|
| OCI Audit Logs | All API calls in tenancy | 90 days (OCI managed) | IAM, API, and resource change tracking |
| VCN Flow Logs | All 6 subnets | 30 days (OCI Logging) | Network forensics, forced inspection proof |
| Service Connector Hub | Flow logs → `bkt_r_elz_sec_logs` | Configurable (Object Storage) | Long-term retention beyond 30-day Logging window |
| Cloud Guard Problems | Cloud Guard service | 180 days | Security problem history |

### 7.2 Service Connector Hub (SCH)

SCH (`sch_r_elz_sec_flow_logs`) in STAR ELZ V1 continuously moves flow log data from OCI Logging into the `bkt_r_elz_sec_logs` Object Storage bucket. This:
- Extends retention beyond the 30-day Logging service window
- Creates an immutable audit trail in versioned Object Storage
- Provides the source data for SIEM ingestion (see Section 8)

### 7.3 Events and Alarms

STAR ELZ V1 Sprint 3 deploys:

| Resource | What It Monitors |
|---|---|
| `ev_r_elz_sec_nw_changes` | DRG route table, DRG attachment, VCN route table, and security list changes |
| `al_r_elz_sec_drg_change` | DRG packet drop rate alarm — fires when spoke-to-spoke routing breaks |
| `nt_r_elz_sec_alerts` | ONS topic — SOC team subscribes via email, webhook, or PagerDuty |

---

## 8. OCI Logging Analytics — Native SIEM Replacement

### 8.1 What Logging Analytics Is

OCI Logging Analytics is a fully managed log intelligence service built into OCI. For organisations in the isolated region that do not want to operate a separate Splunk or QRadar installation, Logging Analytics is the complete native alternative. Oracle explicitly designed and markets it as a SIEM replacement for customers who want everything inside OCI without a third-party dependency.

The Security Fundamentals Dashboards proactively aggregate and analyze OCI logs related to security events by leveraging the advanced capabilities of OCI Logging Analytics, coupled with near real-time monitoring and alerting, allowing security operations teams to detect security risks faster, focus on key information, and take appropriate actions to mitigate risks. The dashboards are designed for customers navigating the cloud security landscape without a dedicated SIEM system.

This means: **no Splunk, no QRadar, no external SIEM licence, no data leaving the isolated region boundary.**

### 8.2 Out-of-Box Security Fundamentals Dashboards

The dashboards query data from OCI native Audit and network-related logs — VCN Flow Logs, Load Balancer Logs, WAF Logs, Network Firewall Logs — for continuous Identity and Network security events monitoring. They meet the Maturity Acceleration Program-Foundation (MAP-F) capabilities related to Logging Monitoring and Alerting and provide visibility into key security metrics.

Pre-built dashboard coverage:

| Dashboard | What It Monitors |
|---|---|
| Identity Security | Authentication patterns, privilege escalation, permission changes, inactive users, API key usage |
| Network Security | VCN Flow Log analysis, traffic spikes, anomalous east-west flows, ingress from unexpected sources |
| Threat IPs | Detected known-malicious IPs in VCN Flow Logs via Oracle Threat Intelligence enrichment |
| Audit Events | Who did what, when, and where — all OCI API calls across tenancy |
| Cloud Guard Problems | Security findings surfaced directly in the analytics layer |

### 8.3 Oracle Threat Intelligence — Built In

Logging Analytics is integrated with Oracle Threat Intelligence to automatically receive the threat feed as logs are ingested. The feature is available for all log sources in regions where both Logging Analytics and Oracle Threat Intelligence services are enabled.

VCN Flow Logs and Audit Logs are automatically enriched with:
- Geo-location per IP address
- Oracle threat intelligence feed — known malicious IPs, command-and-control infrastructure, botnet indicators
- Threat IP widget surfaces any match in real time

For the isolated region: threat intelligence feed data is delivered and cached within the region boundary. No per-lookup external call is made at query time.

### 8.4 Long-Term Retention and Historical Analysis

OCI Audit Logs in the native logging service are only searchable for up to 14 days at a time, making it difficult to conduct comprehensive historical analysis. OCI Logging Analytics' REST API log collection method can ingest historical audit logs spanning back a full year.

Logging Analytics provides:
- Configurable retention (30 days to 12 months+, billed per GB)
- Full-text search across all ingested log sources
- Custom queries and saved searches
- Scheduled reports for compliance evidence
- Integration with the Security Fundamentals Dashboards for historical forensics

Combined with the SCH → Object Storage path in STAR ELZ V1, this gives two retention tiers:
- **Hot tier:** Logging Analytics — indexed, queryable, dashboarded (up to 12 months)
- **Cold tier:** Object Storage (`bkt_r_elz_sec_logs`) — immutable, versioned, archived (indefinite)

### 8.5 Custom Log Sources — Third-Party and On-Premises Ingestion

Logging Analytics supports over 140 out-of-box log sources including Linux syslog, Oracle DB audit logs, Apache, Nginx, and Windows Event Logs. For custom sources:

- **Unified Monitoring Agent** (Fluentd-based) on OCI compute instances forwards any application log
- **REST API ingestion** for custom log formats and on-premises forwarding
- **OCI Streaming (Kafka-compatible)** as an ingestion source — any system that can write to a Kafka topic can feed Logging Analytics

This means Logging Analytics can ingest and correlate:
- OCI-native: Audit, VCN Flow, Cloud Guard, VSS, Events
- Customer application logs from workloads on OCI compute
- On-premises system logs forwarded via Unified Monitoring Agent
- Third-party security appliance logs forwarded via syslog → Unified Monitoring Agent

---

## 9. Autonomous Data Warehouse + Data Lake — Security Analytics Platform

### 9.1 Why ADW as a Security Data Lake

For organisations that need richer analytics than Logging Analytics provides — custom ML models, cross-dataset correlation, long-running SQL analytics, regulatory reporting — Oracle Autonomous Data Warehouse (ADW) running inside the isolated region serves as the security data lake. It is fully managed, self-tuning, and requires no DBA operations.

Oracle Autonomous Data Warehouse is a self-driving, self-securing, self-repairing database service optimised for data warehousing workloads. You do not need to configure or manage any hardware or install any software. OCI handles creating the database, as well as backing up, patching, upgrading, and tuning it.

Running ADW as your security analytics lake inside the isolated region means:
- All security telemetry stays within the sovereign boundary
- No SIEM licence cost — SQL queries replace proprietary SIEM query languages
- Oracle Analytics Cloud (OAC) connects directly for dashboard and reporting
- Oracle Machine Learning (OML) built into ADW for anomaly detection models
- Full SQL access for custom correlation logic that goes beyond what Logging Analytics dashboards offer

### 9.2 Autonomous AI Lakehouse — Multicloud Data Pull

Oracle Autonomous AI Lakehouse combines Oracle Autonomous AI Database with the popular Apache Iceberg standard to avoid functionality tradeoffs, break down analytic silos, and accelerate how teams build AI and analytics solutions. It is available on OCI, AWS, Azure, Google Cloud, and Exadata Cloud@Customer.

For STAR environments where workloads span OCI Isolated Region and other approved cloud environments, the Autonomous AI Lakehouse provides the data integration layer:

Autonomous Database can seamlessly connect to data lakes across various cloud environments, including AWS, Azure, Google Cloud, and Oracle OCI Object Storage. With this multi-cloud support, you gain the flexibility to deploy and scale your data lake across different cloud platforms while maintaining a unified and secure environment.

What this means in practice for security analytics:

| Source | What Is Pulled | How |
|---|---|---|
| OCI Isolated Region | Audit logs, VCN Flow Logs, Cloud Guard findings, VSS results | SCH → Object Storage → ADW external table or direct load |
| AWS (if connected via approved path) | CloudTrail, VPC Flow Logs, GuardDuty findings | AWS S3 → ADW via ARN credential, queried as external table |
| Azure (if connected) | Azure Activity Logs, NSG Flow Logs, Defender alerts | Azure Data Lake Gen2 → ADW via Azure Service Principal |
| Google Cloud (if connected) | Cloud Audit Logs, VPC Flow Logs | GCS → ADW via Google Service Account |
| On-premises | Syslog, SNMP, endpoint agent logs | OCI Data Integration → ADW |

All of this runs SQL analytics against the unified dataset inside ADW. No proprietary SIEM query language. No vendor-specific correlation rules. Standard SQL plus Oracle ML.

> **Isolated region constraint:** Direct internet-routed cloud-to-cloud connectivity is not available in an air-gapped isolated region. Ingestion from AWS/Azure/GCP requires an approved private interconnect path between the isolated region and the external environment (FastConnect equivalent). The data pull architecture is valid; the network path must be provisioned and security-cleared separately.

### 9.3 OCI Data Integration — ETL into the Security Lake

OCI Data Integration is a fully-managed, serverless, cloud-native service that extracts, loads, transforms, cleanses, and reshapes data from various data sources into target OCI services such as Autonomous Data Warehouse and OCI Object Storage. It orchestrates dependencies within data processing flows along with other OCI services, such as OCI Artificial Intelligence and Oracle Machine Learning for data enrichment or further classification, and Data Safe for data security and compliance.

For the security analytics use case this means:
- Cloud Guard findings → transformed and loaded into ADW security events table
- VSS scan results → loaded into ADW vulnerability inventory table
- VCN Flow Logs (from SCH → Object Storage) → external tables in ADW
- Custom log data → ingested via REST API task in OCI Data Integration

### 9.4 Oracle Analytics Cloud — Dashboards on the Security Lake

Oracle Analytics Cloud (OAC) connects directly to ADW and provides:
- Drag-and-drop dashboard creation on top of the ADW security data lake
- No additional data movement — OAC queries ADW in place
- Pre-built security analytics content available from Oracle's analytics library
- Role-based access — SOC analysts see dashboards; engineers see raw tables; executives see summary KPIs

### 9.5 The Complete Native SIEM-Replacement Stack

The following architecture replaces an external SIEM entirely, runs 100% within the OCI Isolated Region boundary, and requires no third-party licence:

```
LOG SOURCES (all internal to isolated region)
  OCI Audit Logs
  VCN Flow Logs (6 subnets)
  Cloud Guard Problems + Sightings
  VSS Scan Results
  Custom application logs (via Unified Monitoring Agent)
        ↓
OCI LOGGING SERVICE
  Hot log store — 30-day searchable window
        ↓ (Service Connector Hub)
DUAL PATH:

PATH A — LOGGING ANALYTICS (near real-time SOC)
  Indexed, searchable, dashboarded
  Security Fundamentals Dashboards (pre-built)
  Oracle Threat Intelligence enrichment
  Geo-location enrichment
  Custom saved searches + alerts
  Retention: up to 12 months queryable
        ↓ (alerts → ONS topic)
  SOC TEAM NOTIFICATION (email, webhook, PagerDuty)

PATH B — OBJECT STORAGE + ADW (analytics + compliance + ML)
  bkt_r_elz_sec_logs (cold archive, immutable, versioned)
        ↓ (external table or direct load)
  AUTONOMOUS DATA WAREHOUSE (security data lake)
  SQL analytics + Oracle ML anomaly models
  Cross-dataset correlation (OCI + third-party if interconnected)
        ↓
  ORACLE ANALYTICS CLOUD
  Custom dashboards + regulatory compliance reports
  Executive KPI summaries
```

**Cost model:** OCI Logging is free. Cloud Guard is free. Service Connector Hub is free for standard connectors. Object Storage is billed per GB. Logging Analytics is billed per GB ingested and retained. ADW is billed per OCPU-hour and storage. OAC is billed per user or OCPU. For a typical landing zone with moderate log volume, the full native stack is significantly cheaper than a Splunk or QRadar licence.

---

## 10. SIEM Integration — Splunk and Others (If Required)

### 8.1 Architecture

In an OCI Isolated Region, SIEM integration uses an **OCI-internal streaming path** — no data leaves the air-gapped environment. The reference architecture:

```
OCI Logging (Audit + VCN Flow Logs)
        ↓
Service Connector Hub
        ↓
OCI Streaming (partitioned stream)
        ↓
Splunk Heavy Forwarder (OCI VM, private subnet)
        ↓
Splunk Enterprise (on-premises or isolated region hosted)
```

Cloud Guard findings follow a parallel path:
```
Cloud Guard Problem detected
        ↓
OCI Events (problem threshold / problem detected)
        ↓
OCI Functions (normalise to syslog or HTTP format)
        ↓
OCI Streaming or direct HTTP to Splunk HEC
        ↓
Splunk Enterprise
```

### 8.2 What Gets Forwarded to Splunk

| Data Stream | Splunk Index | Dashboard |
|---|---|---|
| OCI Audit Logs | `oci` | IAM, API activity, identity events |
| VCN Flow Logs | `oci_vcn_summary` | Network traffic, threat IP detection |
| Cloud Guard findings | `oci` or custom | Security problems, risk score history |
| OCI Events | `oci` | Resource change events |

The **Splunk App for OCI** (available on Splunkbase) provides pre-built dashboards for all of the above. In an isolated region, the Splunk Heavy Forwarder is deployed as a compute instance in a private subnet (no public IP), connecting to the Splunk Enterprise instance within the same air-gapped environment. No data traverses to Splunk Cloud.

### 8.3 Other SIEM Integrations

The same OCI Streaming backbone supports:
- **IBM QRadar** — via OCI Streaming consumer or syslog forwarding from Functions
- **Microsoft Sentinel** — via OCI Logging connector (if Sentinel is running within the isolated region)
- **Custom SOC platforms** — via OCI Streaming API (Kafka-compatible) consumed by any platform with a Kafka connector

### 8.4 Isolated Region Constraints

| Constraint | Impact | Mitigation |
|---|---|---|
| No outbound internet | Cannot forward to public Splunk Cloud | Deploy Splunk Enterprise on-premises or in isolated region |
| No OCI Marketplace access | Cannot install Splunk App via Marketplace | Pre-package Splunk App and deploy manually |
| No external threat feeds | Logging Analytics threat intelligence enrichment cannot pull external feeds | Pre-load threat IP lists as custom enrichment sources within the region |

---

## 9. Third-Party Workloads and Customer Applications

### 9.1 Custom Log Ingestion

OCI Logging supports **custom logs** from non-OCI sources via the Unified Monitoring Agent (a Fluentd-based agent). This covers:
- Application logs from customer workloads running on OCI compute
- Middleware and web server logs (Apache, Nginx, JBoss)
- On-premises systems forwarding via syslog to OCI Logging Agent
- Third-party monitoring agents (Datadog, Dynatrace agents) running on OCI compute instances alongside the OCI Unified Monitoring Agent

### 9.2 Non-OCI Resources

Cloud Guard itself monitors OCI resources only. For third-party or on-premises systems that need to be correlated with Cloud Guard findings, the integration path is:
1. Custom logs ingested into OCI Logging via Unified Monitoring Agent
2. OCI Logging → SCH → OCI Streaming → Splunk
3. Correlation done in Splunk across OCI Cloud Guard data and custom log data

This gives a unified SIEM view of both OCI-native and third-party workload security events.

---

## 10. What STAR ELZ V1 Sprint 3 Deploys

| Resource | Capability Delivered |
|---|---|
| Cloud Guard target on tenancy root | Full CSPM coverage across all 10 C1 compartments |
| Configuration Detector recipe (cloned) | 50+ CIS-aligned misconfiguration rules |
| Activity Detector recipe (cloned) | IAM, network, and API activity threat detection |
| Responder recipe (cloned) | Automated remediation actions (notification + manual-confirm remediation) |
| VSS recipe + target | Weekly host scan, CIS Benchmark check, CVE detection on Sim FW instances |
| Security Zone on SEC | Preventive: no public buckets, encryption required |
| Security Zone on NW | Preventive: no public subnets, no IGW, no public VNICs |
| VCN Flow Logs (6) | Network forensics, forced inspection proof |
| SCH: flow logs → bucket | Log retention and SIEM source |
| KMS Vault + Master Key | Encryption key management for Security Zone enforcement |
| Events rule + alarm | Real-time DRG and route table change detection |
| ONS topic | SOC alerting (email, webhook, PagerDuty) |

---

## 11. What Is Not in Scope for Sprint 3 (V2 Backlog)

| Capability | Notes |
|---|---|
| SBOM generation | Requires third-party tooling (Syft, Grype) integrated at CI/CD pipeline |
| Splunk integration | Sprint 4 / V2 — OCI Streaming + Splunk Heavy Forwarder on isolated VM |
| OCI Data Safe | Sprint 4 / V2 — when database workloads are deployed in spokes |
| Cloud Guard Threat Detector | Available in OCI public cloud; verify availability in isolated region before enabling |
| KMS key rotation | V2 — add `oci_kms_key_version` resource to sprint3/sec_team3_security.tf |
| External threat feed enrichment | V2 — pre-load custom threat IP lists into OCI Logging Analytics |
| MFA enforcement policies | V2 — add MFA condition to IAM policies for all non-service users |

---

## 12. Summary — CNAPP Coverage Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    OCI CNAPP for STAR ELZ V1                    │
├──────────────────┬──────────────────────────────────────────────┤
│ CSPM             │ Cloud Guard Config Detector                  │
│                  │ CIS OCI Foundations Benchmark alignment      │
│                  │ Security Zones (preventive enforcement)      │
├──────────────────┼──────────────────────────────────────────────┤
│ CWPP             │ VSS host scanning (CVE / NVD / OVAL)         │
│                  │ VSS CIS Benchmark scan per host              │
│                  │ VSS container image scanning (OCIR)          │
│                  │ Cloud Guard Instance Security                │
├──────────────────┼──────────────────────────────────────────────┤
│ CDR              │ Cloud Guard Threat Detector (MITRE ATT&CK)   │
│                  │ Activity Detector (IAM, API, network changes)│
│                  │ VCN Flow Logs (network forensics)            │
├──────────────────┼──────────────────────────────────────────────┤
│ SOAR             │ Responder Recipes (auto + manual remediation)│
│                  │ OCI Events → Functions → external ticketing  │
├──────────────────┼──────────────────────────────────────────────┤
│ Observability    │ OCI Logging + SCH + Object Storage retention │
│                  │ ONS alerts + Monitoring alarms               │
├──────────────────┼──────────────────────────────────────────────┤
│ SIEM             │ OCI Streaming → Splunk / QRadar              │
│                  │ Audit + VCN Flow + Cloud Guard events        │
├──────────────────┼──────────────────────────────────────────────┤
│ Isolation        │ Air-gapped OCI Isolated Region               │
│                  │ No data leaves sovereign boundary            │
│                  │ Same service portfolio as OCI public cloud   │
└──────────────────┴──────────────────────────────────────────────┘
```

---

## References

- Oracle Cloud Guard documentation: https://docs.oracle.com/en-us/iaas/cloud-guard/
- Oracle VSS documentation: https://docs.oracle.com/en-us/iaas/scanning/
- CIS OCI Foundations Benchmark v3.0: https://www.cisecurity.org/benchmark/oracle_cloud
- OCI SIEM integration guide: https://docs.oracle.com/en-us/iaas/Content/cloud-adoption-framework/siem-integration.htm
- OCI Splunk architecture: https://github.com/oracle-quickstart/oci-arch-logging-splunk
- Oracle Cloud Isolated Region FAQ: https://www.oracle.com/government/govcloud/isolated/faq/
- KuppingerCole: Oracle Cloud Guard from CSPM to CNAPP (April 2024)
- Oracle A-Team: VSS in CIS Landing Zone: https://www.ateam-oracle.com/vulnerability-scanning-in-cis-oci-landing-zone
- Oracle A-Team: Cloud Guard SIEM integration: https://www.ateam-oracle.com/post/integrate-oracle-cloud-guard-with-external-systems-using-oci-events-and-functions
- Oracle A-Team: Security Fundamentals Dashboards: https://www.ateam-oracle.com/post/security-fundamentals-dashboards-using-logging-analytics
