# Detection Walkthroughs

Guided detection-engineering exercises. Each one has you run an attack against a
Victim, look at the telemetry it produced, and build + validate a detection rule
in Kibana. **You type the commands that matter** — running the attack and writing
the query. The finished rule is exported to [`../detections/`](../detections/).

Attacks are **free-form**: pick any [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team)
test and detect it. These walkthroughs are worked examples of the craft, indexed
by MITRE ATT&CK so you can find one by technique or tactic — not a fixed
curriculum you must follow in order.

## How to self-search an attack

1. On a Victim: `Invoke-AtomicTest <technique-id> -ShowDetails` to see available
   tests, or browse `atomics/` (installed by guide 06) / the
   [ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/).
2. Run it, watch the telemetry in Kibana → Discover.
3. Build a detection. Use a walkthrough below as a template if one is close.

## Index

| ATT&CK | Technique | Tactic | Walkthrough | Status |
|---|---|---|---|---|
| T1059.001 | PowerShell | Execution | [powershell](./T1059.001-powershell/) | ✅ complete (2026-10-04) |
| T1558.003 | Kerberoasting | Credential Access | [kerberoasting](./T1558.003-kerberoasting/) | ✅ complete |

*Add a row per walkthrough as you write it. Suggested next targets once the
pipeline is proven: T1003 (OS Credential Dumping), T1053 (Scheduled Task/Job).*

## Walkthrough structure

Each folder follows the same shape (see the template in the T1059.001 folder):

1. **Attack** — the exact Atomic to run and what it does.
2. **Telemetry** — which events it generates and where to find them.
3. **Detection** — building the query/rule in Kibana, step by step.
4. **Validate** — re-run the attack, confirm the rule fires, check for false positives.
5. **Export** — save the rule to `../detections/` and commit it.
