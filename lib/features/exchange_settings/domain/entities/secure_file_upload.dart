import 'package:bb_mobile/features/exchange/domain/entities/user_summary.dart';

final class SecureFileUpload {
  final String? userId;
  final KycDocumentStatus? status;

  const SecureFileUpload({required this.userId, required this.status});
}
