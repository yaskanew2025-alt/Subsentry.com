import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'config.dart';
import 'store.dart';

/// Google Play Billing: subscriptions and the one-time lifetime unlock.
/// Prices and titles always come from Google Play, never from this code.
class Billing extends ChangeNotifier {
  Billing._();
  static final Billing instance = Billing._();

  /// Automated tests switch this off so no Google plugin is called.
  bool enabled = kEnableBilling;

  bool available = false;
  bool busy = false;
  String? message;
  List<ProductDetails> products = [];
  StreamSubscription<List<PurchaseDetails>>? _sub;

  int _rank(String id) {
    if (id == kYearlyId) return 0;
    if (id == kMonthlyId) return 1;
    return 2;
  }

  Future<void> init() async {
    if (!enabled) return;
    try {
      _sub ??= InAppPurchase.instance.purchaseStream.listen(
        _onUpdates,
        onError: (Object e) {
          busy = false;
          message = 'Something went wrong with Google Play.';
          notifyListeners();
        },
      );
      available = await InAppPurchase.instance.isAvailable();
      if (available) {
        await loadProducts();
        // Re-confirms active purchases on every launch.
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (_) {
      available = false;
    }
    notifyListeners();
  }

  Future<void> loadProducts() async {
    final r = await InAppPurchase.instance.queryProductDetails(kProductIds);
    final list = r.productDetails.toList();
    list.sort((a, b) => _rank(a.id).compareTo(_rank(b.id)));
    products = list;
    notifyListeners();
  }

  Future<void> buy(ProductDetails p) async {
    if (!enabled || busy) return;
    busy = true;
    message = null;
    notifyListeners();
    try {
      // On Android, subscriptions are also started with buyNonConsumable.
      await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      busy = false;
      message = 'Could not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!enabled) return;
    message = 'Checking your purchases...';
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {
      message = 'Could not reach Google Play.';
      notifyListeners();
    }
  }

  Future<void> _onUpdates(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          busy = true;
          break;
        case PurchaseStatus.error:
          busy = false;
          message = 'The payment did not complete.';
          break;
        case PurchaseStatus.canceled:
          busy = false;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (kProductIds.contains(p.productID)) {
            await store.grantPremium();
            busy = false;
            message = 'Premium is active. Thank you!';
          }
          break;
      }
      if (p.pendingCompletePurchase) {
        // Acknowledges the purchase with Google Play (required, or it is refunded).
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }
}
