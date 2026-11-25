# App Store release checklist

What's left to ship **Frets 2 Keys** (iPhone, iPad and Mac, bundle ID `com.mjgibson44.frets2keys`) to the App Store. Tick items off as they're done, and keep this file current.

## Already done

- [x] SwiftUI app for iOS 17+, iPadOS 17+ and macOS 14+ (`apple/`). Version is `1.0`, set as `MARKETING_VERSION` in `apple/project.yml`. App Store category is Music.
- [x] App icon in all sizes (`apple/Frets2Keys/Assets.xcassets/AppIcon.appiconset`), redrawn in November 2026. iPhone and iPad use a square image; the Mac has its own rounded set. The source and export script are in `design/icon-variations/`.
- [x] Privacy manifest (`apple/Frets2Keys/PrivacyInfo.xcprivacy`).
- [x] `ExportOptions.plist` and a TestFlight GitHub Actions workflow (`.github/workflows/testflight.yml`). It checks the App Store Connect API key, archives, exports and uploads with `altool`. See "Releasing to TestFlight" in `README.md` for setup.
- [x] App Store screenshots and app previews in `apple/AppStore/`: iPhone 6.9", iPad 13" and Mac. See `apple/AppStore/README.md` for sizes and how to retake them.
- [x] Web app brought up to the Apple app's features (PR #8). It deploys to Cloudflare Pages.

## Still to do

### App Store Connect setup
- [x] Create the app record in App Store Connect for iOS and macOS, with bundle ID `com.mjgibson44.frets2keys`. Uploads for both platforms succeeded on 2026-11-24.
- [ ] Confirm iCloud is enabled on the app identifier.
- [x] Add repository secrets `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_P8_BASE64`. The key needs the Admin role.
- [x] Run the TestFlight workflow for iOS and macOS. Both uploads succeeded on 2026-11-24.
- [x] Confirm in App Store Connect that both builds finish processing without errors. Build 108 (iOS and macOS, three-strings icon) is attached to both 1.0 versions and in internal TestFlight.
- [x] Revoke the leftover development certificates so the workflow can run again. On 2026-11-24, 20 "Created via API" development certificates were revoked (some came from the other apps' CI on the same account). Kept: Apple Development (Matthew Gibson), Apple Distribution and Mac Installer Distribution.
- [x] Run the workflow once after that. Run 45514341511 (iOS, build 109) archived and uploaded, then printed "Created on this runner: 1" and "Revoked DEVELOPMENT certificate BK632MRCJH, created by this job." A `both` run has not been tried yet.

**Certificate limit.** Each workflow job runs on a fresh runner with no signing identity, so Xcode creates a new Apple Development certificate to sign the archive. Apple allows only a few per account, and on 2026-11-24 Archive failed with "Your account has reached the maximum number of certificates". The workflow now records the account's certificates before Archive and revokes the one it created when the job ends (`.github/scripts/asc_certificates.py`). It revokes a certificate only if it is new since that record, is a development certificate, and has its private key on that runner, so it never touches one that you or another job created. If a job is killed before that step runs, its certificate stays on the account and has to be revoked by hand.

### Testing
- [ ] Install through TestFlight on a real iPhone, iPad and Mac. Test:
  - audio, including with the silent switch on and with Bluetooth output
  - iCloud sync of chord sets between two devices
  - first launch and the tutorial
  - landscape on iPhone
- [ ] Listen to all seven sounds and check loop timing on a device. The web versions of the sounds have never been listened to either.
- [ ] Check VoiceOver on the main screens: instruments, chord panel, chord bank and settings.
- [ ] Check Dynamic Type and dark mode.

### Store listing
These need to be written. None exist yet:
- [ ] App name, subtitle (30 characters) and promotional text.
- [ ] Description and keywords (100 characters).
- [ ] Support URL, and a marketing URL (the web app could be used).
- [ ] Privacy policy URL. This is required even if no data is collected. The app stores chords locally and in the user's own iCloud.
- [ ] App Privacy questionnaire: likely "Data Not Collected". Check this against `PrivacyInfo.xcprivacy`.
- [ ] Age rating questionnaire.
- [ ] Copyright line, and the pricing and availability decision.

### Media
- [ ] Decide whether the screenshots get captions or device frames. They're currently plain captures. Upload them for iPhone 6.9", iPad 13" and Mac.
- [ ] The app previews have a silent audio track. Add music or the app's own sound if you want audio, then upload them. Mac previews aren't made yet; they're optional.

### Submission
- [ ] Fill in App Review information: contact details and notes. The app needs no sign-in.
- [ ] Answer the export compliance question. The app uses no non-exempt encryption; consider setting `ITSAppUsesNonExemptEncryption = NO` in the Info.plist so it isn't asked on every build.
- [ ] Submit iOS and macOS for review, then choose manual or automatic release.

## Notes for the next session
- The certificate cleanup in the TestFlight workflow worked on a real iOS run. A `platform=both` run has only been tested against a fake server; each job should revoke its own certificate. If a job is killed before its revoke step, revoke its "Created via API" certificate by hand.
- Build 108 was built on Matt's Mac and signed with the existing distribution and installer certificates, using two App Store provisioning profiles created through the API: "Frets 2 Keys App Store (local)" and "Frets 2 Keys Mac App Store (local)".
- Debug builds accept `-ScreenshotState`, `-ScreenshotSelect` and `-ScreenshotBank` launch arguments for retaking screenshots safely. They use a separate store and never touch iCloud.
- After adding or removing Swift files, run `xcodegen generate` in `apple/`.
