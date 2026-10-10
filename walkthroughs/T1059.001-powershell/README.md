---
walkthrough: T1059.001
technique: PowerShell
tactic: Execution
victim: Windows Victim
last_verified: 2026-10-04
verified_versions:
  elastic_stack: 8.19.22
status: complete
---

# T1059.001 — PowerShell (Execution)

> ✅ **STATUS: complete.** Walked end to end on 2026-10-04 against Elastic 8.19.22.
> The finished rule is
> [`../../detections/T1059.001-powershell-encoded-command.ndjson`](../../detections/T1059.001-powershell-encoded-command.ndjson).

**Why this one first:** encoded PowerShell is one of the most common things
attackers do on Windows, the Atomic is safe, and it leaves clear evidence. It
also turned out to teach most of the craft in one exercise: a false positive,
two evasions, a silent data-source failure, and a licensing trade-off.

**What you end up with:**

- **Detection rule** `PowerShell Encoded Command Execution`: EQL, Sysmon only,
  medium severity, mapped to T1059.001.
- **Health rule** `Sysmon silent - ws01`: alerts if the Windows Victim
  stops sending Sysmon data.

---

## 1. Attack

On the **Windows Victim**, in an SSM session (load the module first, see guide 06):

```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 17 -ShowDetails
Invoke-AtomicTest T1059.001 -TestNumbers 17
Invoke-AtomicTest T1059.001 -TestNumbers 17 -Cleanup
```

Atomic 17, *PowerShell Command Execution*, runs:

```
powershell.exe -e JgAgACgAZwBjAG0AIAAoACcAaQBlAHsAMAB9ACcA...
```

Decoded (base64, UTF-16LE), the payload is harmless. It prints "Hello, from
PowerShell!", but it's obfuscated the way real attackers obfuscate commands:

| Layer | What it hides |
|---|---|
| `-e` + base64 | The whole command is unreadable on the command line |
| `('ie{0}' -f 'x')` | Builds the word `iex` (Invoke-Expression) so a search for `iex` misses it |
| `"Wr"+"it"+"e-H"+...` | Splits `Write-Host` so keyword searches miss it |

**Lesson: detect the technique, not the payload.** The decoded text changes
every time; `powershell.exe` plus an encoding flag doesn't.

---

## 2. Telemetry

One run produces three useful events on `ws01`:

| Source | Event | Dataset | What it shows |
|---|---|---|---|
| Sysmon | 1 (process start) | `windows.sysmon_operational` | `process.command_line` with `-e <base64>`, parent `cmd.exe`, **`process.pe.original_file_name`** |
| Security log | 4688 (process start) | `system.security` | Same command line and args, but **no** `process.pe` fields |
| PowerShell | 4104 (script block) | `windows.powershell_operational` | The **decoded** script in `powershell.file.script_block_text` |

Discover searches used:

```
host.name : "ws01" and process.name : "powershell.exe"
host.name : "ws01" and event.code : "4688" and process.command_line : *JgAgACgA*
host.name : "ws01" and event.code : "4104" and powershell.file.script_block_text : *gcm*
```

4104 shows why script-block logging matters: encoding hides a command from the
command line, but not from PowerShell's own logging.

Which fields are actually suspicious on their own?

- **The encoded flag in `process.args`.** This is the strongest signal; admins
  rarely encode commands.
- **`process.parent.name`.** Useful context for severity, but too weak as the
  rule itself. (Test 15 later showed attackers can change the parent to
  `wmiprvse.exe` by launching through WMI.)

---

## 3. Build the detection

