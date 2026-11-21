import 'dart:async';
import 'dart:io';

import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/orders/order_rejection.dart';
import 'package:bbx_api/src/orders/order_stats.dart';
import 'package:bbx_api/src/orders/order_summary.dart';
import 'package:bbx_api/src/orders/sepa_payment_processor.dart';
import 'package:dio/dio.dart';

/// The `api-orders` endpoint.
class OrdersApi {
  static const endpoint = '/ak/api-orders';

  final BbxApiClient _client;

  OrdersApi(this._client);

  /// The user's trading statistics.
  Future<OrderStatsReport> getOrderStats() async {
    final result = read<Map<String, dynamic>>(
      await _client.request(endpoint, 'getOrderStats'),
      'result',
    );
    return OrderStatsReport.fromJson(
      read<Map<String, dynamic>>(result['element'], 'element'),
    );
  }

  /// The order [orderId]. The server wraps it in `element` or returns it as
  /// the result itself; both are read.
  Future<OrderSummary> getOrderSummary(String orderId) async {
    final result = read<Map<String, dynamic>>(
      await _client.request(
        endpoint,
        'getOrderSummary',
        params: {'orderId': orderId},
      ),
      'result',
    );
    return OrderSummary.fromJson(
      read<Map<String, dynamic>>(result['element'] ?? result, 'element'),
    );
  }

  /// Asks the server to re-check the order [orderId] and returns it.
  Future<OrderSummary> refreshOrderSummary(String orderId) async =>
      OrderSummary.fromJson(
        read<Map<String, dynamic>>(
          await _client.request(
            endpoint,
            'refreshOrderSummary',
            params: {'orderId': orderId},
          ),
          'result',
        ),
      );

  /// One page of the user's orders, newest first. A missing element list is
  /// a format error.
  Future<OrderSummaryList> listOrderSummaries({
    int page = 1,
    int pageSize = 50,
  }) async {
    final result = read<Map<String, dynamic>>(
      await _client.request(
        endpoint,
        'listOrderSummaries',
        params: {
          'sortBy': {'id': 'createdAt', 'sort': 'desc'},
          'paginator': {'page': page, 'pageSize': pageSize},
        },
      ),
      'result',
    );
    final orders = <OrderSummary>[];
    final rejected = <BbxApiFormatException>[];
    for (final element in read<List<dynamic>>(result['elements'], 'elements')) {
      try {
        orders.add(
          OrderSummary.fromJson(
            read<Map<String, dynamic>>(element, 'elements'),
          ),
        );
      } on BbxApiFormatException catch (e) {
        rejected.add(e);
      }
    }
    return OrderSummaryList(orders: orders, rejected: rejected);
  }

  /// Creates a buy order paid out to [network].
  ///
  /// Exactly one of [address] and [bip21URI] must be given: the server takes
  /// the payout address from the URI, and a payjoin buy has to send the URI.
  /// Throws a [BbxApiOrderLimitException] when the amount is outside a limit.
  Future<OrderSummary> createOrderBuy({
    required String fiatCurrency,
    required String network,
    required bool isOwner,
    String? address,
    String? bip21URI,
    double? fiatAmount,
    double? bitcoinAmount,
  }) async {
    if ((address == null) == (bip21URI == null)) {
      throw ArgumentError(
        'createOrderBuy takes an address or a bip21URI, never both and never '
        'neither',
      );
    }
    return _createOrder('createOrderBuy', {
      'fiatCurrency': fiatCurrency,
      'network': network,
      'isOwner': isOwner,
      if (bip21URI != null) 'bip21URI': bip21URI else 'address': address,
      ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
    });
  }

  /// Creates a sell order paid out to the user's fiat balance.
  ///
  /// [usePayjoin] asks the server to receive the payin through payjoin; it is
  /// sent only when true. Throws a [BbxApiOrderLimitException] when the
  /// amount is outside a limit.
  Future<OrderSummary> sellToBalance({
    required String fiatCurrency,
    required String bitcoinNetwork,
    bool usePayjoin = false,
    double? fiatAmount,
    double? bitcoinAmount,
  }) => _createOrder('sellToBalance', {
    'fiatCurrency': fiatCurrency,
    'bitcoinNetwork': bitcoinNetwork,
    if (usePayjoin) 'usePayjoin': true,
    ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
  });

