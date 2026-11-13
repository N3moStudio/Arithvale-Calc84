# Direct Files, recovery and navigation follow-up

## Import and signing

Direct file selection now accompanies sharing. Backup Import uses the existing document-picker owner and authenticated temporary backup preparation. Choose Files accepts multiple documents through a system copy picker, retains access through dismissal, and queues them through the existing encrypted inbox before Import. Neither route exposes the private library in Files or needs a new iCloud container entitlement. Original files remain unchanged.

FlareStore's official store lists Basic as a distribution certificate without JIT. Its installation guide describes directly signing/installing IPAs. JIT is irrelevant to a standard document picker; no source evidence indicates that Arithen needs a more expensive plan for this feature. This is a compatibility assessment, not a validation of the user's signed app/profile. Do not enable File Browser or iTunes File Sharing merely to import documents: those settings expose app documents and are distinct from user-selected file access.

Sources checked November 12, 2026:
- https://flarestore.vip/
- https://flarestore.app/guide/ios/
- https://flarestore.app/signer/
- https://developer.apple.com/documentation/uikit/providing-access-to-directories

If a particular signature/profile or file provider prevents the picker working, sharing remains supported. No private API, wildcard signing entitlement or certificate purchase is required by this implementation.

## Recovery and reset

The existing calculator code opens the existing library when its device credential remains accessible. The starter entry 160160 only opens recovery/setup; it cannot reveal photos. Existing recovery-key authentication is unchanged. New codes remain 6–12 digits and cannot equal 160160.

Erase and Start Over is available only while locked and idle. It requires typed ERASE and a second destructive confirmation. Erasure checks the library UUID, deletes only its app-owned directory, clears temporary files and the matching device credential, and disconnects automatic folder backup. External backups and originals are untouched. Fresh setup generates a new recovery key; the previous code/key cannot open that new vault. Confirmation prevents mistakes; it does not authenticate someone holding an unlocked phone. This is logical file deletion, not a claim of forensic secure erasure.

## UI and checks

Hide the native tab bar from each tab's content/root/detail and remove the enclosing redundant NavigationStack. Keep the existing custom dock and independent Albums route. Shorten primary settings copy; retain error messages, destructive confirmations and optional help.

Regression tests cover identity-bound erasure, a new empty vault rejecting old credentials, and restoring the untouched external backup. GitHub's source-validation workflow runs core/recovery tests and compiles the iPhone app without creating an IPA. Actual FlareStore picker callbacks, tab-bar appearance, edge-swipe and maximum Dynamic Type require device/simulator acceptance; native compilation is not visual proof.
