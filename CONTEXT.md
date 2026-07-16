# HomeTechnify — Full Change Context & Replication Guide

> **Purpose:** This document captures EVERY change made in a work session on one
> copy of this project, so another AI/developer can replicate all of it on the
> correct repo. It covers design decisions, database, backend, frontend, assets,
> security, testing, and what remains. Apply changes in the order given.
>
> **App:** HomeTechnify — on-demand home-services marketplace (customer /
> provider / admin). Flutter app + Node/Express/Prisma backend on Supabase
> Postgres + Firebase (Auth, FCM, Firestore chat) + Socket.IO realtime.

---

## 0. CRITICAL WARNINGS — read before touching the database

1. **NEVER run `prisma db push --accept-data-loss`.** The live Supabase DB
   contains many orphaned columns from a previous *food-delivery* version of the
   app (e.g. `is_restaurant`, `food_license_image`, `delivery_fee`, `is_veg`,
   `preparation_minutes`, `daily_stock`, `full_name`, `cnic_selfie`,
   `email_verified`, `auth_provider`). These are NOT in `schema.prisma`. Prisma
   will try to DROP them (with their data). Prisma safely ignores extra DB
   columns for queries, so the app works fine with them present. **Add new
   columns via raw SQL `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` only.**

2. **Supabase pooled connection (`:6543`, pgbouncer) drops under bursty load.**
   For migrations/scripts use the `DIRECT_URL` (`:5432`). Admin dashboard fires
   many parallel queries — see the `runLimited` helper fix below.

3. **Binary assets can't be replicated from text.** The Techy mascot animation
   frames and the Plus Jakarta Sans fonts are binary files. Either copy the
   `assets/anim/techy/`, `assets/images/techy_wave.webp`, and `assets/fonts/`
   folders from the source repo, or regenerate (see §7).

---

## 1. DESIGN DECISIONS (agreed with product owner)

### 1.1 Payment model = Commission Wallet (inDrive-style), NOT escrow
- Customer pays the provider **directly** (cash or online). The app never holds
  customer money (avoids SBP/regulatory burden).
- The app charges the **provider a commission per completed job**, deducted from
  the provider's **prepaid wallet balance**.
- When wallet balance runs low/negative, the provider is blocked from accepting
  new jobs until they **top up** (JazzCash/EasyPaisa) — top-up is the only place
  a payment gateway is needed.
- Recommended config: **12% commission, Rs. 300 signup bonus, block at Rs. 0**.
- Why not Urban Company escrow: UC uses FIXED prices and collects payment; our
  app uses NEGOTIATION, so escrow amounts mismatch + regulatory issues. inDrive
  (also negotiation-based) uses exactly the commission-wallet model.
- **STATUS: DB fields added (`wallet_balance`, `jobs_completed`), but the
  deduct-on-completion + top-up flow + wallet UI are NOT yet built.** A hook
  comment marks where deduction goes in `completeWork`.

### 1.2 Two-OTP work lock (built)
- On booking ACCEPTED → generate a 4-digit **Start OTP** (shown to customer only).
- Provider marks "arrived" (GPS) → enters Start OTP + captures a **before photo**
  → status ONGOING; a **Completion OTP** is generated.
- Provider enters Completion OTP + captures an **after photo** → status
  COMPLETED. Only then do payment + rating unlock (enforced server-side).
- OTPs are visible to the **customer only**; stripped from all provider-facing
  responses so the provider must get them verbally on-site.

### 1.3 Smart bidding = hard price fence (built, backend-enforced)
- Each Service has optional `min_price` / `max_price`. Bids outside are rejected.
- Optional per service: blank = open bidding. Admin sets them.
- UX intent: don't show the range as text; give live color feedback (number
  turns red, submit disables) when out of range. Backend already blocks + returns
  a clear message ("Minimum price for X is Rs. 300"), which the UI now surfaces.

### 1.4 Rating-based ranking (built)
- Providers ranked by a blended score, not raw rating:
  `rating*10 + min(jobs_completed,100)*0.15 + (is_online?5:0) + (is_verified?3:0)`.

### 1.5 Live selfie verification (built)
- Provider onboarding selfie step is **front-camera only** (no gallery/file) so
  it can't be faked. Admin compares CNIC vs selfie to verify.

### 1.6 Video auto-compression (built)
- Videos are compressed on-device before upload (10s clip → ~2-3 MB) to save
  storage + user data.

---

## 2. DATABASE CHANGES

### 2.1 `schema.prisma`
- Datasource block — add directUrl:
  ```prisma
  datasource db {
    provider  = "postgresql"
    url       = env("DATABASE_URL")
    directUrl = env("DIRECT_URL")
  }
  ```
- **Service** model — add:
  ```prisma
  min_price   Float?
  max_price   Float?
  ```
