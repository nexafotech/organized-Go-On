import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. SEARCH FIELD
// ─────────────────────────────────────────────────────────────────────────────

class SearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final bool autofocus;
  final FocusNode? focusNode;

  const SearchField({
    Key? key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search...',
    this.autofocus = false,
    this.focusNode,
  }) : super(key: key);

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_handleTextChange);
    }
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SizedBox(
      height: AppSize.input,
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        style: typography.bodyMedium.copyWith(color: colors.textPrimary),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.surfaceMuted,
          hintText: widget.hintText,
          hintStyle: typography.bodyMedium.copyWith(color: colors.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: AppIconSize.row,
            color: colors.textSecondary,
          ),
          suffixIcon: _hasText
              ? IconButton(
                  icon: Icon(
                    Icons.cancel_rounded,
                    size: AppIconSize.chip,
                    color: colors.textMuted,
                  ),
                  tooltip: 'Clear search',
                  onPressed: _clear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mediumBorder,
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mediumBorder,
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mediumBorder,
            borderSide: BorderSide(color: colors.focusRing, width: 2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────

class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final int? count;

  const AppFilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isEnabled = onSelected != null;

    final bg = isSelected ? colors.primary : colors.surface;
    final fg = isSelected ? colors.onPrimary : colors.textPrimary;
    final border = isSelected ? colors.primary : colors.border;

    return Semantics(
      selected: isSelected,
      button: true,
      enabled: isEnabled,
      label: '$label filter',
      child: GestureDetector(
        onTap: isEnabled ? () => onSelected!(!isSelected) : null,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSize.minTouchTarget, // Accessible 48 touch target
          ),
          alignment: Alignment.center,
          child: Container(
            height: AppSize.chip,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: border, width: 1),
              boxShadow: isSelected ? AppElevation.e1 : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppIconSize.statusChip,
                    color: fg,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: typography.labelMedium.copyWith(
                    color: fg,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.onPrimary.withValues(alpha: 0.2)
                          : colors.surfaceMuted,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    child: Text(
                      count.toString(),
                      style: typography.caption.copyWith(
                        color: isSelected ? colors.onPrimary : colors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
