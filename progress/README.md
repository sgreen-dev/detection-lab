# Lab progress

Running log of build sessions: what got done, what broke, and how the lab was
left. One file per session, newest at the top of this list. Session files are
named `YYYY-MM-DD-<short-topic>.md`.

| Date | Session | Lab state at end |
|---|---|---|
| 2026-10-05 | [Attacker agent, `elastic` password reset](./2026-10-05-attacker-agent.md) | Attack Server renamed `attacker` and enrolled on `lab-linux`; policy split confirmed. Next: DC01 health rule, then Kerberoasting |
| 2026-10-04 | [First detection: T1059.001](./2026-10-04-t1059-detection.md) | **Parked**. T1059.001 rule + Sysmon health rule built and exported. Next: check agent policies, then the T1558.003 Kerberoasting walkthrough (stub added) |
| 2026-10-02 | [Rebuild, AD, auditd, Atomic Red Team](./2026-10-02-ad-auditd-atomics.md) | **Parked** (stopped + NAT removed). All guides done; Atomic test 17 run (events found 2026-10-04) |
| 2026-09-16 | [Deploy, Fleet, Sysmon](./2026-09-16-deploy-fleet-sysmon.md) | **Stopped** (all 5 instances) |

## Quick start / stop

Park between sessions instead of destroying, so your progress is kept (see
[docs/cost-and-teardown.md](../docs/cost-and-teardown.md)). Run from the repo root:

```powershell
$env:AWS_PROFILE = "lab-sso"   # IAM Identity Center; if expired: aws sso login --profile lab-sso
.\scripts\unpark.ps1           # start of session; prints the Kibana tunnel command
.\scripts\park.ps1             # end of session
```

The scripts read instance IDs from `terraform output`, so nothing here needs
updating after a re-apply.
