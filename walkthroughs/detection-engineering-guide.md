---
title: Detection engineering guide
last_verified: null
verified_versions:
  elastic_stack: 8.19.22
status: draft
---

# Detection Engineering Guide

> 📝 **STATUS: draft, incomplete.** Sections 1–2 written 2026-10-04; it stops
> partway through section 3, so the worked example and practice path promised
> below don't exist yet. Not yet walked end to end. Field names are standard Elastic (ECS) fields, but confirm
> each one in Discover before relying on it. Doing that is part of the skill.

**Who this is for:** you've built the Lab (guides 01–06) and run an Atomic or
two. Now you want to write Detections the way a detection engineer does at
work, not just paste queries.

**What you'll be able to do by the end:**

- Turn "I want to catch X" into a testable hypothesis.
- Find the evidence an Attack leaves in the SIEM, and know which fields matter.
- Write queries in KQL and EQL, and choose the right Kibana rule type.
- Prove a Detection works (true positives) **and** doesn't fire on normal
  activity (false positives).
- Tune it, document it, and save it as code in [`../detections/`](../detections/).

The worked example is encoded PowerShell (ATT&CK T1059.001), because you've
already run it. The practice path at the end takes you through eight more
Detections, from easy to hard, all using data this Lab already collects.

---

## 1. The detection lifecycle

Every Detection, at every company, goes around the same loop:

```
 Hypothesis ──► Attack ──► Find telemetry ──► Write query ──► Make it a rule
     ▲                                                              │
     │                                                              ▼
 Document & export ◄── Tune ◄── Check false positives ◄── Check true positives
```

| Step | Question you answer |
|---|---|
| **Hypothesis** | What behaviour am I trying to catch, and why is it suspicious? |
| **Attack** | Can I reproduce it safely? (an Atomic, or a manual command) |
| **Find telemetry** | Which events did it create, and which fields prove it? |
| **Write query** | What's the smallest query that matches the bad thing? |
| **Make it a rule** | Which rule type fits? How often should it run? How bad is it? |
| **True positives** | Does it fire on the Attack *and* on the variations of it? |
| **False positives** | Does it stay quiet during normal admin work? |
| **Tune** | What do I exclude, and is each exclusion safe? |
| **Document & export** | Could someone else understand, triage and maintain this? |

New detection engineers usually skip the last four steps. Those four steps are
what make a Detection something you can trust.

---

## 2. Know your data

You can only detect what you collect. This Lab collects the following:

| Source | From | `data_stream.dataset` | Events worth knowing |
|---|---|---|---|
| Sysmon | Windows Victim, Domain Controller | `windows.sysmon_operational` | **1** process start, **3** network connection, **11** file created, **13** registry value set |
| Windows Security log | Windows Victim, Domain Controller | `system.security` | **4624** / **4625** logon ok / failed, **4688** process start, **4720** user created, **4728/4732** added to group, **4769** Kerberos service ticket, **4776** NTLM credential check |
| PowerShell Operational | Windows Victim, Domain Controller | `windows.powershell_operational` | **4104** script block (the actual script text, decoded) |
| Defender | Windows Victim, Domain Controller | `windows_defender` | **1116** threat found, **1117** action taken, **5001** real-time protection turned off |
| auditd | Linux Victim | `auditd.*` (check in Discover) | Syscalls and file watches from the Neo23x0 rules; each rule has a **key** |
| System (Linux) | Linux Victim | `system.auth`, `system.syslog` | sudo, SSH logons, `useradd` |

The Defender source exists only if you did the "Add Windows Defender alerts" step
in [guide 03](../guides/03-sysmon.md).

### The fields you'll use most

Elastic normalises every source into the **Elastic Common Schema (ECS)**. A
process start from Sysmon and one from the Security log use the same field
names, so one query can cover both.

| Field | Example | Use it for |
|---|---|---|
| `host.name` | `win-victim` | Which machine |
| `user.name` | `alice` | Who did it |
| `event.code` | `1`, `4688`, `4104` | Which Windows event ID |
| `event.category` / `event.type` | `process` / `start` | What kind of event (source-independent) |
| `process.name` | `powershell.exe` | The program that ran |
| `process.command_line` | `powershell.exe -e JABz...` | Full command, as one string |
| `process.args` | `["powershell.exe", "-e", "JABz..."]` | The same command split into an array, easier to match exactly |
| `process.parent.name` | `cmd.exe` | What launched it. Often the most telling field of all. |
| `process.pe.original_file_name` | `PowerShell.EXE` | The name baked into the program file. Still correct when an attacker renames it. |
| `powershell.file.script_block_text` | `Set-Content ...` | Decoded PowerShell from 4104 |
| `winlog.event_data.*` | `TicketEncryptionType` | Raw Windows fields that ECS doesn't map |

### Exercise: learn to read an event

1. Run one Atomic on the Windows Victim and note the time.
2. In **Discover**, choose the `logs-*` data view, set the time range to cover
   your run, and search `host.name : "win-victim" and event.code : "1"`.
3. Open one event (the expand arrow on the left) and read **every field**. Find
   the parent process, the user, the full command line and the hashes.
4. In the left sidebar, click a field name such as `process.parent.name` to see
   its top values. That's how you learn what "normal" looks like on a machine.

---

## 3. Query languages and rule types

### KQL vs EQL

| | KQL (Kibana Query Language) | EQL (Event Query Language) |
|---|---|---|
| Used in | Discover search bar, *Custom query* rules | *Event correlation* rules, Timeline |
| Good for | Quick searches, simple single-event rules | Precise matching, and **sequences** of events |

*(Unfinished: the rest of section 3 and later sections are not written yet.)*
