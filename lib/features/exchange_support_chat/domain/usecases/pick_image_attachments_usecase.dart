import 'package:bb_mobile/features/exchange/domain/entities/support_chat_message_attachment.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_support_chat_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:meta/meta.dart';

class PickImageAttachmentsUsecase {
  final AttachmentPickerRepository _repository;

  PickImageAttachmentsUsecase({required this._repository});

  @useResult
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  execute() => _repository.pickImages();
}
