import 'package:bb_mobile/features/exchange/domain/entities/order_stats.dart';

abstract class ExchangeOrderStatsRepository {
  /// Get order statistics for the current user
  Future<OrderStatsResponse> getOrderStats();
}
