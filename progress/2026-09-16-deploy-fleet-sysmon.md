# 2026-09-16 — First deploy, Fleet, Sysmon

**Outcome:** Terraform applied, Elastic Stack 8.19.21 running, Fleet Server up,
agents enrolled on DC + both victims, Sysmon events visible in Discover.
Guides 01–03 verified. Lab **stopped** at end of session.

## Lab inventory

| Host | Instance ID | Private IP | Hostname | Type |
|---|---|---|---|---|
| Elastic (Fleet Server) | i-05acee4d3683e8b0f | 10.10.1.236 | ip-10-10-1-236 | m7i-flex.large |
| Domain Controller | i-06d340be61a6743c4 | 10.10.2.22 | EC2AMAZ-MF08JNE | m7i-flex.large |
| Windows Victim | i-08892eb7c9bef2946 | 10.10.2.28 | EC2AMAZ-4A7UPGQ | m7i-flex.large |
| Linux Victim | i-0de0612cedf97f403 | 10.10.2.135 | ip-10-10-2-135 | t3.small |
| Attack Server | i-0b62fcb94ea71fe79 | — | — | c7i-flex.large |

Region us-east-1. Fleet Server URL used by agents: `https://10.10.1.236:8220`.
No agent on the Attack Server yet (deliberate, still an open choice).

## Done

- `terraform apply` — 28 resources.
- Elastic + Kibana installed by hand per guide 01; Kibana encryption keys added.
- Fleet Server installed on the Elastic host (Quick Start flow).
- Agent policy with *System* + *Windows* integrations; agents enrolled on
  DC, Windows Victim, Linux Victim. All four rows Healthy in Fleet → Agents.
- Sysmon v15.22 + SwiftOnSecurity config on DC and Windows Victim; Event ID 1
  process-creation events confirmed in Discover.
- Guides 02 and 03 stamped `last_verified: 2026-09-16`, status `complete`.

## Problems hit (and where the fix is recorded)

| Problem | Cause | Fix / recorded in |
|---|---|---|
| `terraform output` said "No outputs found" | No state yet, never applied | just run `terraform apply` |
| `my_ip_cidr` invalid | tfvars had a shell `$(curl …)` string; Terraform doesn't run shell | literal IP in `terraform.tfvars` |
| "No valid credential sources found" even after `aws login` | AWS provider 5.x can't read `aws login` session creds | `lab` profile in `~/.aws/config` using `credential_process`; run Terraform with `AWS_PROFILE=lab` |
| Ubuntu AMI SSM parameter "couldn't find resource" | Canonical public parameter not resolving | `data.tf` now uses `aws_ami` lookup by owner/name |
| `amis_used` output "refers to sensitive values" | SSM parameter values are always sensitive | `nonsensitive()` in `data.tf` |
| "instance type is not eligible for Free Tier" | Account is on the AWS **Free plan** (credits $179 to 2027-03-12) | instance types overridden in `terraform.tfvars` |
| Fleet "Error: No data" on Add Fleet Server | Kibana had no `xpack.encryptedSavedObjects.encryptionKey` | guide 01, kibana-encryption-keys step |
| `localhost:5601` unreachable after Kibana restart | SSM port-forward tunnel died | restart the tunnel |
| Fleet Server accidentally installed on Linux Victim | ran the Fleet Server command instead of Add agent | `elastic-agent uninstall -f`, re-enrolled with agent command |
| Enrollment loops on `x509: certificate signed by unknown authority` | Kibana's Add agent command omits `--insecure` | guide 02 open-questions, resolved |
| DC / Windows Victim showed "Not enrolled" though service running | install interrupted mid-enroll | `elastic-agent.exe enroll … --insecure --force` |
| Commands pasted incomplete | terminal prompt and text same colour | keep commands on one line |

## Cost notes

- Five instances running ≈ $0.60/hr. Stopped instances cost only EBS.
- NAT gateway keeps billing (~$1/day) while stopped; only `terraform destroy`
  removes it, which also wipes all in-box work.
- Elastic host public IP changes on each start; private IPs and SSM tunnel do not.

## Next session

Guide 04 — Active Directory: promote the DC to `lab.local`, seed users
(incl. `svc_sql` SPN), join the Windows Victim.
