import 'dart:io';

Future<String?> saveAndLaunchFile(List<int> bytes, String fileName) async {
  try {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    final file = File(fileName);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
