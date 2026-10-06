---
guide: 01
title: Stand up Elastic (Elasticsearch + Kibana)
last_verified: 2026-09-27
verified_versions:
  elastic_stack: 8.19.22
  os: Ubuntu 22.04 LTS
status: complete
---

# 01 — Stand up Elastic (the SIEM)

**Goal:** install a single-node Elasticsearch and Kibana on the Elastic host by
hand, log into Kibana as the `elastic` user, and confirm the cluster is healthy.
This is the foundation everything else ships telemetry into.

**Time:** ~30 minutes. **Prerequisite:** `terraform apply` has finished.

> All commands run **on the Elastic host**, as root, unless noted. Everything you
> type here is the point of the exercise — read each step, don't paste blindly.

---

## 0. Know your versions

This guide is pinned to the versions in [`../versions.yml`](../versions.yml).
Elastic 8.19.x is the final 8.x line; Elastic's live docs now default to 9.x, so
we deliberately add the **8.x** apt repository below. If you bump the version,
re-walk this guide and update the `last_verified` date above.

## 1. Connect to the Elastic host

From your workstation (where the AWS CLI and Session Manager plugin are set up):

```bash
cd terraform
terraform output instance_ids          # copy the "elastic" id
aws ssm start-session --target <elastic-instance-id> --region <your-region>
```

You land as `ssm-user`. Become root for the install:

```bash
sudo -i
```

## 2. Add the Elastic 8.x apt repository

```bash
# Import Elastic's signing key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
  | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

# Install the tools apt needs to fetch over HTTPS
apt-get install -y apt-transport-https

# Add the 8.x repo (NOT 9.x)
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" \
  | tee /etc/apt/sources.list.d/elastic-8.x.list

apt-get update
```

## 3. Install and start Elasticsearch

```bash
apt-get install -y elasticsearch
```

> **Watch the install output.** On a package install, security auto-configuration
> runs on first start, not during `apt-get`. It generates TLS certificates,
> enables the built-in `elastic` superuser, and prepares Kibana enrollment. HTTP
> binds to `0.0.0.0` with TLS; transport binds to localhost. A secure single-node
> cluster works with no extra editing.

Start it:

```bash
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl start elasticsearch.service
```

## 4. Get the `elastic` password and verify the cluster

For a service/package install, the reliable way to obtain the superuser password
is to reset it (the value is printed once — **save it**):

```bash
/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

Confirm Elasticsearch answers over TLS (use the password you just saved):

```bash
curl -k -u elastic https://localhost:9200
```

A JSON blob with `"cluster_name" : "elasticsearch"` and a tagline means it's up.
`-k` skips certificate verification because the cert is self-signed; that's
expected for the lab.

## 5. Install Kibana

```bash
apt-get install -y kibana
```

By default Kibana listens on `localhost` only. To reach it from your browser,
bind it to all interfaces. Edit `/etc/kibana/kibana.yml` and set:

```yaml
server.host: "0.0.0.0"
```

Kibana also needs encryption keys before Fleet will work. Without them, Fleet's
*Add Fleet Server* step fails with an unhelpful `Error: No data` in the UI
while the Kibana log shows `Encrypted Saved Objects plugin is missing
encryption key`. Generate the keys and append them to the config:

```bash
/usr/share/kibana/bin/kibana-encryption-keys generate -q >> /etc/kibana/kibana.yml
```

Then start it:

```bash
systemctl daemon-reload
systemctl enable kibana.service
systemctl start kibana.service
```

## 6. Enroll Kibana with Elasticsearch

Generate a Kibana enrollment token (valid ~30 minutes) on the Elastic host:

```bash
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
```

Now open Kibana in your browser. **Two options — pick one:**

**Option A — direct (simplest, HTTP over the internet from your IP only):**
Browse to the `kibana_url` from `terraform output` (e.g. `http://<elastic-public-ip>:5601`).
Your security group only allows this from `my_ip_cidr`.

**Option B — SSM port-forward (recommended, nothing exposed):** keep 5601 closed
to the world and tunnel it over SSM from your workstation:

```bash
aws ssm start-session \
  --target <elastic-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["5601"],"localPortNumber":["5601"]}' \
  --region <your-region>
```

Then browse to `http://localhost:5601`.

Either way, Kibana asks for an **enrollment token** — paste the one from above.
It then asks for a **verification code**; get it on the Elastic host with:

```bash
/usr/share/kibana/bin/kibana-verification-code
```

> The Kibana page says to run `bin\kibana-verification-code.bat`. Ignore that;
> it's for Windows installs. Ours is Linux, so use the command above in an SSM
> session on the Elastic host (with `sudo` if you're not root). If it finds no
> code, `systemctl restart kibana`, wait ~30 seconds, and try again.

Kibana configures itself and shows a login page. Log in as `elastic` with the
password from step 4.

> **Lost or wrong `elastic` password?** Parking doesn't change it (it lives on
> the Elastic host's disk), so a rejected login means the saved copy is wrong.
> Reset it in an SSM session on the Elastic host and save the new value:
> `sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b`
> This is safe: Kibana, Fleet and the agents use their own tokens, not this password.

## 7. Confirm

In Kibana, open the left menu → **Stack Management → Index Management**, or just
land on the home page without errors. You now have a working SIEM with no data
in it yet. The next guide enrolls agents so telemetry starts flowing.

---

## Troubleshooting

- **Kibana shows "Kibana server is not ready yet"** right after start: give it a
  minute; it waits for Elasticsearch. Check `journalctl -u kibana -f`.
- **Browser can't reach 5601 (Option A):** confirm `server.host: "0.0.0.0"` is
  set and Kibana was restarted, and that your current public IP still matches
  `my_ip_cidr` (it changes on many home connections). Re-run `terraform apply`
  after updating `my_ip_cidr` if your IP moved.
- **Enrollment token expired:** just generate a new one (step 6).
- **`curl` to 9200 refused:** Elasticsearch may still be starting or failed;
  check `journalctl -u elasticsearch -f`.

## When you're done for the day

From `terraform/`, run `terraform destroy`. You'll rebuild from these guides next
time — that repetition is the training. See
[`../docs/cost-and-teardown.md`](../docs/cost-and-teardown.md).

## Next

[`02-fleet-and-agents.md`](./02-fleet-and-agents.md) — set up Fleet and enroll
the Elastic Agent on each host so telemetry starts arriving.
