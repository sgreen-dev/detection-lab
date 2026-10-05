# Cost and teardown

## Read this first

This lab runs five EC2 instances plus a NAT gateway. **They bill by the hour
whether or not you are using them.** Between sessions, **park** the lab instead
of destroying it, so everything you configured by hand is still there next time:

```powershell
.\scripts\park.ps1     # end of session: stop instances, remove NAT gateway
.\scripts\unpark.ps1   # start of session: recreate NAT gateway, start instances
```

Only run `terraform destroy` when you want to throw the whole build away and
start over from guide 01.

## Rough cost (us-east-1, on-demand)

Approximate. Verify current prices in the AWS console; Windows carries a license
fee folded into the hourly rate.

| Item | Size | ~$/hr |
|---|---|---|
| Elastic | t3.large | 0.083 |
| Domain Controller | t3.medium | 0.042 |
| Windows Victim | t3.medium | 0.042 |
| Linux Victim | t3.small | 0.021 |
| Attack Server | t3.medium | 0.042 |
| NAT gateway (+ its Elastic IP) | — | 0.050 |
| **Total running** | | **~0.28/hr** |

That's roughly **$7/day** if left on around the clock, before EBS storage and
data-transfer charges.

## What parking costs

| State | What bills | ~$/month |
|---|---|---|
| Running | everything above | ~$200 if never turned off |
| **Parked** | EBS disks only (2×50 GB + 3×40 GB gp3) | **~$18** |
| Destroyed | nothing | $0 |

Parking works because stopped instances bill for their disks only, and the NAT
gateway (the one piece that bills even with every instance stopped) is removed
by `park.ps1` via `terraform apply -var nat_enabled=false`.

Things that stay the same across park/unpark:

- **Private IPs.** A VPC instance keeps its private IP when stopped and started,
  so the domain, DNS, the Fleet Server URL and enrolled agents keep working.
- **Instance IDs**, disks, passwords in SSM Parameter Store.

Things that change:

- **Public IPs** of Elastic and the Attack Server. Irrelevant if you use the SSM
  tunnel for Kibana (recommended); `terraform output kibana_url` shows the new one.

## Safety net: no surprise rebuilds

The AMI lookups in `terraform/data.tf` always resolve to the *latest* image.
Every instance has `lifecycle { ignore_changes = [ami, user_data] }` so a new
AWS image release never makes `terraform apply` recreate a configured box. If a
`terraform plan` ever says an instance "must be replaced", stop and find out why
before applying.

## Other habits

- **Set a billing alarm.** AWS Budgets → a $20 alert catches a forgotten lab.
- **After a long break,** Windows may install updates on first boot; give it a
  few minutes. Elastic Agents reconnect on their own.

## What `terraform destroy` removes

Everything tagged by this project: instances **and their disks (all your
in-box work)**, VPC, subnets, gateways, security groups, the IAM role/profile,
and the generated passwords in SSM Parameter Store. It does **not** touch
anything you created by hand outside Terraform (e.g. AWS Budgets alarms,
snapshots you took manually).
