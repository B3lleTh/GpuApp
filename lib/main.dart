import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// ─── Palette — deep navy + rose gold ─────────────────────────────────────────
const kBg = Color(0xFF0D0D14); // deep void
const kSurf = Color(0xFF13131C); // surface
const kBorder = Color(0xFF1E1E2C); // border
const kDim = Color(0xFF50506A); // muted
const kHi = Color(0xFFE8E8F0); // primary text

const kAccent = Color(0xFFB07FE8); // lavender — acento principal
const kActive = Color(0xFF7EB8A4); // menta oscuro — estudio activo
const kRest = Color(0xFF6B8FBA); // acero azul — descanso
const kDone = Color(0xFFB07FE8); // lavender — completado
const kErr = Color(0xFFB05C72); // rose — error / pausa

const int kMaxPlans = 5;
const int kMaxHours = 12;
const int kCD = 10;

// ─── Modelo ───────────────────────────────────────────────────────────────────
class Plan {
  final String id;
  final int hours;
  final String method;
  final int studyMin;
  final int breakMin;
  final int totalBlocks;
  final int completedBlocks;

  bool get isDone => completedBlocks >= totalBlocks;
  bool get isRunning => completedBlocks < totalBlocks;
  double get progress => totalBlocks == 0 ? 0 : completedBlocks / totalBlocks;
  int get totalStudyMins => studyMin * totalBlocks;

  const Plan({
    required this.id,
    required this.hours,
    required this.method,
    required this.studyMin,
    required this.breakMin,
    required this.totalBlocks,
    required this.completedBlocks,
  });

  factory Plan.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Plan(
      id: d.id,
      hours: (m['hours'] as num?)?.toInt() ?? 0,
      method: (m['method'] as String?) ?? '—',
      studyMin: (m['studyMin'] as num?)?.toInt() ?? 25,
      breakMin: (m['breakMin'] as num?)?.toInt() ?? 5,
      totalBlocks: (m['totalBlocks'] as num?)?.toInt() ?? 1,
      completedBlocks: (m['completedBlocks'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap(String uid) => {
    'uid': uid,
    'hours': hours,
    'method': method,
    'studyMin': studyMin,
    'breakMin': breakMin,
    'totalBlocks': totalBlocks,
    'completedBlocks': completedBlocks,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
}

// ─── Algorithm ────────────────────────────────────────────────────────────────
Plan buildPlan(int hours) {
  final String method;
  final int sm, bm;
  if (hours <= 2) {
    method = 'Pomodoro';
    sm = 25;
    bm = 5;
  } else if (hours <= 5) {
    method = '52 / 17';
    sm = 52;
    bm = 17;
  } else {
    method = 'Deep Work';
    sm = 90;
    bm = 15;
  }
  final blocks = max((hours * 60) ~/ (sm + bm), 1);
  return Plan(
    id: '',
    hours: hours,
    method: method,
    studyMin: sm,
    breakMin: bm,
    totalBlocks: blocks,
    completedBlocks: 0,
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GPA',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        surface: kSurf,
        error: kErr,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBg,
        labelStyle: const TextStyle(color: kDim, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _ob(),
        enabledBorder: _ob(),
        focusedBorder: _ob(kAccent, 1.2),
      ),
    ),
    home: const _Gate(),
  );

  static OutlineInputBorder _ob([Color c = kBorder, double w = 1.0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
}

// ─── Gate ─────────────────────────────────────────────────────────────────────
class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (_, s) {
      if (s.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          backgroundColor: kBg,
          body: Center(
            child: CircularProgressIndicator(strokeWidth: 1.5, color: kAccent),
          ),
        );
      }
      return s.hasData ? const HomePage() : const LoginPage();
    },
  );
}

// ─── Primitives ───────────────────────────────────────────────────────────────
class SCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? bg;
  const SCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.bg,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg ?? kSurf,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder, width: 0.8),
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  const Pill(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.24), width: 0.7),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: color,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class Tap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Tap({super.key, required this.child, this.onTap});
  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
  );
  late final _s = Tween(begin: 1.0, end: 0.96).animate(_c);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
    onTapUp: widget.onTap == null
        ? null
        : (_) {
            _c.reverse();
            widget.onTap!();
          },
    onTapCancel: () => _c.reverse(),
    child: ScaleTransition(scale: _s, child: widget.child),
  );
}

class PBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;
  final IconData? icon;
  const PBtn({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.color = kAccent,
    this.icon,
  });
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
          boxShadow: on
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: on ? Colors.white.withOpacity(0.8) : kDim,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: on ? Colors.white.withOpacity(0.9) : kDim,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white.withOpacity(0.9) : kDim,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Wave painter ────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double phase1;
  final double phase2;
  final double phase3;
  const _WavePainter(this.phase1, this.phase2, this.phase3);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    void drawWave(double phase, Color color, double yBase, double amp) {
      final path = Path();
      path.moveTo(0, h);
      for (double x = 0; x <= w; x++) {
        final y =
            yBase +
            amp *
                (0.6 * sin(2 * pi * (x / w) + phase) +
                    0.4 * sin(4 * pi * (x / w) + phase * 1.3));
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.lineTo(w, h);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    drawWave(phase1, const Color(0x12B07FE8), h * 0.60, h * 0.06);
    drawWave(phase2, const Color(0x0E6B8FBA), h * 0.68, h * 0.05);
    drawWave(phase3, const Color(0x0B7EB8A4), h * 0.75, h * 0.04);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase1 != phase1 || old.phase2 != phase2 || old.phase3 != phase3;
}

// ─── Login ────────────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LS();
}

class _LS extends State<LoginPage> with TickerProviderStateMixin {
  final _e = TextEditingController(), _p = TextEditingController();
  bool _login = true, _busy = false, _hide = true;
  String _err = '';

