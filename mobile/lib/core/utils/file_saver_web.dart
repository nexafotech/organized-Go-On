// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'file_saver.dart';

Future<SaveFileResult> saveAndLaunchFile(
  List<int> bytes,
  String fileName, {
  String? mimeType,
}) async {
  try {
    final effectiveMimeType = mimeType ??
        (fileName.endsWith('.pdf')
            ? 'application/pdf'
            : (fileName.endsWith('.xlsx')
                ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                : 'application/octet-stream'));

    final blob = html.Blob([bytes], effectiveMimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);

    return SaveFileResult(
      success: true,
      fileName: fileName,
      userDisplayPath: 'Browser Downloads',
      canOpen: false,
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
  return false;
}
