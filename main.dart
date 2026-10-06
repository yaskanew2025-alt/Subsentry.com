import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'ads.dart';
import 'billing.dart';
import 'screens.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const SubSentryApp());
  // Start the plugins after the first frame so the app opens instantly.
  await initNotifications();
  await rescheduleAll(store.subs, store.currency);
  await AdManager.instance.init();
  await Billing.instance.init();
}

class SubSentryApp extends StatelessWidget {
  const SubSentryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'SubSentry',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(primaryColor: kAccent),
      home: RootShell(),
    );
  }
}

/// Four tabs, each with its own navigation stack, plus a banner ad above the
/// tab bar. The Android back button pops the current tab first.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;
  final List<GlobalKey<NavigatorState>> _keys =
      List.generate(4, (_) => GlobalKey<NavigatorState>());

  void _onTab(int i) {
    if (i == _tab) {
      _keys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = _keys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Container(
        color: pal.bg,
        child: Column(
          children: [
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: IndexedStack(
                  index: _tab,
                  children: [
                    CupertinoTabView(
                        navigatorKey: _keys[0],
                        builder: (_) => const OverviewScreen()),
                    CupertinoTabView(
                        navigatorKey: _keys[1],
                        builder: (_) => const GuidesScreen()),
                    CupertinoTabView(
                        navigatorKey: _keys[2],
                        builder: (_) => const ProjectionScreen()),
                    CupertinoTabView(
                        navigatorKey: _keys[3],
                        builder: (_) => const SettingsScreen()),
                  ],
                ),
              ),
            ),
            const AdBanner(),
            CupertinoTabBar(
              currentIndex: _tab,
              onTap: _onTab,
              backgroundColor: pal.card,
              activeColor: kAccent,
              inactiveColor: pal.muted,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.square_grid_2x2),
                    activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
                    label: 'Overview'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.book),
                    activeIcon: Icon(CupertinoIcons.book_fill),
                    label: 'Guides'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.chart_bar),
                    activeIcon: Icon(CupertinoIcons.chart_bar_fill),
                    label: 'Projection'),
                BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.gear),
                    activeIcon: Icon(CupertinoIcons.gear_solid),
                    label: 'Settings'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
