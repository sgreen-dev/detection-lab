---
walkthrough: T1558.003
technique: "Steal or Forge Kerberos Tickets: Kerberoasting"
tactic: Credential Access
victim: Windows Victim (attack) / Domain Controller (telemetry)
last_verified: null
verified_versions:
  elastic_stack: 8.19.22
status: stub
---

# T1558.003 — Kerberoasting (Credential Access)

> 🚧 **STATUS: stub.** Structure and starting points only. Not yet walked.
> Fill in each *(Fill in)* from what you actually see in your lab, the same way
> the [T1059.001 walkthrough](../T1059.001-powershell/) was written.

**Why this one next:** it's the first walkthrough where the evidence lands on a
**different machine** from the one the attack runs on. The request comes from
the Windows Victim, but the Domain Controller records it. The Lab was built for
it: `svc_sql` has a Service Principal Name (`MSSQLSvc/sql.lab.local:1433`) and a
deliberately weak password, and DC01 audits *Kerberos Service Ticket
Operations* (guide 04).

**The behaviour in one paragraph:** any domain user can ask the Domain
Controller for a Kerberos service ticket for any account that has an SPN. Part
of that ticket is encrypted with the service account's password, so an attacker
can take it away and try to crack the password offline. On the network this
looks like ordinary Kerberos, which is what makes it a good detection exercise.
You're looking for the requests that ordinary use doesn't make.

---

## 1. Attack

On the **Windows Victim**, list the Atomics and read one before running it:

```powershell
Invoke-AtomicTest T1558.003 -ShowDetailsBrief
Invoke-AtomicTest T1558.003 -TestNumbers <n> -ShowDetails
Invoke-AtomicTest T1558.003 -TestNumbers <n> -CheckPrereqs
```

Things to sort out before running:

- **Run as a domain user.** SSM sessions run as the local `ssm-user`, which has
  no domain identity, so it can't request domain Kerberos tickets. Find a way to
  run the Atomic as a domain account (e.g. `LAB\alice`), and record what worked
  here.
- **Defender may block some tests.** Many Kerberoasting tools are flagged.
  Check `windows_defender` in Discover if a test fails (guide 03).
- **Prerequisites.** Some tests download tooling; `-GetPrereqs` handles it.

*(Fill in: which test number you used, what it does, how you ran it as a domain
user, and the cleanup command.)*

---

## 2. Telemetry

The key event is on the **Domain Controller**, not the Windows Victim:

| Source | Event | Dataset | Where |
|---|---|---|---|
| Security log | **4769**: a Kerberos service ticket was requested | `system.security` | DC01 |

Start in Discover:

```
host.name : "dc01" and event.code : "4769"
```

First look at **normal** 4769 traffic for a while, without running any attack.
Domain-joined machines request service tickets constantly. Then run the Atomic
and compare.

Fields to inspect (confirm the exact names in your own data, as in the
T1059.001 walkthrough):

| Field (expected) | Question to answer |
|---|---|
| `winlog.event_data.ServiceName` | Which account's ticket was requested? Is it a user account (`svc_sql`) or a computer account (ends in `$`)? |
| `winlog.event_data.TicketEncryptionType` | Which encryption was used? Compare normal traffic with the attack. |
| `winlog.event_data.TargetUserName` | Who asked? |
| `winlog.event_data.IpAddress` | From which machine? |
| `winlog.event_data.Status` | Did the request succeed? |

*(Fill in: what normal 4769 traffic looks like, what the attack's 4769 looks
like, and which field values are the difference.)*

---

## 3. Build the detection

Questions to work through, using the same method as T1059.001:

- **Hypothesis:** what single property makes the attack's request unusual?
- **Rule type:** one suspicious event (Custom query / EQL), or **many** ticket
  requests from one user in a short time (*Threshold*)? Maybe both, as two
  rules.
- **Noise:** which accounts or services legitimately produce matching events
  in your lab? (Computer accounts, `krbtgt`, the DC itself.)
- **Index pattern:** type it by hand, with no trailing space (see the T1059.001
  walkthrough, §4).

*(Fill in: rule type, index pattern, query, severity, ATT&CK mapping (Credential
Access TA0006 → T1558 → T1558.003), schedule, and why each choice.)*

---

## 4. Validate and tune

- **True positive:** re-run the Atomic and confirm an alert from **DC01**.
- **Check which event matched and why.** Open the alert; don't just count it.
- **False positives:** use Rule preview over **Last 7 days** for history, then do
  normal domain activity (log on to WIN-VICTIM as `alice`, browse a share) and
  confirm it stays quiet.
- **Variations:** if more than one Atomic exists, does the rule catch each one?
- **Data source health:** this rule depends on DC01's Security log. Consider a
  health rule like `Sysmon silent - win-victim`, for DC01's `system.security`.

*(Fill in: an iterations table, a regression table, and latency, like
T1059.001.)*

---

## 5. Export

Export to `../../detections/T1558.003-kerberoasting-<short-name>.ndjson`, and any
health rule to `../../detections/health-<name>.ndjson`. See
[`../../detections/README.md`](../../detections/README.md).

---

## References

- MITRE ATT&CK T1558.003: https://attack.mitre.org/techniques/T1558/003/
- Microsoft, event 4769: https://learn.microsoft.com/windows/security/threat-protection/auditing/event-4769
- Elastic's prebuilt rules, to compare with yours *after* writing it:
  https://github.com/elastic/detection-rules