  /// Creates a sell order paid out to the recipient [recipientId].
  ///
  /// See [sellToBalance] for [usePayjoin]. Throws a
  /// [BbxApiOrderLimitException] or a
  /// [BbxApiConfidentialSepaNotActivatedException].
  Future<OrderSummary> sellToRecipient({
    required String recipientId,
    required String bitcoinNetwork,
    SepaPaymentProcessor? paymentProcessor,
    bool usePayjoin = false,
    double? fiatAmount,
    double? bitcoinAmount,
    String? paymentDescription,
  }) => _createOrder('sellToRecipient', {
    'recipientId': recipientId,
    if (paymentProcessor != null) 'paymentProcessor': paymentProcessor.value,
    'bitcoinNetwork': bitcoinNetwork,
    if (usePayjoin) 'usePayjoin': true,
    ..._amount(fiatAmount: fiatAmount, bitcoinAmount: bitcoinAmount),
    'paymentDescription': ?paymentDescription,
  });

  /// Creates a withdrawal of [fiatAmount] from the fiat balance to the
  /// recipient [recipientId].
  ///
  /// The Interac security question and answer are sent only together. Throws
  /// a [BbxApiOrderLimitException] or a
  /// [BbxApiConfidentialSepaNotActivatedException].
  Future<OrderSummary> createWithdrawalOrder({
    required double fiatAmount,
    required String recipientId,
    SepaPaymentProcessor? paymentProcessor,
    String? securityQuestion,
    String? securityAnswer,
  }) => _createOrder('createWithdrawalOrder', {
    'fiatAmount': fiatAmount,
    'recipientId': recipientId,
    if (paymentProcessor != null) 'paymentProcessor': paymentProcessor.value,
    if (securityQuestion != null && securityAnswer != null)
      'paymentProcessorData': {
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
      },
  });

  /// The payment link for a COP bank transfer of [amount] pesos from the
  /// bank [bankCode]; the bank sends the user back to [callbackUrl].
  ///
  /// The request also carries `paymentProcessorCode` as null, like the app
  /// always sent it.
  Future<String> getCopPaymentLink({
    required String bankCode,
    required int amount,
    required String callbackUrl,
  }) async => read<String>(
    await _client.request(
      endpoint,
      'getCopPaymentLink',
      params: {
        'paymentProcessorCode': null,
        'bankCode': bankCode,
        'amount': amount,
        'callbackUrl': callbackUrl,
      },
    ),
    'result',
  );

  /// Confirms the order [orderId] and returns it.
  Future<OrderSummary> confirmOrderSummary(String orderId) =>
      _orderCall('confirmOrderSummary', {'orderId': orderId});

  /// Takes the buy order [orderId] out of its payout batch and pays it now.
  Future<OrderSummary> unbatchAndExpressOrder(String orderId) =>
      _orderCall('unbatchAndExpressOrder', {'orderId': orderId});

  /// Creates an order. A failure after the request may have reached the
  /// server throws a [BbxApiOutcomeUnknownException]; a JSON-RPC refusal and
  /// a failure before sending are rethrown unchanged.
  Future<OrderSummary> _createOrder(
    String method,
    Map<String, Object?> params,
  ) async {
    try {
      return await _orderCall(method, params, rpcError: orderRejection);
    } on BbxApiFormatException catch (e) {
      throw BbxApiOutcomeUnknownException(e.reason);
    } on BbxApiHttpException catch (e) {
      if (!_mayHaveCreated(e.statusCode)) rethrow;
      throw BbxApiOutcomeUnknownException('status ${e.statusCode}');
    } on DioException catch (e) {
      if (!_mayHaveReachedServer(e)) rethrow;
      throw BbxApiOutcomeUnknownException(e.type.name);
    }
  }

  /// A status below 400 has no refusal, and a gateway error can come after
  /// the server took the request.
  static bool _mayHaveCreated(int? status) =>
      status == null || status < 400 || status == 502 || status == 504;

  /// Whether Dio failed after it may have sent the request. A connect
  /// timeout, a bad certificate, a cancel and a refusal raised by the
  /// caller's own interceptors happen before sending.
  static bool _mayHaveReachedServer(DioException e) => switch (e.type) {
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.connectionError => true,
    DioExceptionType.badResponse => _mayHaveCreated(e.response?.statusCode),
    DioExceptionType.unknown =>
      e.error is SocketException ||
          e.error is HttpException ||
          e.error is TimeoutException,
    DioExceptionType.connectionTimeout ||
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel => false,
  };

  Future<OrderSummary> _orderCall(
    String method,
    Map<String, Object?> params, {
    BbxApiRpcException Function(Object error) rpcError =
        BbxApiRpcException.fromJson,
  }) async => OrderSummary.fromJson(
    read<Map<String, dynamic>>(
      await _client.request(
        endpoint,
        method,
        params: params,
        rpcError: rpcError,
      ),
      'result',
    ),
  );

  static Map<String, Object?> _amount({
    double? fiatAmount,
    double? bitcoinAmount,
  }) => {
    'fiatAmount': ?fiatAmount,
    if (fiatAmount == null) 'bitcoinAmount': ?bitcoinAmount,
  };
}
