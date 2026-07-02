import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/supabase_service.dart';
import '../main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  bool _isSignUp = false;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = SupabaseService();

      if (_isSignUp) {
        final res = await svc.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);

        // Supabase does NOT throw an error for an already-registered email
        // (to avoid leaking which emails exist). Instead it returns a user
        // with an empty `identities` list. We have to check for that manually.
        final alreadyRegistered =
            res.user != null && (res.user!.identities?.isEmpty ?? false);

        if (alreadyRegistered) {
          setState(() => _error =
              'This email is already registered. Please sign in instead.');
          return;
        }

        // If email confirmation is enabled in Supabase, signUp succeeds but
        // returns no session until the user confirms via email link.
        if (res.session == null) {
          setState(() {
            _error = 'Account created! Please check your email to confirm '
                'your account, then sign in.';
            _isSignUp = false; // flip to sign-in view for convenience
          });
          return;
        }
      } else {
        await svc.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      }

      // Only navigate if we actually have a live session.
      if (svc.currentUser == null) {
        setState(() => _error = 'Sign in failed. Please try again.');
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } on AuthException catch (e) {
      // Supabase-specific errors (invalid credentials, weak password, etc.)
      // come through as clean messages instead of a raw exception dump.
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.kitchen_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chill Coders',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('Smart Fridge System',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(_isSignUp ? 'Create account' : 'Welcome back',
                  style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 6),
              Text(_isSignUp ? 'Start monitoring your fridge' : 'Sign in to your dashboard',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),

              // Error
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEECEC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: AppTheme.danger, fontSize: 13))),
                  ]),
                ),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),

              // Toggle
              Center(
                child: TextButton(
                  onPressed: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                  child: Text(
                    _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                    style: const TextStyle(color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}