# iOS CI/CD Workflows

This directory contains GitHub Actions workflows for automatically building the QR Sheets Scanner iOS app.

## Available Workflows

### 1. Build iOS (build-ios.yml)
**Automatic workflow** that runs on:
- Push to `main` branch
- Pull requests to `main` branch
- Manual trigger via `workflow_dispatch`

**What it does:**
- Checks out the code
- Sets up Flutter 3.41.2
- Gets dependencies
- Runs code analysis
- Runs tests
- Builds iOS app without code signing
- Archives the build as `.ipa`
- Uploads artifact (30-day retention)

**Use case:** Development builds, PR validation, continuous integration

### 2. Build iOS Release (build-ios-release.yml)
**Manual workflow** triggered via GitHub Actions UI.

**What it does:**
- Same as Build iOS workflow
- Additionally installs signing certificate and provisioning profile (if configured)
- Creates a GitHub release with the build
- Longer artifact retention (90 days)

**Use case:** Production releases, TestFlight builds

## Setup Instructions

### Basic Setup (No Code Signing)
The basic workflow requires no additional setup and will work immediately after pushing to GitHub. It builds an unsigned iOS app.

### Production Setup (With Code Signing)

To enable code signing for release builds, configure these GitHub secrets in your repository settings:

1. **BUILD_CERTIFICATE_BASE64**
   - Your Apple Developer signing certificate (`.p12` file) in base64 format
   - Generate: `base64 -i MyCertificate.p12 | pbcopy`

2. **P12_PASSWORD**
   - Password for your `.p12` certificate

3. **KEYCHAIN_PASSWORD**
   - Any secure password for the temporary keychain created during build
   - Example: `MySecureKeychainPassword123!`

4. **PROVISIONING_PROFILE_BASE64** (optional)
   - Your iOS provisioning profile in base64 format
   - Generate: `base64 -i MyProfile.mobileprovision | pbcopy`

#### Steps to generate certificates:

1. In Xcode, go to **Preferences** → **Accounts**
2. Select your Apple Developer account
3. Click **Manage Certificates**
4. If you don't have one, create a signing certificate
5. Right-click the certificate and select **Export**
6. Save as `.p12` file with a secure password
7. Convert to base64: `base64 -i cert.p12 | pbcopy`
8. Add to GitHub repository secrets

#### Getting your provisioning profile:

1. Go to [Apple Developer](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Download your provisioning profile
4. Convert to base64: `base64 -i profile.mobileprovision | pbcopy`
5. Add to GitHub repository secrets

### Adding GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with the exact names listed above
5. Secrets are encrypted and only used in CI/CD workflows

## Viewing Build Artifacts

1. Go to **Actions** tab in your GitHub repository
2. Click on a completed workflow run
3. Scroll down to **Artifacts** section
4. Download the `.ipa` file

## Triggering Workflows Manually

### Build iOS
1. Go to **Actions** tab
2. Select **Build iOS**
3. Click **Run workflow**
4. Select branch (usually `main`)
5. Click **Run workflow**

### Build iOS Release
1. Go to **Actions** tab
2. Select **Build iOS Release**
3. Click **Run workflow**
4. Enter build number (e.g., `1.0.1`)
5. Click **Run workflow**

## Troubleshooting

### Build fails with "code signing failed"
- Remove code signing secrets if you don't have valid certificates
- Or follow the Production Setup section to add proper signing certificates

### Flutter dependency issues
- Ensure `pubspec.yaml` is committed to the repository
- Check that Flutter version in workflow matches your local version
- Update Flutter version in workflow if needed

### Tests failing
- Tests can be marked as `continue-on-error: true` in the workflow
- Fix test failures locally before pushing

## Next Steps

1. Push this `.github/workflows` directory to your GitHub repository
2. Configure GitHub secrets if you want code signing (Production Setup)
3. Make a test commit to trigger the workflow
4. Monitor the workflow run in the Actions tab

## Additional Configuration

To customize the workflows:
- Edit the trigger conditions (`on:` section)
- Change Flutter version if needed
- Modify retention days for artifacts
- Add additional steps (e.g., notifications, uploads to TestFlight)
