import 'dart:typed_data';

import 'pick_upload_stub.dart'
    if (dart.library.html) 'pick_upload_web.dart' as impl;

class PickedUpload {
  const PickedUpload({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

/// Opens a file chooser. On web uses a native HTML input (avoids broken
/// file_picker plugin registration). Elsewhere uses file_picker / image_picker.
Future<PickedUpload?> pickUpload({bool allowPdf = true}) {
  return impl.pickUpload(allowPdf: allowPdf);
}
