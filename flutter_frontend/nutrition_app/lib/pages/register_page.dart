import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty)    return 'Full name is required';
    if (s.length < 3) return 'Enter your full name';
    return null;
  }

  String? _validateEmail(String? v) {
    final email = (v ?? '').trim();
    if (email.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final p = v ?? '';
    if (p.isEmpty)    return 'Password is required';
    if (p.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final name     = _nameCtrl.text.trim();
      final email    = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      final res = await Supabase.instance.client.auth
          .signUp(email: email, password: password);

      if (res.user != null) {
        // Create profile row in Supabase
        await Supabase.instance.client.from('profiles').insert({
          'user_id': res.user!.id,
          'display_name': name,
          'first_name': name,
          'avatar_url': "", 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome aboard, $name! 🎉'), backgroundColor: Colors.green,),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        throw Exception('Sign-up failed');
      }
    } catch (e) {
      setState(() {
        _error = 'Registration failed. ${e.toString().replaceAll("Exception: ", "")}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required Widget icon,
    required String hint,
  }) =>
      InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          child: icon,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromRGBO(252, 252, 252, 1), Color.fromRGBO(255, 255, 255, 1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Illustration placeholder
                SizedBox(
                    height: 200,
                    child: Center(
                      child: Image.asset(
                        'assets/app_logo.png',
                        width: 240,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Title & subtitle
                const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 3, 209, 110),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign up to start your healthy journey',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xB9252525)),
                ),

                const SizedBox(height: 32),

                // Form container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(0, 255, 255, 255),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Full Name
                        TextFormField(
                          controller: _nameCtrl,
                          validator: _validateName,
                          decoration: _inputDecoration(
                            icon: const Icon(Icons.person_outline),
                            hint: 'Name',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailCtrl,
                          validator: _validateEmail,
                          decoration: _inputDecoration(
                            icon: const Icon(Icons.email_outlined),
                            hint: 'Email',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          validator: _validatePassword,
                          decoration: _inputDecoration(
                            icon: const Icon(Icons.lock_outline),
                            hint: 'Password',
                          ).copyWith(
                            suffixIcon: Padding(
                              padding: EdgeInsetsDirectional.only(end: 16), // right padding
                              child: IconButton(
                                padding: EdgeInsets.zero,     // remove default IconButton padding
                                constraints: BoxConstraints(),// collapse its hit-area to the icon size
                                icon: Icon(
                                  _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                        ],

                        const SizedBox(height: 24),

                        // Sign Up button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ).copyWith(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color?>((states) {
                                if (states.contains(WidgetState.disabled)) {
                                  return Colors.green[200];
                                }
                                return null;
                              }),
                              elevation: WidgetStateProperty.all(0),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                colors: [Color.fromARGB(255, 25, 241, 136), Color.fromARGB(255, 2, 219, 114)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                height: 56,
                                alignment: Alignment.center,
                                child: _loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Sign Up',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        // Back to Login
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                    color: const Color.fromARGB(255, 4, 4, 4),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Log in',
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 2, 219, 114), // colored word
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
