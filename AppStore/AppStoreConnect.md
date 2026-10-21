# App Store Connect: everything to paste

## App information

| Field | Value |
|---|---|
| Name (30 max) | `Handover: Rental Inventory` |
| Subtitle (30 max) | `Check-in & deposit reports` |
| Primary category | Business |
| Secondary category | Productivity |
| Bundle ID | Same as `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Handover.xcconfig` |
| SKU | `handover-ios-001` |
| Content rights | Does not contain third-party content |
| Age rating | Answer **None / No** to every question → **4+** |
| Privacy policy URL | `https://YOUR-DOMAIN/privacy` |
| Support URL | `https://YOUR-DOMAIN/support` |
| Marketing URL | `https://YOUR-DOMAIN/` |
| Copyright | `2026 YOUR LEGAL NAME` |

## Keywords (100 max, no spaces after commas)

```
landlord,inspection,condition,move out,move in,tenant,property,checkout,bond,clerk,letting,lease
```

(Words already in the name and subtitle, like rental, inventory, check-in and deposit, are indexed automatically, so they're left out here.)

## Promotional text (170 max)

```
Photograph each room, let AI write clerk-quality descriptions, sign with your tenant and export a deposit-ready report in minutes. Your first export is free.
```

## Description

```
Handover turns your iPhone into a professional inventory clerk.

Walk through a rental with your camera and Handover produces a detailed check-in report, the kind clerks charge £80 to £350 for, in minutes. At the end of the tenancy, compare every room against the original and build a fair, evidence-backed deposit claim.

PHOTOGRAPH EVERY ROOM
• Room lists built automatically from your property's bedrooms and bathrooms
• Evidence camera with capture time, optional location and a tamper-evident SHA-256 fingerprint for every photo
• Close-ups for each item, plus meter readings and keys

LET AI WRITE IT UP
• One tap describes every item in the wording inventory clerks use: colour, material, marks and their size and position
• Condition and cleanliness ratings on the standard five-point scale
• You review and edit every line before anything is final

SIGN AND SHARE
• Landlord and tenant sign on screen at the property
• Signed reports lock so they stay exactly as agreed
• Polished PDF with cover page, room-by-room tables, photo grids and a full evidence appendix

CHECK-OUT AND DEPOSIT CLAIMS
• Ghost overlay camera lines up each new photo with the check-in shot
• AI separates fair wear and tear from cleaning, damage and missing items
• Suggested deductions you can adjust, with the balance to return
• Side-by-side before-and-after evidence, ready for TDS, DPS, mydeposits, state bond authorities or your own records

STAY COMPLIANT
• Reminders for gas safety, EICR, EPC, smoke and CO alarms, deposit protection deadlines, inspections and more
• Checklists tailored to the UK, Ireland, Australia, New Zealand, the US and Canada

PRIVATE BY DESIGN
• No account needed. Your reports live on your iPhone
• Photos are only sent for AI processing when you tap the AI button, and are never stored

HANDOVER PRO
Start free with one property, three AI rooms and your first report export. Upgrade to Pro for unlimited properties, reports, AI descriptions and comparisons, or buy a single report with no subscription.

Pro is available as a monthly or yearly auto-renewing subscription. Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel any time in your App Store account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://YOUR-DOMAIN/privacy

Handover is not legal advice. Deposit schemes, adjudicators and courts decide each case on its evidence.
```

## In-app purchases

Create **one subscription group** called `Handover Pro`, then:

| Reference name | Product ID | Type | Price (USD tier) | Notes |
|---|---|---|---|---|
| Pro Yearly | `handover.pro.yearly` | Auto-renewable, 1 year | $99.99 | Add an **introductory offer: Free, 1 week**, new subscribers |
| Pro Monthly | `handover.pro.monthly` | Auto-renewable, 1 month | $12.99 | Same group, level 2 |
| Single Report | `handover.report.single` | Consumable | $14.99 | |

Suggested local prices (App Store Connect fills others automatically, adjust these by hand): UK £9.99 / £79.99 / £12.99, Australia A$19.99 / A$149.99 / A$22.99, Euro €11.99 / €89.99 / €13.99.

Display names: "Handover Pro Monthly", "Handover Pro Yearly", "Single Report".
Descriptions: "Unlimited reports, AI descriptions and check-out comparisons." and "Export one signed, evidence-grade report."

For each product, upload the review screenshot (a screenshot of the paywall works).

## App Privacy (nutrition label)

Answer **Yes, we collect data**, then select exactly these:

| Data type | Used for | Linked to identity | Tracking |
|---|---|---|---|
| Photos or Videos | App Functionality | No | No |
| Device ID | App Functionality | No | No |

Everything else: not collected. No third-party advertising or analytics SDKs are used.

## App Review information

**Sign-in required:** No.

**Notes for the reviewer** (paste this):

```
Handover helps landlords record the condition of a rental property and produce check-in and check-out reports.

No account is needed. To see a finished example quickly:
1. Complete the short onboarding (choose any country).
2. On the Properties tab, tap "Explore a sample report". This creates a sample property with a signed check-in and a check-out showing two flagged items.
3. Open the property, open either report and tap "View & share report" or "Preview report" to see the generated PDF.

To try the AI feature:
1. Tap + to add a property, then "New check-in report".
2. Open any room, take a photo of any room or object, then tap "Describe room". The first use shows a consent screen explaining that the photos are sent to Google Gemini for processing.
Free users get 3 AI rooms; Pro is unlimited.

In-app purchases: Handover Pro (monthly or yearly with a 7-day free trial) and a consumable single-report unlock. The paywall appears after onboarding and from export, AI and add-property limits. Restore Purchases is on the paywall and in Settings.

The camera, location and photo library are used only for evidence photos inside reports.
```

## Screenshots

Required: **6.9" iPhone (1320 × 2868)**. Apple scales these down for smaller iPhones. iPad is not needed because the app is iPhone-only.

Take them on an iPhone 16 Pro Max or 17 Pro Max simulator (Cmd+S saves a screenshot), using the sample property plus one real property with your own photos. Suggested set and captions:

1. Properties tab with two properties: **"Clerk-quality reports from your iPhone"**
2. A room with photos and the gold AI card: **"AI writes every description"**
3. Item editor with condition chips: **"Rate condition in one tap"**
4. Camera with ghost overlay: **"Line up check-out with check-in"**
5. Deposit claim tiles in a check-out: **"Fair deposit claims, with evidence"**
6. PDF preview: **"Polished PDF reports, signed and locked"**
7. Reminders tab: **"Never miss a gas or electrical check"**

Apple rejects screenshots that show things the app can't do, so only caption real features. Keep captions as text on a coloured background above the screenshot (deep green #0B241E with gold #C9A45C text matches the brand).

## App preview video (optional)

15 to 30 seconds, portrait 886 × 1920: open a room → take two photos → tap Describe → items fill in → sign → PDF appears.
