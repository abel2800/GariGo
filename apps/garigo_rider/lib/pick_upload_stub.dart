import 'package:image_picker/image_picker.dart';

import 'pick_upload.dart';

Future<PickedUpload?> pickUpload({bool allowPdf = false}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 88,
    maxWidth: 2048,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;
  final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
  return PickedUpload(bytes: bytes, name: name);
}
