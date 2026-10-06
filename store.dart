import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'config.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const List<String> kCycles = ['Weekly', 'Monthly', 'Yearly'];
const List<String> kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String fmtDate(DateTime d) => '${kMonths[d.month - 1]} ${d.day}, ${d.year}';

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $suffix';
}

String fmtMoney(double v, String cur) => '$cur${v.toStringAsFixed(2)}';

String timeLeft(DateTime d) {
  final diff = d.difference(DateTime.now());
  if (diff.isNegative) return 'now';
  if (diff.inHours < 24) return '${diff.inHours}h left';
  return '${diff.inDays}d left';
}

DateTime _addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final y = d.year + total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d.day < last ? d.day : last, d.hour, d.minute);
}

DateTime advance(DateTime d, String cycle) {
  switch (cycle) {
    case 'Weekly':
      return d.add(const Duration(days: 7));
    case 'Yearly':
      return _addMonths(d, 12);
    default:
      return _addMonths(d, 1);
  }
}

int byDate(Sub a, Sub b) => a.nextBill.compareTo(b.nextBill);

int newId() => (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 200000000;

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

class Sub {
  final int id;
  String name;
  double cost;
  String cycle;
  String card;
  DateTime nextBill; // for a trial: the moment it starts charging
  bool isTrial;

  Sub({
    required this.id,
    required this.name,
    required this.cost,
    required this.cycle,
    required this.card,
    required this.nextBill,
    required this.isTrial,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cost': cost,
        'cycle': cycle,
        'card': card,
        'nextBill': nextBill.toIso8601String(),
        'isTrial': isTrial,
      };

  factory Sub.fromJson(Map<String, dynamic> j) => Sub(
        id: j['id'] as int,
        name: j['name'] as String,
        cost: (j['cost'] as num).toDouble(),
        cycle: (j['cycle'] ?? 'Monthly') as String,
        card: (j['card'] ?? '') as String,
        nextBill: DateTime.parse(j['nextBill'] as String),
        isTrial: (j['isTrial'] ?? false) as bool,
      );

  double get monthlyCost {
    switch (cycle) {
      case 'Weekly':
        return cost * 52 / 12;
      case 'Yearly':
        return cost / 12;
      default:
        return cost;
    }
  }

  double get yearlyCost => monthlyCost * 12;
}

class AppStore extends ChangeNotifier {
  List<Sub> subs = [];
  String currency = r'$';
  int bonusSlots = 0; // extra slots earned by watching rewarded ads
  bool _premium = false;
  DateTime? _premiumAt; // last time Google Play confirmed the purchase
  late SharedPreferences prefs;

  /// Premium counts only while Google Play has confirmed it recently.
  bool get isPremium {
    if (!_premium) return false;
    final at = _premiumAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < kPremiumGrace;
  }

  int get slotLimit => kFreeLimit + bonusSlots;
  bool get canAdd => isPremium || subs.length < slotLimit;

  double get monthlyTotal =>
      subs.where((s) => !s.isTrial).fold<double>(0, (a, s) => a + s.monthlyCost);

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    currency = prefs.getString('currency') ?? r'$';
    bonusSlots = prefs.getInt('bonus') ?? 0;
    _premium = prefs.getBool('premium') ?? false;
    final at = prefs.getInt('premiumAt');
    _premiumAt = at == null ? null : DateTime.fromMillisecondsSinceEpoch(at);
    final raw = prefs.getString('subs');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        subs = list
            .map((e) => Sub.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        subs = [];
      }
    }
    _rollForward();
  }

  void _rollForward() {
    final now = DateTime.now();
    for (final s in subs) {
      while (s.nextBill.isBefore(now)) {
        if (s.isTrial) s.isTrial = false; // the trial ended and billing began
        s.nextBill = advance(s.nextBill, s.cycle);
      }
    }
  }

  Future<void> _persist() async {
    await prefs.setString(
        'subs', jsonEncode(subs.map((s) => s.toJson()).toList()));
    await prefs.setString('currency', currency);
    await prefs.setInt('bonus', bonusSlots);
    await prefs.setBool('premium', _premium);
    final at = _premiumAt;
    if (at == null) {
      await prefs.remove('premiumAt');
    } else {
      await prefs.setInt('premiumAt', at.millisecondsSinceEpoch);
    }
  }

  Future<void> _commit() async {
    notifyListeners();
    await _persist();
    rescheduleAll(subs, currency);
  }

  Future<void> upsert(Sub s) async {
    final i = subs.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      subs[i] = s;
    } else {
      subs.add(s);
    }
    await _commit();
  }

  Future<void> remove(int id) async {
    subs.removeWhere((s) => s.id == id);
    await _commit();
  }

  Future<void> setCurrency(String c) async {
    currency = c;
    notifyListeners();
    await prefs.setString('currency', currency);
  }

  /// Called when Google Play confirms a purchase or restores one.
  Future<void> grantPremium() async {
    _premium = true;
    _premiumAt = DateTime.now();
    await _commit();
  }

  Future<void> addBonusSlot() async {
    bonusSlots++;
    await _commit();
  }

  String backupJson() => jsonEncode({
        'v': 1,
        'currency': currency,
        'subs': subs.map((s) => s.toJson()).toList(),
      });

  Future<bool> restoreJson(String raw) async {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['subs'] as List;
      final parsed = list
          .map((e) => Sub.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      subs = parsed;
      currency = (map['currency'] ?? currency) as String;
      _rollForward();
      await _commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAll() async {
    subs = [];
    await _commit();
  }

  /// Used by automated tests only.
  void resetForTest() {
    subs = [];
    currency = r'$';
    bonusSlots = 0;
    _premium = false;
    _premiumAt = null;
    notifyListeners();
  }
}

final AppStore store = AppStore();

// ---------------------------------------------------------------------------
// Local notifications (work offline)
// ---------------------------------------------------------------------------

final FlutterLocalNotificationsPlugin notifs =
    FlutterLocalNotificationsPlugin();
bool notifsReady = false;

const NotificationDetails kAlertDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'trial_alerts',
    'Trial and renewal alerts',
    channelDescription: 'Warnings before free trials convert and bills renew',
    importance: Importance.max,
    priority: Priority.high,
    autoCancel: false,
  ),
);

Future<void> initNotifications() async {
  try {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await notifs.initialize(settings: settings);
    final android = notifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    notifsReady = true;
  } catch (_) {
    notifsReady = false;
  }
}

Future<void> rescheduleAll(List<Sub> subs, String cur) async {
  if (!notifsReady) return;
  try {
    await notifs.cancelAll();
    final now = DateTime.now();
    for (final s in subs) {
      final offsets = s.isTrial ? [48, 24, 2] : [24];
      for (var k = 0; k < offsets.length; k++) {
        final h = offsets[k];
        final when = s.nextBill.subtract(Duration(hours: h));
        if (!when.isAfter(now)) continue;
        final price = fmtMoney(s.cost, cur);
        final title = s.isTrial
            ? 'Free trial ending: ${s.name}'
            : 'Renewal coming up: ${s.name}';
        final body = s.isTrial
            ? '${s.name} starts charging $price in $h hours. Cancel now if you do not want it.'
            : '${s.name} renews for $price in $h hours.';
        await notifs.zonedSchedule(
          id: s.id * 10 + k,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: kAlertDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  } catch (_) {}
}
