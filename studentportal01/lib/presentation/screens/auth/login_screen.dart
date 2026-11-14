import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/school_logo_widget.dart';
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
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _emailFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus) {
      _scrollToField(_emailFieldKey);
    } else if (_passwordFocusNode.hasFocus) {
      _scrollToField(_passwordFieldKey);
    }
  }

  void _scrollToField(GlobalKey key) {
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);

    if (success && mounted) {
      await ref.read(avatarProvider.notifier).reloadForCurrentUser();
      if (mounted) context.go('/');
    }
  }

  String _formatLoginError(String rawError, AppLocalizations l10n) {
    final lower = rawError.toLowerCase();
    if (lower.contains('invalid') ||
        lower.contains('credentials') ||
        lower.contains('grant') ||
        lower.contains('password')) {
      return l10n.translate('invalid_credentials');
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('offline')) {
      return l10n.translate('network_error');
    }
    if (lower.contains('schema') ||
        lower.contains('database') ||
        lower.contains('unexpected') ||
        lower.contains('server') ||
        lower.contains('500') ||
        rawError.contains('{')) {
      return l10n.translate('server_error');
    }
    return rawError;
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emailController = TextEditingController();
    bool isSubmitting = false;
    bool isSubmitted = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              if (isSubmitted) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(44),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
                  actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
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
                      Text(
                        l10n.translate('request_sent_title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.translate('request_sent_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  actions: [
                    BouncingWrapper(
                      shrinkScale: 0.92,
                      overshootScale: 1.05,
                      delayNavigation: false,
                      onTap: () => Navigator.pop(ctx),
                      child: ElevatedButton(
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
                        child: Text(l10n.translate('btn_understood')),
                      ),
                    ),
                  ],
                );
              }

              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(44),
                ),
                titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                title: Row(
                  children: [
                    const Icon(Icons.lock_reset, color: Color(0xFFFF2D78)),
                    const SizedBox(width: 12),
                    Text(
                      l10n.translate('forgot_password_title'),
                      style: const TextStyle(
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
                      l10n.translate('forgot_password_desc'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      onTapOutside: (_) => FocusScope.of(ctx).unfocus(),
                      style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Email ou matricule élève',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
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
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF2D78),
                    ),
                    child: Text(l10n.cancel),
                  ),
                  BouncingWrapper(
                    shrinkScale: 0.92,
                    overshootScale: 1.05,
                    delayNavigation: false,
                    onTap: isSubmitting
                        ? null
                        : () async {
                            if (emailController.text.isEmpty ||
                                !emailController.text.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l10n.translate('email_invalid')),
                                ),
                              );
                              return;
                            }
                            setDialogState(() => isSubmitting = true);
                            final messenger = ScaffoldMessenger.of(context);
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
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (emailController.text.isEmpty ||
                                  !emailController.text.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.translate('email_invalid')),
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => isSubmitting = true);
                              final messenger = ScaffoldMessenger.of(context);
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
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
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
                          ? const IosLoader(size: 20, color: Colors.white)
                          : Text(l10n.translate('btn_send_request')),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
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
            LayoutBuilder(
              builder: (context, constraints) {
                return ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding, vertical: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 40 > 0
                            ? constraints.maxHeight - 40
                            : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.14),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: SchoolLogoWidget(
                                      logoUrl: null,
                                      size: 84,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Title
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    l10n.translate('welcome_portal'),
                                    style: ArabicTypography.headerStyle(
                                      context,
                                      fontSize: context.sp(30),
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1A1A),
                                      letterSpacing: -0.02,
                                      height: 42 / 34,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 36),
                              // Email label + field
                              KeyedSubtree(
                                key: _emailFieldKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20, bottom: 8),
                                      child: Text(
                                        l10n.translate('email_address'),
                                        style: ArabicTypography.bodyStyle(
                                          context,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: _emailController,
                                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                                      focusNode: _emailFocusNode,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      scrollPadding: const EdgeInsets.only(bottom: 120, top: 40),
                                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                      style: ArabicTypography.bodyStyle(
                                        context,
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: l10n.translate('email_hint'),
                                        hintStyle: ArabicTypography.bodyStyle(
                                          context,
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
                                          return l10n.translate('email_required');
                                        }
                                        if (!value.contains('@')) {
                                          return l10n.translate('email_invalid');
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Password label + field
                              KeyedSubtree(
                                key: _passwordFieldKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20, bottom: 8),
                                      child: Text(
                                        l10n.password,
                                        style: ArabicTypography.bodyStyle(
                                          context,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: _passwordController,
                                      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                                      focusNode: _passwordFocusNode,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      scrollPadding: const EdgeInsets.only(bottom: 120, top: 40),
                                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      style: ArabicTypography.bodyStyle(
                                        context,
                                        color: const Color(0xFF1A1A1A),
                                        fontSize: 16,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        hintStyle: ArabicTypography.bodyStyle(
                                          context,
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
                                          return l10n.translate('password_required');
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Forgot password
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    onPressed: () {
                                      FocusScope.of(context).unfocus();
                                      _showForgotPasswordDialog(context);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      l10n.translate('forgot_password_q'),
                                      style: ArabicTypography.bodyStyle(
                                        context,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.02,
                                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Error messages
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
                                              l10n.translate('access_denied'),
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
                                            l10n.translate('access_denied_student_only'),
                                        style: TextStyle(color: Colors.orange.shade800),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.translate('access_denied_admin_dashboard'),
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
                                          _formatLoginError(authState.errorMessage!, l10n),
                                          style: ArabicTypography.bodyStyle(
                                            context,
                                            color: AppColors.error,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Login button
                              BouncingWrapper(
                                shrinkScale: 0.94,
                                overshootScale: 1.04,
                                delayNavigation: false,
                                onTap: authState.isLoading
                                    ? null
                                    : () {
                                        FocusScope.of(context).unfocus();
                                        _handleLogin();
                                      },
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () {
                                            FocusScope.of(context).unfocus();
                                            _handleLogin();
                                          },
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
                                          ? const IosLoader(size: 24, color: Colors.white)
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  l10n.signIn,
                                                  style: ArabicTypography.buttonStyle(
                                                    context,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
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
              },
            ),
          ],
        ),
      ),
    );
  }
}
