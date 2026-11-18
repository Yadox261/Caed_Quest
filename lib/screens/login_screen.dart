import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:card_quest/main.dart';
import 'package:card_quest/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // MOSTRAR / OCULTAR CONTRASEÑA
  // ============================================================
  bool _obscure = true;

  // ============================================================
  // CARGA (mientras Firebase responde)
  // ============================================================
  bool _loading = false;

  // ============================================================
  // REMEMBER ME
  // ============================================================
  bool _rememberMe = false;
  bool _isTogglingRemember = false;
  late final AnimationController _rememberCtrl;

  // ============================================================
  // RIVE (Samurai Hero)
  // ============================================================
  StateMachineController? _controller;
  SMIBool? _isClicked;
  SMITrigger? _click;

  // ============================================================
  // GIROSCOPIO / EFECTO 3D PARALAJE
  // ============================================================
  StreamSubscription<AccelerometerEvent>? _sensorSub;
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  // ============================================================
  // FOCUS NODES & CONTROLLERS
  // ============================================================
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // ============================================================
  // ERRORES
  // ============================================================
  String? emailError;
  String? passError;

  // ============================================================
  // VALIDACIONES
  // ============================================================
  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  // ============================================================
  // LOGIN
  // ============================================================
  Future<void> _onLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    final eError = isValidEmail(email) ? null : 'Invalid email';
    final pError = pass.isEmpty ? 'Enter your password' : null;

    setState(() {
      emailError = eError;
      passError = pError;
    });

    FocusScope.of(context).unfocus();

    if (eError != null || pError != null) {
      return;
    }

    setState(() => _loading = true);
    holdLogin.value = true;

    _click?.fire();
    _isClicked?.value = true;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
      debugPrint('✅ Login exitoso');
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 800));
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error Firebase: ${e.code}');
      if (mounted) {
        setState(() => passError = _mensaje(e.code));
      }
    } finally {
      holdLogin.value = false;
      if (mounted) {
        setState(() => _loading = false);
        _isClicked?.value = false;
      }
    }
  }

  String _mensaje(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'too-many-requests':
        return 'Too many attempts, try later';
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return 'Login error ($code)';
    }
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Reset password', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Email',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send', style: TextStyle(color: Color(0xFFD210EB))),
          ),
        ],
      ),
    );

    if (email == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (!isValidEmail(email)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'If that email is registered, we sent a reset link. '
            'Check your inbox and spam folder.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error reset: ${e.code}');
      messenger.showSnackBar(SnackBar(content: Text(_mensaje(e.code))));
    }
  }

  // ============================================================
  // REMEMBER ME
  // ============================================================
  void _toggleRememberMe() {
    if (_isTogglingRemember) return;

    setState(() {
      _isTogglingRemember = true;
      _rememberMe = !_rememberMe;
    });

    if (_rememberMe) {
      _rememberCtrl.forward();
    } else {
      _rememberCtrl.reverse();
    }
  }

  // ============================================================
  // INIT STATE
  // ============================================================
  @override
  void initState() {
    super.initState();

    _rememberCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          if (!mounted) return;
          setState(() => _isTogglingRemember = false);
        }
      });

    _sensorSub = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (!mounted) return;
        setState(() {
          _tiltX = (event.x / 9.8).clamp(-1.0, 1.0) * 0.35;
          _tiltY = ((event.y - 4.5) / 9.8).clamp(-1.0, 1.0) * 0.35;
        });
      },
      onError: (_) {},
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17), // Fondo oscuro temático de la imagen
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ==================================================
                // ANIMACIÓN RIVE (Samurai Hero más grande con Giroscopio 3D)
                // ==================================================
                TweenAnimationBuilder<Offset>(
                  duration: const Duration(milliseconds: 120),
                  tween: Tween<Offset>(
                    begin: Offset.zero,
                    end: Offset(_tiltX, _tiltY),
                  ),
                  builder: (context, tilt, child) {
                    return Transform(
                      alignment: FractionalOffset.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(-tilt.dx)
                        ..rotateX(tilt.dy),
                      child: child,
                    );
                  },
                  child: Container(
                    width: size.width,
                    height: 330, // Tarjeta más grande
                    color: Colors.transparent,
                    child: RiveAnimation.asset(
                      'assets/samurai-hero.riv',
                      stateMachines: const ['State Machine 1'],
                      fit: BoxFit.contain,
                      onInit: (artboard) {
                        _controller = StateMachineController.fromArtboard(
                          artboard,
                          'State Machine 1',
                        );

                        if (_controller == null) return;
                        artboard.addController(_controller!);

                        _isClicked =
                            _controller!.findSMI('IsClicked') as SMIBool?;
                        _click =
                            _controller!.findSMI('Click') as SMITrigger?;
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // EMAIL
                // ==================================================
                TextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1B2E),
                    errorText: emailError,
                    hintText: 'Email',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.email, color: Color(0xFFD210EB)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E2A44)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD210EB), width: 2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ==================================================
                // PASSWORD
                // ==================================================
                TextField(
                  controller: _passCtrl,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF1E1B2E),
                    errorText: passError,
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFD210EB)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2E2A44)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD210EB), width: 2),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ==================================================
                // REMEMBER ME + FORGOT PASSWORD
                // ==================================================
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isTogglingRemember ? null : _toggleRememberMe,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _rememberCtrl,
                              builder: (context, _) {
                                final t = Curves.easeInOut
                                    .transform(_rememberCtrl.value);

                                return Container(
                                  width: 46,
                                  height: 26,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Color.lerp(
                                      Colors.grey.shade700,
                                      const Color(0xFFD210EB),
                                      t,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Align(
                                    alignment: Alignment.lerp(
                                      Alignment.centerLeft,
                                      Alignment.centerRight,
                                      t,
                                    )!,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _forgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color: Color(0xFFD210EB),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: const Color(0xFFD210EB),
                  disabledColor: const Color(0x66D210EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _loading ? null : _onLogin,
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
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 15),

                // ==================================================
                // SIGN UP
                // ==================================================
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Color(0xFFD210EB),
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================
  @override
  void dispose() {
    _sensorSub?.cancel();
    _rememberCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
