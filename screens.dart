import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:in_app_purchase/in_app_purchase.dart' show ProductDetails;

import 'ads.dart';
import 'billing.dart';
import 'config.dart';
import 'guides.dart';
import 'store.dart';
import 'ui.dart';

// ---------------------------------------------------------------------------
// Navigation helpers (full-screen pages cover the tab bar)
// ---------------------------------------------------------------------------

Future<void> openAdd(BuildContext context, {Sub? existing, String? prefillName}) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AddScreen(existing: existing, prefillName: prefillName),
    ),
  );
}

Future<void> openPaywall(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const PaywallScreen(),
    ),
  );
}

Future<void> watchForSlot(BuildContext context) async {
  final started = AdManager.instance.showRewarded(() => store.addBonusSlot());
  if (!started) {
    await infoDialog(context, 'Ad not ready', 'Please try again in a moment.');
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  Widget _hero(BuildContext context, int active, int trials) {
    return Tilt3D(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF12957B), kAccentDeep],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
                color: Color(0x660E7C66), blurRadius: 32, offset: Offset(0, 18)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Fixed monthly spend',
                      style: ts(context, size: 14, color: kWhite70)),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: store.monthlyTotal),
                    duration: dur(900),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(fmtMoney(v, store.currency),
                          style: ts(context,
                              size: 36, weight: FontWeight.w700, color: kWhite)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('$active active, $trials on trial',
                      style: ts(context, size: 14, color: kWhite70)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _LayerStack(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pal = Pal.of(context);
        final all = [...store.subs]..sort(byDate);
        final trials = all.where((s) => s.isTrial).toList();
        final active = all.where((s) => !s.isTrial).toList();
        var n = 0;
        int next() => n++;

        final children = <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Reveal(index: next(), child: _hero(context, active.length, trials.length)),
          ),
        ];

        if (all.isEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Reveal(
              index: next(),
              child: Column(
                children: [
                  Icon(CupertinoIcons.shield_fill, size: 56, color: kAccent),
                  const SizedBox(height: 14),
                  Text('Nothing tracked yet',
                      style: ts(context, size: 20, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Add a subscription or free trial and SubSentry will warn you before it charges. Everything stays on this phone.',
                    textAlign: TextAlign.center,
                    style: ts(context, size: 15, color: pal.muted, height: 1.35),
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    key: const Key('empty_add'),
                    label: 'Add your first subscription',
                    icon: CupertinoIcons.plus,
                    onPressed: () => openAdd(context),
                  ),
                ],
              ),
            ),
          ));
        } else {
          if (trials.isNotEmpty) {
            children.add(Reveal(
              index: next(),
              child: Group(
                header: 'Trials ending soon',
                children: [
                  for (final s in trials)
                    Tile(
                      icon: CupertinoIcons.exclamationmark_triangle_fill,
                      iconBg: pal.danger,
                      title: s.name,
                      subtitle:
                          'Charges ${fmtMoney(s.cost, store.currency)} on ${fmtDate(s.nextBill)}',
                      trailing: timeLeft(s.nextBill),
                      trailingColor: pal.danger,
                      chevron: true,
                      onTap: () => openAdd(context, existing: s),
                    ),
                ],
              ),
            ));
          }
          if (active.isNotEmpty) {
            children.add(Reveal(
              index: next(),
              child: Group(
                header: 'Upcoming bills',
                children: [
                  for (final s in active)
                    Tile(
                      leading: Avatar(name: s.name),
                      title: s.name,
                      subtitle:
                          '${s.cycle}${s.card.isEmpty ? '' : ' - ${s.card}'} - ${fmtDate(s.nextBill)}',
                      trailing: fmtMoney(s.cost, store.currency),
                      chevron: true,
                      onTap: () => openAdd(context, existing: s),
                    ),
                ],
              ),
            ));
          }
        }

        children.add(Reveal(
          index: next(),
          child: Group(
            header: 'Plan',
            children: [
              if (store.isPremium)
                const Tile(
                    icon: CupertinoIcons.star_fill,
                    title: 'Premium is active',
                    subtitle: 'Unlimited subscriptions, no ads')
              else ...[
                Tile(
                  icon: CupertinoIcons.star_fill,
                  title: 'Free plan',
                  subtitle:
                      '${store.subs.length} of ${store.slotLimit} subscriptions used',
                  trailing: 'Go Premium',
                  trailingColor: kAccent,
                  chevron: true,
                  onTap: () => openPaywall(context),
                ),
                if (AdManager.instance.showAds)
                  Tile(
                    icon: CupertinoIcons.play_circle_fill,
                    title: 'Watch an ad for 1 more slot',
                    chevron: true,
                    onTap: () => watchForSlot(context),
                  ),
              ],
            ],
          ),
        ));
        children.add(const SizedBox(height: 28));

        return CupertinoPageScaffold(
          key: const Key('overview_screen'),
          backgroundColor: pal.bg,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Overview'),
                backgroundColor: pal.bg,
                trailing: Tap(
                  key: const Key('add_button'),
                  onTap: () => openAdd(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(CupertinoIcons.plus_circle_fill,
                        size: 30, color: kAccent),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: Column(children: children)),
            ],
          ),
        );
      },
    );
  }
}

