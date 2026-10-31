---
walkthrough: T1003.001
technique: "OS Credential Dumping: LSASS Memory"
tactic: Credential Access
victim: Windows Victim (WS01) — attack and telemetry on the same host
last_verified: null
verified_versions:
  elastic_stack: 8.19.22
  invoke_atomic_red_team: 2.3.0
status: draft
---

# T1003.001 — LSASS Memory Dump via `comsvcs.dll` (Credential Access)

> 📝 **STATUS: draft — not yet walked on the live lab.** This lays out the attack,
> the telemetry we *expect*, a detection hypothesis, and a validation plan, in the
> same shape as the completed walkthroughs. Every value marked **(confirm live)**
> must be checked against real data on the next unpark before this is promoted to
> `status: complete`. Do not trust the "expected" tables until then — the whole
> point of the exercise is to build the rule on what the lab *actually* logs.

**Why this one next:** it's the first walkthrough where we expect a **telemetry
gap** and an **EDR fight**. The textbook signal for LSASS dumping is Sysmon
**Event 10** (a process opening a handle to `lsass.exe`), but the SwiftOnSecurity
Sysmon config we installed in guide 03 does not log `lsass` ProcessAccess by
default — so the obvious detection may have nothing to fire on. And Microsoft
Defender (real-time protection, on since guide 04) treats comsvcs LSASS dumping
as a known behaviour and will very likely block it. Both are the lesson, not an
obstacle: you learn where your telemetry *ends*, and you see the difference
between an EDR that stops the act and a SIEM that records it.

**The behaviour in one paragraph:** `lsass.exe` (the Local Security Authority
Subsystem) holds secrets in memory — password hashes, Kerberos tickets, cached
credentials. Anything that can read its memory can carry those secrets away to
crack or replay offline. `comsvcs.dll` is a signed Microsoft DLL that ships with
Windows and exposes a `MiniDump` function; calling it through `rundll32.exe`
writes a full memory dump of a target process to disk. Pointed at the `lsass`
PID, it's a living-off-the-land credential dump: no attacker binary, just a
built-in DLL and a built-in launcher. You're looking for the one `rundll32`
command line that ordinary use never produces.

---

## 1. Attack

On **WS01**, list the Atomics and read the one you'll run before running it:

```powershell
Invoke-AtomicTest T1003.001 -ShowDetailsBrief
Invoke-AtomicTest T1003.001 -TestNumbers <n> -ShowDetails
Invoke-AtomicTest T1003.001 -TestNumbers <n> -CheckPrereqs
```