  late final AnimationController _waveCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _waveCtrl.dispose();
    _e.dispose();
    _p.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final em = _e.text.trim(), pw = _p.text.trim();
    if (em.isEmpty || pw.isEmpty) {
      setState(() => _err = 'Fill in all fields');
      return;
    }
    if (pw.length < 6) {
      setState(() => _err = 'Password needs 6+ characters');
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      if (_login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: em,
          password: pw,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: em,
          password: pw,
        );
      }
    } on FirebaseAuthException catch (ex) {
      if (mounted) setState(() => _err = _msg(ex.code));
    } catch (_) {
      if (mounted) setState(() => _err = 'Something went wrong');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _msg(String c) {
    switch (c) {
      case 'user-not-found':
        return 'No account with that email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'invalid-email':
        return 'Invalid email format';
      default:
        return 'Auth failed — try again';
    }
  }

  // Glass input field with label above
  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool obscure = false,
    TextInputType? type,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: kDim,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure && _hide,
          keyboardType: type,
          style: const TextStyle(fontSize: 13, color: kHi),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.09),
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.09),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: kAccent.withOpacity(0.55),
                width: 1.2,
              ),
            ),
            suffixIcon: obscure
                ? GestureDetector(
                    onTap: () => setState(() => _hide = !_hide),
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Icon(
                        _hide
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 16,
                        color: kDim,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedBuilder(
        animation: _waveCtrl,
        builder: (context, _) {
          final t = _waveCtrl.value * 2 * pi;
          return Stack(
            children: [
              // ── Orbs ──
              Positioned(
                top: -80,
                left: -60,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [kAccent.withOpacity(0.16), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 120,
                right: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [kRest.withOpacity(0.12), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // ── Waves ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _WavePainter(t, t * 0.77, t * 0.55),
                ),
              ),

              // ── Content ──
              SafeArea(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top wordmark ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(26, 30, 26, 0),
                            child: RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'G',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: kAccent,
                                      letterSpacing: -1,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'PA',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.w800,
                                      color: kHi,
                                      letterSpacing: -1,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // ── Tagline ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(26, 0, 26, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _login ? 'Welcome back' : 'Get started',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w300,
                                    color: kHi,
                                    letterSpacing: -0.4,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _login
                                      ? 'Plan your time. Own your grades.'
                                      : 'Structured focus for better results.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kDim,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Glass card ──
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 24,
                                  sigmaY: 24,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _field(
                                        'Email',
                                        _e,
                                        type: TextInputType.emailAddress,
                                      ),
                                      const SizedBox(height: 14),
                                      _field('Password', _p, obscure: true),

                                      if (_err.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 12,
                                              color: kErr,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _err,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: kErr,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        child: PBtn(
                                          label: _login
                                              ? 'Sign in'
                                              : 'Create account',
                                          onTap: _busy ? null : _go,
                                          loading: _busy,
                                        ),
                                      ),

                                      const SizedBox(height: 16),
                                      Center(
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _login = !_login;
                                            _err = '';
                                          }),
                                          child: Text.rich(
                                            TextSpan(
                                              style: const TextStyle(
                                                fontSize: 12,
                                                decoration: TextDecoration.none,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: _login
                                                      ? 'No account?  '
                                                      : 'Have account?  ',
                                                  style: const TextStyle(
                                                    color: kDim,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: _login
                                                      ? 'Register'
                                                      : 'Sign in',
                                                  style: const TextStyle(
                                                    color: kAccent,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Home ─────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HS();
}

class _HS extends State<HomePage> {
  final _ctrl = TextEditingController();
  bool _cd = false;
  int _cdN = 0;
  Timer? _cdTimer;
  String _hint = '';
  int _preview = 0;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void dispose() {
    _cdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onH(String v) {
    final h = int.tryParse(v) ?? 0;
    if (h >= 1 && h <= kMaxHours) {
      final p = buildPlan(h);
      setState(() {
        _preview = p.totalBlocks;
        _hint = '${p.method}  ·  ${p.studyMin}m / ${p.breakMin}m';
      });
    } else {
      setState(() {
        _preview = 0;
        _hint = '';
      });
    }
  }

  void _startCD() {
    setState(() {
      _cd = true;
      _cdN = kCD;
    });
    _cdTimer?.cancel();
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cdN <= 1) {
        t.cancel();
        setState(() {
          _cd = false;
          _cdN = 0;
        });
      } else
        setState(() => _cdN--);
    });
  }

  Future<void> _addPlan(int activePlanCount) async {
    final h = int.tryParse(_ctrl.text.trim()) ?? 0;
    if (h < 1) {
      _snack('Enter at least 1 hour', err: true);
      return;
    }
    if (h > kMaxHours) {
      _snack('Max $kMaxHours hours', err: true);
      return;
    }
    if (activePlanCount >= kMaxPlans) {
      _snack('$kMaxPlans plans max — remove one first', err: true);
      return;
    }
    try {
      final plan = buildPlan(h);
      await FirebaseFirestore.instance
          .collection('planes')
          .add(plan.toMap(_uid));
      if (mounted) {
        _snack('Plan added · ${plan.method} · ${plan.totalBlocks} blocks');
        _startCD();
      }
    } catch (e) {
      if (mounted) _snack('Could not save plan', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kHi,
            ),
          ),
          backgroundColor: err
              ? const Color(0xFF1E0A10)
              : const Color(0xFF0E0E18),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: err ? kErr.withOpacity(0.3) : kBorder,
              width: 0.8,
            ),
          ),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('planes')
            .where('uid', isEqualTo: _uid)
            .snapshots(),
        builder: (context, snap) {
          final plans = snap.hasData
              ? (snap.data!.docs.map(Plan.fromDoc).toList()..sort((a, b) {
                  final ad =
                      (snap.data!.docs.firstWhere((d) => d.id == a.id).data()
                              as Map)['createdAt']
                          as int? ??
                      0;
                  final bd =
                      (snap.data!.docs.firstWhere((d) => d.id == b.id).data()
                              as Map)['createdAt']
                          as int? ??
                      0;
                  return ad.compareTo(bd);
                }))
              : <Plan>[];

          final activePlans = plans.where((p) => !p.isDone).toList();
          final donePlans = plans.where((p) => p.isDone).toList();
          final activeCount = activePlans.length;
          final canAdd = activeCount < kMaxPlans;

          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _appBar(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                        children: [
                          _StatsCard(
                            email: _email,
                            active: activeCount,
                            done: donePlans.length,
                            totalMins: plans.fold(
                              0,
                              (s, p) => s + p.totalStudyMins,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _InputCard(
                            ctrl: _ctrl,
                            hint: _hint,
                            preview: _preview,
                            cd: _cd,
                            cdN: _cdN,
                            canAdd: canAdd,
                            activeCount: activeCount,
                            onChanged: _onH,
                            onAdd: () => _addPlan(activeCount),
                          ),
                          const SizedBox(height: 20),
                          if (!snap.hasData)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: kAccent,
                                ),
                              ),
                            )
                          else if (plans.isEmpty)
                            const _Empty()
                          else ...[
                            if (activePlans.isNotEmpty) ...[
                              _SectionLabel(
                                'Active  ·  ${activePlans.length}/$kMaxPlans',
                              ),
                              ...activePlans.map(
                                (p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: PlanCard(plan: p),
                                ),
                              ),
                            ],
                            if (donePlans.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _SectionLabel(
                                'Completed  ·  ${donePlans.length}',
                              ),
                              ...donePlans.map(
                                (p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: PlanCard(plan: p),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_cd) _CDOverlay(n: _cdN),
            ],
          );
        },
      ),
    );
  }

  Widget _appBar() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 12, 0),
    child: Row(
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'G',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kAccent,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),
              TextSpan(
                text: 'PA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kHi,
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Tap(
          onTap: () => FirebaseAuth.instance.signOut(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.logout_rounded, size: 16, color: kDim),
          ),
        ),
      ],
    ),
  );
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: kDim,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ─── Stats card ───────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final String email;
  final int active, done, totalMins;
  const _StatsCard({
    required this.email,
    required this.active,
    required this.done,
    required this.totalMins,
  });

  String get _initials {
    final n = email.split('@').first;
    final p = n.split('.');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  String _fmt(int m) {
    final h = m ~/ 60, r = m % 60;
    if (h == 0) return '${r}m';
    if (r == 0) return '${h}h';
    return '${h}h ${r}m';
  }

  @override
  Widget build(BuildContext context) => SCard(
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kAccent.withOpacity(0.20),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kHi,
                    ),
                  ),
                  const Text(
                    'Study stats',
                    style: TextStyle(fontSize: 11, color: kDim),
                  ),
                ],
              ),
            ),
            Pill('$active/$kMaxPlans', active >= kMaxPlans ? kErr : kAccent),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 0.8, color: kBorder),
        const SizedBox(height: 12),
        Row(
          children: [
            _M('$active', 'Active', kAccent, Icons.layers_outlined),
            Container(width: 0.8, height: 32, color: kBorder),
            _M('$done', 'Completed', kActive, Icons.check_rounded),
            Container(width: 0.8, height: 32, color: kBorder),
            _M(_fmt(totalMins), 'Planned', kRest, Icons.schedule_outlined),
          ],
        ),
      ],
    ),
  );
}

