import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/theme.dart';
import '../widgets/shared.dart';
import '../widgets/wave_painter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _e = TextEditingController(), _p = TextEditingController();
  bool _login = true, _busy = false, _hide = true;
  String _err = '';

  late final _waveCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() { _waveCtrl.dispose(); _e.dispose(); _p.dispose(); super.dispose(); }

  Future<void> _go() async {
    final em = _e.text.trim(), pw = _p.text.trim();
    if (em.isEmpty || pw.isEmpty) { setState(() => _err = 'Fill in all fields'); return; }
    if (pw.length < 6)            { setState(() => _err = 'Password needs 6+ chars'); return; }
    setState(() { _busy = true; _err = ''; });
    try {
      if (_login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: em, password: pw);
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: em, password: pw);
      }
    } on FirebaseAuthException catch (ex) {
      if (mounted) setState(() => _err = _authErr(ex.code));
    } catch (_) {
      if (mounted) setState(() => _err = 'Something went wrong');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authErr(String c) => switch (c) {
    'user-not-found'       => 'No account with that email',
    'wrong-password'       => 'Incorrect password',
    'email-already-in-use' => 'Email already registered',
    'invalid-email'        => 'Invalid email format',
    _                      => 'Auth failed — try again',
  };

  Widget _field(String label, TextEditingController ctrl,
      {bool obscure = false, TextInputType? type}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600, color: kDim, letterSpacing: 1.0)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl, obscureText: obscure && _hide, keyboardType: type,
        style: const TextStyle(fontSize: 13, color: kHi),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          filled: true, fillColor: Colors.white.withOpacity(0.04),
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.09), width: 0.8)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.09), width: 0.8)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: kAccent.withOpacity(0.55), width: 1.2)),
          suffixIcon: obscure ? GestureDetector(
            onTap: () => setState(() => _hide = !_hide),
            child: Padding(padding: const EdgeInsets.all(13),
              child: Icon(_hide ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined, size: 16, color: kDim)),
          ) : null,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, __) {
        final t = _waveCtrl.value * 2 * pi;
        return Stack(children: [
          Positioned(top: -80, left: -60, child: Orb(kAccent.withOpacity(0.16), 280)),
          Positioned(top: 120, right: -80, child: Orb(kRest.withOpacity(0.12), 220)),
          Positioned.fill(child: CustomPaint(painter: WavePainter(t, t * 0.77, t * 0.55))),
          SafeArea(child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height
                      - MediaQuery.of(context).padding.vertical),
              child: IntrinsicHeight(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(26, 30, 26, 0),
                    child: RichText(text: const TextSpan(children: [
                      TextSpan(text: 'G', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800,
                          color: kAccent, letterSpacing: -1, decoration: TextDecoration.none)),
                      TextSpan(text: 'PA', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800,
                          color: kHi, letterSpacing: -1, decoration: TextDecoration.none)),
                    ]))),
                  const Spacer(),
                  Padding(padding: const EdgeInsets.fromLTRB(26, 0, 26, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_login ? 'Welcome back' : 'Get started',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300,
                              color: kHi, letterSpacing: -0.4, decoration: TextDecoration.none)),
                      const SizedBox(height: 3),
                      Text(_login ? 'Plan your time. Own your grades.'
                          : 'Structured focus for better results.',
                          style: const TextStyle(fontSize: 12, color: kDim, decoration: TextDecoration.none)),
                    ])),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: ClipRRect(borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.10), width: 0.8),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _field('Email', _e, type: TextInputType.emailAddress),
                            const SizedBox(height: 14),
                            _field('Password', _p, obscure: true),
                            if (_err.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                const Icon(Icons.error_outline_rounded, size: 12, color: kErr),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_err, style: const TextStyle(
                                    fontSize: 11, color: kErr, decoration: TextDecoration.none))),
                              ]),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(width: double.infinity,
                              child: PBtn(label: _login ? 'Sign in' : 'Create account',
                                  onTap: _busy ? null : _go, loading: _busy)),
                            const SizedBox(height: 16),
                            Center(child: GestureDetector(
                              onTap: () => setState(() { _login = !_login; _err = ''; }),
                              child: Text.rich(TextSpan(
                                style: const TextStyle(fontSize: 12, decoration: TextDecoration.none),
                                children: [
                                  TextSpan(text: _login ? 'No account?  ' : 'Have account?  ',
                                      style: const TextStyle(color: kDim)),
                                  TextSpan(text: _login ? 'Register' : 'Sign in',
                                      style: const TextStyle(color: kAccent, fontWeight: FontWeight.w600)),
                                ],
                              )),
                            )),
                          ]),
                        ),
                      ),
                    )),
                ],
              )),
            ),
          )),
        ]);
      },
    ),
  );
}