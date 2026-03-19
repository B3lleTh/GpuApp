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

// ================= AUTH =================

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

// ================= LOGIN =================

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
  bool obscure = true;
  String error = "";

  Future submit() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = "";
    });

    try {
      if (email.text.isEmpty || pass.text.isEmpty) {
        error = "Complete all fields";
      } else if (pass.text.length < 6) {
        error = "Password must be at least 6 characters";
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
      error = "Invalid credentials";
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
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: glass(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("StudyFlow",
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),

                  TextField(
                    controller: email,
                    decoration: const InputDecoration(labelText: "Email"),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: pass,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: "Password",
                      suffixIcon: IconButton(
                        icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => obscure = !obscure),
                      ),
                    ),
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
                          : Text(isLogin ? "Login" : "Create Account"),
                    ),
                  ),

                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin
                        ? "No account? Register"
                        : "Already have an account"),
                  ),

                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= HOME =================

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

    if (minutos <= 120) {
      recommendation = "Pomodoro is optimal";

      while (minutos >= 30) {
        sesiones.add({
          'duracion': 25,
          'descanso': 5,
          'tipo': 'Pomodoro',
        });
        minutos -= 30;
      }
    } else if (minutos <= 300) {
      recommendation = "52/17 balance is ideal";

      while (minutos >= 69) {
        sesiones.add({
          'duracion': 52,
          'descanso': 17,
          'tipo': '52/17',
        });
        minutos -= 69;
      }
    } else {
      recommendation = "Deep Work recommended";

      while (minutos >= 105) {
        sesiones.add({
          'duracion': 90,
          'descanso': 15,
          'tipo': 'Deep Work',
        });
        minutos -= 105;
      }
    }

    return sesiones;
  }

  Future generar() async {
    if (loading) return;

    int h = int.tryParse(horas.text) ?? 0;
    if (h <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid hours")),
      );
      return;
    }

    setState(() => loading = true);

    String uid = FirebaseAuth.instance.currentUser!.uid;

    // borrar anteriores
    var old = await FirebaseFirestore.instance
        .collection('sesiones')
        .where('uid', isEqualTo: uid)
        .get();

    for (var doc in old.docs) {
      await doc.reference.delete();
    }

    var sesiones = generarSesiones(h);

    var batch = FirebaseFirestore.instance.batch();

    for (var s in sesiones) {
      var ref = FirebaseFirestore.instance.collection('sesiones').doc();
      batch.set(ref, {
        'uid': uid,
        ...s,
        'completado': false,
      });
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            glass(
              child: Column(
                children: [
                  TextField(
                    controller: horas,
                    decoration:
                        const InputDecoration(labelText: "Available hours"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: generar,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text("Optimize sessions"),
                  ),
                  if (recommendation.isNotEmpty)
                    Text(recommendation),
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

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 15),
                    itemBuilder: (_, i) =>
                        SessionCard(id: docs[i].id, data: docs[i]),
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

// ================= GLASS =================

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

// ================= SESSION CARD =================

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
  bool isBreak = false;

  int get duracion => widget.data['duracion'];
  int get descanso => widget.data['descanso'];

  void start() {
    if (running) return;

    running = true;
    isBreak = false;
    seconds = duracion * 60;

    runTimer();
  }

  void runTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        if (!isBreak) {
          setState(() {
            isBreak = true;
            seconds = descanso * 60;
          });
        } else {
          t.cancel();
          running = false;

          FirebaseFirestore.instance
              .collection('sesiones')
              .doc(widget.id)
              .update({'completado': true});
        }
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
          Text(widget.data['tipo']),
          Text("${duracion} min / ${descanso} break"),

          Text(
            isBreak ? "Break Time" : "Study Session",
            style: TextStyle(
              color: isBreak ? Colors.blue : Colors.green,
            ),
          ),

          Text(
            seconds > 0
                ? "$min:${sec.toString().padLeft(2, '0')}"
                : "Ready",
            style: const TextStyle(fontSize: 32),
          ),

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
