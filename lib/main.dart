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
        scaffoldBackgroundColor: const Color(0xFF0B0F1A),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

// AUTH
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

// LOGIN
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "GPU | StudyFlow",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: "Email"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: pass,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: submit,
                      child: Text(isLogin ? "Login" : "Crear cuenta"),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(isLogin ? "Crear cuenta" : "Ya tengo cuenta"),
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
      ),
    );
  }
}

// HOME
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final horas = TextEditingController();
  String metodo = "pomodoro";
  String error = "";

  List<Map<String, dynamic>> generarSesiones(int h) {
    List<Map<String, dynamic>> sesiones = [];
    int minutos = h * 60;

    if (metodo == "pomodoro") {
      while (minutos >= 25) {
        sesiones.add({'duracion': 25, 'descanso': 5, 'completado': false});
        minutos -= 25;
      }
    } else if (metodo == "52-17") {
      while (minutos >= 52) {
        sesiones.add({'duracion': 52, 'descanso': 17, 'completado': false});
        minutos -= 52;
      }
    } else {
      sesiones.add({
        'duracion': minutos ~/ 60,
        'descanso': 0,
        'completado': false,
      });
    }

    return sesiones;
  }

  void guardar() async {
    int h = int.tryParse(horas.text) ?? 0;

    if (h <= 0) {
      setState(() => error = "Ingresa horas válidas");
      return;
    }

    setState(() => error = "");

    String uid = FirebaseAuth.instance.currentUser!.uid;
    var sesiones = generarSesiones(h);

    for (var s in sesiones) {
      await FirebaseFirestore.instance.collection('sesiones').add({
        'uid': uid,
        ...s,
      });
    }
  }

  void eliminarSesion(String id) {
    FirebaseFirestore.instance.collection('sesiones').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("StudyFlow"),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            glassContainer(
              child: Column(
                children: [
                  TextField(
                    controller: horas,
                    decoration: const InputDecoration(
                      labelText: "Horas disponibles",
                    ),
                  ),
                  DropdownButton<String>(
                    value: metodo,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: "pomodoro",
                        child: Text("Pomodoro"),
                      ),
                      DropdownMenuItem(value: "52-17", child: Text("52/17")),
                      DropdownMenuItem(
                        value: "normal",
                        child: Text("Deep Work"),
                      ),
                    ],
                    onChanged: (v) => setState(() => metodo = v!),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: guardar,
                    child: const Text("Generar sesiones"),
                  ),
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
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
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      var s = docs[i];
                      return SessionCard(
                        id: s.id,
                        data: s,
                        onDelete: eliminarSesion,
                      );
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

// GLASS CONTAINER
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
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: child,
      ),
    ),
  );
}

// SESSION CARD + TIMER 
class SessionCard extends StatefulWidget {
  final String id;
  final dynamic data;
  final Function(String) onDelete;

  const SessionCard({
    super.key,
    required this.id,
    required this.data,
    required this.onDelete,
  });

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
          Text(
            "${widget.data['duracion']} min",
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          Text(
            seconds > 0 ? "${min}:${sec.toString().padLeft(2, '0')}" : "Ready",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: startTimer,
                icon: const Icon(Icons.play_arrow, size: 30),
              ),
              IconButton(
                onPressed: () => widget.onDelete(widget.id),
                icon: const Icon(Icons.delete, color: Colors.red),
              ),
              Checkbox(
                value: widget.data['completado'],
                onChanged: (v) {
                  FirebaseFirestore.instance
                      .collection('sesiones')
                      .doc(widget.id)
                      .update({'completado': v});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
