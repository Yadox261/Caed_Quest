import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // ---------- Validaciones ----------
  String? _validateName(String? v) {
    if (v == null || v.trim().length < 2) return 'Enter your name';
    return null;
  }

  String? _validateEmail(String? v) {
    final email = v?.trim() ?? '';
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!re.hasMatch(email)) return 'Invalid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final pass = v ?? '';
    if (pass.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[a-z]').hasMatch(pass)) return 'Add a lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(pass)) return 'Add an uppercase letter';
    if (!RegExp(r'\d').hasMatch(pass)) return 'Add a number';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pass)) return 'Add a symbol';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  // ---------- Registro ----------
  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      final user = cred.user!;
      final name = _nameCtrl.text.trim();

      // Guardar datos iniciales de progreso en la colección 'users'
      try {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'name': name,
              'email': user.email,
              'unlockedLevel': 1,      // Inicia en el nivel 1
              'totalVictories': 0,     // 0 victorias iniciales
              'highScore': 0,          // Récord inicial en 0
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('⚠️ No se pudo guardar en Firestore: $e');
      }

      debugPrint('✅ Registro exitoso: ${user.email}');
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 8));
        debugPrint('📄 Doc en servidor: ${doc.exists}');
      } catch (e) {
        debugPrint('⚠️ Lectura Firestore falló: $e');
      }
      // La cuenta ya quedó con sesión iniciada: regresamos a la raíz
      // y AuthGate muestra la pantalla principal.
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error registro: ${e.code}');
      if (mounted) setState(() => _error = _mensaje(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mensaje(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email is already registered';
      case 'invalid-email':
        return 'Invalid email format';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled';
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return 'Sign up error ($code)';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  validator: _validateName,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration('Name', Icons.person),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: _decoration('Email', Icons.email),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  validator: _validatePassword,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _decoration(
                    'Password',
                    Icons.lock,
                    suffix: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Min. 8 characters, with upper and lower case, a number and a symbol.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  validator: _validateConfirm,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _decoration('Confirm password', Icons.lock_outline),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: const Color.fromRGBO(210, 16, 235, 0.536),
                  disabledColor: const Color.fromRGBO(210, 16, 235, 0.536),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _loading ? null : _signUp,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign up',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}