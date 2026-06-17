import 'package:image_picker/image_picker.dart';

abstract interface class GalleryImageDataSource {
  Future<String?> pickQrImagePath();
}

class GalleryImageDataSourceImpl implements GalleryImageDataSource {
  GalleryImageDataSourceImpl({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickQrImagePath() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    return image?.path;
  }
}
