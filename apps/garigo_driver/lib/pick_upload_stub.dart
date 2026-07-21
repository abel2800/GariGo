import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'pick_upload.dart';

Future<PickedUpload?> pickUpload({bool allowPdf = true}) async {
  if (allowPdf) {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
          'tif',
          'tiff',
          'heic',
          'heif',
          'avif',
          'pdf',
        ],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.first;
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      final name = f.name.isNotEmpty ? f.name : 'upload.${f.extension ?? 'jpg'}';
      return PickedUpload(bytes: bytes, name: name);
    } catch (_) {
      // Fall through to image_picker if file_picker isn't available.
    }
  }

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
