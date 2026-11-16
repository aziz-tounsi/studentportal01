import 'package:flutter/material.dart';

/// Representation of a single sort option
class SortOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SortOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

typedef AdminSortOption<T> = SortOption<T>;

/// Modern reusable sort dropdown with rounded radius, checkmark indicator,
/// and smooth theme alignment across all admin dashboard tables and pages.
class AdminSortDropdown<T> extends StatelessWidget {
  final T selectedValue;
  final List<SortOption<T>> options;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final bool showLabel;
  final double radius;
  final double height;
  final Color? activeColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final T? defaultValue;
  final bool hasShadow;
  final Color? iconColor;

  AdminSortDropdown({
    super.key,
    T? selectedValue,
    T? value,
    required this.options,
    ValueChanged<T>? onSelected,
    ValueChanged<T>? onChanged,
    this.tooltip = 'Trier par',
    this.showLabel = false,
    this.radius = 8,
    this.height = 40,
    this.activeColor,
    this.backgroundColor,
    this.borderColor,
    this.defaultValue,
    this.hasShadow = false,
    this.iconColor,
  })  : selectedValue = (selectedValue ?? value) as T,
        onSelected = (onSelected ?? onChanged) ?? ((_) {});

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? const Color(0xFF6D4CF6);
    final defVal = defaultValue ?? (options.isNotEmpty ? options.first.value : null);
    final isNonDefault = selectedValue != defVal;

    final selectedOpt = options.firstWhere(
      (o) => o.value == selectedValue,
      orElse: () => options.first,
    );

    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(radius),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      offset: Offset(0, height + 4),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<T>>[];

        items.add(
          PopupMenuItem<T>(
            enabled: false,
            height: 32,
            child: Row(
              children: [
                Icon(Icons.sort_rounded, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text(
                  'TRIER PAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        );
        items.add(const PopupMenuDivider(height: 1));

        for (final opt in options) {
          final isSelected = opt.value == selectedValue;
          items.add(
            PopupMenuItem<T>(
              value: opt.value,
              height: 40,
              child: Row(
                children: [
                  if (opt.icon != null) ...[
                    Icon(
                      opt.icon,
                      size: 16,
                      color: isSelected ? effectiveActiveColor : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? effectiveActiveColor : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: effectiveActiveColor,
                    ),
                ],
              ),
            ),
          );
        }

        return items;
      },
      child: Container(
        height: height,
        width: showLabel ? null : height,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 12 : 0,
          vertical: 0,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.swap_vert_rounded,
                  size: height <= 34 ? 16 : 20,
                  color: iconColor ?? (isNonDefault ? effectiveActiveColor : const Color(0xFF6B7280)),
                ),
                if (isNonDefault && !showLabel)
                  Positioned(
                    right: -1,
                    top: -1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: effectiveActiveColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                selectedOpt.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isNonDefault ? FontWeight.w700 : FontWeight.w500,
                  color: isNonDefault ? effectiveActiveColor : const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isNonDefault ? effectiveActiveColor : const Color(0xFF9CA3AF),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
