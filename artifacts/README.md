# Artifacts

Screenshots taken while building and testing the lab, kept as evidence of the
work.

## T1003.001 LSASS dump via `comsvcs.dll` (2026-11-21)

| File | Shows |
|---|---|
| [`telemetry-gap.png`](./telemetry-gap.png) | On WS01: the Sysmon config has no ProcessAccess rules, and the local Sysmon log holds no Event 10. |
| [`telemetry-gap-elastic-dashboard.png`](./telemetry-gap-elastic-dashboard.png) | The same gap in Kibana: no Sysmon Event 10 from `ws01` in the last 90 days. |
| [`t1003-test2-show-details.png`](./t1003-test2-show-details.png) | The Atomic test that was run (T1003.001 test 2, comsvcs.dll MiniDump). |
| [`t1003-test2-access-is-denied-by-defender.png`](./t1003-test2-access-is-denied-by-defender.png) | First run, Defender on: the test is blocked. |
| [`t1003-test2-defender-block-kibana-dashboard.png`](./t1003-test2-defender-block-kibana-dashboard.png) | Kibana after the blocked run: Defender's record of the block. |
| [`t1003-test2-defender-disabled-kibana-dashboard-eventcode1.png`](./t1003-test2-defender-disabled-kibana-dashboard-eventcode1.png) | Real-time protection off: Sysmon Event 1 for `rundll32.exe` with the comsvcs `MiniDump` command line. |
| [`t1003-test2-defender-disabled-kibana-dashboard-eventcode11.png`](./t1003-test2-defender-disabled-kibana-dashboard-eventcode11.png) | Real-time protection off: Sysmon Event 11 for the dump file being written. |
| [`t1003-test2-defender-disabled-after-alert-creation.png`](./t1003-test2-defender-disabled-after-alert-creation.png) | The fresh run made after the rule was enabled (exit code 0). |
| [`t1003-test2-defender-disabled-alert-triggered.png`](./t1003-test2-defender-disabled-alert-triggered.png) | The rule's alert for that run. |

**Why it matters:** three findings from one technique
([`T1003.001`](../walkthroughs/T1003.001-lsass-comsvcs/README.md)). The textbook
detection (Sysmon Event 10 on `lsass.exe`) has no data on this Sysmon config.
Defender stops the attack before `rundll32.exe` starts, so the blocked attempt
leaves no Sysmon event and only Defender's log records it. With Defender out of
the way, the command-line rule on Event 1 catches the dump.

## `Security log silent - dc01` health rule (2026-10-29)

| File | Shows |
|---|---|
| [`dc01-security-log-health-check-rule.png`](./dc01-security-log-health-check-rule.png) | The rule definition: Elasticsearch query on `logs-*`, `host.name:"dc01" and data_stream.dataset:"system.security"`, count **below 1** over the last **15 minutes**, checked every minute. *Test query* reads 0 because the agent was stopped. |
| [`dc01-elastic-service-stop.png`](./dc01-elastic-service-stop.png) | The test: `Stop-Service "Elastic Agent"` on DC01, cutting off its logs. |
| [`security-log-rule-alert.png`](./security-log-rule-alert.png) | The result: the alert goes **Active** ("Document count is 0 in the last 15m"). |
| [`dc01-elastic-service-start.png`](./dc01-elastic-service-start.png) | Recovery: `Start-Service "Elastic Agent"` brings the logs back. |

**Why it matters:** the Kerberoasting rule
([`T1558.003`](../walkthroughs/T1558.003-kerberoasting/README.md)) reads DC01's
Security log. If that log stops arriving, the rule finds nothing, and nothing
looks wrong. This health rule turns "no data" into an alert, and the test
proves it fires.