- **Booking** model — add:
  ```prisma
  start_otp       String?
  completion_otp  String?
  arrived_at      DateTime?
  started_at      DateTime?
  completed_at    DateTime?
  before_photo    String?
  after_photo     String?
  ```
- **ProviderProfile** model — add:
  ```prisma
  selfie_url          String?
  selfie_verified     Boolean  @default(false)
  wallet_balance      Float    @default(0)
  jobs_completed      Int      @default(0)
  ```

### 2.2 Apply to the live DB via raw SQL (NOT db push)
Run this Node script (or equivalent `ALTER TABLE`s) against `DIRECT_URL`:
```sql
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "start_otp" TEXT;
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "completion_otp" TEXT;
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "arrived_at" TIMESTAMP(3);
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "started_at" TIMESTAMP(3);
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "completed_at" TIMESTAMP(3);
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "before_photo" TEXT;
ALTER TABLE "Booking" ADD COLUMN IF NOT EXISTS "after_photo" TEXT;
ALTER TABLE "Service" ADD COLUMN IF NOT EXISTS "min_price" DOUBLE PRECISION;
ALTER TABLE "Service" ADD COLUMN IF NOT EXISTS "max_price" DOUBLE PRECISION;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "selfie_url" TEXT;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "selfie_verified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "wallet_balance" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "ProviderProfile" ADD COLUMN IF NOT EXISTS "jobs_completed" INTEGER NOT NULL DEFAULT 0;
```
Then run `npx prisma generate`. (If the query-engine DLL is locked on Windows,
kill stray `node` processes first.)

---

## 3. BACKEND CHANGES (Node/Express, `backend/src/`)

### 3.1 NEW FILE — `middleware/requireAdmin.js`
```js
// Admin-only guard. Must run AFTER authMiddleware (which sets req.user).
const requireAdmin = (req, res, next) => {
    if (!req.user || req.user.role !== 'ADMIN') {
        return res.status(403).json({ success: false, message: 'Admin access required', code: 'FORBIDDEN' });
    }
    next();
};
module.exports = requireAdmin;
```

### 3.2 `middleware/authMiddleware.js` — block blocked users
After fetching `user` and before `req.user = user`, add:
```js
if (user.is_blocked) {
    return res.status(403).json({ success: false, message: 'Your account has been blocked. Please contact support.', code: 'ACCOUNT_BLOCKED' });
}
```

### 3.3 `controllers/authController.js` — stop ADMIN self-grant
In `syncUser`, the new-user branch: replace `const role = req.body.role || 'CUSTOMER';` with:
```js
// Client may only self-select CUSTOMER or PROVIDER; ADMIN only via server script.
const role = req.body.role === 'PROVIDER' ? 'PROVIDER' : 'CUSTOMER';
```
(The update branch already only sets name/phone/image/fcmToken — leave it.)

### 3.4 `utils/prisma.js` — retry + bounded concurrency helpers
Append after `const prisma = new PrismaClient();`:
```js
async function withRetry(fn, retries = 3, delayMs = 400) {
    let lastErr;
    for (let i = 0; i <= retries; i++) {
        try { return await fn(); }
        catch (e) {
            lastErr = e;
            const transient = e && (e.code === 'P1001' || e.code === 'P1017' || e.code === 'P2024');
            if (!transient || i === retries) throw e;
            await new Promise(r => setTimeout(r, delayMs * (i + 1)));
        }
    }
    throw lastErr;
}
async function runLimited(thunks, concurrency = 4) {
    const results = new Array(thunks.length);
    let next = 0;
    async function worker() {
        while (next < thunks.length) { const idx = next++; results[idx] = await withRetry(thunks[idx]); }
    }
    await Promise.all(Array.from({ length: Math.min(concurrency, thunks.length) }, worker));
    return results;
}
module.exports = prisma;
module.exports.withRetry = withRetry;
module.exports.runLimited = runLimited;
```

### 3.5 `controllers/adminController.js` — resilient dashboards
- `getDashboardStats`: replace the 12-wide `await Promise.all([...])` with
  `await runLimited([ () => q1, () => q2, ... ], 3)` (wrap each query in a thunk
  `() => prisma...`). Import `const { runLimited } = require('../utils/prisma');`
- `getFinanceStats`: same treatment, `runLimited([...], 2)`.
- Reason: the 12 parallel count queries dropped the pooled DB connection (500s).

### 3.6 `services/notificationService.js` — fix broadcast (removed API)
In `sendBroadcastNotification`, `admin.messaging().sendToDevice(...)` was removed
in firebase-admin v11+. Replace the send block with multicast + string data:
```js
const stringData = { type: 'BROADCAST', click_action: 'FLUTTER_NOTIFICATION_CLICK' };
for (const [k, v] of Object.entries(data)) stringData[k] = v == null ? '' : String(v);
let successCount = 0;
for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const response = await admin.messaging().sendEachForMulticast({ tokens: batch, notification: { title, body }, data: stringData });
    successCount += response.successCount;
}
return successCount;
```

