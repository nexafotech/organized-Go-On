import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'file_saver.dart';

const MethodChannel _fileSaverChannel =
    MethodChannel('com.aifaceattendance.mobile_app/file_saver');

Future<SaveFileResult> saveAndLaunchFile(
  List<int> bytes,
  String fileName, {
  String? mimeType,
}) async {
  final effectiveMimeType = mimeType ??
      (fileName.endsWith('.pdf')
          ? 'application/pdf'
          : (fileName.endsWith('.xlsx')
              ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
              : 'application/octet-stream'));

  // 1. Android: use native MediaStore.Downloads via MethodChannel
  if (Platform.isAndroid) {
    try {
      final res = await _fileSaverChannel.invokeMethod<Map>('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': effectiveMimeType,
      });

      if (res != null && res['success'] == true) {
        final path = res['path'] as String? ?? 'Downloads/$fileName';
        final uri = res['uri'] as String?;
        final returnedName = res['fileName'] as String? ?? fileName;
        return SaveFileResult(
          success: true,
          path: path,
          uriString: uri,
          fileName: returnedName,
          userDisplayPath: path,
          canOpen: true,
        );
      }
    } catch (e) {
      debugPrint('[FileSaver] Android native channel unavailable or failed: $e. Using local fallback.');
    }
  }

  // 2. Windows / macOS / Linux Desktop: save directly to user's real Downloads folder
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      String? downloadsPath;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsPath = '$userProfile\\Downloads';
        }
      } else {
        final home = Platform.environment['HOME'];
        if (home != null) {
          downloadsPath = '$home/Downloads';
        }
      }

      Directory targetDir;
      if (downloadsPath != null && Directory(downloadsPath).existsSync()) {
        targetDir = Directory(downloadsPath);
      } else {
        targetDir = Directory.current;
      }

      final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return SaveFileResult(
        success: true,
        path: file.path,
        fileName: fileName,
        userDisplayPath: file.path,
        canOpen: true,
      );
    } catch (e) {
      debugPrint('[FileSaver] Desktop Downloads save failed: $e');
    }
  }

  // 3. Fallback (e.g. iOS, headless test runners, or when primary paths fail)
  try {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    return SaveFileResult(
      success: true,
      path: file.path,
      fileName: fileName,
      userDisplayPath: file.path,
      canOpen: true,
    );
  } catch (e) {
    return SaveFileResult(
      success: false,
      fileName: fileName,
      errorMessage: e.toString(),
    );
  }
}

Future<bool> openSavedFile(
  SaveFileResult result, {
  String? mimeType,
}) async {
  final effectiveMimeType = mimeType ??
      (result.fileName.endsWith('.pdf')
          ? 'application/pdf'
          : (result.fileName.endsWith('.xlsx')
              ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
              : '*/*'));

  // 1. Android: use native ACTION_VIEW intent via MethodChannel
  if (Platform.isAndroid) {
    try {
      final opened = await _fileSaverChannel.invokeMethod<bool>('openFile', {
        'uri': result.uriString,
        'filePath': result.path,
        'mimeType': effectiveMimeType,
      });
      return opened == true;
    } catch (e) {
      debugPrint('[FileSaver] Android openFile error: $e');
    }
  }

  // 2. Desktop: launch default application
  if (result.path != null && result.path!.isNotEmpty) {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', result.path!]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [result.path!]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [result.path!]);
        return true;
      }
    } catch (e) {
      debugPrint('[FileSaver] Desktop openFile error: $e');
    }
  }

  return false;
}
