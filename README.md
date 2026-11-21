# Detection Lab

A build-it-yourself security **detection engineering** lab on AWS. Terraform
stands up the bare machines; **you** install and configure everything inside
them by hand, run real attacks, and write the detections that catch them.

The point is learning by doing. Automation stops at the edge of each server on
purpose. See [`CONTEXT.md`](./CONTEXT.md) for the vocabulary used throughout.

> ⚠️ **This lab is deliberately insecure and costs real money.** It is meant to
> be attacked, from your own IP only, and **destroyed when you're done**. Read
> [`docs/cost-and-teardown.md`](./docs/cost-and-teardown.md) before you `apply`.

## What you build

| Machine | OS | Role |
|---|---|---|
| Elastic | Ubuntu 22.04 | The SIEM: Elasticsearch + Kibana + Fleet |
| Domain Controller | Windows Server 2022 | Active Directory (`lab.local`) |
| Windows Victim | Windows Server 2022 | Domain-joined attack target |
| Linux Victim | Ubuntu 22.04 | Attack target |
| Attack Server | Ubuntu 22.04 | Where you launch attacks from |

Telemetry (Sysmon, Windows audit logs, auditd) ships to Elastic via Fleet-managed
Elastic Agent. Attacks come from [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team).

## The workflow

1. **`terraform apply`** to create the machines (see below).
2. **Work through [`guides/`](./guides/)** in order to build the lab from the
   ground up: stand up Elastic, enroll agents, configure Sysmon and auditd,
   build Active Directory, install Atomic Red Team.
3. **Pick an attack** by MITRE ATT&CK technique and run it against a Victim.
4. **Write the detection** in Kibana. The [`walkthroughs/`](./walkthroughs/)
   teach the craft; [`detections/`](./detections/) stores the finished rules.
5. **`terraform destroy`** when you stop for the day.

## Quick start

Prerequisites: an AWS account, the AWS CLI configured (`aws configure`),
Terraform ≥ 1.5, and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
for shell access.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set my_ip_cidr to "$(curl -s https://checkip.amazonaws.com)/32"
terraform init
terraform apply
```

After it finishes, `terraform output` gives you the Kibana URL, host addresses,
and the exact commands to read back generated passwords and open sessions. Then
open [`guides/01-elastic.md`](./guides/01-elastic.md).

## Repo layout

```
terraform/     Bare infrastructure: VPC, machines, security groups, SSM access
guides/        Build Guides — stand up the lab, in order (01 → 06)
walkthroughs/  Detection Walkthroughs — run an attack, author a detection (by ATT&CK id)
detections/    Exported, version-controlled Elastic detection rules
artifacts/     Screenshots of rules and tests, kept as evidence
versions.yml   Pinned, last-verified versions of every component
docs/          Architecture, cost, and teardown
CONTEXT.md     Glossary
```

## Keeping it current

Software drifts. Every component version lives in [`versions.yml`](./versions.yml),
and every guide is stamped with the date and versions it was last verified
against. If a step no longer matches reality, that's the file to fix first.

## Status

Working lab. All six Build Guides have been walked end to end, most recently
against Elastic 8.19.22.

| Detection | ATT&CK | Status |
|---|---|---|
| PowerShell encoded command | T1059.001 | Complete, alert confirmed on the live lab |
| Kerberoasting (service ticket for a user SPN) | T1558.003 | Complete, alert confirmed on the live lab |
| LSASS dump via comsvcs.dll | T1003.001 | Complete, alert confirmed on the live lab |

Three health rules alert when Sysmon or the Security log goes quiet for 15
minutes. Exported rules are in [`detections/`](./detections/); session notes
are in [`progress/`](./progress/).
