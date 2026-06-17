import 'package:mobile_scanner/mobile_scanner.dart';

abstract interface class QrCodeDataSource {
  Future<String> decodeImageFile(String path);
}

class MobileScannerQrCodeDataSource implements QrCodeDataSource {
  const MobileScannerQrCodeDataSource();

  @override
  Future<String> decodeImageFile(String path) async {
    final controller = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
    );

    try {
      final capture = await controller.analyzeImage(
        path,
        formats: const [BarcodeFormat.qrCode],
      );
      final rawValue = capture?.barcodes
          .map((barcode) => barcode.rawValue)
          .whereType<String>()
          .firstOrNull;

      if (rawValue == null || rawValue.trim().isEmpty) {
        throw const QrCodeException('Không tìm thấy mã QR trong ảnh.');
      }
      return rawValue.trim();
    } on QrCodeException {
      rethrow;
    } catch (_) {
      throw const QrCodeException('Không thể đọc mã QR từ ảnh đã chọn.');
    } finally {
      await controller.dispose();
    }
  }
}

class QrCodeException implements Exception {
  const QrCodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
