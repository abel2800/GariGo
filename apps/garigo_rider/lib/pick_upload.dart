import 'dart:typed_data';

import 'pick_upload_stub.dart'
    if (dart.library.html) 'pick_upload_web.dart' as impl;

class PickedUpload {
  const PickedUpload({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

Future<PickedUpload?> pickUpload({bool allowPdf = false}) {
  return impl.pickUpload(allowPdf: allowPdf);
}