### 3.7 `controllers/providerController.js` — PII fix + ranking
`getProviders` (PUBLIC endpoint) leaked full User objects. Change the query to
`select` only safe fields (no firebaseUid/fcmToken/email/phone/CNIC/bank), and
after fetching, sort by blended score:
```js
select: {
  id: true, name: true, profileImage: true, is_verified: true, created_at: true,
  provider_profile: { select: { bio: true, hourly_rate: true, rating: true, is_online: true, is_verified: true, experience: true, services: true, jobs_completed: true, current_lat: true, current_lng: true, category: true } },
},
// ...after query:
const score = (u) => { const p = u.provider_profile; if (!p) return -1;
  return (p.rating||0)*10 + Math.min(p.jobs_completed||0,100)*0.15 + (p.is_online?5:0) + (p.is_verified?3:0); };
providers.sort((a,b) => score(b) - score(a));
```

### 3.8 `controllers/coreController.js` — service price bounds
- `createService`: read `minPrice, maxPrice` from body, validate `min <= max`,
  save as `min_price`, `max_price` (null when blank).
- `updateService`: accept `minPrice, maxPrice`; always include them in `data`
  (value or null) so bounds can be set or cleared. Use `parseBound` helper that
  maps '' / null → null else parseFloat.

### 3.9 `controllers/jobController.js` — correct service on job-accept
In `acceptJob`, the booking's `service_id` used `prisma.service.findFirst()`
(random/wrong service). Replace with category-aware resolution:
```js
let defaultService = await prisma.service.findFirst({ where: { category: { name: { equals: job.category, mode: 'insensitive' } } } });
if (!defaultService) {
  const pp = await prisma.providerProfile.findUnique({ where: { user_id: providerId } });
  if (pp) defaultService = await prisma.service.findFirst({ where: { category_id: pp.service_category_id } });
}
if (!defaultService) defaultService = await prisma.service.findFirst();
if (!defaultService) throw new Error("No services configured in system");
```

### 3.10 `controllers/bookingController.js` — OTP flow + fence + fixes
Add helpers near the top (after the notifyUser helper):
```js
const genOtp = () => String(Math.floor(1000 + Math.random() * 9000));
const stripOtpForProvider = (booking, userId) =>
  (booking && booking.provider_id === userId) ? { ...booking, start_otp: null, completion_otp: null } : booking;
const validateBidPrice = async (serviceId, amount) => {
  if (!serviceId || amount == null) return { ok: true };
  const s = await prisma.service.findUnique({ where: { id: serviceId }, select: { name: true, min_price: true, max_price: true } });
  if (!s) return { ok: true };
  const amt = parseFloat(amount);
  if (s.min_price != null && amt < s.min_price) return { ok: false, message: `Minimum price for ${s.name} is Rs. ${s.min_price}` };
  if (s.max_price != null && amt > s.max_price) return { ok: false, message: `Maximum price for ${s.name} is Rs. ${s.max_price}` };
  return { ok: true };
};
```
Edits:
- `createBooking`: before `prisma.booking.create`, call `validateBidPrice(finalServiceId, totalAmount)`; return 400 with message if not ok.
- `counterOffer`: **BUG** — success path never called `res.json` (client hung).
  After fetching booking, call `validateBidPrice(booking.service_id, price)` (400 if bad);
  and at the end (after notifyUser) add a socket emit + `res.json({ success: true, data: updatedBooking })`.
- `acceptOffer`: when setting status ACCEPTED, also set `start_otp: booking.start_otp || genOtp()`.
- `getMyBookings`: map results through `stripOtpForProvider(b, userId)`.
- `getBookingById`: return `stripOtpForProvider(booking, req.user.id)`.
- Add three NEW exported functions:
```js
const providerArrived = async (req, res) => { /* only assigned provider; status must be ACCEPTED;
  set arrived_at=now, start_otp=start_otp||genOtp(), update lat/lng; notify customer; return stripped */ };
const startWork = async (req, res) => { /* only provider; status ACCEPTED; require body.otp === booking.start_otp (else 400);
  require body.beforePhoto (else 400); set status ONGOING, started_at, before_photo, completion_otp=genOtp();
  notify + socket emit customer; return stripped */ };
const completeWork = async (req, res) => { /* only provider; status ONGOING; require otp === completion_otp (else 400);
  require afterPhoto (else 400); set status COMPLETED, completed_at, after_photo; increment providerProfile.jobs_completed;
  // HOOK: commission-wallet deduction goes here when that feature is enabled
  notify + socket emit customer; return stripped */ };
```
- Export `providerArrived, startWork, completeWork` alongside the others.

