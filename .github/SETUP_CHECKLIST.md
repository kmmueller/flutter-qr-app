# CI/CD Setup Checklist

## Quick Start (5 minutes)

- [ ] Push the `.github/workflows/` directory to your GitHub repository
- [ ] Go to your GitHub repository **Settings** → **Actions** → **General**
- [ ] Verify "Allow all actions and reusable workflows" is selected
- [ ] Make a test commit or create a pull request to trigger the workflow
- [ ] Go to **Actions** tab to monitor the build

## For Code Signing (Optional)

If you want to enable code signing for production releases:

- [ ] Follow the instructions in [.github/WORKFLOWS.md](.github/WORKFLOWS.md) under "Production Setup"
- [ ] Generate your Apple signing certificate
- [ ] Generate your provisioning profile
- [ ] Add GitHub secrets:
  - [ ] `BUILD_CERTIFICATE_BASE64`
  - [ ] `P12_PASSWORD`
  - [ ] `KEYCHAIN_PASSWORD`
  - [ ] `PROVISIONING_PROFILE_BASE64` (optional)
- [ ] Test the Build iOS Release workflow

## Optional: Advanced Configuration

- [ ] Modify workflow triggers in `.github/workflows/build-ios.yml`
- [ ] Add TestFlight upload step
- [ ] Add notifications (Slack, email, etc.)
- [ ] Add version bump automation
- [ ] Set up AppStore Connect API key for automated deployment

## Repository Requirements

- [ ] GitHub Actions enabled
- [ ] Main branch exists
- [ ] `pubspec.yaml` is committed
- [ ] `ios/` directory is committed
