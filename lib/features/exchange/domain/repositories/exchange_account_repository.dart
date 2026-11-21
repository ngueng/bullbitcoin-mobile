import 'package:bb_mobile/features/exchange/domain/entities/user_summary.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

abstract interface class ExchangeAccountRepository {
  @useResult
  Future<Result<UserSummary, ExchangeFailure>> getAccount();
}