### 3.11 Routes
- `routes/bookingRoutes.js` — import the 3 new fns and add:
  ```js
  router.put('/:id/arrived', providerArrived);
  router.put('/:id/start', startWork);       // provider: Start OTP + before photo
  router.put('/:id/complete', completeWork);  // provider: Completion OTP + after photo
  ```
- `routes/adminRoutes.js` — add `const requireAdmin = require('../middleware/requireAdmin');`
  and `router.use(requireAdmin);` right after `router.use(authMiddleware);`.
- `routes/coreRoutes.js` — categories/services **write** routes (POST/PUT/DELETE)
  add `requireAdmin` after `authMiddleware`. GET stays public.
- `routes/notificationRoutes.js` — `/broadcast`, `/send-custom`, `/send-broadcast`
  add `requireAdmin`.

---

## 4. FRONTEND CHANGES (Flutter, `lib/`)

### 4.1 Brand theme
- `core/constants/app_colors.dart` — palette to brand kit:
  `primaryBlue=0xFF1495FF, primaryDark=0xFF0B72D8, primaryLight=0xFF6EC6FF,
  primaryAccent=0xFFE6F2FF, brandNavy=0xFF0D1B2A`. `textPrimary=0xFF0D1B2A,
  textSecondary=0xFF51677A, textTertiary=0xFF8298A9`. Update all gradients
  (primaryGradient uses 6EC6FF→1495FF→0B72D8) and `info=0xFF1495FF`.
- `core/theme/app_theme.dart` — add `fontFamily: 'PlusJakartaSans'` and a
  `pageTransitionsTheme` using a custom `_FadeThroughTransitionsBuilder`
  (FadeTransition + slight upward SlideTransition, easeOutCubic) for all
  platforms — removes white flash between screens.

### 4.2 Mascot ("Techy") — see §7 for assets
- NEW `core/widgets/techy_animation.dart`:
  - `TechyFrameAnimation` — precaches 85 webp frames (`assets/anim/techy/f001..f085.webp`)
    then plays them as a flipbook via an AnimationController; params: `duration`,
    `onReady`, `onCompleted`, `onTrigger` + `triggerFraction` (fires a callback
    partway so navigation can overlap the animation → no blank frame), `fit`.
  - `TechyStill` — shows `assets/images/techy_wave.webp` (static waving pose).
- DELETE the old hand-drawn `core/widgets/techy_mascot.dart` (rejected).
- `features/splash/splash_screen.dart` — rewrite: full-bleed `TechyFrameAnimation`
  (feathered edges via ShaderMask so no visible box), brand wordmark
  "HOME TECHNIFY" + tagline "Pakistan's #1 Premium Home Services", slim progress
  bar; navigate via `onTrigger` at ~0.88 so the next screen fades in under the
  mascot flying off (no white/stuck screen). Session/auth resolved in background.
- `features/auth/screens/login_screen.dart` — replace the icon header with
  `TechyStill(height: ...)`.
- `features/home/screens/home_screen.dart` — add a gradient hero card with
  greeting + "Book a Service" CTA + `TechyStill`; a trust strip (Verified Pros /
  Secure Payment / Top Rated); use `TechyStill` in empty states.

### 4.3 `pubspec.yaml`
- assets: add `assets/anim/techy/`, `assets/images/techy_wave.webp`.
- fonts: register family `PlusJakartaSans` with 5 weights (400/500/600/700/800)
  from `assets/fonts/PlusJakartaSans-*.ttf`.
- dependencies: add `video_compress: ^3.1.4`.

### 4.4 Two-OTP + photo flow
- `core/services/supabase_service.dart` — add:
  ```dart
  static Future<String?> uploadWorkPhoto({required File image, required String bookingId, required String stage}) =>
    uploadDocument(file: image, fileName: '${stage}_$bookingId.jpg', folder: 'work-photos/$stage', userId: bookingId);
  static Future<String?> uploadLiveSelfie({required File image, required String userId}) =>
    uploadDocument(file: image, fileName: 'live_selfie.jpg', folder: 'provider-docs/live-selfies', userId: userId);
  ```
- `features/booking/data/models/booking_model.dart` — add nullable fields
  `startOtp, completionOtp, beforePhoto, afterPhoto, arrivedAt, startedAt,
  completedAt`; parse from json keys `start_otp, completion_otp, before_photo,
  after_photo, arrived_at, started_at, completed_at`.
- `features/booking/domain/repositories/booking_repository.dart` — add abstract:
  `markArrived(id, lat, lng)`, `startWork(id, otp, beforePhotoUrl)`,
  `completeWork(id, otp, afterPhotoUrl)` (all `Future<Result<BookingModel>>`).
