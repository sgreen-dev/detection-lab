# 2026-10-02 — Rebuild, AD, auditd, Atomic Red Team

**Outcome:** the lab is fully built. Guides 01–06 are done. Active Directory is
up (`lab.local`), WIN-VICTIM is joined, auditd is on linux-victim, and Atomic
Red Team is installed on both Victims. The lab was **parked** at the end of the
session: all 5 instances stopped and the NAT gateway removed (confirmed).

Between 2026-09-16 and today the lab was destroyed and re-applied (2026-09-27),
then the park/unpark scripts were added (2026-09-29). That's why the instance
IDs and IPs differ from the 09-16 log.

## Lab inventory

| Host | Instance ID | Private IP | Hostname |
|---|---|---|---|
| Elastic (Fleet Server) | i-014927d00b14aabfd | 10.10.1.129 | ip-10-10-1-129 |
| Domain Controller | i-002d3545991c4ee38 | 10.10.2.234 | DC01 (`lab.local`, NetBIOS `LAB`) |
| Windows Victim | i-0c19ed6bfb6f62a87 | 10.10.2.220 | WIN-VICTIM (joined to `lab.local`) |
| Linux Victim | i-0d0600cc47f2a9f22 | 10.10.2.232 | linux-victim |
| Attack Server | i-031719438393fa168 | 10.10.1.163 | ip-10-10-1-163 (no agent, by choice) |

Fleet Server URL used by agents: `https://10.10.1.129:8220`. Private IPs survive
park/unpark; they only change after a `terraform destroy` and re-apply.

## State at end of session

Checked directly on each host over SSM before parking, except where marked
*(user-reported)*.

| Area | State |
|---|---|
| Elastic Agent | Healthy on DC01, WIN-VICTIM, linux-victim, and Fleet Server on the Elastic host |
| Sysmon | Running on DC01 and WIN-VICTIM |
| AD | `lab.local` forest. Users `labadmin` (Domain Admins), `svc_sql` (SPN `MSSQLSvc/sql.lab.local:1433`), `alice`, `bob`. Computers DC01, WIN-VICTIM. |
| Audit policy | GPO **Lab Audit Logging** (script block logging + command line in 4688) applies to both Windows hosts. `auditpol` categories set on DC01. On WIN-VICTIM they were missing at last check and then set *(user-reported)*. |
| auditd | Active on linux-victim, 206 rules (Neo23x0 ruleset) |
| Atomic Red Team (Windows) | WIN-VICTIM: module plus 346 atomics in `C:\AtomicRedTeam`. Defender exclusions on `C:\AtomicRedTeam` and `$env:TEMP`. |
| Atomic Red Team (Linux) | linux-victim: PowerShell 7.6.6 and `powershell-yaml` checked. ART install in `/root/AtomicRedTeam` *(user-reported)*. |
| First attack | **T1059.001 test 17** (PowerShell Command Execution, an encoded command) run on WIN-VICTIM before parking *(user-reported)*. **Its events were not found in Kibana yet**; left for next session. |

## Problems hit (and where the fix is recorded)

| Problem | Cause | Fix / recorded in |
|---|---|---|
| Enroll stuck on `x509: certificate signed by unknown authority` | `--insecure` missing from Kibana's command | guide 02 step 3 pitfalls |
| `Unexpected token 'Invoke-WebRequest'` | Windows enroll block pasted as one line | guide 02, single-line `;` version |
| Ran `sudo` / Linux paths on the wrong machine | Mixed up which SSM window was which host | `PS C:\>` = Windows, `root@linux-victim` / `$` = Linux |
| Static IP / DNS delegation / NT4 crypto warnings during DC promotion | Expected on AWS | guide 04, warnings note |
| `Get-Credential` stuck at a bare `Credential` prompt; join never happened | No GUI pop-up in SSM | guide 04, PSCredential-from-SSM one-liner, `NetSetup.LOG` tip |
| `powershell-yaml is not loaded` | NuGet `[Y/N]` prompt not answered in SSM | guide 06 step 1 prerequisites |
| `file contains a virus or potentially unwanted software` | Defender blocked the atomics zip | guide 06 step 2 exclusions |
| `Install-AtomicsFolder` not recognized | It's a separate script, not in the module | guide 06 recovery note |
| `Import-Module invoke-atomicredteam` / `Invoke-AtomicTest` not found | Module isn't on PowerShell's search path | guide 06, import by full path or profile line |
| `Command 'pwsh' not found` on Linux | PowerShell 7 not installed | guide 06 Linux step 1 |
| `powershell-yaml ... currently in use` | Already installed; harmless | none needed |

## Next session: start-up checklist

From the repo root on your PC:

1. `$env:AWS_PROFILE = "lab-sso"`. If commands say the token expired, run
   `aws sso login --profile lab-sso`.
2. `.\scripts\unpark.ps1`. This recreates the NAT gateway and starts all 5
   hosts (a few minutes).
3. **Wait ~5 minutes** for Windows to finish booting. DC01 must be up before
   WIN-VICTIM can log on to the domain.
4. Open the Kibana tunnel using the command `unpark.ps1` prints. Leave that
   window open, then browse to `http://localhost:5601`.
5. **Check:** Fleet → Agents shows DC01, WIN-VICTIM and linux-victim
   **Healthy**. If one is Offline, give it a few more minutes. Restart its
   agent only if it stays Offline.
6. Open an SSM session to the host you need:
   `aws ssm start-session --region us-east-1 --target <instance-id>` (IDs above).

## Next session: what to do

Continue the first detection walkthrough,
[T1059.001 PowerShell](../walkthroughs/T1059.001-powershell/). Step 1 (Attack)
is done: test 17 was run on 2026-10-02.

1. **Telemetry (walkthrough section 2).** In Kibana Discover, set the time range
   to cover 2026-10-02 and search:
   `host.name : "win-victim" and event.code : ("1" or "4688" or "4104")`.
   Look for `powershell.exe` with `-e` / `-EncodedCommand` in
   `process.command_line`, and the decoded script text in the 4104 event
   (`powershell.file.script_block_text`). Finding these also completes the
   guide 06 **Verify** step.
   These events weren't found on 2026-10-02. If they still don't show up,
   widen the time range, try `host.name : *victim*`, then re-run the test
   (WIN-VICTIM, after loading the module):
   `Invoke-AtomicTest T1059.001 -TestNumbers 17`, then `-Cleanup`.
2. **Build the detection (section 3).** Write a rule that catches encoded
   PowerShell without catching normal admin PowerShell.
3. **Validate (section 4)** by re-running test 17 and some harmless PowerShell,
   then **export** the rule into `detections/` (section 5).

Good follow-ups: tests 10 (fileless script) and 15 (`-EncodedCommand`
variations; run `-GetPrereqs` first). Avoid 1 and 4 (Mimikatz) and the
BloodHound/download tests for now.

## End of session

`.\scripts\park.ps1`. **Park, don't destroy.** `terraform destroy` wipes all of
the hand-built work above.
