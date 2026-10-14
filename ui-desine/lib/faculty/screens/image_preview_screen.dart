import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_tokens.dart';

import '../../services/faculty_service.dart';
import 'recognition_review_screen.dart';

class ImagePreviewScreen extends StatefulWidget {
  final File initialImage;
  final Uint8List? initialBytes;
  final String? initialName;
  final bool isFromCamera;

  const ImagePreviewScreen({
    Key? key,
    required this.initialImage,
    this.initialBytes,
    this.initialName,
    this.isFromCamera = false,
  }) : super(key: key);

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late File _currentImage;
  Uint8List? _currentBytes;
  String? _currentName;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
    _currentBytes = widget.initialBytes;
    _currentName = widget.initialName;
  }

  Future<void> _pickNewImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _currentImage = File(picked.path);
          _currentBytes = bytes;
          _currentName = picked.name;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _submitPhoto() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    final facultyService = Provider.of<FacultyService>(context, listen: false);
    try {
      final result = await facultyService.uploadGroupPhoto(
        _currentImage,
        bytes: _currentBytes,
        filename: _currentName,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecognitionReviewScreen(recognitionResult: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = facultyService.errorMessage ?? e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: kIsWeb && _currentBytes != null
                  ? Image.memory(
                      _currentBytes!,
                      fit: BoxFit.contain,
                    )
                  : Image.file(
                      _currentImage,
                      fit: BoxFit.contain,
                    ),
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.errorBg,
                border: Border(top: BorderSide(color: colors.error.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: typography.bodySmall.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.glassSurfaceStrong,
              border: Border(top: BorderSide(color: colors.glassBorder)),
              boxShadow: AppGlass.shadowElevated,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textPrimary,
                            side: BorderSide(color: colors.glassBorder),
                            shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: Icon(Icons.refresh_rounded, color: colors.primary),
                          label: Text(widget.isFromCamera ? 'Retake Photo' : 'Choose Other', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _isUploading
                              ? null
                              : () => _pickNewImage(widget.isFromCamera ? ImageSource.camera : ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                      ),
                      icon: _isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.face_retouching_natural_rounded),
                      label: Text(
                        _isUploading ? 'Recognizing Faces...' : 'Recognize Faces',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                      ),
                      onPressed: _isUploading ? null : _submitPhoto,
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
}
