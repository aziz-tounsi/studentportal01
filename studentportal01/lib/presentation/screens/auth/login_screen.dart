import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avatar_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);

    if (success && mounted) {
      await ref.read(avatarProvider.notifier).reloadForCurrentUser();
      context.go('/');
    }
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailController = TextEditingController();
    bool isSubmitting = false;
    bool isSubmitted = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isSubmitted) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D78).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read,
                      size: 48,
                      color: Color(0xFFFF2D78),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Demande envoyée !',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre demande de réinitialisation a été envoyée à l\'administrateur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D78).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFFF2D78),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vous recevrez un nouveau mot de passe une fois votre demande approuvée.',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFFF2D78).withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D78),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Compris'),
                ),
              ],
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.lock_reset, color: Color(0xFFFF2D78)),
                const SizedBox(width: 12),
                const Text(
                  'Mot de passe oublié',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrez votre email pour demander une réinitialisation de mot de passe.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'exemple@email.com',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFFFF2D78),
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      gapPadding: 0,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      gapPadding: 0,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9999),
                      borderSide: const BorderSide(
                        color: Color(0xFFFF2D78),
                        width: 1.5,
                      ),
                      gapPadding: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D78).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: Color(0xFFFF2D78),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'L\'administrateur traitera votre demande dans les plus brefs délais.',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFFFF2D78).withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF2D78),
                ),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (emailController.text.isEmpty ||
                            !emailController.text.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez entrer un email valide'),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);

                        try {
                          await ref
                              .read(authProvider.notifier)
                              .requestPasswordReset(
                                emailController.text.trim(),
                              );
                          setDialogState(() {
                            isSubmitting = false;
                            isSubmitted = true;
                          });
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2D78),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Envoyer la demande'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        color: const Color(0xFFF5F7FB),
        child: SafeArea(
          child: Stack(
            children: [
              // Ambient pink glow at bottom center
              Positioned(
                bottom: -140,
                left: -180,
                child: IgnorePointer(
                  child: Container(
                    width: 560,
                    height: 560,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF2D78).withValues(alpha: 0.18),
                          const Color(0xFFFF2D78).withValues(alpha: 0.04),
                          const Color(0xFFF5F7FB).withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.4, 0.65],
                      ),
                    ),
                  ),
                ),
              ),
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            // Title
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'Bienvenue sur EduPortail',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                  letterSpacing: -0.02,
                                  height: 42 / 34,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Spacer(flex: 1),
                            // Form fields
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  // Email label + field
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20, bottom: 8),
                                        child: Text(
                                          'Adresse e-mail',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'votre@email.com',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                          filled: true,
                                          fillColor: Colors.transparent,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF2D78),
                                              width: 1.5,
                                            ),
                                            gapPadding: 0,
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Veuillez entrer votre email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Email invalide';
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Password label + field
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 20, bottom: 8),
                                        child: Text(
                                          'Mot de passe',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _handleLogin(),
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '••••••••',
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                          ),
                                          filled: true,
                                          fillColor: Colors.transparent,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFF2D78),
                                              width: 1.5,
                                            ),
                                            gapPadding: 0,
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(9999),
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                            gapPadding: 0,
                                          ),
                                            suffixIcon: Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons.visibility_off_outlined
                                                      : Icons.visibility_outlined,
                                                  color: AppColors.textSecondary,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword = !_obscurePassword;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Veuillez entrer votre mot de passe';
                                            }
                                            return null;
                                          },
                                        ),
                                    ],
                                  ),
                                  // Forgot password
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: TextButton(
                                        onPressed: () => _showForgotPasswordDialog(context),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Mot de passe oublié ?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.02,
                                            color: AppColors.textSecondary.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Error messages
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  if (authState.accessDenied) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.orange.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Accès Refusé',
                                                  style: TextStyle(
                                                    color: Colors.orange.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            authState.errorMessage ??
                                                'Cette application est réservée aux étudiants uniquement.',
                                            style: TextStyle(color: Colors.orange.shade800),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Si vous êtes administrateur, veuillez utiliser le tableau de bord admin.',
                                            style: TextStyle(
                                              color: Colors.orange.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ] else if (authState.errorMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: AppColors.error),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              authState.errorMessage!,
                                              style: const TextStyle(color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  // Login button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 60,
                                    child: ElevatedButton(
                                      onPressed: authState.isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF2D78),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shadowColor: const Color(0xFFFF2D78).withValues(alpha: 0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(9999),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        child: authState.isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    l10n.signIn,
                                                    style: const TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(flex: 3),
                          ],
                        ),
                      ),
                    ),
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
