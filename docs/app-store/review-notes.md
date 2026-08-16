# App Review notes and review flow

## Review flow

The release build starts with an empty local workspace; no account or network connection is required. Fictional demo records are available only in Debug builds and are never included in the TestFlight or App Store experience.

1. Complete the short local-data onboarding.
2. Open People and create a client and dog.
3. Open Catalog and create an exercise and training template.
4. Open Sessions and create a scheduled training for the dog.
5. Open Packages to create a package template and sell a package to the client.
6. Open Data & Privacy to create a backup, export privacy-safe diagnostics, and enable device authentication.
7. Open Upgrade to view StoreKit products and Restore Purchases.

Existing data remains readable and exportable without a subscription. The Foundation content is educational material for professional trainers and contains no diagnosis, medical advice, guaranteed outcome, social feed, or user-generated marketplace.

## Submission fields requiring operator confirmation

- Support URL and Privacy Policy URL hosted over HTTPS.
- App Privacy answers reviewed by the operator/legal reviewer.
- Age rating questionnaire: no unrestricted web access, gambling, contests, medical treatment, or user-generated social content; final answers must match the submitted binary and content.
- Monthly, annual, and Foundation-pack IAP metadata configured in App Store Connect.
- Reviewer access requires no account credentials.
- Release `1.0.0` uses build number `1`; each later upload must use a strictly higher build number.
