import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../models/faculty_attendance_model.dart';
import '../../services/faculty_service.dart';

class BatchPhotoItem {
  final String filename;
  final Uint8List bytes;

  BatchPhotoItem({required this.filename, required this.bytes});
}

class BatchPhotoPickerDialog extends StatefulWidget {
  final int timetableEntryId;
  final String date;
  final String periodName;
  final String className;
  final String subjectName;

  const BatchPhotoPickerDialog({
    Key? key,
    required this.timetableEntryId,
    required this.date,
    required this.periodName,
    required this.className,
    required this.subjectName,
  }) : super(key: key);

  static Future<BatchRecognitionResultModel?> show(
    BuildContext context, {
    required int timetableEntryId,
    required String date,
    required String periodName,
    required String className,
    required String subjectName,
  }) {
    return showDialog<BatchRecognitionResultModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchPhotoPickerDialog(
        timetableEntryId: timetableEntryId,
        date: date,
        periodName: periodName,
        className: className,
        subjectName: subjectName,
      ),
    );
  }

  @override
  State<BatchPhotoPickerDialog> createState() => _BatchPhotoPickerDialogState();
}

class _BatchPhotoPickerDialogState extends State<BatchPhotoPickerDialog> {
  final List<BatchPhotoItem> _photos = [];
  bool _isProcessing = false;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        for (final xf in pickedFiles) {
          final bytes = await xf.readAsBytes();
          _photos.add(BatchPhotoItem(
            filename: xf.name.isNotEmpty ? xf.name : 'photo_${_photos.length + 1}.jpg',
            bytes: bytes,
          ));
        }
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick photos: $e';
      });
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _photos.add(BatchPhotoItem(
            filename: pickedFile.name.isNotEmpty
                ? pickedFile.name
                : 'camera_${_photos.length + 1}.jpg',
            bytes: bytes,
          ));
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture photo: $e';
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _runRecognition() async {
    if (_photos.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final facultyService = Provider.of<FacultyService>(context, listen: false);
      final uploadList = _photos
          .map((p) => (filename: p.filename, bytes: p.bytes.toList()))
          .toList();

      final result = await facultyService.batchRecognizePhotos(
        timetableEntryId: widget.timetableEntryId,
        date: widget.date,
        files: uploadList,
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.cardInnerPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.smallBorder,
                    ),
                    child: Icon(Icons.photo_library_rounded, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Photo Attendance',
                          style: typography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.periodName} • ${widget.className} • ${widget.date}',
                          style: typography.caption.copyWith(color: colors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!_isProcessing)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cancel',
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),

              // Instructions / Helper Text
              Text(
                'Upload 1 or more classroom photos from different angles. The recognition engine will detect and combine all recognized students.',
                style: typography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Buttons to Add Photos
              if (!_isProcessing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.primary,
                          side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: _photos.length >= 15 ? null : _pickFromGallery,
                        icon: const Icon(Icons.collections, size: 18),
                        label: const Text('Add from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.accent,
                          side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: _photos.length >= 15 ? null : _pickFromCamera,
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.md),

              // Photos Grid / List Preview
              Expanded(
                child: _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 56, color: colors.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No photos selected yet',
                              style: typography.bodyMedium.copyWith(color: colors.textMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select 1, 2, 5, or up to 15 classroom photos',
                              style: typography.caption.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Selected Photos (${_photos.length}/15)',
                                style: typography.labelMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              if (!_isProcessing)
                                TextButton(
                                  onPressed: () => setState(() => _photos.clear()),
                                  child: Text('Clear All', style: TextStyle(color: colors.error, fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.0,
                              ),
                              itemCount: _photos.length,
                              itemBuilder: (ctx, idx) {
                                final photo = _photos[idx];
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: AppRadius.smallBorder,
                                      child: Image.memory(
                                        photo.bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // Photo Number Badge
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${idx + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Remove 'X' Button
                                    if (!_isProcessing)
                                      Positioned(
                                        top: 2,
                                        right: 2,
                                        child: InkWell(
                                          onTap: () => _removePhoto(idx),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.errorBg,
                    borderRadius: AppRadius.smallBorder,
                    border: Border.all(color: colors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: colors.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: typography.bodySmall.copyWith(color: colors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Bottom Actions
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  onPressed: (_photos.isEmpty || _isProcessing) ? null : _runRecognition,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.face_retouching_natural_rounded),
                  label: Text(
                    _isProcessing
                        ? 'Processing Batch Recognition...'
                        : 'Run Face Recognition (${_photos.length} photo${_photos.length == 1 ? '' : 's'})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
