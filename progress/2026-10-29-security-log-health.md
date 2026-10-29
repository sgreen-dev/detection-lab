# 2026-10-29 — Security log health rule, billing check

## Done

- **`Security log silent - dc01`** health rule built (Stack rule, Elasticsearch
  query on `logs-*`, `host.name:"dc01" and data_stream.dataset:"system.security"`,
  count < 1 over 15m, every 1m). Exported to
  `detections/health-security-silent-dc01.ndjson`. Covers the gap noted on
  2026-10-10: the Kerberoasting rule depends on DC01's Security log, which the
  Sysmon health rule doesn't watch.
- **Live test:** stopped the Elastic Agent on DC01. The alert went Active at
  19:35 EDT, and the agent was then restarted. Screenshots are in `artifacts/`.
- Checked before building: DC01 logs about 800 Security events in 25 minutes
  after boot (mostly 4688/4624/4672), so a 15-minute window won't false-alarm.

## Billing

- October to date: **$28.92** (forecast about $31). Disks/NAT $16.40, compute
  $10.42, KMS $1.82. Lab was parked from 10-11 to 10-28 (about $0.63/day).
- The AWS free-plan API now reports the account as **PAID** with **$0 credits**,
  and October shows no credits applied. Earlier notes had $179 to 2027-03-12.
  Check Billing → Credits in the console.

## Lab state

Unparked this session. Park with `.\scripts\park.ps1` at the end.

## Next

- Pick the next technique for walkthrough #3.
- Optional: grant `alice` *Log on as a batch job* so a Kerberoast run shows a
  real user as the requester.
