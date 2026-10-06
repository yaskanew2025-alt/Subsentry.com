import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config.dart';
import 'store.dart';

/// Loads and shows AdMob ads. Ads never show for Premium users.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  /// Automated tests switch this off so no Google plugin is called.
  bool enabled = true;

  bool _ready = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);
  int _actions = 0;

  bool get showAds => enabled && !store.isPremium;
  bool get rewardedReady => _rewarded != null;

  Future<void> init() async {
    if (!enabled) return;
    try {
      await MobileAds.instance.initialize();
      _ready = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (_) {
      _ready = false;
    }
  }

  void _loadInterstitial() {
    if (!_ready || !enabled) return;
    InterstitialAd.load(
      adUnitId: interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) => _interstitial = null,
      ),
    );
  }

  void _loadRewarded() {
    if (!_ready || !enabled) return;
    RewardedAd.load(
      adUnitId: rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (error) => _rewarded = null,
      ),
    );
  }

  /// Call after a natural pause (a save, opening a guide). Shows a full-screen
  /// ad every [kInterstitialEvery] actions, never closer than [kInterstitialMinGap].
  void action() {
    if (!showAds) return;
    _actions++;
    if (_actions % kInterstitialEvery != 0) return;
    _showInterstitial();
  }

  void _showInterstitial() {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    if (DateTime.now().difference(_lastShown) < kInterstitialMinGap) return;
    _interstitial = null;
    _lastShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  /// Shows a rewarded ad. Returns false if none is ready yet.
  bool showRewarded(VoidCallback onReward) {
    final ad = _rewarded;
    if (ad == null || !showAds) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (a, reward) => onReward());
    return true;
  }
}

/// Banner ad that sits above the tab bar. Takes no space when there is no ad.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (AdManager.instance.showAds) _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: bannerUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted) {
            a.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, error) {
          a.dispose();
          _ad = null;
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ad = _ad;
        if (!AdManager.instance.showAds || !_loaded || ad == null) {
          return const SizedBox.shrink();
        }
        return Container(
          alignment: Alignment.center,
          width: double.infinity,
          height: AdSize.banner.height.toDouble() + 8,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            width: AdSize.banner.width.toDouble(),
            height: AdSize.banner.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
