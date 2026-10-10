# Detections

Finished, version-controlled Elastic detection rules. Each rule here is the
end product of a Walkthrough: the query you arrived at, exported so it can be
re-imported, reviewed, and improved over time.

## Layout

One file per rule, named by the ATT&CK technique it detects:

```
detections/
  T1059.001-powershell-encoded-command.ndjson   # exported from Kibana
```

## Exporting a rule from Kibana

In Kibana: **Security → Rules → Detection rules (SIEM)**, select the rule, then
**Bulk actions → Export**. Save the resulting `.ndjson` here and commit it.

## Importing on a fresh lab

**Security → Rules → Detection rules (SIEM) → Import**, choose the `.ndjson`.

> Rules reference index patterns (e.g. `logs-*`) and fields that must exist in
> your data. If a rule imports but never fires, confirm the source telemetry is
> actually arriving (see the matching Walkthrough).

## Health rules (`health-*.ndjson`)

Health rules alert when a data source goes quiet, so a detection rule can't go
blind unnoticed. They're Kibana **Stack** rules, not Security detection rules,
so they export and import through a different screen.

| File | Watches |
|---|---|
| `health-sysmon-silent-ws01.ndjson` | No Sysmon events from `ws01` for 15 minutes. Backs up `T1059.001-powershell-encoded-command`, which is Sysmon-only. |

**Export:** Stack Management → Kibana → **Saved objects** → filter Type =
*rule* → tick the rule → **Export**, with *Include related objects* on (this
brings the `logs-*` data view along).

**Import:** Stack Management → Kibana → **Saved objects → Import**, then
open the rule (Stack Management → Rules) and **enable it**. Imported rules
always arrive **disabled**.
