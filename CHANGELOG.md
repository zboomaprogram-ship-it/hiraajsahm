# Changelog

All notable changes to the Hiraajsahm application will be documented in this file.

---

## [1.1.0] - 2026-06-08 to 2026-06-19
### Added
- **Long-Term Session Tokens**: Extended user login session validity from 2 days to 365 days, preventing frequent auto-logouts.

### Fixed
- **Telr Payment Gateway**: Resolved a backend PHP API error responsible for checkout failures on the Telr payment gateway.
- **Dynamic Subscription Tiers**: Fixed listing price data and subscription tiers (Bronze, Silver, Gold, Elzabyeh) by migrating away from hardcoded values.
- **Apple IAP Verification**: Fixed the Apple In-App Purchase (IAP) Receipt Verification error.

---

## [1.0.0] - 2026-05-09 to 2026-05-19
### Added
- **Saudi E-Commerce Compliance**: Updated application details and structures to meet Saudi Arabia e-commerce licensing guidelines:
  - Removed explicit email addresses and phone numbers from user public profiles.
  - Removed Google Maps integrations from standard products and vendor profiles.
  - Added direct WhatsApp chat shortcut buttons to contact vendors.
- **Video & Image Watermarks**: Implemented automatic branding watermarks on all uploaded user media (images and videos).
- **Tablet UI Responsiveness**: Enhanced layout rules and media queries to support larger screen sizes and tablets.

### Fixed
- **Video Upload Failures**: Resolved server-side buffer timeouts when uploading large video assets.
- **Vendor Tiers Checkout**: Resolved empty state crashes that occurred when selecting subscription tiers during the "Become a Vendor" onboarding flow.
- **Production Visualization**: Patched UI rendering error causing visual distortions in the production release.
- **App Releases**: Pushed compiled app updates to iOS App Store and Android Google Play Console.
