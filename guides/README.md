# Build Guides

Stand up the lab from the ground up. Work these **in order** — each assumes the
previous is done. Every guide is stamped with the date and versions it was last
verified against; pinned versions live in [`../versions.yml`](../versions.yml).

| # | Guide | Builds | Status |
|---|---|---|---|
| 01 | [Elastic](./01-elastic.md) | Elasticsearch + Kibana (the SIEM) | ✅ complete |
| 02 | [Fleet & Agents](./02-fleet-and-agents.md) | Fleet Server + Elastic Agent on every host | 🚧 stub |
| 03 | [Sysmon](./03-sysmon.md) | Sysmon + SwiftOnSecurity config on Windows | 🚧 stub |
| 04 | [Active Directory](./04-active-directory.md) | `lab.local` domain, users, audit-policy GPO | 🚧 stub |
| 05 | [auditd](./05-auditd.md) | Linux audit rules on the Linux Victim | 🚧 stub |
| 06 | [Atomic Red Team](./06-atomic-red-team.md) | Attack execution framework on both Victims | 🚧 stub |

**Status key:** ✅ complete = walked end to end and verified. 🚧 stub = outline
with the verified commands, not yet walked end to end. Stubs are safe to follow
but expect rough edges; fix and promote them to complete as you go.

Once all six are complete, the lab collects telemetry and is ready to attack.
Head to [`../walkthroughs/`](../walkthroughs/) to build your first detection.
