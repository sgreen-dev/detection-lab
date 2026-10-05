---
guide: 06
title: Install Atomic Red Team on the Victims
last_verified: 2026-10-02
verified_versions:
  invoke_atomic_red_team: 2.3.0
status: complete
---

# 06 — Atomic Red Team

> ✅ **STATUS: complete.** Windows and Linux installs walked 2026-10-02. The
> Verify step is done as part of the T1059.001 walkthrough.

**Goal:** install the `Invoke-AtomicRedTeam` framework on both Victims so you can
run any attack with a single uniform command, then confirm a test fires and shows
up as telemetry in Elastic.

## Install

### Windows Victim (elevated PowerShell)

Verified on WIN-VICTIM 2026-10-02. Run each line on its own, in order.

**1. Install the prerequisites first, so nothing prompts.** The framework needs
the `powershell-yaml` module (atomics are YAML files), which comes through the
NuGet package provider. If you skip this, the installer stops at a
`NuGet provider is required… [Y] Yes [N] No` prompt that an SSM session doesn't
answer reliably, and fails with
`The required module 'powershell-yaml' is not loaded`.

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
```
```powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```
```powershell
Install-Module -Name powershell-yaml -Scope AllUsers -Force
```

**2. Exclude the Atomic Red Team folders from Windows Defender.** The atomics
contain real attack samples. Without this, Defender blocks the download zip and
the install fails with
`Installation of the AtomicsFolder Failed … the file contains a virus or potentially unwanted software`.
The zip lands in `$env:TEMP` before extraction, hence the second path.

```powershell
Add-MpPreference -ExclusionPath "C:\AtomicRedTeam", $env:TEMP
```

Defender still protects everything else, and its alerts (Windows Defender
log, event 1116) are useful detection data in their own right.

**3. Install.** Keep it on one line. The backtick-continued two-line version
breaks easily when pasted.

```powershell
IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); Install-AtomicRedTeam -getAtomics -Force
```

Installs the module and downloads the `atomics/` test definitions to
`C:\AtomicRedTeam`. `-Force` overwrites a half-finished earlier attempt.

> **Module installed but atomics failed?** The installer still ends with
> "Installation of Invoke-AtomicRedTeam is complete" even if the atomics step
> failed. Rerun just the atomics. `Install-AtomicsFolder` lives in its own script,
> not in the module, so `Import-Module` alone won't find it:
>
> ```powershell
> IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicsfolder.ps1' -UseBasicParsing); Install-AtomicsFolder -Force
> ```

**4. Check:**

```powershell
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force; (Get-ChildItem C:\AtomicRedTeam\atomics).Count; Invoke-AtomicTest T1059.001 -ShowDetailsBrief
```

Expect a count in the hundreds, then a list of T1059.001 tests.

Optionally, once the atomics are in place, drop the temp exclusion:
`Remove-MpPreference -ExclusionPath $env:TEMP`.

### Linux Victim (requires PowerShell 7)

Run as root (`sudo -i` first). Run each line on its own, in order. **Paste only
the commands, never the output.** If error text gets pasted back in, bash tries
to run each line and prints a burst of `command not found` and
`syntax error near unexpected token` messages. Those are harmless noise.

**1. Install PowerShell 7.** `pwsh` isn't on Ubuntu by default. Without it,
step 3 fails with `Command 'pwsh' not found`.

```bash
source /etc/os-release; wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb; dpkg -i packages-microsoft-prod.deb; apt-get update; apt-get install -y powershell
```
```bash
pwsh --version
```

**2. Install the prerequisite** so nothing prompts (same reason as Windows step 1):

```bash
pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name powershell-yaml -Scope AllUsers -Force"
```

**3. Install Atomic Red Team:**

```bash
pwsh -Command "IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing); Install-AtomicRedTeam -getAtomics -Force"
```

Atomics land in `~/AtomicRedTeam` (`/root/AtomicRedTeam` as root).

**4. Check.** T1059.004 is Unix shell; most T1059.001 tests are Windows-only.

```bash
ls ~/AtomicRedTeam/atomics | wc -l; pwsh -Command "Import-Module ~/AtomicRedTeam/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1; Invoke-AtomicTest T1059.004 -ShowDetailsBrief"
```

## The command that matters

Once installed, every attack runs through one interface, identical on both OSes.

**Load the module first, by full path, in every new session.** It lives in
`C:\AtomicRedTeam` (or `~/AtomicRedTeam`), which isn't in PowerShell's module
search path, so `Import-Module invoke-atomicredteam` fails with
`no valid module file was found`, and `Invoke-AtomicTest` is "not recognized".

```powershell
# Windows
Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
```
```bash
# Linux (as root): start pwsh, then import
pwsh
Import-Module ~/AtomicRedTeam/invoke-atomicredteam/Invoke-AtomicRedTeam.psd1 -Force
```

To make it load automatically in every new Windows session (run once):

```powershell
New-Item -ItemType File -Path $PROFILE.AllUsersAllHosts -Force | Out-Null; Add-Content $PROFILE.AllUsersAllHosts 'Import-Module "C:\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force'
```

Then:

```powershell
Invoke-AtomicTest T1059.001 -ShowDetails      # inspect what it will do
Invoke-AtomicTest T1059.001                   # run it
Invoke-AtomicTest T1059.001 -Cleanup          # undo it
```

> Only run attacks you understand, and only in this lab. `-ShowDetails` first,
> every time.

## Cheat sheet

Each **technique** (e.g. T1059.001, PowerShell) contains several numbered
**tests**, each a different way of doing it. With no test selected,
`Invoke-AtomicTest <technique>` runs **all** of them. Run one test at a time, so
you know which events in Kibana came from which test.

### `Invoke-AtomicTest` flags

**Look before you run (read-only):**

| Flag | What it does |
|---|---|
| `-ShowDetailsBrief` | One line per test: number and name |
| `-ShowDetails` | Full detail: description, exact commands, cleanup commands, inputs |
| `-anyOS` | With the two above, also list tests for other OSes |

**Pick which tests:**

| Flag | Example |
|---|---|
| `-TestNumbers` | `-TestNumbers 17` or `-TestNumbers 10,15,17` |
| `-TestNames` | `-TestNames "PowerShell Command Execution"` |
| `-TestGuids` | `-TestGuids <guid>` (GUIDs shown by `-ShowDetails`) |
| *(none)* | Runs **every** test for the technique, so avoid this |

**Prerequisites:**

| Flag | What it does |
|---|---|
| `-CheckPrereqs` | Reports whether requirements are met. Changes nothing. |
| `-GetPrereqs` | Downloads or installs what's missing |

**Run and undo:**

| Flag | What it does |
|---|---|
| *(no flag)* | Runs the attack |
| `-Cleanup` | Runs the test's undo commands |
| `-TimeoutSeconds 120` | Kills a test that runs too long (default 120) |
| `-Interactive` | Shows live output, and lets you answer if the test prompts |
| `-InputArgs @{ name = "value" }` | Overrides one of the test's input arguments (e.g. a file path) |
| `-PromptForInputArgs` | Asks for each input argument instead |

**Logging:**

| Flag | What it does |
|---|---|
| `-ExecutionLogPath C:\temp\art.csv` | Where to write the run log (time, host, test, command). Handy for matching a run to its events in Kibana. |
| `-NoExecutionLog` | Don't write a log |

### Typical sequence for one test

```powershell
Invoke-AtomicTest T1059.001 -ShowDetailsBrief
Invoke-AtomicTest T1059.001 -TestNumbers 17 -ShowDetails
Invoke-AtomicTest T1059.001 -TestNumbers 17 -CheckPrereqs
Invoke-AtomicTest T1059.001 -TestNumbers 17
Invoke-AtomicTest T1059.001 -TestNumbers 17 -Cleanup
```

Run each line on its own.

### Other commands

| Command | What it does |
|---|---|
| `Get-ChildItem C:\AtomicRedTeam\atomics -Directory \| Select-Object -Expand Name` | Lists every technique ID you have tests for |
| `Install-AtomicRedTeam -getAtomics -Force` | Reinstalls the framework and atomics |
| `Install-AtomicsFolder -Force` | Re-downloads just the atomics (separate script; see the recovery note in Install) |
| `Get-Help Invoke-AtomicTest -Full` | Built-in help listing every flag |

> **Never run `Invoke-AtomicTest All`.** It runs every test for every technique.

## Verify

Run a benign test (e.g. a T1059.001 PowerShell atomic) and confirm the resulting
process-creation event appears in Kibana. That end-to-end path — atomic on the
Victim to event in the SIEM — is what proves the whole lab works.

## Next

The lab is built. Go to [`../walkthroughs/`](../walkthroughs/) and author your
first detection: [T1059.001 (PowerShell)](../walkthroughs/T1059.001-powershell/).
