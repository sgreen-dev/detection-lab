---
guide: 02
title: Fleet Server and Elastic Agent enrollment
last_verified: 2026-09-27
verified_versions:
  elastic_stack: 8.19.22
status: complete
---

# 02 — Fleet & Elastic Agent

> ✅ **STATUS: complete.** Walked end to end on 2026-09-16 (8.19.21) and again on 2026-09-27 against Elastic 8.19.22.

**Goal:** turn on Fleet in Kibana, run a Fleet Server on the Elastic host, then
enroll a Fleet-managed Elastic Agent on the DC, both Victims, and (optionally)
the Attack Server, so telemetry flows into Elasticsearch.

## Outline

1. **Enable Fleet.** In Kibana → **Fleet**. On first visit it initializes.
2. **Add a Fleet Server.** Fleet → Agents → *Add Fleet Server* → **Quick Start**.
   Enter `https://<elastic-private-ip>:8220` as the Fleet Server host
   (`terraform output elastic_private_ip`), then *Generate Fleet Server policy*.
   Kibana then shows a ready-made **Linux** command block that downloads the
   agent, `cd`s into its folder, and runs `sudo ./elastic-agent install ...` with
   your real service token, policy, and CA fingerprint already filled in.

   > ⚠️ **Don't type the command yourself. Use Kibana's Copy button.** Every
   > value in it is specific to your install, and `<placeholders>` typed
   > literally fail with `-bash: token: No such file or directory`.

   Paste the whole block into an SSM session **on the Elastic host** (not your
   own PC). The binary only exists inside the downloaded folder, so running
   `elastic-agent` from anywhere else fails. No `--insecure` here; that's only
   for the agents in step 3.
3. **Enroll agents on each host** (run as root/admin on that host). Get the exact
   command from Kibana's *Add agent* flyout; the shape is:
   ```bash
   # Linux Victim
   elastic-agent install --url=https://<elastic-private-ip>:8220 \
     --enrollment-token=<token> --insecure
   ```
   ```powershell
   # Windows hosts (elevated PowerShell) — command comes from the flyout
   ```
   Use the **private** IP of the Elastic host (`terraform output elastic_private_ip`);
   agents reach it inside the VPC.

   Pitfalls hit on 2026-09-27:
   - Run the commands **inside an SSM session on the target host**, not on your PC.
   - Match the flyout tab to the host's OS. Windows commands (`Invoke-WebRequest`,
     `.exe`) fail on Linux with `not found`.
   - On Windows, **remove `--unprivileged`** if the flyout adds it. An unprivileged
     agent can't read the Security and Sysmon event logs.

   Pitfalls hit on 2026-10-02:
   - **Add `--insecure` yourself.** The flyout leaves it off, and the install then
     hangs at *Waiting For Enroll...* repeating `x509: certificate signed by unknown
     authority`. See the resolved question below for the why and the cleanup.
   - **The Windows flyout block can paste as one long line.** If the line breaks
     are lost, PowerShell fails with `Unexpected token 'Invoke-WebRequest'` and
     nothing runs. Join the commands with `;` on a single line instead, e.g.
     (your version, token and IP will differ):
     ```powershell
     $ProgressPreference = 'SilentlyContinue'; cd $env:TEMP; Invoke-WebRequest -Uri https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.19.22-windows-x86_64.zip -OutFile elastic-agent-8.19.22-windows-x86_64.zip; Expand-Archive .\elastic-agent-8.19.22-windows-x86_64.zip -DestinationPath . -Force; cd elastic-agent-8.19.22-windows-x86_64; .\elastic-agent.exe install --url=https://<elastic-private-ip>:8220 --enrollment-token=<token> --insecure
     ```
   - "Root" on Windows means an **Administrator** PowerShell. SSM sessions already
     run as `ssm-user`, a local administrator, so nothing extra is needed there.
4. **Add integrations to the agent policy:** *System*, *Windows*, and later the
   Sysmon and auditd data (guides 03 and 05). Integrations are what actually
   define which logs are collected.
5. **Verify:** Fleet → Agents shows each host *Healthy*; Kibana → Discover shows
   documents in `logs-*`.

## Open questions to resolve while writing this

- ~~Exact TLS trust flags for enrolling against a self-signed Fleet Server.~~
  **Resolved (2026-09-16):** Fleet Server (Quick Start) uses a self-signed cert.
  Every `elastic-agent install --url=... --enrollment-token=...` command MUST
  end with `--insecure`, on Linux and Windows. Kibana's *Add agent* flyout does
  not add it. Without it enrollment loops forever on
  `x509: certificate signed by unknown authority`, because the agent doesn't
  trust the self-signed cert and treats that as a temporary error (it retries
  with backoff up to 10 minutes and never gives up). If that happens, `Ctrl+C`,
  uninstall, and rerun the install with `--insecure`:
  - Linux: `sudo /opt/Elastic/Agent/elastic-agent uninstall -f`
  - Windows: `& "C:\Program Files\Elastic\Agent\elastic-agent.exe" uninstall -f`
  The Fleet Server install on the Elastic host itself does not need it; it
  uses `--fleet-server-es-ca-trusted-fingerprint` instead.
- ~~Whether to install an agent on the Attack Server.~~ **Resolved
  (2026-10-05):** yes. It's enrolled on the `lab-linux` policy (same as
  srv01, with `--insecure`), so attacker-side activity is logged too.
  Rename it to `atk01` first (guide 04, "give hosts readable names").

## Next

[`03-sysmon.md`](./03-sysmon.md)
