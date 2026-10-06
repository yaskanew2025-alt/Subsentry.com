import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:subsentry/ads.dart';
import 'package:subsentry/billing.dart';
import 'package:subsentry/main.dart';
import 'package:subsentry/store.dart';
import 'package:subsentry/ui.dart';

Future<void> boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  AdManager.instance.enabled = false;
  Billing.instance.enabled = false;
  motionEnabled = false;
  await store.load();
  store.resetForTest();
  await tester.pumpWidget(const SubSentryApp());
  await tester.pumpAndSettle();
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byType(CupertinoTabBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

Sub sample(String name, {bool trial = false}) => Sub(
      id: newId() + name.length,
      name: name,
      cost: 9.99,
      cycle: 'Monthly',
      card: '',
      nextBill: DateTime.now().add(const Duration(days: 10)),
      isTrial: trial,
    );

void main() {
  testWidgets('all four tabs open and return', (tester) async {
    await boot(tester);
    expect(find.byKey(const Key('overview_screen')), findsOneWidget);
    await tapTab(tester, 'Guides');
    expect(find.byKey(const Key('guides_screen')), findsOneWidget);
    await tapTab(tester, 'Projection');
    expect(find.byKey(const Key('projection_screen')), findsOneWidget);
    await tapTab(tester, 'Settings');
    expect(find.byKey(const Key('settings_screen')), findsOneWidget);
    await tapTab(tester, 'Overview');
    expect(find.byKey(const Key('overview_screen')), findsOneWidget);
  });

  testWidgets('empty state button opens the add page', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('empty_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsOneWidget);
  });

  testWidgets('add page: cancel closes it', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('add_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsNothing);
    expect(find.byKey(const Key('overview_screen')), findsOneWidget);
  });

  testWidgets('add page: empty name is rejected', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('add_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsOneWidget);
    expect(find.text('Enter a name'), findsOneWidget);
    expect(store.subs.length, 0);
  });

  testWidgets('add a subscription and see it on Overview', (tester) async {
    await boot(tester);
    await tester.tap(find.byKey(const Key('add_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name_field')), 'Netflix');
    await tester.enterText(find.byKey(const Key('price_field')), '15.99');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsNothing);
    expect(find.text('Netflix'), findsWidgets);
    expect(store.subs.length, 1);
  });

  testWidgets('tap a subscription to edit it, then delete it', (tester) async {
    await boot(tester);
    await store.upsert(sample('Spotify'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spotify').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsOneWidget);
    expect(find.text('Edit subscription'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(store.subs.length, 0);
    expect(find.byKey(const Key('add_screen')), findsNothing);
  });

  testWidgets('free limit shows the upgrade sheet', (tester) async {
    await boot(tester);
    for (var i = 0; i < 5; i++) {
      await store.upsert(sample('Service $i'));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name_field')), 'Sixth');
    await tester.enterText(find.byKey(const Key('price_field')), '1');
    await tester.tap(find.byKey(const Key('save_button')));
    await tester.pumpAndSettle();
    expect(find.text('Free limit reached'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(store.subs.length, 5);
  });

  testWidgets('guides: search, open a guide, back, track service', (tester) async {
    await boot(tester);
    await tapTab(tester, 'Guides');
    await tester.enterText(find.byKey(const Key('guide_search')), 'spot');
    await tester.pumpAndSettle();
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Netflix'), findsNothing);
    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_detail')), findsOneWidget);
    await tester.tap(find.byKey(const Key('track_service')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_detail')), findsNothing);
    expect(find.byKey(const Key('guides_screen')), findsOneWidget);
  });

  testWidgets('Android back button closes a guide, then leaves the tab', (tester) async {
    await boot(tester);
    await tapTab(tester, 'Guides');
    await tester.tap(find.text('Netflix').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_detail')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('guide_detail')), findsNothing);
    expect(find.byKey(const Key('guides_screen')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('overview_screen')), findsOneWidget);
  });

  testWidgets('projection: switch years', (tester) async {
    await boot(tester);
    await store.upsert(sample('Spotify'));
    await tapTab(tester, 'Projection');
    await tester.tap(find.text('3 years'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('projection_screen')), findsOneWidget);
    await tester.tap(find.text('5 years'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 years'), findsWidgets);
  });

  testWidgets('settings: paywall opens and closes', (tester) async {
    await boot(tester);
    await tapTab(tester, 'Settings');
    await tester.tap(find.byKey(const Key('premium_tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paywall_screen')), findsOneWidget);
    expect(find.textContaining('Purchases are available'), findsOneWidget);
    await tester.tap(find.byKey(const Key('paywall_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paywall_screen')), findsNothing);
    expect(find.byKey(const Key('settings_screen')), findsOneWidget);
  });

  testWidgets('settings: privacy opens and goes back', (tester) async {
    await boot(tester);
    await tapTab(tester, 'Settings');
    await tester.tap(find.byKey(const Key('privacy_tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_screen')), findsOneWidget);
    await tester.tap(find.byType(CupertinoNavigationBarBackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privacy_screen')), findsNothing);
    expect(find.byKey(const Key('settings_screen')), findsOneWidget);
  });

  testWidgets('premium removes the free limit', (tester) async {
    await boot(tester);
    for (var i = 0; i < 5; i++) {
      await store.upsert(sample('Service $i'));
    }
    expect(store.canAdd, false);
    await store.grantPremium();
    expect(store.isPremium, true);
    expect(store.canAdd, true);
  });
}
