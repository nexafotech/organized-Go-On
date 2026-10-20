import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

class SaveFileResult {
  final bool success;
  final String? path;
  final String? uriString;
  final String fileName;
  final String? userDisplayPath;
  final String? errorMessage;
  final bool canOpen;

  const SaveFileResult({
    required this.success,
    this.path,
    this.uriString,
    required this.fileName,
    this.userDisplayPath,
    this.errorMessage,
    this.canOpen = false,
  });

  /// Human-friendly display of destination location
  String get destinationDisplay {
    if (userDisplayPath != null && userDisplayPath!.isNotEmpty) {
      return userDisplayPath!;
    }
    if (path != null && path!.isNotEmpty) {
      return path!;
    }
    return 'Downloads';
  }
}

Future<SaveFileResult> saveFile(
  List<int> bytes,
  String fileName, {
  String? mimeType,
}) =>
    saveAndLaunchFile(bytes, fileName, mimeType: mimeType);

Future<bool> openFile(
  SaveFileResult result, {
  String? mimeType,
}) =>
    openSavedFile(result, mimeType: mimeType);
