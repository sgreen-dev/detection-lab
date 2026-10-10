# 2026-10-10 — Hostname convention, DC01 health rule, Kerberoasting

## Done

- **Hosts renamed** to a `<role><number>` convention (committed `972757b`,
  pushed): `WIN-VICTIM`→`WS01`, `linux-victim`→`srv01`, `attacker`→`atk01`,
  Elastic host `ip-10-10-1-129`→`siem01`. `DC01` unchanged. Verified over SSM;
  agents healthy. Fixed a missing `preserve_hostname` file on `srv01`. Guides,
  walkthroughs, detections and `CONTEXT.md` updated; `Sysmon silent` rule renamed
  to `Sysmon silent - ws01`.
- **`Sysmon silent - dc01`** health rule built and exported
  (`detections/health-sysmon-silent-dc01.ndjson`, committed `aa23301`, pushed).
- **T1558.003 Kerberoasting walkthrough COMPLETE** — first detection where the
  attack and the telemetry are on different hosts (attack on WS01, 4769 on DC01).
  - Attack: Atomic test 5, run as a scheduled task under `NT AUTHORITY\SYSTEM`
    (so it has a domain identity — `ssm-user` on WS01 is local-only, and
    `Start-Process -Credential` / a task as `LAB\alice` both fail from Session 0
    / without the batch-logon right).
  - Rule: `Kerberoasting - Service Ticket Requested for User SPN`, Custom query,
    index `logs-system.security-*`, High/73, 5m. Exported to
    `detections/T1558.003-kerberoasting-user-spn.ndjson`. Live alert confirmed.

## Gotchas hit (all written into the walkthrough §4 / detections README)

- **Kerberos ticket caching** — re-running Kerberoast reuses the cached service
  ticket, so the DC logs no new 4769 and the rule never fires. ("The attack only
  runs once.") Fix: `klist purge` before re-requesting.
- **Rule index pattern** — a Security-log rule needs `logs-system.security-*`;
  with none set (or the Sysmon index) it matches nothing silently.
- **Forward-only rules + preview window** — rules don't back-scan history; use
  Preview with a range covering when the attack ran. Kibana shows browser TZ
  (EDT), hosts are UTC (−4h).
- **Export is per screen** — detection rules export from Security → Rules, not
  Saved objects (which returns `exportedCount:0`).

## Notes

- During debugging I ran Atomic test 5 several times via SSM (as `WS01$`), so
  there are extra `svc_sql` 4769 events in today's data.
- `alice` still lacks the *Log on as a batch job* right, so the SYSTEM task was
  used. Optional follow-up: grant it so a run shows a real user as requestor.

## Lab state

**NOT parked** — lab is running at end of this note. Run `.\scripts\park.ps1`
when done.

## Next

- Optional: `Security log silent - dc01` health rule (backs the Kerberoasting
  rule, which depends on DC01's Security log, not Sysmon).
- Pick the next technique/walkthrough.
