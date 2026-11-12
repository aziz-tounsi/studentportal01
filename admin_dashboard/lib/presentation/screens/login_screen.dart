import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/ios_loader.dart';
import '../widgets/school_logo_preview.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Login Screen  ░░░
// ═══════════════════════════════════════════════════════════════════

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (success && mounted) {
      context.go('/');
    }
  }

  String _getUserFriendlyErrorMessage(String? rawError, bool accessDenied) {
    if (accessDenied) {
      return 'Access restricted. You need administrator privileges to sign in.';
    }
    if (rawError == null || rawError.isEmpty) {
      return 'Unable to sign in. Please verify your credentials and try again.';
    }

    final lower = rawError.toLowerCase();

    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid email or password') ||
        lower.contains('incorrect email or password') ||
        lower.contains('invalid password') ||
        lower.contains('user not found')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed') ||
        lower.contains('not been confirmed')) {
      return 'Your email address is not verified yet. Please check your inbox.';
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('too many attempts') ||
        lower.contains('over_email_send_rate_limit')) {
      return 'Too many sign-in attempts. Please wait a moment before trying again.';
    }
    if (lower.contains('socket') ||
        lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('timeout') ||
        lower.contains('timed out')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }
    if (lower.contains('jwt') ||
        lower.contains('token') ||
        lower.contains('session')) {
      return 'Your session has expired. Please sign in again.';
    }
    if (lower.contains('server error') ||
        lower.contains('temporarily unavailable') ||
        lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504')) {
      return 'The server is temporarily unavailable. Please try again shortly.';
    }

    // Clean English fallback instead of technical database/stack errors
    return 'Unable to sign in. Please check your credentials and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Row(
          children: [
            // ── Left Panel — Midnight Aurora branding ──
            if (size.width > 900)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF050912),
                        Color(0xFF0A1128),
                        Color(0xFF0F1B3D),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Subtle grid pattern overlay
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter()),
                      ),
                      // Blue aurora orb — top right
                      Positioned(
                        top: -80,
                        right: -60,
                        child: Container(
                          width: 380,
                          height: 380,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.18),
                                AppColors.primary.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Violet aurora orb — bottom left
                      Positioned(
                        bottom: -120,
                        left: -80,
                        child: Container(
                          width: 450,
                          height: 450,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.secondary.withOpacity(0.14),
                                AppColors.secondary.withOpacity(0.04),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Coral accent orb — center-right
                      Positioned(
                        top: size.height * 0.4,
                        right: 40,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accent.withOpacity(0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Content layer
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo bar
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const SchoolLogoPreview(
                                    logoUrl: null,
                                    size: 48,
                                    borderRadius: AppRadius.sm,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PythaOne',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Text(
                                      'Administration',
                                      style: TextStyle(
                                        color: AppColors.primaryLight.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Hero text — scrollable to prevent overflow
                            Expanded(
                              child: SingleChildScrollView(
                                child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Accent line
                                    Container(
                                      width: 40,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Bienvenue sur\nvotre espace\nadministrateur',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Gérez efficacement votre établissement scolaire\navec notre plateforme moderne et intuitive.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.45),
                                        fontSize: 16,
                                        height: 1.7,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 44),
                                    // Feature cards — frosted glass
                                    _AuroraFeatureCard(
                                      icon: Icons.people_outline_rounded,
                                      title: 'Gestion des utilisateurs',
                                      subtitle: 'Étudiants, enseignants, parents',
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    _AuroraFeatureCard(
                                      icon: Icons.insights_rounded,
                                      title: 'Tableaux de bord analytiques',
                                      subtitle: 'Métriques en temps réel',
                                      color: AppColors.secondary,
                                    ),
                                    const SizedBox(height: 12),
                                    _AuroraFeatureCard(
                                      icon: Icons.account_balance_wallet_outlined,
                                      title: 'Suivi des paiements',
                                      subtitle: 'Facturation et recouvrement',
                                      color: AppColors.accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ),
                            ),
                            const SizedBox(height: 16),
                            // Footer
                            Text(
                              '© 2024 PythaOne. Tous droits réservés.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.25),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Right Panel — Login Form ──
            Expanded(
              flex: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  // Subtle radial glow under the form area
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.3),
                    radius: 1.2,
                    colors: [
                      AppColors.primarySoft.withOpacity(0.5),
                      AppColors.background,
                    ],
                  ),
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Mobile Logo
                                if (size.width <= 900) ...[
                                  Center(
                                    child: Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius: BorderRadius.circular(AppRadius.lg),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.35),
                                            blurRadius: 24,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.hexagon_rounded, color: Colors.white, size: 32),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                ],

                                // Header
                                Row(
                                  mainAxisAlignment: size.width <= 900
                                      ? MainAxisAlignment.center
                                      : MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Connexion',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.only(left: 18),
                                  child: Text(
                                    'Accédez à votre espace d\'administration',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: size.width <= 900 ? TextAlign.center : TextAlign.left,
                                  ),
                                ),
                                const SizedBox(height: 36),

                                // Email field
                                _AuroraTextField(
                                  controller: _emailController,
                                  label: 'Adresse email',
                                  hint: 'admin@pythaone.com',
                                  prefixIcon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Veuillez entrer un email valide';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Password field
                                _AuroraTextField(
                                  controller: _passwordController,
                                  label: 'Mot de passe',
                                  hint: '••••••••',
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textTertiary,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre mot de passe';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                // Error message
                                if (authState.errorMessage != null || authState.accessDenied)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: authState.accessDenied
                                          ? AppColors.warningSoft
                                          : AppColors.errorSoft,
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                           color: (authState.accessDenied
                                                   ? AppColors.warning
                                                   : AppColors.error)
                                               .withOpacity(0.12),
                                           borderRadius: BorderRadius.circular(AppRadius.xs),
                                         ),
                                         child: Icon(
                                           authState.accessDenied
                                               ? Icons.shield_outlined
                                               : Icons.error_outline_rounded,
                                           color: authState.accessDenied
                                               ? AppColors.warning
                                               : AppColors.error,
                                           size: 20,
                                         ),
                                       ),
                                       const SizedBox(width: 12),
                                       Expanded(
                                         child: Text(
                                           _getUserFriendlyErrorMessage(
                                             authState.errorMessage,
                                             authState.accessDenied,
                                           ),
                                           style: TextStyle(
                                             color: authState.accessDenied
                                                 ? AppColors.warning
                                                 : AppColors.error,
                                             fontWeight: FontWeight.w600,
                                             fontSize: 13,
                                             height: 1.35,
                                           ),
                                         ),
                                       ),
                                     ],
                                   ),
                                 ),

                                // Login button
                                _AuroraLoginButton(
                                  onPressed: authState.isLoading ? null : _handleLogin,
                                  isLoading: authState.isLoading,
                                  label: 'Se connecter',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ░░░  Internal Widgets  ░░░
// ═══════════════════════════════════════════════════════════════════

/// Frosted glass feature card for the left panel
class _AuroraFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _AuroraFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, color: color.withOpacity(0.9), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.15), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle grid pattern painter for the left panel background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Premium text field with floating label aesthetic
class _AuroraTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  const _AuroraTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textTertiary.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(prefixIcon, color: AppColors.textTertiary, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide(color: AppColors.border.withOpacity(0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient login button with hover glow
class _AuroraLoginButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const _AuroraLoginButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
  });

  @override
  State<_AuroraLoginButton> createState() => _AuroraLoginButtonState();
}

class _AuroraLoginButtonState extends State<_AuroraLoginButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 54,
        decoration: BoxDecoration(
          gradient: widget.onPressed != null ? AppColors.primaryGradient : null,
          color: widget.onPressed == null ? AppColors.slate300 : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: widget.onPressed != null
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(_isHovered ? 0.45 : 0.2),
                    blurRadius: _isHovered ? 24 : 12,
                    offset: Offset(0, _isHovered ? 10 : 5),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Center(
              child: widget.isLoading
                  ? const IosLoader(size: 22, color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(
                            _isHovered ? 4.0 : 0.0, 0, 0,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