class _LayerStack extends StatelessWidget {
  const _LayerStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 96,
      child: Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: i * 6.0,
              top: (2 - i) * 14.0,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.002)
                  ..rotateX(-0.55)
                  ..rotateZ(-0.35),
                child: Container(
                  width: 56,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, 0.18 + i * 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x55FFFFFF)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / edit subscription (full-screen page)
// ---------------------------------------------------------------------------

class AddScreen extends StatefulWidget {
  final Sub? existing;
  final String? prefillName;
  const AddScreen({super.key, this.existing, this.prefillName});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _card;
  late String _cycle;
  late bool _trial;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? widget.prefillName ?? '');
    _cost = TextEditingController(text: e == null ? '' : e.cost.toStringAsFixed(2));
    _card = TextEditingController(text: e?.card ?? '');
    _cycle = e?.cycle ?? 'Monthly';
    _trial = e?.isTrial ?? false;
    final soon = DateTime.now().add(const Duration(days: 7));
    _date = e?.nextBill ?? DateTime(soon.year, soon.month, soon.day, 9, 0);
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _card.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    var temp = _date;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        final pal = Pal.of(ctx);
        return Container(
          height: 320,
          color: pal.card,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Tap(
                  key: const Key('date_done'),
                  onTap: () => Navigator.of(ctx).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Done',
                        style: TextStyle(
                            color: kAccent,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none)),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _date,
                  minimumYear: 2020,
                  maximumYear: 2100,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (mounted) setState(() => _date = temp);
  }

  void _showLimit() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Free limit reached'),
        message: Text('The free plan tracks ${store.slotLimit} subscriptions.'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              openPaywall(context);
            },
            child: const Text('Go Premium'),
          ),
          if (AdManager.instance.showAds)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                watchForSlot(context);
              },
              child: const Text('Watch an ad for 1 more slot'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Not now'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (widget.existing == null && !store.canAdd) {
      _showLimit();
      return;
    }
    final cost = double.parse(_cost.text.trim().replaceAll(',', '.'));
    final sub = Sub(
      id: widget.existing?.id ?? newId(),
      name: _name.text.trim(),
      cost: cost,
      cycle: _cycle,
      card: _card.text.trim(),
      nextBill: _date,
      isTrial: _trial,
    );
    await store.upsert(sub);
    if (!mounted) return;
    Navigator.of(context).pop();
    AdManager.instance.action();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete ${e.name}?',
      message: 'It will be removed from this phone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await store.remove(e.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _prefix(String text) => SizedBox(width: 96, child: Text(text));

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final editing = widget.existing != null;
    return CupertinoPageScaffold(
      key: const Key('add_screen'),
      backgroundColor: pal.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: pal.bg,
        automaticallyImplyLeading: false,
        leading: Tap(
          key: const Key('cancel_button'),
          onTap: () => Navigator.of(context).pop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text('Cancel',
                style: TextStyle(
                    color: kAccent, fontSize: 17, decoration: TextDecoration.none)),
          ),
        ),
        middle: Text(editing ? 'Edit subscription' : 'New subscription'),
        trailing: Tap(
          key: const Key('save_button'),
          onTap: _save,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Text('Save',
                style: TextStyle(
                    color: kAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none)),
          ),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              CupertinoFormSection.insetGrouped(
                backgroundColor: pal.bg,
                header: const Text('Details'),
                children: [
                  CupertinoTextFormFieldRow(
                    key: const Key('name_field'),
                    controller: _name,
                    prefix: _prefix('Name'),
                    placeholder: 'Service name',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  CupertinoTextFormFieldRow(
                    key: const Key('price_field'),
                    controller: _cost,
                    prefix: _prefix(_trial ? 'Price after' : 'Price'),
                    placeholder: '0.00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final x = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'));
                      if (x == null || x < 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                  CupertinoTextFormFieldRow(
                    key: const Key('card_field'),
                    controller: _card,
                    prefix: _prefix('Card tag'),
                    placeholder: 'Optional, e.g. Visa 4417',
                  ),
                  CupertinoFormRow(
                    prefix: _prefix('Billing'),
                    child: CupertinoSlidingSegmentedControl<String>(
                      groupValue: _cycle,
                      children: {
                        for (final c in kCycles)
                          c: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(c, style: const TextStyle(fontSize: 13)),
                          ),
                      },
                      onValueChanged: (v) {
                        if (v != null) setState(() => _cycle = v);
                      },
                    ),
                  ),
                ],
              ),
              CupertinoFormSection.insetGrouped(
                backgroundColor: pal.bg,
                header: const Text('Alerts'),
                footer: Text(_trial
                    ? 'You will get alerts 48 hours, 24 hours and 2 hours before it starts charging.'
                    : 'You will get an alert 24 hours before each renewal.'),
                children: [
                  CupertinoFormRow(
                    prefix: _prefix('Free trial'),
                    child: CupertinoSwitch(
                      key: const Key('trial_switch'),
                      value: _trial,
                      onChanged: (v) => setState(() => _trial = v),
                    ),
                  ),
                  CupertinoFormRow(
                    prefix: _prefix(_trial ? 'Trial ends' : 'Next charge'),
                    child: Tap(
                      key: const Key('date_row'),
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${fmtDate(_date)}, ${fmtTime(_date)}',
                          style: ts(context, color: kAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (editing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Tap(
                    key: const Key('delete_button'),
                    onTap: _delete,
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: pal.card,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text('Delete subscription',
                          style: ts(context, color: pal.danger)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cancellation guides
// ---------------------------------------------------------------------------

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key});

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final q = _q.trim().toLowerCase();
    final list = kGuides.where((g) => g.name.toLowerCase().contains(q)).toList();
    return CupertinoPageScaffold(
      key: const Key('guides_screen'),
      backgroundColor: pal.bg,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Guides'),
            backgroundColor: pal.bg,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: CupertinoSearchTextField(
                key: const Key('guide_search'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
              child: Text(
                'How to cancel popular services. Menus change over time, so check the service Help page if a step is missing.',
                style: ts(context, size: 13, color: pal.muted),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text('No match. Try the service Help page.',
                          style: ts(context, color: pal.muted)),
                    ),
                  )
                : Group(
                    children: [
                      for (final g in list)
                        Tile(
                          title: g.name,
                          chevron: true,
                          onTap: () {
                            Navigator.of(context).push(CupertinoPageRoute<void>(
                                builder: (_) => GuideDetail(guide: g)));
                            AdManager.instance.action();
                          },
                        ),
                    ],
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

class GuideDetail extends StatelessWidget {
  final Guide guide;
  const GuideDetail({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return CupertinoPageScaffold(
      key: const Key('guide_detail'),
      backgroundColor: pal.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: pal.bg,
        previousPageTitle: 'Guides',
        middle: Text(guide.name),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: pal.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to cancel',
                      style: ts(context, size: 13, color: pal.muted)),
                  const SizedBox(height: 8),
                  Text(guide.steps, style: ts(context, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              key: const Key('track_service'),
              label: 'Track this service',
              icon: CupertinoIcons.plus,
              onPressed: () => openAdd(context, prefillName: guide.name),
            ),
            const SizedBox(height: 16),
            Text(
              'Menus change over time. If a step is missing, search the service Help page for "cancel".',
              style: ts(context, size: 13, color: pal.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Projection
// ---------------------------------------------------------------------------

class ProjectionScreen extends StatefulWidget {
  const ProjectionScreen({super.key});

  @override
  State<ProjectionScreen> createState() => _ProjectionScreenState();
}

class _ProjectionScreenState extends State<ProjectionScreen> {
  int _years = 1;

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final yearly = store.subs.fold<double>(0, (a, s) => a + s.yearlyCost);
        final sorted = [...store.subs]
          ..sort((a, b) => b.yearlyCost.compareTo(a.yearlyCost));
        final maxV = (sorted.isEmpty || sorted.first.yearlyCost <= 0)
            ? 1.0
            : sorted.first.yearlyCost;
        return CupertinoPageScaffold(
          key: const Key('projection_screen'),
          backgroundColor: pal.bg,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Projection'),
                backgroundColor: pal.bg,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _years,
                        children: const {
                          1: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('1 year')),
                          3: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('3 years')),
                          5: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('5 years')),
                        },
                        onValueChanged: (v) {
                          if (v != null) setState(() => _years = v);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Reveal(
                        index: 0,
                        child: Tilt3D(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF12957B), kAccentDeep],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x660E7C66),
                                    blurRadius: 32,
                                    offset: Offset(0, 18)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'You would spend over $_years ${_years == 1 ? 'year' : 'years'}',
                                    style: ts(context, size: 14, color: kWhite70)),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                      begin: 0, end: yearly * _years),
                                  duration: dur(700),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) => FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(fmtMoney(v, store.currency),
                                        style: ts(context,
                                            size: 38,
                                            weight: FontWeight.w700,
                                            color: kWhite)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'If you keep every subscription and trial at today prices.',
                                    style: ts(context, size: 13, color: kWhite70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (sorted.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            'Add a subscription to see where your money goes.',
                            textAlign: TextAlign.center,
                            style: ts(context, color: pal.muted)),
                      )
                    else
                      Group(
                        header: 'Where it goes, per year',
                        children: [
                          for (final s in sorted)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                          child: Text(s.name, style: ts(context))),
                                      Text(fmtMoney(s.yearlyCost, store.currency),
                                          style: ts(context,
                                              weight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                        begin: 0, end: s.yearlyCost / maxV),
                                    duration: dur(700),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, v, _) => Transform(
                                      alignment: Alignment.centerLeft,
                                      transform: Matrix4.diagonal3Values(
                                          v.clamp(0.02, 1.0).toDouble(), 1, 1),
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                            color: kAccent,
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _cur =
      TextEditingController(text: store.currency);

  @override
  void dispose() {
    _cur.dispose();
    super.dispose();
  }

  Future<void> _permission() async {
    final android = notifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ok = await android?.requestNotificationsPermission();
    if (!mounted) return;
    await infoDialog(
        context,
        'Notifications',
        ok == false
            ? 'Notifications are blocked. Turn them on in your phone settings for SubSentry.'
            : 'Notifications are allowed.');
  }

  Future<void> _testAlert() async {
    if (!notifsReady) {
      await infoDialog(context, 'Not ready',
          'Notifications are not ready. Allow them in your phone settings.');
      return;
    }
    try {
      await notifs.show(0, 'SubSentry test alert',
          'Alerts are working on this phone.', kAlertDetails);
    } catch (_) {
      if (mounted) {
        await infoDialog(context, 'Could not show the alert', 'Please try again.');
      }
    }
  }

  Future<void> _backup() async {
    await Clipboard.setData(ClipboardData(text: store.backupJson()));
    if (!mounted) return;
    await infoDialog(context, 'Backup copied',
        'Paste it into a note or message to keep it safe.');
  }

  Future<void> _restore() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      await infoDialog(
          context, 'Nothing to restore', 'Copy your backup text first.');
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Restore backup?',
        message: 'This replaces everything currently in the app.',
        action: 'Restore');
    if (!ok) return;
    final done = await store.restoreJson(text);
    if (!mounted) return;
    await infoDialog(
        context,
        done ? 'Restored' : 'Could not restore',
        done
            ? 'Your backup was restored.'
            : 'That does not look like a SubSentry backup.');
  }

  Future<void> _clear() async {
    final ok = await confirmDialog(context,
        title: 'Delete all data?',
        message: 'Every subscription will be removed from this phone.',
        action: 'Delete all',
        destructive: true);
    if (!ok) return;
    await store.clearAll();
    if (!mounted) return;
    await infoDialog(context, 'Deleted', 'All data was removed.');
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return CupertinoPageScaffold(
          key: const Key('settings_screen'),
          backgroundColor: pal.bg,
          child: CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Settings'),
                backgroundColor: pal.bg,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Group(
                      header: 'Plan',
                      children: [
                        Tile(
                          key: const Key('premium_tile'),
                          icon: CupertinoIcons.star_fill,
                          title: 'SubSentry Premium',
                          subtitle: store.isPremium
                              ? 'Active'
                              : 'Unlimited subscriptions, no ads',
                          chevron: true,
                          onTap: () => openPaywall(context),
                        ),
                      ],
                    ),
                    Group(
                      header: 'Alerts',
                      children: [
                        Tile(
                          icon: CupertinoIcons.bell_fill,
                          title: 'Allow notifications',
                          chevron: true,
                          onTap: _permission,
                        ),
                        Tile(
                          icon: CupertinoIcons.paperplane_fill,
                          title: 'Send a test alert',
                          chevron: true,
                          onTap: _testAlert,
                        ),
                      ],
                    ),
                    Group(
                      header: 'Currency',
                      footer: 'Shown before every price, for example \$ or EUR.',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: CupertinoTextField(
                            key: const Key('currency_field'),
                            controller: _cur,
                            placeholder: 'Symbol',
                            onChanged: (v) => store.setCurrency(v),
                          ),
                        ),
                      ],
                    ),
                    Group(
                      header: 'Your data',
                      children: [
                        Tile(
                          icon: CupertinoIcons.doc_on_clipboard_fill,
                          title: 'Copy backup',
                          subtitle: 'Copies your data as text',
                          chevron: true,
                          onTap: _backup,
                        ),
                        Tile(
                          icon: CupertinoIcons.arrow_clockwise,
                          title: 'Restore from copied backup',
                          chevron: true,
                          onTap: _restore,
                        ),
                        Tile(
                          icon: CupertinoIcons.delete_solid,
                          iconBg: pal.danger,
                          title: 'Delete all data',
                          titleColor: pal.danger,
                          onTap: _clear,
                        ),
                      ],
                    ),
                    Group(
                      header: 'About',
                      children: [
                        Tile(
                          key: const Key('privacy_tile'),
                          icon: CupertinoIcons.lock_fill,
                          title: 'Privacy',
                          chevron: true,
                          onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                  builder: (_) => const PrivacyScreen())),
                        ),
                        Tile(
                          icon: CupertinoIcons.creditcard_fill,
                          title: 'Manage subscription',
                          chevron: true,
                          onTap: () => infoDialog(
                              context,
                              'Manage subscription',
                              'Open the Google Play app, tap your profile picture, then Payments & subscriptions > Subscriptions > SubSentry.'),
                        ),
                        const Tile(title: 'Version', trailing: '1.0.0'),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    Widget para(String head, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(head, style: ts(context, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(body, style: ts(context, size: 15, color: pal.muted, height: 1.4)),
            ],
          ),
        );
    return CupertinoPageScaffold(
      key: const Key('privacy_screen'),
      backgroundColor: pal.bg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: pal.bg,
        previousPageTitle: 'Settings',
        middle: const Text('Privacy'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            para('Your subscriptions stay on your phone',
                'SubSentry has no account and no login. The subscriptions you add are stored only on this device and are never uploaded to us.'),
            para('No bank access',
                'The app never asks for your bank or card details. The card tag is a label you type yourself.'),
            para('Ads',
                'The free version shows ads from Google AdMob. AdMob may use your device advertising ID to show and measure ads. Premium removes ads.'),
            para('Purchases',
                'Payments are handled entirely by Google Play. SubSentry never sees your payment details.'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Premium paywall (full-screen page)
// ---------------------------------------------------------------------------

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Widget _plan(BuildContext context, ProductDetails p) {
    final pal = Pal.of(context);
    final label = p.id == kYearlyId
        ? 'Yearly'
        : p.id == kMonthlyId
            ? 'Monthly'
            : 'Lifetime';
    final note = p.id == kLifetimeId
        ? 'One-time purchase'
        : 'Renews automatically. Cancel any time.';
    final best = p.id == kYearlyId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tap(
        key: Key('plan_${p.id}'),
        onTap: Billing.instance.busy ? null : () => Billing.instance.buy(p),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: best ? kAccent : pal.line, width: best ? 1.5 : 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ts(context, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(note, style: ts(context, size: 13, color: pal.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (best)
                    Text('Best value',
                        style: ts(context,
                            size: 12, weight: FontWeight.w600, color: kAccent)),
                  Text(p.price,
                      style: ts(context, size: 17, weight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([Billing.instance, store]),
      builder: (context, _) {
        final b = Billing.instance;
        Widget plans;
        if (store.isPremium) {
          plans = Group(children: const [
            Tile(
                icon: CupertinoIcons.checkmark_circle_fill,
                title: 'You have Premium',
                subtitle: 'Thank you for supporting SubSentry'),
          ]);
        } else if (!b.available) {
          plans = Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              'Purchases are available when SubSentry is installed from Google Play.',
              textAlign: TextAlign.center,
              style: ts(context, size: 15, color: pal.muted),
            ),
          );
        } else if (b.products.isEmpty) {
          plans = Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              'Plans are not available right now. Please try again later.',
              textAlign: TextAlign.center,
              style: ts(context, size: 15, color: pal.muted),
            ),
          );
        } else {
          plans = Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(children: [
              for (final p in b.products) _plan(context, p),
            ]),
          );
        }

        return CupertinoPageScaffold(
          key: const Key('paywall_screen'),
          backgroundColor: pal.bg,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: pal.bg,
            automaticallyImplyLeading: false,
            leading: Tap(
              key: const Key('paywall_close'),
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(CupertinoIcons.xmark_circle_fill,
                    size: 28, color: kAccent),
              ),
            ),
            middle: const Text('Premium'),
            trailing: Tap(
              key: const Key('paywall_restore'),
              onTap: b.enabled ? () => b.restore() : null,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Text('Restore',
                    style: TextStyle(
                        color: kAccent,
                        fontSize: 17,
                        decoration: TextDecoration.none)),
              ),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Tilt3D(
                    child: Container(
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF12957B), kAccentDeep],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x660E7C66),
                              blurRadius: 32,
                              offset: Offset(0, 18)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.star_fill,
                              size: 44, color: kWhite),
                          const SizedBox(height: 10),
                          Text('SubSentry Premium',
                              style: ts(context,
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: kWhite)),
                        ],
                      ),
                    ),
                  ),
                ),
                Group(
                  header: 'What you get',
                  children: const [
                    Tile(
                        icon: CupertinoIcons.square_stack_3d_up_fill,
                        title: 'Unlimited subscriptions'),
                    Tile(
                        icon: CupertinoIcons.eye_slash_fill,
                        title: 'No ads, anywhere'),
                    Tile(
                        icon: CupertinoIcons.heart_fill,
                        title: 'Supports ongoing updates'),
                  ],
                ),
                plans,
                if (b.message != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Text(b.message!,
                        textAlign: TextAlign.center,
                        style: ts(context, size: 14, color: pal.muted)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Text(
                    'Subscriptions renew automatically until cancelled. Manage or cancel any time in Google Play > Payments & subscriptions > Subscriptions.',
                    textAlign: TextAlign.center,
                    style: ts(context, size: 12, color: pal.muted, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
