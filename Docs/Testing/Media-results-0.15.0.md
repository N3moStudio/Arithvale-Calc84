# Arithen 0.15.0 media measurements

Build 29 was compiled from app revision `453f5ebb01267c4beff5ed6b28711b65a0382f4b`. XCUITest drove first-run setup, the system Photos picker, selection in the library, and Save to Photos on an iPhone 17 Pro simulator running iOS 26.2. The export sheet showed one selected photo and confirmed one saved photo. The previous sheet could open with zero items. [Build and simulator evidence](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/45518011972)

## Import and export

The following timings are from the first simulator run of build 29. Bulk tests handed real PhotoKit asset identifiers to the production Photos import handler. The UI test tapped the picker for one photo. Timing starts when the import handler receives the selection and ends when the app posts its verified import result.

| Fixture | Result | Time to verified import |
| --- | --- | --- |
| 150 screenshots, first batch | 150 saved | 12.69 s |
| 150 screenshots, second batch in the same vault | 150 saved | 9.16 s |
| 150 screenshots, third batch in the same vault | 150 saved | 6.37 s |
| 248 screenshots and two 30-minute 4K videos | 250 saved | 15.64 s |
| One 30-minute 4K/30 high-bitrate video, 4,917,240,548 bytes | Saved and reopened | 19.57 s |

The screenshot fixture was a 1179 × 2556 PNG of 76,737 bytes repeated as distinct Photos assets. The two mixed-batch H.264 MP4 files contained synthetic scenes at 3840 × 2160, one at 30 fps and the other at 60 fps. The vault had all 700 expected visible items after locking and reopening. Submitting each batch took less than 1 ms in this run. Completing 150 imports exceeded the one-second target.

The simulator exported a screenshot and both mixed-batch videos. For each new Photos asset, the test checked the exact capture instant from seven days earlier and compared the original Photos resource against the input by SHA-256. Both videos retained their 1,800-second duration. The separate high-bitrate video also retained its hash, capture time, and duration through Photos import, vault reopen, and Photos export. Its hash was `8bdd92a3c9b681ef2da8914f5fe1e7de9bf697375eb33638f08110d03b81ed76`.

Apple Photos uses capture time when the library is sorted by **Date Captured**. **Recently Added** uses the time the exported copy entered Photos. The test verified the saved asset’s creation date through PhotoKit. It did not inspect the ordering of the Photos app’s grid. [Apple’s Photos sorting guide](https://support.apple.com/en-gb/guide/iphone/iph2e66e2f2c/ios)

The first run’s later Files test stalled after tapping Open on a selected text file. A fresh simulator reran the same revision and passed the full suite, including that Files selection and the Save to Photos UI. Its three 150-item batches took 6.27, 7.13 and 7.53 seconds. The 250-item batch took 17.24 seconds and the 4.92 GB video took 23.77 seconds. [Successful rerun](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/45518011972/attempts/2)

## Storage

The storage-engine benchmark ran on a hosted Mac. It stored synthetic files of 0.5, 1, 5, 16, 24 and 20 GiB in the same vault. After every step it exported the file, compared streamed SHA-256 digests, locked the vault, reopened it and checked the stored byte total. The largest verified total was **66.5 GiB** and the largest verified file was **24 GiB**. A 64 GiB plus one byte input was rejected before it changed the vault. All 184 Swift tests and 28 independent recovery tests passed in this run. [Storage job and measurements](https://github.com/N3moStudio/Arithvale-Calc84/actions/runs/45514607510/job/138870703389)

The picker allows 250 items per selection. The storage engine admits up to 64 GiB per original resource and less than 1 TiB minus 128 MiB of combined payload. The archive ceiling is 1 TiB. The library also allows 5,000 stored resources, including thumbnails and Live Photo companions. A phone needs room for the original, staging and verification. The app checks free space during import. Older app versions and recovery tools may reject backups above their old size limits.

## Physical iPhone coverage

Test an actual camera recording with its Cinematic focus adjustments, HDR or HEVC, an iCloud-only original, and a batch of the phone’s ordinary photos. Check playback, timing, temperature and behavior when the phone locks or has little free space. The simulator used synthetic video and Mac storage. Phone-specific throughput and the largest usable library on a particular phone remain unmeasured. Limited and denied Photos permissions and visual sorting in the Photos app were outside the measured batch run.
