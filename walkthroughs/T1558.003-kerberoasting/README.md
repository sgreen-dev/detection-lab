---
walkthrough: T1558.003
technique: "Steal or Forge Kerberos Tickets: Kerberoasting"
tactic: Credential Access
victim: Windows Victim (attack) / Domain Controller (telemetry)
last_verified: 2026-10-10
verified_versions:
  elastic_stack: 8.19.22
  invoke_atomic_red_team: 2.3.0
status: complete
---

# T1558.003 — Kerberoasting (Credential Access)

> ✅ **STATUS: complete.** Walked end to end on the live lab 2026-10-10: attack
> run (test 5), telemetry confirmed on DC01 (`svc_sql` 4769, AES256), rule built,
> validated with a live alert, and exported to
> [`../../detections/T1558.003-kerberoasting-user-spn.ndjson`](../../detections/T1558.003-kerberoasting-user-spn.ndjson).
> Two hard-won gotchas are written up in §4: Kerberos ticket caching, and the
> rule index pattern / forward-only time window.

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

**Which test.** Checked 2026-10-10 against the installed Atomics (7 tests):

| Test | What it does | Use it? |
|---|---|---|
| 1 | Downloads Empire's `Invoke-Kerberoast` from GitHub | Later, as a variation. Defender is likely to block it. |
| 2, 6, 7 | Rubeus / WinPwn tooling | Later. Defender flags these tools. |
| 3 | `setspn` lists every SPN (recon only, no tickets) | Recon step only |
| 4 | Requests **one** ticket, for `HTTP/<DC>`, a computer account | No. It never touches `svc_sql`. |
| **5** | Lists every SPN, then requests a ticket for each one, using built-in .NET | **Yes.** No download, and it requests `svc_sql`'s ticket. |

Tests 3 and 5 default `domain_name` to `%USERDNSDOMAIN%`. Test 5 runs in
PowerShell, which doesn't expand `%VAR%`, so pass the domain explicitly:
`-InputArgs @{domain_name="lab.local"}`.

Things to sort out before running:

- **Run as a domain user.** SSM sessions on WS01 run as the local `ssm-user`,
  which has no domain identity, so it can't request domain Kerberos tickets.
  (On DC01, `ssm-user` *is* a domain account, which is why it shows up in 4769
  events there.) Run the Atomic as `LAB\alice` and record what worked here.
- **Defender is on** (real-time protection; `C:\AtomicRedTeam` and
  `C:\Windows\Temp` are excluded). If a test fails, check `windows_defender` in
  Discover (guide 03).
- **Prerequisites.** Tests 1–5 only need the machine to be domain-joined.

**What was run (2026-10-10):** test 5, *Request All Tickets via PowerShell*. It
runs `setspn -T lab.local -Q */*` to list every SPN, then requests a Kerberos
ticket for each with the built-in `System.IdentityModel` .NET class. No download,
nothing to clean up (it only requests tickets).

**Running it as a domain user — what actually worked.** `ssm-user` on WS01 runs
in Session 0 (a non-interactive service session), so the obvious routes fail:

- `Start-Process -Credential (LAB\alice)` launches a process that exits
  immediately without running — empty output, no error. Session 0 won't start an
  interactive process as another user.
- A scheduled task **as `LAB\alice`** registers but never runs
  (`LastTaskResult 267011` = "has not run"): a standard user lacks the *Log on
  as a batch job* right by default.

