# Receiving app feature-preservation map

Copy this into the receiving app's docs. Replace example rows; do not treat them as that app's actual inventory.

App / repository:

Baseline commit / pre-existing dirty files:

Supported platforms / deployment target / build environment:

| Setting or action | Old location | New location | Model / binding / handler | Stored key / backup field | Visibility / permission / gate | Save / Cancel / error behavior | Validation evidence |
|---|---|---|---|---|---|---|---|
| EXAMPLE: notifications | Settings | Notifications detail | Existing model setter | Existing key, unchanged | System permission | Preserve permission denial and settings link | Pending |
| EXAMPLE: backup import | Settings | Your data → Backup | Existing importer | Existing schema, unchanged | Existing access rules | Preserve preview, confirmation, errors | Pending old-backup fixture |

Before calling the adoption complete:

- [ ] Inventory includes hidden/conditional settings and actions, not just currently visible rows.
- [ ] Every old control has a working equivalent; explicitly authorized removals are documented.
- [ ] Existing values/defaults/storage keys and import/export compatibility are preserved.
- [ ] No preview/demo data source or placeholder action is wired to a real setting.
- [ ] Native navigation, deep links, permission denial, Cancel/Save and destructive confirmations checked.
- [ ] Visual/accessibility evidence and any untested device-only behavior are recorded.

Do not put account secrets, tokens or user backup contents in this document.
