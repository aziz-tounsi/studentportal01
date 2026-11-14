import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/console_translations.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';

class ConsoleLoginScreen extends ConsumerStatefulWidget {
  const ConsoleLoginScreen({super.key});

  @override
  ConsumerState<ConsoleLoginScreen> createState() => _ConsoleLoginScreenState();
}

class _ConsoleLoginScreenState extends ConsumerState<ConsoleLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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

    final success =
        await ref.read(consoleAuthProvider.notifier).signIn(email, pass);
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(consoleTranslationsProvider);
    final currentLang = ref.watch(consoleLocaleProvider);
    final state = ref.watch(consoleAuthProvider);

    // If session is already active or restored from local storage on reload, auto-redirect to dashboard
    if (state.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
      return const Scaffold(
        backgroundColor: ConsoleColors.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ConsoleColors.brand,
          ),
        ),
      );
    }

    if (!state.isInitialized || state.isLoading) {
      return const Scaffold(
        backgroundColor: ConsoleColors.background,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ConsoleColors.brand,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ConsoleColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ConsoleColors.brand.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ConsoleColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Language Switcher at Top Right
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ConsoleColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langButton(
                    label: 'EN',
                    isActive: currentLang == ConsoleLanguage.en,
                    onTap: () => ref
                        .read(consoleLocaleProvider.notifier)
                        .setLanguage(ConsoleLanguage.en),
                  ),
                  const SizedBox(width: 4),
                  _langButton(
                    label: 'FR',
                    isActive: currentLang == ConsoleLanguage.fr,
                    onTap: () => ref
                        .read(consoleLocaleProvider.notifier)
                        .setLanguage(ConsoleLanguage.fr),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ConsoleColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: ConsoleColors.primaryGradient,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.loginTitle,
                            style: const TextStyle(
                              color: ConsoleColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            tr.loginSubtitle,
                            style: const TextStyle(
                              color: ConsoleColors.brand,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    tr.loginCardHeading,
                    style: const TextStyle(
                      color: ConsoleColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr.loginCardSubheading,
                    style: const TextStyle(
                      color: ConsoleColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (state.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: ConsoleColors.errorSoft,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: ConsoleColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: ConsoleColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: ConsoleColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: tr.emailLabel,
                      hintText: tr.emailPlaceholder,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: ConsoleColors.textTertiary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: tr.passwordLabel,
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: ConsoleColors.textTertiary,
                        size: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: ConsoleColors.textTertiary,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: state.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ConsoleColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: state.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              tr.btnSignIn,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? ConsoleColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : ConsoleColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
