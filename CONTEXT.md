# Detection Lab

A self-hosted, Terraform-provisioned lab for learning security detection engineering by running attacks against victim machines and building detections for them in a SIEM.

## Language

### Infrastructure

**Lab**:
The complete set of machines, network, and SIEM that make up one environment. Terraform provisions only the bare infrastructure (VMs, network, firewall); the Learner builds everything inside the boxes by hand from Build Guides.
_Avoid_: Range, environment, stack

**Domain Controller**:
The Windows Active Directory server that the Windows Victim is joined to.
_Avoid_: AD server, DC (in prose)

**Victim**:
A machine that attacks are run against and whose telemetry the SIEM collects. There is a Windows Victim and a Linux Victim.
_Avoid_: Target, endpoint, host

**Attack Server**:
The Linux machine the learner operates from to launch attacks against Victims.
_Avoid_: Attacker box, Kali, red box

**SIEM**:
The system that ingests Victim telemetry and where Detections are authored and run.
_Avoid_: Log platform, dashboard

### Learning

**Build Guide**:
A detailed, ground-up instruction document for standing up one Lab component from a bare Terraform-provisioned VM: installing Elastic, enrolling agents, configuring Sysmon and auditd, building Active Directory, installing Atomic Red Team. The Learner types every step to learn how the pipeline is assembled.
_Avoid_: Setup script, runbook, install guide

**Attack**:
A single adversary technique executed against a Victim, usually mapped to a MITRE ATT&CK technique ID.
_Avoid_: Test, scenario, exploit

**ATT&CK Technique**:
An entry in the MITRE ATT&CK taxonomy, identified by a T-number (e.g. T1059.001). Walkthroughs and detections are indexed by it.
_Avoid_: TTP, tactic (a tactic is the broader category), technique ID in prose

**Atomic**:
An Atomic Red Team test: a scripted, self-contained execution of one Attack.
_Avoid_: ART test, script

**Detection**:
A SIEM rule or query that fires when the telemetry of an Attack is observed.
_Avoid_: Alert, signature, use case

**Walkthrough**:
A guided document that teaches the Learner to author a Detection: they run an Attack to generate telemetry, then build and validate the Detection against it, typing the commands that matter themselves. Attacks are chosen freely by the Learner; Walkthroughs center on the detection-engineering craft, not a fixed attack list.
_Avoid_: Tutorial, lab exercise, playbook

**Learner**:
The person operating the Lab to gain detection-engineering experience.
_Avoid_: User, student, analyst