- `features/booking/data/repositories/remote_booking_repository.dart` — implement:
  PUT `/bookings/$id/arrived` {lat,lng}; PUT `/bookings/$id/start` {otp,beforePhoto};
  PUT `/bookings/$id/complete` {otp,afterPhoto}.
- `features/booking/data/repositories/mock_booking_repository.dart` — add matching
  stub overrides (return the found booking) so the interface compiles.
- `features/booking/providers/booking_provider.dart` — add `markArrived`,
  `startWork`, `completeWork` that call the repo and `_replace` the booking.
- NEW `features/booking/provider_work_flow_screen.dart` — a stepper screen
  (Arrive → Start → Complete) taking a `BookingModel`:
  - "I've Arrived" → geolocator position → `markArrived`.
  - Start stage: 4-digit OTP field + camera-only before photo (`ImagePicker` camera)
    → upload via `SupabaseService.uploadWorkPhoto(stage:'before')` → `startWork`.
  - Complete stage: OTP + after photo → upload (stage:'after') → `completeWork` →
    pop(true). Guards: OTP length 4, photo required; capture provider before async gaps.
- `features/booking/booking_detail_screen.dart` — add `_buildOtpCard(booking)`
  (gradient card, 4 digit boxes) shown to the CUSTOMER: Start OTP when
  status==ACCEPTED, Completion OTP when status==ONGOING; insert it right after the
  status card. Also: counter-offer dialog now shows `bookingProvider.errorMessage`
  on failure (surfaces the smart-bid fence rejection).
- `features/provider/screens/ongoing_service_screen.dart` — replace the old
  direct-complete `bottomNavigationBar` with a "Start/Complete Work (OTP)" button
  that opens `ProviderWorkFlowScreen(booking:_booking!)` and refreshes on return.
  Remove the now-dead `_buildCompleteButton`, `_stopTimer`, `_isCompleting`, and
  the unused `provider_controller` import.
- `features/booking/my_bookings_screen.dart` — status casing bug: backend returns
  UPPERCASE; compare case-insensitively (`s.toLowerCase()=='completed'||'cancelled'`).

### 4.5 Smart bidding (admin)
- `features/admin/screens/admin_services_screen.dart` — service dialog: add
  Min Bid / Max Bid number fields (optional), validate min<=max, pass to API; show
  a "Bid range: Rs. X – Y" badge in the service list when set.
- `core/services/admin_api_service.dart` — `createService`/`updateService` accept
  `minPrice`/`maxPrice` and send them (updateService always sends both, value or null).

### 4.6 Live selfie
- `features/provider/screens/cnic_verification_screen.dart` — step 3 label
  "Live Selfie"; add `_takeLiveSelfie()` that uses `ImagePicker().pickImage(
  source: ImageSource.camera, preferredCameraDevice: CameraDevice.front)`; the
  upload button on step index 2 calls `_takeLiveSelfie` (not the gallery picker).
- Admin match screen already exists: `provider_verification_admin_screen.dart`
  shows CNIC front/back + selfie side by side.

### 4.7 Video compression
- NEW `core/services/video_compressor.dart` — `VideoCompressor.compress(path)`
  uses `VideoCompress.compressVideo(path, quality: MediumQuality, ...)`; returns
  the compressed path only if smaller, else the original (never throws).
- `features/home/widgets/job_posting_modal.dart` — in `_pickVideo`, after picking,
  `final compressedPath = await VideoCompressor.compress(file.path);` then set
  `_mediaPath = compressedPath` (show "Optimizing video…" then "Video ready!").
- `features/chat/screens/chat_screen.dart` — in `_pickAndSendMedia`, if `isVideo`
  compress the path before `_sendMedia`.

