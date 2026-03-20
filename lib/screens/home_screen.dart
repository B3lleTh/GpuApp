import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/theme.dart';
import '../models/plan.dart';
import '../widgets/shared.dart';
import '../widgets/plan_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  bool   _cd  = false;
  int    _cdN = 0;
  Timer? _cdTimer;
  String _hint    = '';
  int    _preview = 0;

  String get _uid   => FirebaseAuth.instance.currentUser!.uid;
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void dispose() { _cdTimer?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _onH(String v) {
    final h = int.tryParse(v) ?? 0;
    if (h >= 1 && h <= kMaxHours) {
      final p = buildPlan(h);
      setState(() { _preview = p.totalBlocks; _hint = '${p.method}  ·  ${p.studyMin}m / ${p.breakMin}m'; });
    } else {
      setState(() { _preview = 0; _hint = ''; });
    }
  }

  void _startCD() {
    setState(() { _cd = true; _cdN = kCD; });
    _cdTimer?.cancel();
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_cdN <= 1) { t.cancel(); setState(() { _cd = false; _cdN = 0; }); }
      else setState(() => _cdN--);
    });
  }

  Future<void> _addPlan(int activeCount) async {
    final h = int.tryParse(_ctrl.text.trim()) ?? 0;
    if (h < 1)                { _snack('Enter at least 1 hour', err: true); return; }
    if (h > kMaxHours)        { _snack('Max $kMaxHours hours', err: true); return; }
    if (activeCount >= kMaxPlans) { _snack('$kMaxPlans plans max — remove one first', err: true); return; }
    try {
      final plan = buildPlan(h);
      await FirebaseFirestore.instance.collection('planes').add(plan.toMap(_uid));
      if (mounted) { _snack('Plan added · ${plan.method} · ${plan.totalBlocks} blocks'); _startCD(); }
    } catch (_) {
      if (mounted) _snack('Could not save plan', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kHi)),
        backgroundColor: err ? const Color(0xFF1E0A10) : const Color(0xFF0E0E18),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: err ? kErr.withOpacity(0.3) : kBorder, width: 0.8)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('planes')
          .where('uid', isEqualTo: _uid).snapshots(),
      builder: (context, snap) {
        final plans = snap.hasData
            ? (snap.data!.docs.map(Plan.fromDoc).toList()
                ..sort((a, b) {
                  final at = (snap.data!.docs.firstWhere((d) => d.id == a.id).data() as Map)['createdAt'] as int? ?? 0;
                  final bt = (snap.data!.docs.firstWhere((d) => d.id == b.id).data() as Map)['createdAt'] as int? ?? 0;
                  return at.compareTo(bt);
                }))
            : <Plan>[];

        final active = plans.where((p) => !p.isDone).toList();
        final done   = plans.where((p) =>  p.isDone).toList();

        return SafeArea(child: Column(children: [
            _AppBar(email: _email),
            Expanded(child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
              children: [
                _StatsCard(email: _email, active: active.length,
                    done: done.length,
                    totalMins: plans.fold(0, (s, p) => s + p.totalStudyMins)),
                const SizedBox(height: 10),
                _InputCard(ctrl: _ctrl, hint: _hint, preview: _preview,
                    cd: _cd, cdN: _cdN, canAdd: active.length < kMaxPlans,
                    activeCount: active.length,
                    onChanged: _onH, onAdd: () => _addPlan(active.length)),
                const SizedBox(height: 20),
                if (!snap.hasData)
                  const Center(child: Padding(padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent)))
                else if (plans.isEmpty)
                  const _Empty()
                else ...[
                  if (active.isNotEmpty) ...[
                    _SLabel('Active  ·  ${active.length}/$kMaxPlans'),
                    ...active.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8),
                        child: PlanCard(plan: p))),
                  ],
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _SLabel('Completed  ·  ${done.length}'),
                    ...done.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8),
                        child: PlanCard(plan: p))),
                  ],
                ],
              ],
            )),
          ]));
      },
    ),
  );
}

// ─── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final String email;
  const _AppBar({required this.email});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
    child: Row(children: [
      RichText(text: const TextSpan(children: [
        TextSpan(text: 'G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: kAccent, letterSpacing: -0.5, decoration: TextDecoration.none)),
        TextSpan(text: 'PA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: kHi, letterSpacing: -0.5, decoration: TextDecoration.none)),
      ])),
      const Spacer(),
      Tap(onTap: () => FirebaseAuth.instance.signOut(),
        child: Padding(padding: const EdgeInsets.all(8),
          child: const Icon(Icons.logout_rounded, size: 16, color: kDim))),
    ]),
  );
}

