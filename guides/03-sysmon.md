---
guide: 03
title: Sysmon with the SwiftOnSecurity config
last_verified: 2026-09-16
verified_versions:
  sysmon: v15.22
  sysmon_config_commit: 1836897f12fbd6a0a473665ef6abc34a6b497e31
status: complete
---

# 03 — Sysmon on Windows

> ✅ **STATUS: complete.** Walked end to end on 2026-09-16 against Elastic 8.19.21.

**Goal:** install Sysmon on the Domain Controller and Windows Victim with the
SwiftOnSecurity config, and confirm Sysmon events reach Elastic via the agent.

## Why SwiftOnSecurity's config

It is heavily commented — you can read *why* each event is captured or dropped.
That teaching value is the reason we start here. Once you understand the fields,
graduate to `OlafHartong/sysmon-modular` (ATT&CK-tagged, more comprehensive).

## Outline (elevated PowerShell on each Windows host)

```powershell
# 1. Download Sysmon (Sysinternals)
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile Sysmon.zip
Expand-Archive Sysmon.zip -DestinationPath C:\Sysmon

# 2. Download the pinned SwiftOnSecurity config
Invoke-WebRequest `
  https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/1836897f12fbd6a0a473665ef6abc34a6b497e31/sysmonconfig-export.xml `
  -OutFile C:\Sysmon\sysmonconfig.xml

# 3. Install with the config
C:\Sysmon\Sysmon64.exe -accepteula -i C:\Sysmon\sysmonconfig.xml

# To update the config later: Sysmon64.exe -c C:\Sysmon\sysmonconfig.xml
```

Sysmon logs to **Microsoft-Windows-Sysmon/Operational** (Event IDs: 1 process
create, 3 network, 11 file create, etc.).

## Ship to Elastic

Sysmon events come from a Windows event channel, so collection is configured in
the **agent policy** (guide 02), not on the host. Nothing else is needed on the
host once Sysmon is installed.

**Integration used: Elastic *Windows* integration, default settings.** Added in
Kibana via Fleet → Agent policies → *your policy* → **Add integration** →
search "Windows" → *Add Windows* → keep every toggle at its default → *Save and
continue*. Both Windows hosts pick it up on the next check-in (about a minute).

Out of the box the Windows integration collects these channels:

| Channel | Data stream |
|---|---|
| `Microsoft-Windows-Sysmon/Operational` | `logs-windows.sysmon_operational` |
| `Microsoft-Windows-PowerShell/Operational` | `logs-windows.powershell_operational` |
| `Windows PowerShell` | `logs-windows.powershell` |
| `ForwardedEvents` | `logs-windows.forwarded` |

The *System* integration (added with the policy) covers `Security`,
`Application` and `System`.

### Add Windows Defender alerts

Neither integration collects **Microsoft Defender** alerts. They live in their
own channel, `Microsoft-Windows-Windows Defender/Operational`. Without it, an
attack that Defender blocks leaves no trace in Elastic, and Sysmon/4688 won't
show it either, because the blocked process never starts. (Found 2026-10-04:
Atomic T1059.001 test 10 was blocked as `Trojan:Win32/Powessere.K` and nothing
reached Kibana.)

Fleet → Agent policies → *your policy* → **Add integration** → search
**Custom Windows Event Logs** → *Add*:

| Setting | Value |
|---|---|
| Integration name | `windows-defender` |
| Channel name | `Microsoft-Windows-Windows Defender/Operational` (exact, with the spaces) |
| Dataset name | `windows_defender` |

*Save and continue* → *Save and deploy*. Both Windows hosts pick it up within a
minute.

Key event IDs: **1116** (threat detected), **1117** (action taken, e.g. blocked
or removed), **5001** (real-time protection turned off). 5001 is worth
detecting in its own right.

**Check** in Discover:

```
data_stream.dataset : "windows_defender" and event.code : ("1116" or "1117")
```

The threat name and blocked command line are in `message`.

### Confirm what a host collects

To confirm what a host is actually collecting, run on that host (elevated). It
lists every event log channel the agent reads:

```powershell
& "C:\Program Files\Elastic\Agent\elastic-agent.exe" inspect | Select-String -Pattern "^\s+name: "
```

## Verify

In Kibana → Discover, filter for Sysmon process-creation events (e.g.
`event.provider: "Microsoft-Windows-Sysmon"` and `event.code: "1"`). Open a few
processes on the host to generate events and watch them arrive.

## Next

[`04-active-directory.md`](./04-active-directory.md)
