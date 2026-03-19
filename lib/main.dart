// PRO LEVEL 3 - SMART ROUTE + ANIMATIONS + VISUAL SCHEDULE

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F1A),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) return const HomePage();
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool isLogin = true;
  String error = "";

  Future submit() async {
    try {
      if (email.text.isEmpty || pass.text.isEmpty) {
        setState(() => error = "Completa todos los campos");
        return;
      }

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: pass.text.trim(),
        );
      }
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: glassContainer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("StudyFlow", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
                const SizedBox(height: 10),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: submit, child: Text(isLogin ? "Login" : "Crear cuenta")),
                TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? "Crear cuenta" : "Ya tengo cuenta")),
                if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final horas = TextEditingController();
  bool loading = false;
  String recommendation = "";

  List<Map<String, dynamic>> generarSesiones(int h) {
    int minutos = h * 60;
    List<Map<String, dynamic>> sesiones = [];

    if (minutos <= 60) {
      recommendation = "Mejor método: Pomodoro";
      while (minutos >= 25) {
        sesiones.add({'duracion': 25, 'tipo': 'Pomodoro'});
        minutos -= 25;
      }
    } else if (minutos <= 180) {
      recommendation = "Mejor método: 52/17";
      while (minutos >= 52) {
        sesiones.add({'duracion': 52, 'tipo': '52/17'});
        minutos -= 52;
      }
    } else {
      recommendation = "Ruta óptima combinada";
      while (minutos > 0) {
        if (minutos >= 90) {
          sesiones.add({'duracion': 90, 'tipo': 'Deep Work'});
          minutos -= 90;
        } else if (minutos >= 52) {
          sesiones.add({'duracion': 52, 'tipo': '52/17'});
          minutos -= 52;
        } else if (minutos >= 25) {
          sesiones.add({'duracion': 25, 'tipo': 'Pomodoro'});
          minutos -= 25;
        } else {
          break;
        }
      }
    }

    return sesiones;
  }

  Future generar() async {
    int h = int.tryParse(horas.text) ?? 0;
    if (h <= 0) return;

    setState(() => loading = true);
    await Future.delayed(const Duration(seconds: 2));

    String uid = FirebaseAuth.instance.currentUser!.uid;
    var sesiones = generarSesiones(h);

    for (var s in sesiones) {
      await FirebaseFirestore.instance.collection('sesiones').add({
        'uid': uid,
        ...s,
        'completado': false,
      });
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("StudyFlow")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            glassContainer(
              child: Column(
                children: [
                  TextField(controller: horas, decoration: const InputDecoration(labelText: "Horas disponibles")),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: generar, child: const Text("Calcular mejor ruta")),
                  const SizedBox(height: 10),
                  if (loading) const CircularProgressIndicator(),
                  if (recommendation.isNotEmpty)
                    Text(recommendation, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('sesiones')
                    .where('uid', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;

                  return ListView.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 15),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      var s = docs[i];
                      return SessionCard(data: s);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

Widget glassContainer({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(25),
        ),
        child: child,
      ),
    ),
  );
}

class SessionCard extends StatefulWidget {
  final dynamic data;

  const SessionCard({super.key, required this.data});

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  int seconds = 0;
  Timer? timer;

  void startTimer() {
    seconds = widget.data['duracion'] * 60;
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;

    return glassContainer(
      child: Column(
        children: [
          Text(widget.data['tipo'], style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 5),
          Text("${widget.data['duracion']} min"),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              seconds > 0 ? "${min}:${sec.toString().padLeft(2, '0')}" : "Ready",
              key: ValueKey(seconds),
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(onPressed: startTimer, icon: const Icon(Icons.play_arrow, size: 30)),
        ],
      ),
    );
  }
}