class _M extends StatelessWidget {
  final String v, l;
  final Color c;
  final IconData i;
  const _M(this.v, this.l, this.c, this.i);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(i, size: 13, color: c),
        const SizedBox(height: 3),
        Text(
          v,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          l,
          style: const TextStyle(fontSize: 10, color: kDim),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ─── Input card ───────────────────────────────────────────────────────────────
class _InputCard extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int preview, cdN, activeCount;
  final bool cd, canAdd;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;

  const _InputCard({
    required this.ctrl,
    required this.hint,
    required this.preview,
    required this.cd,
    required this.cdN,
    required this.canAdd,
    required this.activeCount,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) => SCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'New session',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kHi,
              ),
            ),
            const Spacer(),
            if (preview > 0)
              Text(
                '$preview blocks',
                style: const TextStyle(
                  fontSize: 11,
                  color: kAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          activeCount >= kMaxPlans
              ? 'Limit reached — delete a plan to add more'
              : '1–$kMaxHours h  ·  up to $kMaxPlans concurrent',
          style: TextStyle(
            fontSize: 11,
            color: activeCount >= kMaxPlans ? kErr : kDim,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: kHi),
          decoration: const InputDecoration(labelText: 'Available hours'),
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kAccent,
                ),
              ),
              const SizedBox(width: 7),
              Text(hint, style: const TextStyle(fontSize: 11, color: kDim)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: PBtn(
            label: cd ? 'Add another  ·  ${cdN}s' : 'Add session',
            onTap: canAdd ? onAdd : null,
            loading: false,
            color: kAccent,
          ),
        ),
      ],
    ),
  );
}