**Which test (confirm live).** T1003.001 ships several tests; the one for this
walkthrough is the `comsvcs.dll` MiniDump test (named something like *"Dump LSASS
with comsvcs.dll"*). Confirm its number from `-ShowDetailsBrief` — **do not
hard-code a number from memory**, the Atomics set drifts between versions. Skip
the tests that download Mimikatz / Out-Minidump / procdump for now; Defender
flags those tools outright and they muddy the telemetry you're trying to read.
Come back to them later as variations (§4).

The core command the comsvcs test runs is a single `rundll32` invocation, roughly:

```
rundll32.exe C:\Windows\System32\comsvcs.dll, MiniDump <lsass_pid> C:\Windows\Temp\lsass.dmp full
```

Things to sort out before running:

- **Run elevated.** Reading `lsass` memory needs `SeDebugPrivilege` /
  administrator. Decide how you'll run it as an elevated identity on WS01 and
  record what worked — reuse the scheduled-task-as-`NT AUTHORITY\SYSTEM`
  technique from the Kerberoasting walkthrough §1 if an SSM session isn't
  elevated enough. SYSTEM has `SeDebugPrivilege`, so it's the natural fit here.
- **Defender is on** (real-time protection; `C:\AtomicRedTeam` and
  `C:\Windows\Temp` are excluded from *scanning*, but behavioural blocking of
  LSASS access is a separate protection and may still fire). **Expect the dump to
  be blocked or the file quarantined.** When it fails, that's a finding, not a
  dead end — check the `windows_defender` dataset in Discover (guide 03) and
  capture the block as the **EDR-vs-SIEM** talking point (§4), *then* decide
  whether to add a deliberate exclusion so the dump completes and you can see the
  full telemetry chain.
- **Clean up.** Delete any `*.dmp` the test leaves in `C:\Windows\Temp` (or
  `C:\Users\Public`). A real LSASS dump on disk is sensitive even in a lab.

**What was run:** *(fill in live — test number, how it was launched, whether
Defender blocked it on the first try, and what you changed to get a completed
dump.)*

---

## 2. Telemetry

Everything here lands on **WS01 itself** — unlike Kerberoasting, the attack and
the evidence are on the same host. Expected events (all **confirm live**):

| Source | Event | Dataset | What it shows |
|---|---|---|---|
| Sysmon | **1** ProcessCreate | `windows.sysmon_operational` | `rundll32.exe` launched with the comsvcs `MiniDump` command line — **the strongest signal** |
| Sysmon | **11** FileCreate | `windows.sysmon_operational` | the `.dmp` file being written to disk |
| Sysmon | **10** ProcessAccess | `windows.sysmon_operational` | a handle opened to `lsass.exe` — **expected MISSING** (see gap below) |
| Defender | block / detection | `windows_defender` | Defender stopping or quarantining the dump |
| Security | 4688 (if audited) | `system.security` | process creation, coarser than Sysmon 1 |

Start in Discover and look at **normal** `rundll32` activity first, before
attacking — Windows uses `rundll32` legitimately all the time, so you need to
know what ordinary command lines look like before you can single out the bad one:

```
host.name : "ws01" and event.code : "1" and process.name : "rundll32.exe"
```

Then run the Atomic and compare.

> **Expected telemetry gap — Sysmon Event 10 on `lsass`.** The classic LSASS-dump
> detection keys on Sysmon **Event 10 (ProcessAccess)** where
> `TargetImage` ends in `lsass.exe` and `GrantedAccess` is a dump-capable mask
> (e.g. `0x1410`, `0x1010`). The SwiftOnSecurity config ships ProcessAccess rules
> but **does not include `lsass` access by default** (it's commented out / scoped
> to cut noise). So on this lab you probably get **no Event 10** for the dump —
> the textbook rule would have nothing to match. **Confirm whether any Event 10
> appears for `lsass`.** If not, you have two honest choices, and the walkthrough
> should show both:
>
> 1. **Detect on what you *do* have** — the Event 1 `rundll32 … comsvcs … MiniDump`
>    command line. This is the pragmatic, works-today rule.
> 2. **Close the gap** — add an `lsass` include to the Sysmon ProcessAccess
>    section of the config, redeploy it (guide 03), re-run the attack, and confirm
>    Event 10 now fires. This is the "improve your sensor" lesson and the better
>    long-term detection.

Fields to inspect (confirm the exact names in your own data, as in the T1059.001
walkthrough — Sysmon maps into both `process.*` ECS fields and
`winlog.event_data.*`):

| Field (expected) | Question to answer |
|---|---|
| `process.command_line` / `winlog.event_data.CommandLine` | Does it contain `comsvcs`, `MiniDump`, and an `lsass` PID? |
| `process.name` / `process.pe.original_file_name` | Is it `rundll32.exe`? |
| `process.parent.name` / `winlog.event_data.ParentImage` | What launched it? (SYSTEM task, cmd, powershell?) |
| `file.path` (Event 11) | Where was the `.dmp` written? |
| `winlog.event_data.TargetImage` (Event 10, if present) | Did anything open a handle to `lsass.exe`? |
| `winlog.event_data.GrantedAccess` (Event 10, if present) | Dump-capable access mask? |

**What was observed:** *(fill in live — which events fired, which didn't,
exact field names, and whether Event 10 was present or absent.)*

---

## 3. Build the detection

**Hypothesis (confirm against §2 once you have live data):** `rundll32.exe`
launched with a command line that references `comsvcs.dll` and `MiniDump`.
Ordinary `rundll32` use never names comsvcs's MiniDump export, so this is a
high-fidelity, low-noise signal that survives the Event 10 gap.

This is a command-line pattern on a single Sysmon process-create event, so an
**EQL** rule over the Sysmon index fits best (same style as the T1059.001 rule):

```
process where host.name == "ws01" and event.code == "1"
  and process.name == "rundll32.exe"
  and process.command_line : "*comsvcs*MiniDump*"
```

Then work through:

- **Confirm the field names first (confirm live).** Check whether the command
  line is in `process.command_line`, `winlog.event_data.CommandLine`, or both,
  and build on what you actually see — not just this snippet.
- **Set the index pattern.** Sysmon lives in `logs-windows.sysmon_operational-*`
  (the Security log is a *different* index — getting this wrong means a silent
  no-match, the hard-won lesson from the Kerberoasting walkthrough §3). Confirm
  the source is **Index patterns** and `logs-windows.sysmon_operational-*` shows
  as a blue tag.
- **Case-insensitivity.** `MiniDump` may be typed in any case; EQL `:` is
  case-insensitive, so the wildcard match above is deliberate. Verify your match
  isn't defeated by case or by `comsvcs.dll` being given with a full path.
- **If you added Event 10 (the gap-closing path):** write a *second* rule on
  `event.code == "10"`, `TargetImage` ends in `lsass.exe`, dump-capable
  `GrantedAccess`. Note that it only works *after* you redeploy the Sysmon config.
- **Noise:** does any legitimate `rundll32 … comsvcs` command line exist in
  normal operation? Expected: none. Confirm with Rule preview over Last 7 days.

**What was built:** *(fill in live — final name, type, index, query, severity,
schedule, tags, ATT&CK mapping, like the Kerberoasting table.)*

| Setting | Value |
|---|---|
| Name | `Credential Dumping - LSASS via comsvcs.dll MiniDump` *(proposed)* |
| Type | EQL (Event Correlation) *(proposed)* |
| Index | `logs-windows.sysmon_operational-*` |
| Query | `process where host.name == "ws01" and event.code == "1" and process.name == "rundll32.exe" and process.command_line : "*comsvcs*MiniDump*"` *(proposed)* |
| Severity / risk | High / 73 *(proposed — confirm)* |
| Schedule | every 5m, look back 6m *(proposed)* |
| Tags | `T1003.001`, `lab` |
| ATT&CK | Credential Access TA0006 → T1003 → T1003.001 |

An investigation guide (triage steps) goes in the rule's Note field so it travels
with the export.

---

## 4. Validate and tune

**Validation plan (do on the live lab):**

1. **EDR-vs-SIEM, captured first.** Run the Atomic with Defender still on. Expect
   a block. Screenshot the Defender detection (`windows_defender` in Discover and
   the Windows Security notification) — this is the clean illustration that an
   **EDR stops the act** while the **SIEM records the attempt**. Save it to
   `../../artifacts/` (interview talking points).
2. **Full chain, Defender relaxed.** Add a deliberate, documented exclusion (or
   disable real-time protection briefly), re-run, and confirm the dump completes
   and the Sysmon Event 1 (and 11) fire. Re-enable protection afterwards.
3. **Live alert.** With the rule enabled, run a fresh dump and confirm one alert
   within the schedule window — open the alert, don't just count it. Remember
   detection rules are **forward-only** (they don't back-scan history): use **Rule
   preview** with a range covering past runs to test logic, then run a fresh
   attack for a live alert. Kibana shows your browser TZ (EDT = UTC−4); hosts are
   UTC.
4. **The telemetry gap, demonstrated.** Show the Event-10 rule firing *nothing*
   on the stock Sysmon config, then (optionally) redeploy the config with an
   `lsass` ProcessAccess include and show it firing. This is the headline lesson.
5. **False positives:** Rule preview over Last 7 days; do normal admin activity on
   WS01 and confirm the rule stays quiet.
6. **Variations:** does the rule also catch the Mimikatz / procdump tests, or are
   those a *different* signal (and a separate rule)? Note what each one needs.

- **Data-source health:** this rule depends on WS01's **Sysmon** telemetry, so it
  is covered by the existing `Sysmon silent - ws01` health rule
  ([`health-sysmon-silent-ws01.ndjson`](../../detections/health-sysmon-silent-ws01.ndjson)).
  The Event-10 variant (if built) depends on the Sysmon *config* including
  `lsass` access — note that a silent-sensor health rule won't catch a
  *mis-scoped config*, only a dead agent.

*(Fill in live: iterations table, regression table, latency, like T1059.001.)*

---

## 5. Export

Security → Rules → tick the rule → **Bulk actions → Export**. Save to
`../../detections/T1003.001-lsass-comsvcs-minidump.ndjson`. See
[`../../detections/README.md`](../../detections/README.md) for how to import it.
Any second rule (Event 10) or health rule exports separately.

---

## References

- MITRE ATT&CK T1003.001: https://attack.mitre.org/techniques/T1003/001/
- LOLBAS, `comsvcs.dll` MiniDump: https://lolbas-project.github.io/lolbas/Libraries/comsvcs/
- Sysmon Event 10 (ProcessAccess): https://learn.microsoft.com/sysinternals/downloads/sysmon#event-id-10-processaccess
- Elastic's prebuilt rules, to compare with yours *after* writing it:
  https://github.com/elastic/detection-rules
