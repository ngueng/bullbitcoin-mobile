import 'package:bb_mobile/features/exchange/domain/entities/support_chat_message.dart';
import 'package:bb_mobile/features/exchange/domain/entities/support_chat_message_attachment.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_support_chat_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeSupportChatRepository {
  @useResult
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>>
  getMessages({int? page, int? pageSize});

  @useResult
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  });

  @useResult
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId);
}
