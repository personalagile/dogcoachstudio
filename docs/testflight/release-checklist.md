# TestFlight release checklist

## Binary identity

- App name: DogCoach Studio
- Bundle identifier: `com.personalagile.dogcoach`
- Marketing version: `1.0.0`
- First TestFlight build: `1`
- Signing style: automatic
- Apple Developer team: `32ZWRSU45R`
- Export compliance: no non-exempt encryption (`ITSAppUsesNonExemptEncryption = NO`)

Increment `CURRENT_PROJECT_VERSION` for every upload, including a replacement build for the same marketing version. Never reuse a build number already uploaded to App Store Connect.

## Before upload

1. Regenerate `DogCoachStudio.xcodeproj` with XcodeGen and verify there is no project drift.
2. Run the full unit and UI test suite on iPhone and the adaptive smoke test on iPad.
3. Archive the Release configuration for `generic/platform=iOS`.
4. Validate the archive contains `PrivacyInfo.xcprivacy`, a valid team signature, and no Debug demo seed. App Store export re-signs the archive for distribution.
5. Confirm the App Store Connect app record uses the exact bundle identifier above.
6. Confirm App Privacy answers, privacy-policy URL, support URL, age rating, and required agreements.
7. Upload with Xcode Organizer or the checked-in `ExportOptions-TestFlight.plist`.

## After processing

1. Resolve any App Store Connect compliance warnings.
2. Add internal testers first and complete a clean-device smoke test.
3. Fill Beta App Description, Feedback Email, Contact Information, and What to Test.
4. For external testers, create a group and submit the first build for TestFlight Beta App Review.
5. Record the build number, processing result, test groups, and known issues in the release log.

## Privacy manifest rationale

The app does not transmit operational client, dog, intake, finance, or training data to the developer or third parties. The privacy manifest therefore declares no collected data and no tracking. It declares the Required Reason API category `UserDefaults` with reason `CA92.1`, because preferences such as onboarding, notifications, and app lock are stored only inside the app's own container.
