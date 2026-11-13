# Folder connection investigation

iOS supports folder selection and persistent security-scoped bookmarks. Arithen uses a folder-opening document picker, retains access across dismissal, verifies a coordinated write/read/delete, then resolves and verifies the bookmark before replacing a working connection. Cancellation, multiple selections and failures cannot report a successful connection.

Apple reference: https://developer.apple.com/documentation/uikit/providing-access-to-directories

LiveContainer intercepts document-picker construction. Its current DocumentPicker.m expands requested types to both items and folders. Legacy Fix File Picker also forces copying and can return an app-local Inbox copy instead of a persistent external folder grant. The app cannot turn a copied folder or a shared file into permission to its parent directory. Modern Fix File Picker may help; legacy mode should be disabled for folder access. This is a source-based explanation, not a confirmed diagnosis on the user's phone.

References:
- https://github.com/LiveContainer/LiveContainer/blob/main/TweakLoader/DocumentPicker.m
- https://github.com/LiveContainer/livecontainer.github.io/blob/main/docs/guides/app-settings.md

The connection screen now owns its picker directly, waits for dismissal before processing, allows explicit folder selection where a host expands the type filter, and reports missing selections instead of silently doing nothing. App-local copies are rejected. If a host still cannot grant access, explicit Save Backup to Files remains available. Reopening the app and saving through each real provider must be tested on a device; bookmark round-trip validation in one process cannot prove future access.
