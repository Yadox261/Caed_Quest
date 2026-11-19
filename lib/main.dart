import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:card_quest/screens/login_screen.dart';
import 'package:card_quest/screens/progress_ranking_screen.dart';
import 'firebase_options.dart';

/// Instancia global de Firestore para usar en toda la app
final FirebaseFirestore db = FirebaseFirestore.instance;

/// Mientras sea true, la puerta de sesión mantiene el login en pantalla
/// para que la animación termine antes de cambiar de pantalla.
final ValueNotifier<bool> holdLogin = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('✅ Firebase conectado: ${Firebase.app().options.projectId}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Quest',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD210EB),
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final Stream<User?> _authStream = FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: holdLogin,
      builder: (context, hold, _) {
        return StreamBuilder<User?>(
          stream: _authStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F0E17),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFD210EB)),
                ),
              );
            }

            // Si tiene sesión activa y terminó la animación -> ProfileScreen con datos de Firestore
            if (snapshot.hasData && !hold) {
              final user = snapshot.data!;
              return ProfileScreen(
                providers: [
                  EmailAuthProvider(),
                ],
                actions: [
                  SignedOutAction((context) {
                    // Al cerrar sesión vuelve al Login
                  }),
                ],
                appBar: AppBar(
                  title: const Text('Mi Perfil'),
                  backgroundColor: const Color(0xFF1E1B2E),
                  actions: [
                    IconButton(
                      tooltip: 'Progreso y Ranking',
                      icon: const Icon(Icons.leaderboard, color: Color(0xFFD210EB)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressRankingScreen(currentUserId: user.uid),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                // Panel visual que prueba la lectura y escritura en tiempo real de Firestore
                children: [
                  const SizedBox(height: 16),
                  _FirestoreTestCard(userId: user.uid),
                ],
              );
            }

            // Si no tiene sesión -> LoginScreen con el Samurai
            return const LoginScreen();
          },
        );
      },
    );
  }
}

/// Widget para verificar en vivo la conexión con Firestore usando los datos del usuario
class _FirestoreTestCard extends StatefulWidget {
  final String userId;
  const _FirestoreTestCard({required this.userId});

  @override
  State<_FirestoreTestCard> createState() => _FirestoreTestCardState();
}

class _FirestoreTestCardState extends State<_FirestoreTestCard> {
  bool _testingWrite = false;
  String? _statusMessage;

  // Prueba de escritura/actualización en Firestore
  Future<void> _testWrite() async {
    setState(() {
      _testingWrite = true;
      _statusMessage = null;
    });

    try {
      await db.collection('users').doc(widget.userId).set({
        'lastPing': FieldValue.serverTimestamp(),
        'testStatus': 'Conexión exitosa a Firestore ✅',
        'level': 1,
      }, SetOptions(merge: true));

      setState(() {
        _statusMessage = '¡Escritura en Firestore confirmada!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error al escribir: $e';
      });
    } finally {
      if (mounted) setState(() => _testingWrite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD210EB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.cloud_done, color: Color(0xFFD210EB)),
              SizedBox(width: 8),
              Text(
                'Estado de Firestore (users)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stream en tiempo real para leer los datos del usuario en la colección 'users'
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: db.collection('users').doc(widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(color: Color(0xFFD210EB)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Text(
                  '❌ Error de lectura: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Text(
                  '⚠️ No se encontró documento para este usuario en /users. Haz clic abajo para crearlo y probar la base de datos.',
                  style: TextStyle(color: Colors.amberAccent),
                );
              }

              final data = snapshot.data!.data() ?? {};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📄 ID de Documento: ${widget.userId}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Divider(color: Colors.white24),
                  Text('👤 Nombre: ${data['name'] ?? 'No especificado'}',
                      style: const TextStyle(color: Colors.white)),
                  Text('✉️ Email: ${data['email'] ?? 'No especificado'}',
                      style: const TextStyle(color: Colors.white)),
                  if (data['testStatus'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '📡 Estado: ${data['testStatus']}',
                        style: const TextStyle(
                            color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (data['lastPing'] != null)
                    Text(
                      '⏱ Último Ping: ${(data['lastPing'] as Timestamp).toDate()}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          if (_statusMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.contains('Error')
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  fontSize: 13,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD210EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _testingWrite ? null : _testWrite,
              icon: _testingWrite
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: const Text('Probar escritura en Firestore'),
            ),
          ),
        ],
      ),
    );
  }
}
