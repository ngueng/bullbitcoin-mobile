import 'package:bb_mobile/features/exchange/domain/exchange_errors.dart';
import 'package:bb_mobile/features/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/features/exchange/domain/entities/file_upload.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:dio/dio.dart';

/// [ExchangeKycRepository] through the `bbx_api` package.
class BbxApiKycRepository implements ExchangeKycRepository {
  final bbx.BbxApiClient _api;

  BbxApiKycRepository({required this._api});

  @override
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    try {
      await _api.kyc.uploadDocument(
        fileBytes: fileBytes,
        fileName: fileName,
        idTypeCode: docType,
        sourceDetail: sourceDetail,
      );
      return FileUploadResult.success();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      final reason = switch (e) {
        DioException(:final type, :final response) =>
          'DioException(${type.name}, status: ${response?.statusCode})',
        _ => e.runtimeType.toString(),
      };
      return FileUploadResult.failure('Failed to upload document: $reason');
    }
  }
}