// ─── Stats card ───────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final String email;
  final int active, done, totalMins;
  const _StatsCard({required this.email, required this.active,
      required this.done, required this.totalMins});

  String get _initials {
    final n = email.split('@').first.split('.');
    return n.length >= 2 ? '${n[0][0]}${n[1][0]}'.toUpperCase()
        : email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  String _fmt(int m) {
    final h = m ~/ 60, r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) => SCard(
    child: Column(children: [
      Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: kAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withOpacity(0.20), width: 0.8)),
          child: Center(child: Text(_initials, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: kAccent)))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kHi)),
          const Text('Study stats', style: TextStyle(fontSize: 11, color: kDim)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (active >= kMaxPlans ? kErr : kAccent).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (active >= kMaxPlans ? kErr : kAccent).withOpacity(0.24), width: 0.7),
          ),
          child: Text('$active/$kMaxPlans', style: TextStyle(fontSize: 10,
              color: active >= kMaxPlans ? kErr : kAccent, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
      ]),
      const SizedBox(height: 12),
      Container(height: 0.8, color: kBorder),
      const SizedBox(height: 12),
      Row(children: [
        _M('$active',      'Active',    kAccent, Icons.layers_outlined),
        Container(width: 0.8, height: 32, color: kBorder),
        _M('$done',        'Completed', kActive, Icons.check_rounded),
        Container(width: 0.8, height: 32, color: kBorder),
        _M(_fmt(totalMins),'Planned',   kRest,   Icons.schedule_outlined),
      ]),
    ]),
  );
}

class _M extends StatelessWidget {
  final String v, l; final Color c; final IconData i;
  const _M(this.v, this.l, this.c, this.i);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Icon(i, size: 13, color: c),
    const SizedBox(height: 3),
    Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
        color: c, letterSpacing: -0.3), textAlign: TextAlign.center),
    Text(l, style: const TextStyle(fontSize: 10, color: kDim), textAlign: TextAlign.center),
  ]));
}

// ─── Input card ───────────────────────────────────────────────────────────────
class _InputCard extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int preview, cdN, activeCount;
  final bool cd, canAdd;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  const _InputCard({required this.ctrl, required this.hint, required this.preview,
      required this.cd, required this.cdN, required this.canAdd,
      required this.activeCount, required this.onChanged, required this.onAdd});

  @override
  Widget build(BuildContext context) => SCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('New session', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kHi)),
        const Spacer(),
        if (preview > 0)
          Text('$preview blocks', style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w500)),
      ]),
      const SizedBox(height: 2),
      Text(
        activeCount >= kMaxPlans ? 'Limit reached — delete a plan to add more'
            : '1–$kMaxHours h  ·  up to $kMaxPlans concurrent',
        style: TextStyle(fontSize: 11, color: activeCount >= kMaxPlans ? kErr : kDim),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: ctrl, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: kHi),
        decoration: const InputDecoration(labelText: 'Available hours'),
      ),
      if (hint.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccent)),
          const SizedBox(width: 7),
          Text(hint, style: const TextStyle(fontSize: 11, color: kDim)),
        ]),
      ],
      const SizedBox(height: 12),
      // Cooldown vive en el botón — sin overlay, sin bloquear la pantalla
      _AddBtn(cd: cd, cdN: cdN, canAdd: canAdd, onAdd: onAdd),
    ]),
  );
}

// Botón de agregar con cooldown inline
class _AddBtn extends StatelessWidget {
  final bool cd, canAdd;
  final int cdN;
  final VoidCallback onAdd;
  const _AddBtn({required this.cd, required this.cdN,
      required this.canAdd, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    // Durante cooldown: botón activo con ring de progreso y contador
    // Sin cooldown: botón normal
    final enabled = canAdd && !cd || canAdd && cd;
    // Siempre se puede tocar si hay slots — el cooldown es solo visual/informativo
    return SizedBox(
      width: double.infinity, height: 48,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: canAdd ? kAccent : kBorder,
          borderRadius: BorderRadius.circular(11),
          boxShadow: canAdd ? [BoxShadow(color: kAccent.withOpacity(0.20),
              blurRadius: 12, offset: const Offset(0, 3))] : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: canAdd ? onAdd : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (cd) ...[
                  // Ring sutil de countdown
                  SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                      value: cdN / kCD,
                      strokeWidth: 1.5,
                      backgroundColor: Colors.white.withOpacity(0.20),
                      valueColor: AlwaysStoppedAnimation(
                          canAdd ? Colors.white.withOpacity(0.9) : kDim),
                    )),
                  const SizedBox(width: 8),
                  Text('Add another  ·  ${cdN}s',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: canAdd ? Colors.white.withOpacity(0.9) : kDim,
                          letterSpacing: 0.1)),
                ] else ...[
                  Icon(Icons.add_rounded, size: 15,
                      color: canAdd ? Colors.white.withOpacity(0.9) : kDim),
                  const SizedBox(width: 6),
                  Text('Add session',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: canAdd ? Colors.white.withOpacity(0.9) : kDim,
                          letterSpacing: 0.1)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: kBorder, width: 1)),
        child: const Icon(Icons.add, size: 18, color: kBorder)),
      const SizedBox(height: 14),
      const Text('No sessions', style: TextStyle(fontSize: 13, color: kDim, fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      const Text('Enter hours above to get started', style: TextStyle(fontSize: 11, color: kDim)),
    ])),
  );
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w600, color: kDim, letterSpacing: 1.2)),
  );
}