// ─── Empty ────────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBorder, width: 1),
            ),
            child: const Icon(Icons.add, size: 18, color: kBorder),
          ),
          const SizedBox(height: 14),
          const Text(
            'No sessions',
            style: TextStyle(
              fontSize: 13,
              color: kDim,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Enter hours above to get started',
            style: TextStyle(fontSize: 11, color: kDim),
          ),
        ],
      ),
    ),
  );
}

// ─── Cooldown overlay ─────────────────────────────────────────────────────────
class _CDOverlay extends StatelessWidget {
  final int n;
  const _CDOverlay({required this.n});
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: ColoredBox(
          color: Colors.black.withOpacity(0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: n / kCD,
                          strokeWidth: 1.5,
                          backgroundColor: kBorder,
                          valueColor: const AlwaysStoppedAnimation(kAccent),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$n',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: kHi,
                              letterSpacing: -1,
                              height: 1,
                            ),
                          ),
                          const Text(
                            'sec',
                            style: TextStyle(
                              fontSize: 9,
                              color: kDim,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Session added',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: kHi,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'You can add another right now',
                  style: TextStyle(fontSize: 11, color: kDim),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ─── Plan card ────────────────────────────────────────────────────────────────
enum _Phase { idle, study, rest, done }

class PlanCard extends StatefulWidget {
  final Plan plan;
  const PlanCard({super.key, required this.plan});
  @override
  State<PlanCard> createState() => _PCS();
}

class _PCS extends State<PlanCard> {
  _Phase _phase = _Phase.idle;
  int _secs = 0;
  Timer? _timer;

  Plan get p => widget.plan;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlanCard old) {
    super.didUpdateWidget(old);
    if (p.isDone && _phase != _Phase.done) {
      _timer?.cancel();
      setState(() {
        _phase = _Phase.done;
        _secs = 0;
      });
    }
  }

  void _start() {
    if (_phase == _Phase.study || _phase == _Phase.rest || p.isDone) return;
    setState(() {
      _phase = _Phase.study;
      _secs = p.studyMin * 60;
    });
    _tick();
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _secs = 0;
    });
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secs > 0) {
        setState(() => _secs--);
        return;
      }
      if (_phase == _Phase.study) {
        setState(() {
          _phase = _Phase.rest;
          _secs = p.breakMin * 60;
        });
      } else {
        _timer?.cancel();
        final next = p.completedBlocks + 1;
        FirebaseFirestore.instance.collection('planes').doc(p.id).update({
          'completedBlocks': next,
        });
        setState(() {
          _phase = next >= p.totalBlocks ? _Phase.done : _Phase.idle;
          _secs = 0;
        });
      }
    });
  }

  Future<void> _delete() async {
    _timer?.cancel();
    await FirebaseFirestore.instance.collection('planes').doc(p.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    final fin = p.isDone || _phase == _Phase.done;
    final run = _phase == _Phase.study || _phase == _Phase.rest;
    final m = _secs ~/ 60, s = _secs % 60;

    final Color accent;
    final String label;
    if (fin) {
      accent = kDone;
      label = 'Done';
    } else if (_phase == _Phase.study) {
      accent = kActive;
      label = 'Focus';
    } else if (_phase == _Phase.rest) {
      accent = kRest;
      label = 'Rest';
    } else {
      accent = kDim;
      label = 'Idle';
    }

    final pct = run
        ? _secs / ((_phase == _Phase.study ? p.studyMin : p.breakMin) * 60)
        : (fin ? 1.0 : 0.0);

    return SCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                p.method,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: kHi,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${p.hours}h',
                style: const TextStyle(fontSize: 12, color: kDim),
              ),
              const Spacer(),
              // Estado sin icono — solo texto con dot
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 2,
                    backgroundColor: kBorder,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${p.completedBlocks}/${p.totalBlocks}',
                style: TextStyle(
                  fontSize: 10,
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Timer row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Ring — sin icono interior
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  value: pct,
                  strokeWidth: 2,
                  backgroundColor: kBorder,
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run
                          ? '${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}'
                          : fin
                          ? 'Completed'
                          : 'Block ${p.completedBlocks + 1} / ${p.totalBlocks}',
                      style: TextStyle(
                        fontSize: run ? 22 : 13,
                        fontWeight: run ? FontWeight.w300 : FontWeight.w500,
                        color: run ? accent : kHi,
                        letterSpacing: run ? 2 : 0,
                      ),
                    ),
                    if (!fin)
                      Text(
                        run
                            ? (_phase == _Phase.study
                                  ? '${p.studyMin}m focus'
                                  : '${p.breakMin}m rest')
                            : '${p.studyMin}m focus  ·  ${p.breakMin}m rest',
                        style: const TextStyle(fontSize: 11, color: kDim),
                      ),
                  ],
                ),
              ),

              // Actions
              if (!fin) ...[
                if (run)
                  _ActBtn('Pause', kErr, _pause, icon: Icons.pause_rounded)
                else
                  _ActBtn(
                    p.completedBlocks == 0 ? 'Start' : 'Resume',
                    accent,
                    _start,
                    icon: Icons.play_arrow_rounded,
                  ),
                const SizedBox(width: 8),
              ],

              // Delete — X con hover rojo
              _DeleteBtn(onTap: _delete),
            ],
          ),
        ],
      ),
    );
  }
}

// Botón de acción con icono + hover animado
class _ActBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  const _ActBtn(this.label, this.color, this.onTap, {this.icon});
  @override
  State<_ActBtn> createState() => _ActBtnState();
}

class _ActBtnState extends State<_ActBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hov ? c.withOpacity(0.18) : c.withOpacity(0.09),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hov ? c.withOpacity(0.45) : c.withOpacity(0.20),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: c),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: c,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Botón eliminar — X roja con hover
class _DeleteBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteBtn({required this.onTap});
  @override
  State<_DeleteBtn> createState() => _DeleteBtnState();
}

class _DeleteBtnState extends State<_DeleteBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hov = true),
    onExit: (_) => setState(() => _hov = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _hov ? kErr.withOpacity(0.18) : kErr.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hov ? kErr.withOpacity(0.50) : kErr.withOpacity(0.18),
            width: 0.8,
          ),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 15,
          color: _hov ? kErr : kErr.withOpacity(0.55),
        ),
      ),
    ),
  );
}