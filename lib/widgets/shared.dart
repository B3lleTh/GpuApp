import 'package:flutter/material.dart';
import '../constants/theme.dart';

// ─── Surface card ─────────────────────────────────────────────────────────────
class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? bg;
  const SCard({super.key, required this.child, this.padding, this.radius = 16, this.bg});
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg ?? kSurf, borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder, width: 0.8),
    ),
    child: child,
  );
}

// ─── Scale-down tap ───────────────────────────────────────────────────────────
class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Tap({super.key, required this.child, this.onTap});
  @override State<Tap> createState() => _TapState();
}
class _TapState extends State<Tap> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
  late final _s = Tween(begin: 1.0, end: 0.96).animate(_c);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
    onTapUp:   widget.onTap == null ? null : (_) { _c.reverse(); widget.onTap!(); },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: widget.child),
  );
}

// ─── Primary button ───────────────────────────────────────────────────────────
class PBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;
  final IconData? icon;
  const PBtn({super.key, required this.label, this.onTap, this.loading = false,
    this.color = kAccent, this.icon});
  @override
  Widget build(BuildContext context) {
    final on = onTap != null && !loading;
    return Tap(
      onTap: on ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: on ? color : kBorder,
          boxShadow: on ? [BoxShadow(color: color.withOpacity(0.22),
              blurRadius: 14, offset: const Offset(0, 4))] : [],
        ),
        child: loading
            ? Center(child: SizedBox(width: 17, height: 17,
                child: CircularProgressIndicator(strokeWidth: 1.5,
                    color: on ? Colors.white.withOpacity(0.8) : kDim)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: on ? Colors.white.withOpacity(0.9) : kDim),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                    color: on ? Colors.white.withOpacity(0.9) : kDim, letterSpacing: 0.1)),
              ]),
      ),
    );
  }
}

// ─── Decorative orb ───────────────────────────────────────────────────────────
class Orb extends StatelessWidget {
  final Color color;
  final double size;
  const Orb(this.color, this.size, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent])),
  );
}

// ─── Action button with hover ─────────────────────────────────────────────────
class ActBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  const ActBtn(this.label, this.color, this.onTap, {super.key, this.icon});
  @override State<ActBtn> createState() => _ActBtnS();
}
class _ActBtnS extends State<ActBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hov ? c.withOpacity(0.18) : c.withOpacity(0.09),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _hov ? c.withOpacity(0.45) : c.withOpacity(0.20), width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 12, color: c), const SizedBox(width: 4)],
            Text(widget.label, style: TextStyle(fontSize: 11, color: c,
                fontWeight: FontWeight.w600, letterSpacing: 0.1)),
          ]),
        )),
    );
  }
}

// ─── Delete button with hover ─────────────────────────────────────────────────
class DeleteBtn extends StatefulWidget {
  final VoidCallback onTap;
  const DeleteBtn({super.key, required this.onTap});
  @override State<DeleteBtn> createState() => _DeleteBtnS();
}
class _DeleteBtnS extends State<DeleteBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit:  (_) => setState(() => _hov = false),
    child: GestureDetector(onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: _hov ? kErr.withOpacity(0.18) : kErr.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: _hov ? kErr.withOpacity(0.50) : kErr.withOpacity(0.18), width: 0.8),
        ),
        child: Icon(Icons.close_rounded, size: 15,
            color: _hov ? kErr : kErr.withOpacity(0.55)),
      )),
  );
}