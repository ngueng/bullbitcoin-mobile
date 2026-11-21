import 'package:bb_mobile/features/exchange/domain/entities/file_upload.dart';

abstract class ExchangeKycRepository {
  /// Upload a KYC document file
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  });
}
