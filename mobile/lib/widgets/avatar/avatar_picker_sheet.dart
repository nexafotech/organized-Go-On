import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/student_model.dart';

/// AvatarPickerSheet — Modal sheet for selecting from the 16 illustrated avatars
/// Inspired by the minimalist illustrated character design reference.
class AvatarPickerSheet extends StatefulWidget {
  final String currentAvatarId;
  final String userSeed;
  final Future<bool> Function(String selectedAvatarId) onSave;

  const AvatarPickerSheet({
    Key? key,
    required this.currentAvatarId,
    required this.userSeed,
    required this.onSave,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required String currentAvatarId,
    required String userSeed,
    required Future<bool> Function(String selectedAvatarId) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AvatarPickerSheet(
        currentAvatarId: currentAvatarId,
        userSeed: userSeed,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late String _selectedAvatarId;
  String _selectedCategory = 'all'; // 'all', 'masculine', 'feminine', 'neutral'
  bool _isSaving = false;
  String? _statusMessage;
  bool _hasSaved = false;

  @override
  void initState() {
    super.initState();
    _selectedAvatarId = widget.currentAvatarId.isNotEmpty
        ? widget.currentAvatarId
        : AvatarItemModel.resolveAsset(null, fallbackSeed: widget.userSeed).split('/').last.replaceAll('.png', '');
  }

  List<AvatarItemModel> get _filteredAvatars {
    if (_selectedCategory == 'all') {
      return AvatarItemModel.catalog;
    } else if (_selectedCategory == 'neutral') {
      return AvatarItemModel.catalog.where((a) => a.isNeutral).toList();
    } else {
      return AvatarItemModel.catalog.where((a) => a.category == _selectedCategory).toList();
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    final success = await widget.onSave(_selectedAvatarId);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isSaving = false;
        _hasSaved = true;
        _statusMessage = 'Avatar updated successfully!';
      });
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Failed to save avatar. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;
    final activeItem = AvatarItemModel.findById(_selectedAvatarId);

    return Container(
      height: sheetHeight,
      constraints: const BoxConstraints(
        maxWidth: 640,
      ),
      margin: isDesktop ? const EdgeInsets.only(bottom: 24) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0xFF161922) : const Color(0xFFFBFBFA),
        borderRadius: isDesktop
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.glassBorderStrong,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Avatar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an illustrated character for your profile',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary, size: 22),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 12, thickness: 0.8),

          // 2. Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Featured Active Preview Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.glassSurfaceStrong,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Large Avatar Circle
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.primary, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              activeItem.assetPath,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeItem.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      activeItem.category.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: colors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (activeItem.isNeutral) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: colors.accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'NEUTRAL',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: colors.accent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeItem.tags.map((t) => '#$t').join('  '),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category Filter Tabs
                  Row(
                    children: [
                      _buildCategoryChip('All (16)', 'all', colors),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Masculine (8)', 'masculine', colors),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Feminine (8)', 'feminine', colors),
                      const SizedBox(width: 8),
                      _buildCategoryChip('Neutral (6)', 'neutral', colors),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4-Column Grid matching 4x4 reference image
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth >= 500 ? 4 : 3;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredAvatars.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemBuilder: (context, index) {
                          final avatar = _filteredAvatars[index];
                          final isSelected = avatar.id == _selectedAvatarId;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAvatarId = avatar.id;
                                _statusMessage = null;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                color: colors.isDark ? const Color(0xFF1E222C) : const Color(0xFFF3F2EE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? colors.primary : colors.glassBorder,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withValues(alpha: 0.35),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.asset(
                                        avatar.assetPath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => Center(
                                          child: Icon(Icons.person, color: colors.textMuted),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _hasSaved
                            ? colors.present.withValues(alpha: 0.12)
                            : colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _hasSaved ? colors.present : colors.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasSaved ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: _hasSaved ? colors.present : colors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _hasSaved ? colors.present : colors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // 3. Bottom Action Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(top: BorderSide(color: colors.glassBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: colors.border),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Save Avatar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String categoryKey, AppColors colors) {
    final isSelected = _selectedCategory == categoryKey;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = categoryKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.glassSurfaceStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.glassBorder,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
