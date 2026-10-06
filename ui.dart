import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Automated tests switch this off so animations never keep timers alive.
bool motionEnabled = true;
Duration dur(int ms) => motionEnabled ? Duration(milliseconds: ms) : Duration.zero;

const Color kAccent = Color(0xFF0E7C66);
const Color kAccentDeep = Color(0xFF0A5A4A);
const Color kWhite = Color(0xFFFFFFFF);
const Color kWhite70 = Color(0xB3FFFFFF);

/// Light and dark colors (never pure black).
class Pal {
  final bool dark;
  const Pal(this.dark);

  static Pal of(BuildContext c) =>
      Pal(MediaQuery.platformBrightnessOf(c) == Brightness.dark);

  Color get bg => dark ? const Color(0xFF111113) : const Color(0xFFF2F2F7);
  Color get card => dark ? const Color(0xFF1C1C1F) : const Color(0xFFFFFFFF);
  Color get ink => dark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
  Color get muted => dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
  Color get line => dark ? const Color(0x33FFFFFF) : const Color(0x1F000000);
  Color get danger => dark ? const Color(0xFFF97066) : const Color(0xFFD92D20);
  Color get accentSoft =>
      dark ? const Color(0xFF12332C) : const Color(0xFFE6F4F1);
}

TextStyle ts(BuildContext c,
    {double size = 16,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color ?? Pal.of(c).ink,
    height: height,
    decoration: TextDecoration.none,
  );
}

// ---------------------------------------------------------------------------
// Press feedback
// ---------------------------------------------------------------------------

class Tap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const Tap({super.key, required this.onTap, required this.child});

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _down ? 0.6 : 1,
        duration: dur(90),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: dur(120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const PrimaryButton(
      {super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kAccent, kAccentDeep]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330E7C66), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kWhite),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(
                    color: kWhite,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staggered reveal (opacity + transform only)
// ---------------------------------------------------------------------------

class Reveal extends StatefulWidget {
  final int index;
  final Widget child;
  const Reveal({super.key, required this.index, required this.child});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!motionEnabled) {
      _c.value = 1;
      return;
    }
    _t = Timer(Duration(milliseconds: math.min(widget.index, 8) * 60), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!motionEnabled) return widget.child;
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(_a),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3D tilt card: floats gently, tilts toward your finger, springs back
// ---------------------------------------------------------------------------

class Tilt3D extends StatefulWidget {
  final Widget child;
  final double maxAngle;
  const Tilt3D({super.key, required this.child, this.maxAngle = 0.26});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
      vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController _back = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  Offset _tilt = Offset.zero; // dx = rotateY, dy = rotateX (radians)
  Animation<Offset>? _backAnim;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (motionEnabled) _idle.repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    _back.dispose();
    super.dispose();
  }

  void _update(Offset p) {
    final s = context.size ?? const Size(300, 160);
    if (s.width <= 0 || s.height <= 0) return;
    final nx = ((p.dx / s.width) - 0.5) * 2;
    final ny = ((p.dy / s.height) - 0.5) * 2;
    setState(() {
      _tilt = Offset(
        nx.clamp(-1.0, 1.0) * widget.maxAngle,
        -ny.clamp(-1.0, 1.0) * widget.maxAngle,
      );
    });
  }

  void _release() {
    if (!_dragging) return;
    _dragging = false;
    if (!motionEnabled) {
      setState(() => _tilt = Offset.zero);
      return;
    }
    _backAnim = Tween<Offset>(begin: _tilt, end: Offset.zero)
        .animate(CurvedAnimation(parent: _back, curve: Curves.elasticOut));
    _back
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _dragging = true;
        _back.stop();
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (_dragging) _update(e.localPosition);
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _back]),
        builder: (context, child) {
          final t = _dragging ? _tilt : (_backAnim?.value ?? Offset.zero);
          final w = _idle.value * 2 * math.pi;
          final ix = _dragging || !motionEnabled ? 0.0 : math.sin(w) * 0.035;
          final iy = _dragging || !motionEnabled ? 0.0 : math.cos(w) * 0.025;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(t.dy + iy)
            ..rotateY(t.dx + ix);
          return Transform(
              alignment: Alignment.center, transform: m, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// iOS-style grouped list pieces
// ---------------------------------------------------------------------------

class Group extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  const Group({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Container(
            height: 0.5, margin: const EdgeInsets.only(left: 16), color: pal.line));
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 6),
              child: Text(header!.toUpperCase(),
                  style: ts(context, size: 13, color: pal.muted)),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(color: pal.card, child: Column(children: rows)),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer!, style: ts(context, size: 13, color: pal.muted)),
            ),
        ],
      ),
    );
  }
}

class Tile extends StatelessWidget {
  final IconData? icon;
  final Color? iconBg;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Color? trailingColor;
  final Color? titleColor;
  final bool chevron;
  final VoidCallback? onTap;

  const Tile({
    super.key,
    this.icon,
    this.iconBg,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingColor,
    this.titleColor,
    this.chevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    Widget? lead = leading;
    if (lead == null && icon != null) {
      lead = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: iconBg ?? kAccent, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: kWhite),
      );
    }
    return Tap(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (lead != null) ...[lead, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ts(context, color: titleColor ?? pal.ink)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle!,
                            style: ts(context, size: 13, color: pal.muted)),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Text(trailing!,
                    style: ts(context,
                        weight: FontWeight.w600,
                        color: trailingColor ?? pal.ink)),
              ],
              if (chevron) ...[
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_right, size: 16, color: pal.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  const Avatar({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final pal = Pal.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: pal.accentSoft, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: ts(context, weight: FontWeight.w700, color: kAccent),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog helpers
// ---------------------------------------------------------------------------

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        CupertinoDialogAction(
            isDestructiveAction: destructive,
            isDefaultAction: !destructive,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action)),
      ],
    ),
  );
  return r ?? false;
}

Future<void> infoDialog(BuildContext context, String title, String message) {
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK')),
      ],
    ),
  );
}