### 4.8 Rating badges
- `features/services/service_detail_screen.dart` — provider card: add a
  `Icons.verified_rounded` tick next to the name and a "Top Rated" pill when
  `rating >= 4.8`. (Note: this screen's provider list is still hardcoded/mock.)

### 4.9 Android
- `android/app/src/main/AndroidManifest.xml` — add
  `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
  (required for FCM on Android 13+).

---

## 5. SECURITY FIXES SUMMARY (all in §3)
1. Anyone could self-register as ADMIN via `/auth/sync` → role escalation blocked.
2. Admin routes had no role check → `requireAdmin` added to all admin/core-write/notification-broadcast routes.
3. Public `/api/providers` leaked PII (firebaseUid, fcmToken, email, phone, CNIC, bank) → safe `select` only.
4. Blocked users kept API access → `authMiddleware` now 403s `is_blocked` users.
5. Booking status transitions / ownership already enforced; two-OTP adds a physical-presence gate.

**Still open (pre-launch):** Firestore rules are wide open (any authed user reads/writes all users+chats); secrets (`serviceAccountKey.json`, `.env` DB password) in repo — gitignore + rotate; Socket.IO CORS `'*'`; `usesCleartextTraffic=true`; `SKIP_AUTH=true` + placeholder `JWT_SECRET` in backend `.env` (unused, clean up).

---

## 6. TESTING PERFORMED (replicate these to verify)
Method: temporary Node scripts calling the REAL controllers with mock `req/res`
against the REAL DB (using `DIRECT_URL`), with cleanup at the end.
- **Backend E2E — 33/33 pass:** signup → job post → provider bid → negotiation
  (counter/accept) → booking lifecycle (ongoing/completed) → review + rating
  update → provider dashboard → admin stats/finance/users/providers → notifications
  → PII checks → stranger cannot change booking (403) → duplicate review rejected.
- **Tier-1 — 21/21 pass:** smart-bid floor/ceiling reject + in-range accept; two-OTP
  (start/completion) with wrong-OTP + missing-photo rejection; OTP hidden from
  provider, visible to customer; jobs_completed increments; rating ranking sorted.
- **Security — 6/6 pass:** requireAdmin blocks CUSTOMER/PROVIDER (403), allows
  ADMIN; `/auth/sync` role:ADMIN ignored (becomes CUSTOMER); PROVIDER self-select works.
- `flutter analyze` → **No issues found**. `flutter build apk --debug` → success (~196MB).

---

## 7. BINARY ASSETS (must copy or regenerate)
- **Mascot animation:** 85 webp frames in `assets/anim/techy/f001.webp`..`f085.webp`
  + `assets/images/techy_wave.webp`. Source: a 3D mascot video
  (`The_mascot_naturally_blinks_s.mp4`). Regenerate with ffmpeg, cropping out the
  bottom-right watermark:
  ```
  ffmpeg -ss 2.7 -i SOURCE.mp4 -t 7.1 -vf "fps=12,crop=720:1060:0:0" -c:v libwebp -quality 72 assets/anim/techy/f%03d.webp
  ffmpeg -ss 2.85 -i SOURCE.mp4 -frames:v 1 -vf "crop=600:920:60:130,scale=480:-2" -c:v libwebp -quality 80 assets/images/techy_wave.webp
  ```
  The mascot is a white robot with a blue house-roof head, dark visor with glowing
  eyes, "HT / HOME TECHNIFY" chest logo, holding a wrench, blue cape, rocket flame.
- **Fonts:** Plus Jakarta Sans TTFs (weights 400/500/600/700/800) in `assets/fonts/`.
  Source: github.com/tokotype/PlusJakartaSans (OFL licensed).
- The old hand-drawn CustomPainter mascot was rejected — only the real 3D
  character (video frames) is used.

---

## 8. WHAT REMAINS (not done this session)
**Launch blockers:** deploy backend (Railway/Render) + set real prod URL in
`lib/core/services/api_service.dart` (`_prodUrl` is a placeholder `herokuapp`);
real JazzCash/EasyPaisa merchant creds (or ship cash-only v1); tighten Firestore
rules; gitignore + rotate secrets.
**Features pending:** commission-wallet logic (deduct on `completeWork` + top-up
flow + provider wallet screen — hook comment is in place); real in-app voice/video
calls (currently demo; the in-service call button uses the phone dialer).
**Mock screens to wire to real backend:** `service_detail_screen` (hardcoded
provider list), chat `negotiation_screen` (fake replies — real negotiation is via
`booking_detail_screen`), `job_posting_modal` (sends budget=null), provider
`wallet_screen` top-up ("coming soon").
**Store:** privacy policy URL, data-safety form, icon/screenshots/graphic, signed
release AAB (keystore + `android/key.properties` exist), content rating, version bump.
**Cleanup:** ~40 leftover `analysis_*.txt`/`analyze_*.txt` files + a WhatsApp video
in repo root; stale `COMPLETE_SYSTEM_ANALYSIS.md`; orphaned food-delivery DB columns.

---

## 9B. MARKETPLACE FLOW FIX (job post → offers → negotiate) + DB RESILIENCE

Testing revealed the post-job flow went to a FAKE simulated map. Fixes:

### DB resilience (the "Can't reach database server :6543" error)
- `backend/.env`: point `DATABASE_URL` to the SESSION pooler (`:5432`, no
  `pgbouncer=true`) instead of the transaction pooler (`:6543`) — far more
  stable for a long-running server. (`DIRECT_URL` stays `:5432`.)
- `backend/src/utils/prisma.js`: wrap the client in a `$extends` global
  auto-retry so EVERY query retries transient drops (P1001/P1017/P2024):
  ```js
  const prisma = new PrismaClient().$extends({
    query: { $allOperations({ args, query }) { return _retry(() => query(args)); } },
  });
  ```
  Keep exporting `withRetry`/`runLimited` on it for the admin controllers.
- After changing `.env`, RESTART the node server.

### Correct flow (real, backend already supports the bidding model)
Customer posts job → broadcast (FCM) to providers of that category → providers
see it in **Job Requests** (`getNearbyJobs`) → open **`/provider/set-price`**
(`SetPriceScreen`) → bid (`acceptJob` creates a Booking `NEGOTIATING` linked to
the job) → customer sees the bid in **Offers Received** → Accept/Counter (via
`/booking-detail` panel) → ACCEPTED → **two-OTP flow** → COMPLETED → rate.
The job also appears in the customer's **My Posts** (`MyJobsScreen` → Posted Jobs).

### Frontend changes
- `features/home/widgets/job_posting_modal.dart` `_postJob`: after a successful
  post, navigate to `'/finding-providers'` (REAL) with args
  `{jobId, serviceName, serviceId: newJob.category ?? serviceId, jobData: newJob}` —
  NOT `'/provider-map'` (the fake `ProviderMapScreen` that uses
  `ProviderSimulationService`; that screen is now deprecated/unused).
- `features/job/screens/finding_providers_screen.dart`: REWRITTEN from a
  map-based screen to a clean **LIST** (user explicitly did not want a map):
  a job summary card, an "Offers Received (N)" list (real bookings for this job
  with `Chat` + `View & Respond`→booking-detail), and an "Available Providers (N)"
  list (real ranked providers with a `Request`→chat button). Keeps the real data
  logic: `RemoteProviderRepository.getProviders(categoryId)` (fallback to all),
  `BookingProvider.fetchMyBookings`, and the socket `offer_received` listener that
  refreshes offers live. Providers who already sent an offer are hidden from the
  Available list.

### Loopholes found by E2E testing (all fixed) — apply these too
- `backend/src/utils/prisma.js` `isTransient`: broaden retry to also catch
  `PrismaClientInitializationError` (its `.code` is undefined) and messages
  matching /can't reach database server|connection.*closed|ECONNRESET|ETIMEDOUT|Timed out/i.
  Without this, a cold-start pooler blip 500s the request instead of retrying.
- `backend/src/controllers/bookingController.js` `createBooking`: the old code
  trusted any UUID-looking `service_id` and hit a FK violation when the client
  sent a CATEGORY id (the "Send Request" flow does). Now it VERIFIES the id maps
  to a real Service, else resolves by name / category_id / provider category /
  first service. Never FK-crashes.
- `bookingController.js` `getBookingById`: had NO ownership check — any authed
  user could read any booking (PII: emails, phones, location). Added:
  `if (booking.customer_id !== req.user.id && booking.provider_id !== req.user.id && req.user.role !== 'ADMIN') return 403`.
- `bookingController.js` `acceptOffer`: when a job is awarded it cancelled only
  competing `NEGOTIATING` bids; customer direct requests (`PENDING`) survived.
  Changed the updateMany filter to `status: { in: ['NEGOTIATING','PENDING'] }`.

### Customer "Send Request" flow (frontend)
`finding_providers_screen.dart` `_sendRequest(provider)` builds a `BookingModel`
(status PENDING, price = job budget or 0, `jobPostId` = the job, serviceId =
job category) and calls `BookingProvider.createBooking`, so a customer can invite
a specific provider who then accepts/counters. The provider card has a chat icon
+ a "Request" button. E2E result after fixes: **34/34 pass** (post→bid→request→
negotiate→accept→two-OTP→complete→review + security checks).

### Non-bug note
The greeting showing e.g. "efg4g4" is NOT a bug — that test account's `name`
column literally holds that junk value (entered at signup). Other accounts show
real names. No code fix; edit the profile name.

## 9C. PROVIDER AVAILABILITY + NOTIFICATION DELETE + LOCATION FILTERING

### Provider notification delete
- Backend `DELETE /notifications/:id` already scopes to `user_id` (safe).
- `provider_repository.dart` (interface + remote): add `deleteNotification(id)`
  → `dio.delete('/notifications/$id')`.
- `provider_controller.dart`: add `deleteNotification(id)` (optimistic remove,
  roll back on failure).
- `provider_notifications_screen.dart`: wrap each item in a `Dismissible`
  (endToStart, red delete background) → `_deleteNotification`.

### Provider availability toggle (Available / Not Available)
- Backend `providerController.js`:
  - NEW `toggleAvailability` → `PUT /providers/availability` { is_online } →
    updates `providerProfile.is_online`; export + route it.
  - `updateProfile`: REMOVE the hardcoded `is_online: true` from the UPDATE
    branch (it forced providers back online on every profile edit, overriding
    the toggle). Keep it in the CREATE branch (new provider starts online).
  - `getDashboardStats`: select + return `isAvailable` (is_online),
    `walletBalance`, `jobsCompleted` so the app can hydrate the toggle.
- Frontend `provider_repository.dart`: add `setAvailability(bool) → PUT
  /providers/availability`. `provider_controller.dart`: `_isAvailable` state +
  `setAvailability` (optimistic, roll back) + hydrate from dashboard stats
  `isAvailable`. `provider_dashboard_screen.dart`: an availability Switch card in
  the header (`_buildAvailabilityToggle`).

### Location-based + active-only provider display
- Backend `getProviders`: new query params `available=true` (filter
  `provider_profile.is_online = true`) and `lat`/`lng` (attach `distance_km`
  via haversine and sort nearest-first, rating as tiebreaker; no location →
  blended rating rank). Built the `provider_profile` relation filter
  incrementally so category + online can combine.
- Backend `notificationService.sendBroadcastNotification`: for role PROVIDER,
  only notify online providers (`where.provider_profile = { is_online: true }`)
  so unavailable providers aren't disturbed by new-job broadcasts.
- Frontend `provider_model.dart`: add `distanceKm` (from `distance_km`).
  `provider_repository.getProviders`: add `availableOnly`, `lat`, `lng` params.
  `finding_providers_screen.dart` `_fetchRegisteredProviders`: get the customer's
  GPS location, request ACTIVE providers nearest-first (with graceful fallbacks
  to all-category / all-providers if empty), and show "X km away" on each card.
- E2E: Step-3 backend test 6/6 (available filter, nearest-first, distance,
  toggle hides/shows).

## 9D. ADMIN RATINGS MANAGEMENT + THRESHOLD AUTO-FLAG

### Database
- New Prisma model `AppSetting { key @id, value, updated_at }` (key-value store).
  Create the table via raw SQL (NOT db push):
  `CREATE TABLE IF NOT EXISTS "AppSetting" ("key" TEXT PRIMARY KEY, "value" TEXT NOT NULL, "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP);`
  then seed `INSERT ... ('rating_threshold','2.0') ON CONFLICT DO NOTHING`, then `prisma generate`.

### Backend (`adminController.js` + `adminRoutes.js`)
- Helper `getThresholdValue()` reads `AppSetting['rating_threshold']` (default 2.0).
- `getRatings` → `GET /admin/ratings`: every provider with `rating`, `reviewCount`,
  `is_blocked`, and `flag` ('low' if 0<rating<threshold, 'good' if ≥threshold,
  'none' if 0). Returns `{ threshold, data }`, sorted worst-first.
- `setProviderRating` → `PUT /admin/providers/:id/rating` {rating 0–5}: admin sets/edits.
- `resetProviderRating` → `DELETE /admin/providers/:id/rating`: resets rating to 0.
- `getRatingThreshold`/`setRatingThreshold` → `GET`/`PUT /admin/settings/rating-threshold` {threshold 0–5}.
- `adminController.getProviders`: now also attaches `ratingFlag` per provider +
  returns `ratingThreshold` (so the providers list can show the red flag).
- Customer ratings already auto-update `ProviderProfile.rating` in
  `reviewController.createReview` (recomputes the average) — no change needed.
- E2E: admin ratings backend test 8/8 (threshold set, low/good flag, set/edit/remove, validation).

### Frontend
- `admin_api_service.dart`: `fetchRatings`, `setProviderRating`, `resetProviderRating`, `setRatingThreshold`.
- NEW `admin_ratings_screen.dart`: worst-first provider list; a gradient header
  with the threshold + a "tune" button (slider dialog) to SET it; each row shows
  rating with a RED "Low" badge (below threshold) or green "Good", a per-row menu
  (Edit rating / Remove rating / Block), and a one-tap "Block this low-rated
  provider" button for flagged rows.
- `admin_dashboard_screen.dart`: added a "Ratings" nav item (index 11 → case 11 →
  `AdminRatingsScreen`) + import.
- `admin_providers_screen.dart`: the rating chip now turns RED with a warning
  icon + "Low" when `ratingFlag=='low'`, green "Good" otherwise — so the admin can
  spot and block low-rated providers right from the providers list.

## 9. ENVIRONMENT NOTES
- Backend `.env` needs `DATABASE_URL` (pooled `:6543`) and `DIRECT_URL` (`:5432`).
- Flutter dev API URL is the dev machine's LAN IP in `api_service.dart`
  (`_devUrl`); phone + PC must be on the same WiFi and backend running (`npm start`
  in `backend/`) for the debug APK to talk to it.
- Supabase Storage bucket used: `documents` (folders: provider-docs/*, work-photos/*).
