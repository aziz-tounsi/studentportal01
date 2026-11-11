import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class BouncyDropdownItem<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color color;

  const BouncyDropdownItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class BouncyDropdownSelector<T> extends StatefulWidget {
  final List<BouncyDropdownItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final String categoryTitle;
  final double itemHeight;
  final double maxHeight;
  final double borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry padding;
  final double? menuWidth;
  final Alignment menuAlignment;
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle, BouncyDropdownItem<T>? selectedItem)? customTrigger;

  const BouncyDropdownSelector({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    this.categoryTitle = '',
    this.itemHeight = 52.0,
    this.maxHeight = 312.0,
    this.borderRadius = 22.0,
    this.border,
    this.boxShadow,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.menuWidth,
    this.menuAlignment = Alignment.bottomLeft,
    this.customTrigger,
  });

  static final List<VoidCallback> _activeClosers = [];

  static void closeAll() {
    for (final closer in List<VoidCallback>.from(_activeClosers)) {
      closer();
    }
    _activeClosers.clear();
  }

  @override
  State<BouncyDropdownSelector<T>> createState() => _BouncyDropdownSelectorState<T>();
}

class _BouncyDropdownSelectorState<T> extends State<BouncyDropdownSelector<T>>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  late final AnimationController _c;
  late final ScrollController _scrollController;
  OverlayEntry? _entry;
  bool _isOpen = false;
  bool _closing = false;

  // Spring physics from user specification:
  // Lower damping = more bounce.
  static final _spring = SpringDescription(mass: 1, stiffness: 380, damping: 19);

  double get _fullHeight {
    final totalHeight = widget.items.length * widget.itemHeight + 12.0;
    return math.min(totalHeight, widget.maxHeight);
  }

  bool get _isScrollable {
    final totalHeight = widget.items.length * widget.itemHeight + 12.0;
    return totalHeight > widget.maxHeight;
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this, value: 0);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    BouncyDropdownSelector._activeClosers.remove(_forceClose);
    _entry?.remove();
    _entry = null;
    _c.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _forceClose() {
    if (_entry != null) {
      _entry?.remove();
      _entry = null;
      _closing = false;
      if (mounted) {
        setState(() => _isOpen = false);
      }
    }
  }

  void _open() {
    if (_entry != null || _closing) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    BouncyDropdownSelector._activeClosers.add(_forceClose);
    setState(() => _isOpen = true);

    _entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            // Tap outside or drag to close
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                onPanStart: (_) => _close(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: widget.menuAlignment == Alignment.bottomRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              followerAnchor: widget.menuAlignment == Alignment.bottomRight
                  ? Alignment.topRight
                  : Alignment.topLeft,
              offset: Offset(0, size.height + 6),
              child: SizedBox(
                width: widget.menuWidth ?? (size.width < 220 ? 240.0 : size.width),
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final h = _fullHeight * math.max(0.0, _c.value);
                    final isScrollable = _isScrollable;
                    return Material(
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(widget.borderRadius),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        child: SizedBox(
                          height: h,
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            minHeight: 0,
                            maxHeight: _fullHeight,
                            child: SizedBox(
                              height: _fullHeight,
                              child: isScrollable
                                  ? RawScrollbar(
                                      controller: _scrollController,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      interactive: true,
                                      thickness: 5.0,
                                      radius: const Radius.circular(9999),
                                      trackRadius: const Radius.circular(9999),
                                      thumbColor: const Color(0xFFFF2D78).withValues(alpha: 0.65),
                                      trackColor: const Color(0xFFF1F5F9),
                                      padding: const EdgeInsets.only(right: 5, top: 12, bottom: 12),
                                      child: _buildListView(isScrollable),
                                    )
                                  : _buildListView(isScrollable),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    _c.animateWith(SpringSimulation(_spring, _c.value, 1.0, 0.0));
  }

  Widget _buildListView(bool isScrollable) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          6,
          6,
          isScrollable ? 14 : 6,
          6,
        ),
        physics: isScrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final isSelected = item.value == widget.selectedValue;
          return InkWell(
            onTap: () {
              widget.onSelected(item.value);
              _close();
            },
            borderRadius: BorderRadius.circular(14),
            splashColor: item.color.withValues(alpha: 0.1),
            highlightColor: item.color.withValues(alpha: 0.05),
            child: SizedBox(
              height: widget.itemHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? item.color : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded, color: item.color, size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _close() async {
    if (_entry == null || _closing) return;
    _closing = true;
    BouncyDropdownSelector._activeClosers.remove(_forceClose);
    if (mounted) {
      setState(() => _isOpen = false);
    }
    try {
      await _c.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInBack,
      );
    } catch (_) {}
    _entry?.remove();
    _entry = null;
    _closing = false;
  }

  void _toggle() {
    if (_isOpen || _entry != null) {
      _close();
    } else {
      _open();
    }
  }

  @override
  Widget build(BuildContext context) {
    BouncyDropdownItem<T>? selectedItem;
    for (final item in widget.items) {
      if (item.value == widget.selectedValue) {
        selectedItem = item;
        break;
      }
    }
    selectedItem ??= widget.items.isNotEmpty ? widget.items.first : null;

    final selectedColor = selectedItem?.color ?? const Color(0xFFFF2D78);
    final selectedIcon = selectedItem?.icon ?? Icons.category_rounded;
    final selectedLabel = selectedItem?.label ?? '';

    if (widget.customTrigger != null) {
      return CompositedTransformTarget(
        link: _link,
        child: widget.customTrigger!(context, _isOpen, _toggle, selectedItem),
      );
    }

    return CompositedTransformTarget(
      link: _link,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: widget.boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: AnimatedScale(
              scale: _isOpen ? 0.98 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Container(
                padding: widget.padding,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selectedColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(selectedIcon, color: selectedColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.categoryTitle,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: selectedColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AnimatedRotation(
                        turns: _isOpen ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey[600],
                          size: 20,
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
  }
}
