# 2026-10-05 — Attacker agent, `elastic` password reset

**Outcome:** the Attack Server is now monitored. It was renamed to `attacker`
and enrolled in Fleet on the `lab-linux` policy. The `elastic` superuser
password was reset after a failed Kibana login following the unpark.

Infrastructure is unchanged from the [2026-10-02 log](./2026-10-02-ad-auditd-atomics.md):
same instance IDs and private IPs, Elastic/Fleet Server at `10.10.1.129`.

## Done

- **Attack Server renamed** to `attacker` (`hostnamectl`, plus
  `preserve_hostname` so cloud-init doesn't revert it). Added to guide 04's
  rename table.
- **Elastic Agent on `attacker`**, assigned the `lab-linux` policy. This
  resolves guide 02's open question about monitoring the Attack Server.

## Problems hit (and where the fix is recorded)

| Problem | Cause | Fix / recorded in |
|---|---|---|
| Kibana login as `elastic` fails after unpark | The saved password was wrong. Parking doesn't change it; Elasticsearch returned 401 | `elasticsearch-reset-password -u elastic -b`; guide 01, step 6 note |

- **2026-10-04 open items confirmed:** linux-victim is on `lab-linux`, and the
  auditd integration is off the Windows policy. The `lab-windows` /
  `lab-linux` policy split is done.

## Open items

- No `Sysmon silent` health rule for **DC01** yet (from 2026-10-04).

## Next session

1. Unpark, open the Kibana tunnel, check Fleet → Agents shows all five hosts
   Healthy (including `attacker`).
2. ~~Rename hosts to the new convention.~~ **Done 2026-10-10** (see below).
3. Build the `Sysmon silent - dc01` health rule (copy of the ws01 one).
4. Start the [T1558.003 Kerberoasting walkthrough](../walkthroughs/T1558.003-kerberoasting/).

## 2026-10-10: hosts renamed

Hostnames now follow `<role><number>` (see `CONTEXT.md`):
WIN-VICTIM → `WS01`, linux-victim → `srv01`, attacker → `atk01`,
Elastic host `ip-10-10-1-129` → `siem01`. DC01 unchanged. Steps are in guide 04,
"Renaming hosts in a lab that's already built".

- Verified: all five report the new names over SSM, agents running, WS01 still on
  `lab.local`, Elasticsearch and Kibana up on siem01.
- `srv01` had no `preserve_hostname` file (the 2026-09-27 rename never added
  one), so it would have reverted on the next boot. Added.
- `Sysmon silent` rule edited in Kibana to `Sysmon silent - ws01`, query
  `host.name : "ws01"`.
- Events from before the rename keep the old names; search both, e.g.
  `host.name : ("ws01" or "win-victim")`.

## End of session

`.\scripts\park.ps1`. **Park, don't destroy.**
