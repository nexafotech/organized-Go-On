import 'file_saver.dart';

Future<SaveFileResult> saveAndLaunchFile(
  List<int> bytes,
  String fileName, {
  String? mimeType,
}) async {
  return SaveFileResult(
    success: false,
    fileName: fileName,
    errorMessage: 'Platform not supported',
  );
}

Future<bool> openSavedFile(
  SaveFileResult result, {
  String? mimeType,
}) async {
  return false;
}
