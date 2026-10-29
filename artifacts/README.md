# Artifacts

Screenshots taken while building and testing the lab, kept as evidence of the
work.

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
