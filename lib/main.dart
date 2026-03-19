import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const AuthGate(),
    );
  }
}

// AUTH GATE
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) return const HomePage();
        return const LoginPage();
      },
    );
  }
}

// LOGIN PROFESIONAL
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  String error = "";

  Future submit() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = "";
    });

    try {
      if (email.text.isEmpty || pass.text.isEmpty) {
        error = "Completa todos los campos";
      } else if (isLogin) {
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
      error = "Credenciales inválidas";
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF020617)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: glass(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "StudyFlow",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password"),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(),
                            )
                          : Text(isLogin ? "Iniciar sesión" : "Crear cuenta"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(
                      isLogin
                          ? "¿No tienes cuenta? Regístrate"
                          : "Ya tengo cuenta",
                    ),
                  ),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// HOME PROFESIONAL
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

    if (minutos <= 90) {
      recommendation = "Pomodoro es óptimo";
      while (minutos >= 25) {
        sesiones.add({'duracion': 25, 'tipo': 'Pomodoro'});
        minutos -= 25;
      }
    } else if (minutos <= 240) {
      recommendation = "Balance 52/17 ideal";
      while (minutos >= 52) {
        sesiones.add({'duracion': 52, 'tipo': '52/17'});
        minutos -= 52;
      }
    } else {
      recommendation = "Deep Work recomendado";
      while (minutos >= 90) {
        sesiones.add({'duracion': 90, 'tipo': 'Deep Work'});
        minutos -= 90;
      }
    }

    return sesiones;
  }

  Future generar() async {
    if (loading) return;

    int h = int.tryParse(horas.text) ?? 0;
    if (h <= 0) return;

    setState(() => loading = true);

    String uid = FirebaseAuth.instance.currentUser!.uid;

    var sesiones = generarSesiones(h);

    var batch = FirebaseFirestore.instance.batch();

    for (var s in sesiones) {
      var ref = FirebaseFirestore.instance.collection('sesiones').doc();
      batch.set(ref, {'uid': uid, ...s, 'completado': false});
    }

    await batch.commit();

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("StudyFlow"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            glass(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Planifica tu estudio",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: horas,
                    decoration: const InputDecoration(
                      labelText: "Horas disponibles",
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: loading ? null : generar,
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(),
                          )
                        : const Text("Optimizar sesiones"),
                  ),
                  const SizedBox(height: 10),
                  if (recommendation.isNotEmpty)
                    Text(
                      recommendation,
                      style: const TextStyle(color: Colors.blueAccent),
                    ),
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
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(child: Text("No hay sesiones aún"));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 15),
                    itemBuilder: (context, i) {
                      return SessionCard(id: docs[i].id, data: docs[i]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget glass({required Widget child}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: const EdgeInsets.all(20),
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
  final String id;
  final dynamic data;

  const SessionCard({super.key, required this.id, required this.data});

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  int seconds = 0;
  Timer? timer;
  bool running = false;

  void start() {
    if (running) return;
    running = true;
    seconds = widget.data['duracion'] * 60;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
        running = false;
      } else {
        setState(() => seconds--);
      }
    });
  }

  void pause() {
    timer?.cancel();
    running = false;
  }

  @override
  Widget build(BuildContext context) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;

    return glass(
      child: Column(
        children: [
          Text(widget.data['tipo'], style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 5),
          Text("${widget.data['duracion']} min"),
          const SizedBox(height: 10),
          Text(
            seconds > 0 ? "${min}:${sec.toString().padLeft(2, '0')}" : "Ready",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: start, icon: const Icon(Icons.play_arrow)),
              IconButton(onPressed: pause, icon: const Icon(Icons.pause)),
              IconButton(
                onPressed: () => FirebaseFirestore.instance
                    .collection('sesiones')
                    .doc(widget.id)
                    .delete(),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}