**Rule type: Event Correlation (EQL).** KQL's exact matches are case-sensitive
(`-e` wouldn't match `-E`). EQL's `:` operator ignores case and supports
wildcards, which makes it the precise choice even for a single-event rule.

### Final query

```
process where event.type == "start" and
  (process.name : ("powershell.exe", "pwsh.exe") or
   ?process.pe.original_file_name : ("PowerShell.EXE", "pwsh.dll")) and
  process.args : ("?e", "?ec", "?en", "?enc", "?enco", "?encod", "?encode", "?encoded",
                  "?encodedc", "?encodedco", "?encodedcom", "?encodedcomm",
                  "?encodedcomma", "?encodedcomman", "?encodedcommand")
```

| Part | Why |
|---|---|
| `event.type == "start"` | Process starts only |
| `process.name : (...)` | Windows PowerShell and PowerShell 7 |
| `?process.pe.original_file_name : (...)` | The name built into the program file, which still matches if PowerShell is copied to another name. The leading `?` marks the field **optional**, so the query is still valid against sources that lack it. |
| `process.args : ("?e", ...)` | Every valid abbreviation of `-EncodedCommand`, **exact** (no `*`), with `?` (any one character) standing in for the dash |

`?` means two different things here. Before a field name it means "optional
field"; inside a quoted value it means "any single character".

### Rule settings

| Setting | Value |
|---|---|
| Index patterns | `logs-windows.sysmon_operational-*` (typed by hand, see §4 bug 3) |
| Name | `PowerShell Encoded Command Execution` |
| Severity / risk | Medium / 47 |
| MITRE ATT&CK | Execution (TA0002) → T1059 → T1059.001 |
| Schedule | Every 5 minutes, 1 minute additional look-back |
| False positive example | Some management and deployment tools launch PowerShell with -EncodedCommand |
| Investigation guide | Triage steps, notes, known false positives, validation (in the exported rule's `note` field) |

---

## 4. Validate and tune

The query above is version 4. Each earlier version passed a quick check and was
still wrong. **Always open an alert and confirm *which* event matched and *why*.**

### Iterations

| # | Change | Found by | Problem |
|---|---|---|---|
| 1 | `process.args : ("-e", "-ec", "-en*", "/e", "/ec", "/en*")` | First version | — |
| 2 | Exact spellings plus `?` for the dash | Atomic 15 with an **en dash** (`–NoProfile –E ...`, launched via WMI) | **Gap:** the en dash isn't `-` or `/`, and PowerShell accepts it. **False positive:** `-en*` matched the test harness's own `-EncodedCommandParamVariation` argument ("right alert, wrong reason"), and would match `-Encoding UTF8` in normal scripts. |
| 3 | Add `process.pe.original_file_name` | PowerShell copied to `C:\Windows\Temp\updater.exe` | **Gap:** `process.name` was `updater.exe`. Sysmon still records `OriginalFileName: PowerShell.EXE`. |
| 4 | Make it `?process.pe.original_file_name` | Rule editor: `Unknown column [process.pe.original_file_name]` | The Security log index has no `process.pe` mapping at all (`GET logs-system.security-*/_mapping/field/process.pe*` returns `{}`) |

### Bug: the rule never searched Sysmon

After version 4, **every alert still came from `system.security`**, and none
from Sysmon, even though Rule preview and Dev Tools EQL both matched Sysmon
events and every rule run reported *Succeeded*.

Narrowing it down:

1. Alerts table (Fields → add `data_stream.dataset`) → all alerts were 4688.
2. The alerts index itself → `kibana.alert.ancestors.index` was always
   `system.security`, so Sysmon alerts were never created, not hidden.
3. The rule's query run in Dev Tools over the same window → Sysmon events
   matched, so the query was fine.
4. Kibana server log on the Elastic host → no errors.
5. The saved rule:
   ```
   GET .kibana_alerting_cases/_search?filter_path=hits.hits._source.alert.params.index
   { "query": { "match_phrase": { "alert.name": "PowerShell Encoded Command Execution" } } }
   ```
   returned `"logs-windows.sysmon_operational-* "` with a **trailing space**.

Elasticsearch silently skipped the pattern because no index matched it. That one
invisible character also caused the earlier "Unknown column" error: only the
Security index was ever searched.

**Fix:** delete the pattern and retype it by hand, pressing Enter right after the
`*`. Verify the saved value with the query above.

**Lessons:**

- A rule can report *Succeeded* on every run while missing half its data.
  Validate **per data source**, not just "it alerted".
- Check the saved configuration, not the form. Invisible characters don't show
  in the UI.

### Regression test (final)

Re-run every case after each change:

| Activity | Expected | Result |
|---|---|---|
| Atomic 17 (`-e`) | alert | ✅ |
| Atomic 15, EnDash (`–E`, via WMI) | alert | ✅ |
| `powershell.exe -ExecutionPolicy Bypass -Command "Get-Date"` | none | ✅ |
| `powershell.exe -NoProfile -Command "Get-Content C:\Windows\win.ini -Encoding UTF8"` | none | ✅ |
| Renamed copy `updater.exe -e ...` | alert | ✅ (Sysmon) |

Atomic 15 needs `-GetPrereqs` first, and is run with:

```powershell
Invoke-AtomicTest T1059.001 -TestNumbers 15 -InputArgs @{ command_line_switch_type = "EnDash"; encoded_command_param_variation = "E" }
```

**Detection latency:** up to about 6 minutes (5-minute schedule plus
ingestion).

---

## 5. Design decision: Sysmon only, plus a health rule

With both sources working, each attack produced **two** alerts (Sysmon 1 and
Security 4688). Alert suppression would merge them, but it needs a Platinum
licence or a trial, and this lab stays on the free Basic licence.

| Option | Verdict |
|---|---|
| Both sources, suppress duplicates | Needs a paid licence |
| Both sources, accept duplicates | Twice the triage work |
| **Sysmon only, plus a health rule** ✅ | One alert per attack. Sysmon also catches renamed PowerShell, which 4688 can't. |

The only reason to keep 4688 in the rule was resilience if Sysmon broke. That's
a data-health problem, so it gets its own rule:

**`Sysmon silent - ws01`** (Stack Management → Rules → *Elasticsearch
query*, free):

| Setting | Value |
|---|---|
| Query (KQL, data view `logs-*`) | `host.name : "ws01" and data_stream.dataset : "windows.sysmon_operational"` |
| Condition | `count()` IS BELOW 1 for the last 15 minutes |
| Check every | 5 minutes |

**Testing it:** `Stop-Service Sysmon64` fails, because Sysmon 15 runs as a
**protected process**. Even an administrator can't stop it that way, which is a
defence against attackers. Instead, temporarily point the query at a host that
doesn't exist (`ws01-healthtest`): the rule goes **Active**. Change it
back and it returns to **OK**.

4688 events are still collected and remain available for investigations.

---

## 6. Export

**Security → Rules → Detection rules (SIEM)** → tick the rule → **Bulk actions →
Export**. Saved as
[`../../detections/T1059.001-powershell-encoded-command.ndjson`](../../detections/T1059.001-powershell-encoded-command.ndjson)
(rule revision 7, with the investigation guide).

The health rule is a Stack rule, exported separately through Saved objects to
[`../../detections/health-sysmon-silent-ws01.ndjson`](../../detections/health-sysmon-silent-ws01.ndjson).
See the [detections README](../../detections/README.md) for how to import it. It
arrives disabled.

---

## Pitfalls hit (2026-10-04)

| Symptom | Cause | Fix |
|---|---|---|
| Atomic 10 failed with `Access is denied` | Defender blocked the command line (`Trojan:Win32/Powessere.K`) | Expected. Defender's alert is itself a finding; collect it via the Defender integration (guide 03). |
| A Discover filter on `process.parent.name : "powershell.exe"` missed Atomic 15 | The harness launches PowerShell via WMI (parent `wmiprvse.exe`) | Don't assume the parent; search by command line |
| Rule fired on the Atomic 15 harness, not the attack | `-en*` matched `-EncodedCommandParamVariation` | Exact spellings, no `*` |
| `Unknown column [process.pe.original_file_name]` | Field absent from the Security index (and, as it turned out, the Sysmon pattern wasn't being searched) | `?field` for optional fields; retype the index pattern |
| Only 4688 alerts, never Sysmon | Trailing space in the saved index pattern | Retype the pattern; verify via `.kibana_alerting_cases` |
| Alert suppression greyed out | Needs a Platinum licence | Sysmon-only rule plus a health rule |
| `Stop-Service Sysmon64` fails | Sysmon 15 is a protected process | Test the health rule with a non-existent host instead |
| Alert times don't match attack times | The Alerts table `@timestamp` is when the rule ran | Use `kibana.alert.original_time` for the event time |

## Next ideas

- Run Atomic 15 with other variations (`EmDash`, `ForwardSlash`, `EncodedCommand`)
  as extra regression cases.
- A companion rule on 4104 script-block content (e.g. `FromBase64String` +
  `iex`), so a second, independent signal covers the same technique.
- Add a `Sysmon silent` health rule for DC01.
