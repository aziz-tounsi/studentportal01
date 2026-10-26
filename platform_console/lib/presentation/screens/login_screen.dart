import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';

class ConsoleLoginScreen extends ConsumerStatefulWidget {
  const ConsoleLoginScreen({super.key});

  @override
  ConsumerState<ConsoleLoginScreen> createState() => _ConsoleLoginScreenState();
}

class _ConsoleLoginScreenState extends ConsumerState<ConsoleLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@isgc.dz');
  final _passCtrl = TextEditingController(text: 'Admin1234!');
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;

    final success = await ref.read(consoleAuthProvider.notifier).signIn(email, pass);
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consoleAuthProvider);

    return Scaffold(
      backgroundColor: ConsoleColors.background,
      body: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: ConsoleColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ConsoleColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & Badge
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: ConsoleColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pythagore Console',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Master Platform Controller',
                        style: TextStyle(color: ConsoleColors.primaryLight, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Connexion Fondateur',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Accès réservé exclusivement au rôle super_admin.',
                style: TextStyle(color: ConsoleColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 24),

              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ConsoleColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ConsoleColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: ConsoleColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: ConsoleColors.error, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Super Admin',
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ConsoleColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Accéder à la Console',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
