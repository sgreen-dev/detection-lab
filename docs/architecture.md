# Architecture

## Network

One VPC (`10.10.0.0/16` by default), split into two subnets:

```
                          Internet
                             │
                    ┌────────┴────────┐
                    │ Internet Gateway│
                    └────────┬────────┘
                             │
        ┌────────────────────┴─────────────────────┐
        │ PUBLIC subnet (10.10.1.0/24)              │
        │   • Elastic (SIEM)   ← Kibana from my_ip  │
        │   • Attack Server    ← SSH from my_ip     │
        │   • NAT Gateway ──────────────┐           │
        └───────────────────────────────┼──────────┘
                                         │ (outbound only)
        ┌───────────────────────────────┼──────────┐
        │ PRIVATE subnet (10.10.2.0/24)  ▼          │
        │   • Domain Controller (lab.local)         │
        │   • Windows Victim (domain-joined)        │
        │   • Linux Victim                          │
        └───────────────────────────────────────────┘
```

- **Public subnet** hosts get public IPs. Only Elastic (Kibana/ES ports) and the
  Attack Server (SSH) accept inbound traffic, and only from `my_ip_cidr`.
- **Private subnet** hosts have no public IP. They reach the internet outbound
  through the NAT gateway (for package installs, agent enrollment, Atomic
  downloads) but cannot be reached from the internet.
- **Inside the VPC**, all hosts talk freely, so attacks and telemetry behave like
  a real network.

## Access without open ports

Admin access uses **AWS SSM Session Manager**, not open management ports. Every
host runs the SSM agent and has an instance profile granting
`AmazonSSMManagedInstanceCore`, so you get a shell or RDP tunnel through the AWS
API. RDP (3389) and SSH (22) are also opened to `my_ip_cidr` as a fallback.

## Telemetry pipeline

```
 Windows Victim / DC ──(Sysmon + Windows event logs)──┐
 Linux Victim ─────────(auditd + system logs)─────────┤
                                                       ├──► Elastic Agent
                                                       │    (Fleet-managed)
                                                       ▼
                                              Elasticsearch  ◄── Kibana
                                                                  │
                                                          Detection rules
```

Elastic Agent is enrolled against Fleet (running on the Elastic node) and ships
each host's telemetry into Elasticsearch, where you query it and build detection
rules in Kibana's Security app.

## What Terraform does and does not do

**Does:** VPC, subnets, gateways, routing, security groups, IAM/SSM, the five
EC2 instances, generated credentials in SSM Parameter Store, and setting the
Windows Administrator password on first boot.

**Does not:** anything inside a host. Installing Elastic, enrolling agents,
configuring Sysmon/auditd, building Active Directory, and installing Atomic Red
Team are all manual, and are what the Build Guides teach.