What worked: a scheduled task running as **`NT AUTHORITY\SYSTEM`**, which on a
domain-joined host authenticates as the machine account `WS01$` — a real domain
identity that can request service tickets. Register it with the action below,
`-RunLevel Highest`, `Start-ScheduledTask`, then read the output from
`C:\Users\Public` (a standard user can't write to `C:\Windows\Temp`):

```powershell
$a = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -Command "Import-Module C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1; Invoke-AtomicTest T1558.003 -TestNumbers 5 -InputArgs @{domain_name=''lab.local''} *> C:\Users\Public\kerberoast.txt"'; Register-ScheduledTask -TaskName kroast -Action $a -User "NT AUTHORITY\SYSTEM" -RunLevel Highest -Force; Start-ScheduledTask -TaskName kroast
```

Check and read (then `Unregister-ScheduledTask -TaskName kroast -Confirm:$false`):

```powershell
(Get-ScheduledTaskInfo kroast).LastTaskResult; Get-Content C:\Users\Public\kerberoast.txt
```

`LastTaskResult 0` = success. The output lists a ticket per SPN, including
`MSSQLSvc/sql.lab.local:1433`.

> **Caveat — the requestor is `WS01$`, not a user.** Because the task runs as
> SYSTEM, the 4769 event's `TargetUserName` is the machine account. The
> Kerberoasting *signal* is unaffected (it's about which SPN is requested, see
> below), but if you want a user as the requestor, grant `alice` the *Log on as
> a batch job* right, then run the task as `LAB\alice`.

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

What normal looked like on 2026-10-10 (last 24 hours, read on DC01): about 40
requests, **all** for computer accounts (`DC01$`, `WS01$`) or `krbtgt`, all
encryption type `0x12` (AES256), and all successful. Requests from
`WIN-VICTIM$` are WS01 under its old name, from before the rename.

> **Encryption type caveat.** Classic Kerberoasting detections look for
> `TicketEncryptionType` `0x17` (RC4), because attack tools ask for RC4, which is
> much faster to crack. `svc_sql` has no `msDS-SupportedEncryptionTypes` set, so
> the DC's default decides. Recent Windows updates are moving domain controllers
> off RC4 by default. Note which type the attack's ticket actually gets before
> you base the rule on it.

Fields to inspect (confirm the exact names in your own data, as in the
T1059.001 walkthrough):

| Field (expected) | Question to answer |
|---|---|
| `winlog.event_data.ServiceName` | Which account's ticket was requested? Is it a user account (`svc_sql`) or a computer account (ends in `$`)? |
| `winlog.event_data.TicketEncryptionType` | Which encryption was used? Compare normal traffic with the attack. |
| `winlog.event_data.TargetUserName` | Who asked? |
| `winlog.event_data.IpAddress` | From which machine? |
| `winlog.event_data.Status` | Did the request succeed? |

**What was observed (2026-10-10, read on DC01).** The attack produced one 4769
for each SPN. The one that matters:

| svc (ServiceName) | enc | requestor | status |
|---|---|---|---|
| `svc_sql` | `0x12` (AES256) | `WS01$` | `0x0` (success) |
| `krbtgt`, `DC01$`, `WS01$`, `Dfsr-…`, `WSMAN/…` | `0x12` | `WS01$` | `0x0` |

Compared with normal traffic, **nothing about the encryption or the requestor
stands out** — it's all AES, all successful. The one difference is the
`ServiceName`: `svc_sql` is a **user account** that happens to own an SPN, while
every normal 4769 names a computer account (ends in `$`) or `krbtgt`.

> **The textbook detection does not apply here.** Classic Kerberoasting rules
> alert on `TicketEncryptionType 0x17` (RC4), because attack tools request RC4 to
> crack it faster. This DC issued **AES256 (`0x12`)** for `svc_sql`, so an
> RC4-only rule would miss this attack entirely. Modern DCs default to AES; don't
> build the rule on encryption type alone.

---

## 3. Build the detection

**Hypothesis (from what we saw above):** a service ticket (4769) was requested
for an **SPN owned by a user account** — not a computer account (`*$`) and not
`krbtgt`. In this lab that's `svc_sql`. A legitimate app requesting that ticket
is rare; an attacker enumerating SPNs to crack always hits it.

A starting query to try in the rule (type the index by hand, no trailing space):

```
host.name : "dc01" and event.code : "4769"
  and not winlog.event_data.ServiceName : *$
  and not winlog.event_data.ServiceName : "krbtgt"
```

Then work through:

- **Confirm the field name first.** Confirmed 2026-10-10: the service is in
  `winlog.event_data.ServiceName`, computer accounts end in `$`, and `host.name`
  is lowercase `dc01`. Build on what you see, not just this snippet.
- **Set the index pattern — this bit hard (2026-10-10).** A Security-log rule
  must point at `logs-system.security-*`. Sysmon lives in a *different* index
  (`logs-windows.sysmon_operational-*`), so a rule with the wrong or missing
  index matches nothing and fires no alert, with no error. In the Define step,
  confirm the source toggle is **Index patterns** (not an empty Data view) and
  that `logs-system.security-*` shows as a blue tag (type it, press **Enter**).
- **Rule type:** this is one suspicious event → *Custom query*. A *Threshold*
  rule (many SPNs requested by one account in a short window) is a good second
  rule, since test 5 requests *every* SPN at once — a very attacker-like burst.
- **Noise:** does any legitimate service account SPN get requested in normal
  operation? In this lab, only `svc_sql` is a user SPN, so the rule should be
  quiet until you attack. Confirm with Rule preview.
- **Encryption:** do **not** filter on `TicketEncryptionType 0x17` (RC4) — see
  §2; this DC issues AES. You could add a *separate* rule for RC4 requests as a
  belt-and-braces detection, and note that it won't fire on test 5.

**What was built (2026-10-10):**

| Setting | Value |
|---|---|
| Name | `Kerberoasting - Service Ticket Requested for User SPN` |
| Type | Custom query |
| Index | `logs-system.security-*` |
| Query | `host.name : "dc01" and event.code : "4769" and not winlog.event_data.ServiceName : *$ and not winlog.event_data.ServiceName : "krbtgt"` |
| Severity / risk | High / 73 |
| Schedule | every 5m, look back 6m |
| Tags | `T1558.003`, `lab` |
| ATT&CK | Credential Access TA0006 → T1558 → T1558.003 |

An investigation guide (triage steps) is set in the rule's Note field and travels
with the export. The `*$` clause uses a leading wildcard — allowed but slow;
fine at lab volume.

---

## 4. Validate and tune

**Validated 2026-10-10:** a fresh `svc_sql` 4769 on DC01 produced one live alert
within the schedule window. Confirmed by opening the alert, not just the count.

> **The gotcha that cost the most time: Kerberos caches tickets.** Once a host
> holds `svc_sql`'s service ticket, re-running the attack **reuses the cached
> ticket** — the DC sees no new request, logs no new 4769, and the rule has
> nothing to fire on. (Symptom: "the attack only runs once.") To generate a
> fresh event every time, purge first. As SYSTEM (so it has a domain identity),
> run a scheduled task whose action is:
>
> ```powershell
> powershell -NoProfile -Command "klist purge | Out-Null; Add-Type -AssemblyName System.IdentityModel; New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList 'MSSQLSvc/sql.lab.local:1433'"
> ```
>
> Real attackers purge for the same reason, so this is realistic, not a lab
> artifact.

> **Second gotcha: the preview/alert time window.** A detection rule only
> evaluates events going *forward* from when it runs; it does not back-scan
> history. If you build the rule after the attack, no live alert appears for that
> past event — use **Rule preview** (set the range wide enough to cover when the
> attack actually ran) to test the logic, then run a fresh attack for a live
> alert. Remember Kibana shows your browser's timezone (EDT = UTC−4); the hosts
> are UTC.

- **Check which event matched and why.** Open the alert; don't just count it.
- **False positives:** use Rule preview over **Last 7 days** for history, then do
  normal domain activity (log on to WS01 as `alice`, browse a share) and
  confirm it stays quiet.
- **Variations:** if more than one Atomic exists, does the rule catch each one?
- **Data source health:** this rule depends on DC01's **Security log**
  (`system.security`), not Sysmon, so `Sysmon silent - dc01` doesn't cover it.
  A `Security log silent - dc01` health rule, built the same way with
  `data_stream.dataset : "system.security"`, covers it
  ([`health-security-silent-dc01.ndjson`](../../detections/health-security-silent-dc01.ndjson)).
  Tested 2026-10-29 by stopping the Elastic Agent on DC01: the alert went
  Active, then cleared after the agent restarted.

*(Fill in: an iterations table, a regression table, and latency, like
T1059.001.)*

---

## 5. Export

Security → Rules → tick the rule → **Bulk actions → Export**. Saved as
[`../../detections/T1558.003-kerberoasting-user-spn.ndjson`](../../detections/T1558.003-kerberoasting-user-spn.ndjson).
See [`../../detections/README.md`](../../detections/README.md) for how to import
it. Any health rule exports separately, to
`../../detections/health-<name>.ndjson`.

---

## References

- MITRE ATT&CK T1558.003: https://attack.mitre.org/techniques/T1558/003/
- Microsoft, event 4769: https://learn.microsoft.com/windows/security/threat-protection/auditing/event-4769
- Elastic's prebuilt rules, to compare with yours *after* writing it:
  https://github.com/elastic/detection-rules
