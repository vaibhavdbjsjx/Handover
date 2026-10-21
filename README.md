# Handover: Rental Inventory

An iPhone app that turns a landlord's phone into an inventory clerk. Photograph each room, let AI write clerk-style descriptions, sign with the tenant, and export an evidence-grade PDF. At check-out, compare each room against the check-in and build a deposit claim.

```
Handover.xcodeproj     Xcode project (iOS 17+, iPhone, SwiftUI + SwiftData, no third-party packages)
Handover/              App source
Config/                Handover.xcconfig: bundle ID, team, AI server URL and key
Products.storekit      Local StoreKit config for testing purchases in the simulator
Server/                Cloudflare Worker that proxies AI requests to Gemini
docs/                  Marketing website, privacy policy, terms, support (GitHub Pages ready)
AppStore/              Everything to paste into App Store Connect
```

## Set up, in order

### 1. The AI server (about 10 minutes)

The Gemini key must never ship inside the app, because anyone can extract it from an IPA. The app talks to a tiny Cloudflare Worker instead, which holds the key and the prompts. Cloudflare's free plan is enough to start.

1. In [Google AI Studio](https://aistudio.google.com/), use your Gemini API key and **turn on billing for the project**. On the paid tier Google doesn't use your requests to improve its products, which is what the privacy policy promises. Cost is a fraction of a cent per room.
2. Make up an app key, a long random string. For example run `openssl rand -hex 32`.
3. Deploy:

   ```bash
   cd Server
   npm install
   npx wrangler login
   npx wrangler secret put GEMINI_API_KEY   # paste your Gemini key
   npx wrangler secret put APP_KEY          # paste the random string
   npx wrangler deploy
   ```

   Wrangler prints a URL like `https://handover-api.your-name.workers.dev`. Open `/health` on it to check it's live.
4. Optional, recommended: per-device daily limits. Run `npx wrangler kv namespace create QUOTA`, paste the id into `wrangler.toml` (uncomment the block), and deploy again.
5. `npm test` runs the Worker tests.

The model is set in `wrangler.toml` (`GEMINI_MODEL`, with fallbacks). You can change it and redeploy without an app update.

### 2. The app

1. Open `Config/Handover.xcconfig` and set:
   - `PRODUCT_BUNDLE_IDENTIFIER` to your bundle ID (for example `com.yourname.handover`)
   - `DEVELOPMENT_TEAM` to your Team ID (or pick the team in Xcode under Signing & Capabilities)
   - `HANDOVER_API_BASE_URL` to the Worker URL. Keep the `https:/$()/` trick, because xcconfig treats `//` as a comment
   - `HANDOVER_APP_KEY` to the same random string you used for `APP_KEY`
2. Open `Handover.xcodeproj` in Xcode 16 or later and run on a simulator. Purchases use `Products.storekit` locally. If the scheme doesn't pick it up, choose it in Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration.
3. Run on a real iPhone to use the camera.

### 3. Website, privacy policy and support

The `docs/` folder is a complete static site.

1. In the GitHub repo: Settings → Pages → Deploy from branch → `main` / `docs`.
2. Optional: add a custom domain (for example `handoverapp.co`) in the same screen.
3. Replace `[YOUR LEGAL NAME OR COMPANY]` and `[YOUR POSTAL ADDRESS]` in `docs/privacy.html` and `docs/terms.html`.
4. Replace `support@handoverapp.co` everywhere with your support email, and the `#` App Store links in `docs/index.html` once the app is live.
5. Update the URLs and email in `Handover/App/AppConfig.swift` to match.

### 4. App Store Connect

Follow `AppStore/AppStoreConnect.md`: name, subtitle, keywords, description, the three in-app purchases (product IDs must match exactly), the privacy label answers, review notes and the screenshot plan.

## How the product works

| Area | Where |
|---|---|
| Data model (properties, inspections, rooms, items, photos, meters, keys, signatures, compliance) | `Handover/Models` |
| Evidence storage and SHA-256 fingerprints | `Services/PhotoStore.swift` |
| Camera with ghost overlay | `Features/Camera/CaptureView.swift` |
| AI client | `Services/AIService.swift` (prompts live in `Server/src/prompts.js`) |
| PDF report | `Services/ReportRenderer.swift`, `Services/ReportLayout.swift` |
| Subscriptions and free limits | `Services/StoreManager.swift`, `App/AppConfig.swift` |
| Sample report for new users and App Review | `Services/SampleData.swift` |

### Free vs Pro

- Free: 1 property (the sample doesn't count), 3 AI rooms, first report export free, then watermarked previews.
- Pro (monthly or yearly with 7-day trial): unlimited everything.
- Single report: one-time unlock of one report.

Change the limits in `AppConfig.swift`.
