import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'pick_upload.dart';

Future<PickedUpload?> pickUpload({bool allowPdf = false}) async {
  final input = HTMLInputElement()
    ..type = 'file'
    ..accept =
        'image/*,.jpg,.jpeg,.png,.webp,.gif,.bmp,.heic,.heif,.avif'
    ..multiple = false
    ..style.display = 'none';

  final completer = Completer<PickedUpload?>();

  void finish(PickedUpload? value) {
    if (!completer.isCompleted) completer.complete(value);
    input.remove();
  }

  input.onchange = (Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }

    final reader = FileReader();
    reader.onloadend = (Event _) {
      final byteBuffer = (reader.result as JSArrayBuffer?)?.toDart;
      final bytes = byteBuffer?.asUint8List();
      if (bytes == null || bytes.isEmpty) {
        finish(null);
        return;
      }
      final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
      finish(PickedUpload(bytes: bytes, name: name));
    }.toJS;
    reader.onerror = (Event _) {
      finish(null);
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.oncancel = (Event _) {
    finish(null);
  }.toJS;

  document.body?.appendChild(input);
  input.click();
  return completer.future;
}
