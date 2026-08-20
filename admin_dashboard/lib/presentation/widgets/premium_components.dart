import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/widgets/ios_loader.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Premium UI Components  ░░░
// ═══════════════════════════════════════════════════════════════════

/// Frosted-glass page header with blur effect
class PremiumPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Gradient? iconGradient;
  final List<Widget>? actions;

  const PremiumPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconGradient,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            border: Border(
              bottom: BorderSide(color: AppColors.border.withOpacity(0.4)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: iconGradient ?? AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (iconGradient != null
                              ? AppColors.primary
                              : const Color(0xFF2563EB))
                          .withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (actions != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      actions![i],
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass-morphism card with hover glow
class PremiumCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool hoverEffect;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.hoverEffect = true,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.hoverEffect ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.hoverEffect ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        padding: widget.padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_isHovered ? 1.0 : 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.border.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Gradient-filled or outlined pill button
class PremiumActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final bool isLoading;
  final bool outlined;

  const PremiumActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.gradient,
    this.isLoading = false,
    this.outlined = false,
  });

  @override
  State<PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<PremiumActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.outlined) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _isHovered ? AppColors.primary : AppColors.primary.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 17, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          gradient: widget.gradient ?? AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              child: widget.isLoading
                  ? const IosLoader(
                      size: 20,
                      color: Colors.white,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 17, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 0.1,
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

/// Frosted search field with animated focus ring
class PremiumSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const PremiumSearchField({
    super.key,
    required this.controller,
    this.hint = 'Rechercher...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 42),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 14),
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

/// Pill status badge with dot indicator
class PremiumStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Gradient? gradient;
  final IconData? icon;

  const PremiumStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.gradient,
    this.icon,
  });

  factory PremiumStatusBadge.success(String label) => PremiumStatusBadge(
        label: label,
        color: AppColors.success,
      );

  factory PremiumStatusBadge.warning(String label) => PremiumStatusBadge(
        label: label,
        color: AppColors.warning,
      );

  factory PremiumStatusBadge.error(String label) => PremiumStatusBadge(
        label: label,
        color: AppColors.error,
      );

  factory PremiumStatusBadge.info(String label) => PremiumStatusBadge(
        label: label,
        color: AppColors.info,
      );

  @override
  Widget build(BuildContext context) {
    final bool useGradient = gradient != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: useGradient ? gradient : null,
        color: !useGradient ? color.withOpacity(0.10) : null,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: !useGradient ? Border.all(color: color.withOpacity(0.20)) : null,
        boxShadow: useGradient
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: useGradient ? Colors.white : color),
            const SizedBox(width: 6),
          ] else ...[
            // ── Dot indicator ──
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: useGradient ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              color: useGradient ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Illustrated empty state
class PremiumEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Decorative circle with icon ──
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.secondary.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.10)),
            ),
            child: Icon(icon, size: 38, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 320,
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 28),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Frosted data table wrapper
class PremiumDataTableCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? titleIcon;
  final List<Widget>? actions;

  const PremiumDataTableCard({
    super.key,
    required this.child,
    this.title,
    this.titleIcon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.border.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Row(
                children: [
                  if (titleIcon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.12),
                            AppColors.secondary.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(titleIcon, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          // ── Subtle divider ──
          if (title != null)
            Container(
              height: 1,
              color: AppColors.border.withOpacity(0.3),
            ),
          ClipRRect(
            borderRadius: title != null
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  )
                : BorderRadius.circular(AppRadius.lg),
            child: child,
          ),
        ],
      ),
    );
  }
}
