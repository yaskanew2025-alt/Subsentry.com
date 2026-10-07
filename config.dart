// ---------------------------------------------------------------------------
// SubSentry settings. This is the one file you edit to go live.
// ---------------------------------------------------------------------------

// SAFETY SWITCHES -------------------------------------------------------------
// If the app ever crashes on start, set one of these to false, rebuild, and see
// whether it opens. That tells us which part is the cause.
// The build workflow sets these automatically to make test versions.
const bool kEnableAds = bool.fromEnvironment('ADS', defaultValue: true);
const bool kEnableBilling = bool.fromEnvironment('BILLING', defaultValue: true);
const bool kEnableNotifications =
    bool.fromEnvironment('ALERTS', defaultValue: true);

// ADS ------------------------------------------------------------------------
// Keep true while testing. Clicking your own live ads can get AdMob to ban you.
// Set to false only in the version you publish.
const bool kUseTestAds = true;

// Your AdMob App ID (looks like ca-app-pub-1234567890123456~1234567890).
// The default below is Google's official test App ID.
const String kAdMobAppId = 'ca-app-pub-3940256099942544~3347511713';

// Your AdMob ad unit IDs (look like ca-app-pub-1234567890123456/1234567890).
const String kBannerUnitId = '';
const String kInterstitialUnitId = '';
const String kRewardedUnitId = '';

// Google's official test ad units (used while kUseTestAds is true or an id is empty).
const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

String get bannerUnit =>
    (kUseTestAds || kBannerUnitId.isEmpty) ? _testBanner : kBannerUnitId;
String get interstitialUnit => (kUseTestAds || kInterstitialUnitId.isEmpty)
    ? _testInterstitial
    : kInterstitialUnitId;
String get rewardedUnit =>
    (kUseTestAds || kRewardedUnitId.isEmpty) ? _testRewarded : kRewardedUnitId;

// Show a full-screen ad after every Nth natural action (save, open a guide),
// but never more often than the minimum gap.
const int kInterstitialEvery = 2;
const Duration kInterstitialMinGap = Duration(seconds: 60);

// PAYMENTS --------------------------------------------------------------------
// Create these product IDs in Google Play Console (Monetize > Subscriptions and
// In-app products). Prices are set there; the app reads them live.
const String kYearlyId = 'subsentry_premium_yearly'; // subscription
const String kMonthlyId = 'subsentry_premium_monthly'; // subscription
const String kLifetimeId = 'subsentry_premium_lifetime'; // one-time in-app product
const Set<String> kProductIds = {kYearlyId, kMonthlyId, kLifetimeId};

// If the app cannot re-confirm a purchase with Google Play for this long
// (for example the phone is offline for a week), Premium switches off until it can.
const Duration kPremiumGrace = Duration(days: 7);

// FREE PLAN -------------------------------------------------------------------
const int kFreeLimit = 5;
