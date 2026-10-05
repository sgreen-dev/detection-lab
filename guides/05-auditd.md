---
guide: 05
title: auditd on the Linux Victim
last_verified: 2026-10-02
verified_versions:
  auditd_rules: Neo23x0/auditd (master)
status: complete
---

# 05 — auditd on Linux

> ✅ **STATUS: complete.** Walked end to end on 2026-10-02.

**Goal:** enable Linux auditing on the Linux Victim, start with a few
hand-written rules so you understand the syscall model, then adopt the mature
Neo23x0 best-practice ruleset, and confirm events reach Elastic.

## Why build up by hand first

Writing your first `-a exit,always` rules teaches what a syscall audit rule
actually matches. Only then layer in the comprehensive set, so it isn't magic.

## Outline (on the Linux Victim, as root)

```bash
# 1. Install auditd
apt-get update && apt-get install -y auditd audispd-plugins
systemctl enable --now auditd

# 2. Start with a couple of hand-written rules to learn the model
#    Watch execution of a sensitive binary and reads of /etc/shadow:
auditctl -a always,exit -F arch=b64 -S execve -k exec_watch
auditctl -w /etc/shadow -p r -k shadow_read
auditctl -l                       # list active rules
# generate an event, then:
ausearch -k shadow_read

# 3. Adopt the Neo23x0 best-practice ruleset (pin a commit for reproducibility)
curl -fsSL https://raw.githubusercontent.com/Neo23x0/auditd/master/audit.rules \
  -o /etc/audit/rules.d/audit.rules
augenrules --load        # or: service auditd restart
auditctl -l | head
```

## Ship to Elastic

Collect auditd via the Elastic Agent **auditd** integration (or the *System*
integration's audit options) in the agent policy from guide 02. Record the exact
integration settings here.

## Verify

In Kibana → Discover, filter for auditd events (e.g. `event.module: "auditd"`).
Run a watched command and confirm it shows up with its `key` (the `-k` tag).

## Open questions

- Pin the Neo23x0 ruleset to a specific commit in `versions.yml` for reproducibility.
- Reconcile noisy rules with the lab's needs (the full set is chatty).

## Next

[`06-atomic-red-team.md`](./06-atomic-red-team.md)
