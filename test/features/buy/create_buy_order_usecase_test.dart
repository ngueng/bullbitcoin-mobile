import 'package:bb_mobile/features/exchange/domain/entities/order.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_errors.dart';
import 'package:bb_mobile/features/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/buy/domain/buy_failure.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockOrderRepository extends Mock implements ExchangeOrderRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

class _MockPayjoinPolicyAccess extends Mock implements PayjoinPolicyAccess {}

class _MockBuyOrder extends Mock implements BuyOrder {}

class _MockLogger extends Mock implements Logger {}

void main() {
  test('regtest refuses creation before backend or payjoin access', () async {
    final mainnet = _MockOrderRepository();
    final testnet = _MockOrderRepository();
    final settings = _MockSettingsRepository();
    final receiver = _MockPayjoinReceiver();
    final policy = _MockPayjoinPolicyAccess();
    when(settings.fetch).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    final result =
        await CreateBuyOrderUsecase(
          mainnetExchangeOrderRepository: mainnet,
          testnetExchangeOrderRepository: testnet,
          settingsRepository: settings,
          payjoinReceiver: receiver,
          payjoinPolicy: policy,
        ).execute(
          toAddress: 'bcrt1qexample',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          isLiquid: false,
          isOwner: true,
          payjoinWalletId: 'regtest-wallet',
          payjoinAmountSat: 10000,
        );
    expect(
      result,
      isA<Err<BuyOrder, BuyFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BuyUnsupportedNetworkFailure>(),
      ),
    );
    verifyZeroInteractions(mainnet);
    verifyZeroInteractions(testnet);
    verifyZeroInteractions(receiver);
    verifyZeroInteractions(policy);
  });

  setUpAll(() {
    registerFallbackValue(
      StartPayjoinReceiver(
        walletId: 'fallback',
        network: BitcoinNetwork.testnet,
        address: 'tb1qfallback',
      ),
    );
  });

  // The receiver starts before the exchange's five-minute payout window. It
  // needs a short margin without surviving for the protocol's 24-hour default.
  test(
    'the payjoin payout session expires with the exchange, not in 24h',
    () async {
      final orders = _MockOrderRepository();
      final settings = _MockSettingsRepository();
      final receiver = _MockPayjoinReceiver();
      final policy = _MockPayjoinPolicyAccess();

      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => policy.load()).thenAnswer(
        (_) async => Ok(
          PayjoinPolicy(
            sendEnabled: false,
            receiveEnabled: false,
            buyEnabled: true,
            sellEnabled: false,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
          ),
        ),
      );
      when(
        () => orders.placeBuyOrder(
          toAddress: 'tb1qexampleaddress',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          network: OrderBitcoinNetwork.bitcoin,
          isOwner: true,
          payjoinBip21: null,
        ),
      ).thenAnswer((_) async => _MockBuyOrder());

      StartPayjoinReceiver? captured;
      when(() => receiver.start(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.first as StartPayjoinReceiver;
        throw StateError('stop here: the expiry is what this test is about');
      });

      final usecase = CreateBuyOrderUsecase(
        mainnetExchangeOrderRepository: orders,
        testnetExchangeOrderRepository: orders,
        settingsRepository: settings,
        payjoinReceiver: receiver,
        payjoinPolicy: policy,
      );

      final before = DateTime.now();
      final result = await usecase.execute(
        toAddress: 'tb1qexampleaddress',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        isLiquid: false,
        isOwner: true,
        payjoinWalletId: 'wallet-1',
        payjoinAmountSat: 10000,
      );
      final after = DateTime.now();

      expect(result, isA<Ok<BuyOrder, BuyFailure>>());

      final expiresAt = captured?.expiresAt;
      expect(expiresAt, isNotNull, reason: 'a payjoin session must be started');
      // Started under the buy switch while receiving from users is off: the
      // session must stay gated by buy, not by receive.
      expect(captured!.isTrade, isTrue);

      // Bracketed against the wall clock either side of the call: the use case
      // computes its own `now` somewhere between `before` and `after`, so the
      // deadline must land in [before + 6m, after + 6m]. Tight enough that 24h
      // fails, loose enough that a slow machine does not.
      expect(
        expiresAt!.isBefore(before.add(const Duration(minutes: 6))),
        isFalse,
      );
      expect(expiresAt.isAfter(after.add(const Duration(minutes: 6))), isFalse);
    },
  );
  test('a payjoin fallback log never carries the foreign cause text', () async {
    final previousLogger = log;
    final logger = _MockLogger();
    log = logger;
    addTearDown(() => log = previousLogger);
    final orders = _MockOrderRepository();
    final settings = _MockSettingsRepository();
    final receiver = _MockPayjoinReceiver();
    final policy = _MockPayjoinPolicyAccess();

    when(() => settings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.testnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
      ),
    );
    when(() => policy.load()).thenAnswer(
      (_) async => Ok(
        PayjoinPolicy(
          sendEnabled: false,
          receiveEnabled: false,
          buyEnabled: true,
          sellEnabled: false,
          minimumAmount: PayjoinPolicy.minimumAllowedAmount,
          sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
        ),
      ),
    );
    when(
      () => orders.placeBuyOrder(
        toAddress: 'tb1qexampleaddress',
        orderAmount: const FiatAmount(100),
        currency: FiatCurrency.cad,
        network: OrderBitcoinNetwork.bitcoin,
        isOwner: true,
        payjoinBip21: null,
      ),
    ).thenAnswer((_) async => _MockBuyOrder());
    // Foreign exception text can quote the payment request it failed on.
    when(() => receiver.start(any())).thenThrow(
      StateError('bitcoin:tb1qexampleaddress?pj=https://private-directory'),
    );

    final result =
        await CreateBuyOrderUsecase(
          mainnetExchangeOrderRepository: orders,
          testnetExchangeOrderRepository: orders,
          settingsRepository: settings,
          payjoinReceiver: receiver,
          payjoinPolicy: policy,
        ).execute(
          toAddress: 'tb1qexampleaddress',
          orderAmount: const FiatAmount(100),
          currency: FiatCurrency.cad,
          isLiquid: false,
          isOwner: true,
          payjoinWalletId: 'wallet-1',
          payjoinAmountSat: 10000,
        );

    expect(result, isA<Ok<BuyOrder, BuyFailure>>());
    final logged = verify(
      () => logger.warning(
        captureAny(),
        error: captureAny(named: 'error'),
        trace: captureAny(named: 'trace'),
      ),
    ).captured.join(' ');
    expect(logged, contains('StateError'));
    expect(logged, isNot(contains('tb1qexampleaddress')));
    expect(logged, isNot(contains('private-directory')));
  });

  group('a payjoin buy whose order write fails', () {
    late _MockOrderRepository orders;
    late _MockPayjoinReceiver receiver;
    late CreateBuyOrderUsecase usecase;

    setUp(() {
      orders = _MockOrderRepository();
      receiver = _MockPayjoinReceiver();
      final settings = _MockSettingsRepository();
      final policy = _MockPayjoinPolicyAccess();
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => policy.load()).thenAnswer(
        (_) async => Ok(
          PayjoinPolicy(
            sendEnabled: false,
            receiveEnabled: false,
            buyEnabled: true,
            sellEnabled: false,
            minimumAmount: PayjoinPolicy.minimumAllowedAmount,
            sessionLifetime: PayjoinPolicy.minimumSessionLifetime,
          ),
        ),
      );
      when(() => receiver.start(any())).thenAnswer(
        (_) async => Ok(
          PayjoinReceiverSession(
            status: PayjoinStatus.started,
            id: 'receiver-1',
            network: BitcoinNetwork.testnet,
            walletId: 'wallet-1',
            payjoinUri: 'bitcoin:tb1qexampleaddress?pj=https://payjo.in/s',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 6)),
          ),
        ),
      );
      when(() => receiver.cancel(any()))
          .thenAnswer((_) async => const Ok(null));
      usecase = CreateBuyOrderUsecase(
        mainnetExchangeOrderRepository: orders,
        testnetExchangeOrderRepository: orders,
        settingsRepository: settings,
        payjoinReceiver: receiver,
        payjoinPolicy: policy,
      );
    });

    void failWith(Object error) => when(
      () => orders.placeBuyOrder(
        toAddress: any(named: 'toAddress'),
        orderAmount: any(named: 'orderAmount'),
        currency: any(named: 'currency'),
        network: any(named: 'network'),
        isOwner: any(named: 'isOwner'),
        payjoinBip21: any(named: 'payjoinBip21'),
      ),
    ).thenThrow(error);

    Future<Result<BuyOrder, BuyFailure>> buy() => usecase.execute(
      toAddress: 'tb1qexampleaddress',
      orderAmount: const FiatAmount(100),
      currency: FiatCurrency.cad,
      isLiquid: false,
      isOwner: true,
      payjoinWalletId: 'wallet-1',
      payjoinAmountSat: 10000,
    );

    setUpAll(() {
      registerFallbackValue(const FiatAmount(0));
      registerFallbackValue(FiatCurrency.cad);
      registerFallbackValue(OrderBitcoinNetwork.bitcoin);
    });

    test('an unknown outcome keeps the receiver', () async {
      failWith(const BullBitcoinApiOrderOutcomeUnknownException());

      final result = await buy();

      expect(
        result,
        isA<Err<BuyOrder, BuyFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<BuyOutcomeUnknownFailure>(),
        ),
      );
      verifyNever(() => receiver.cancel(any()));
    });

    test('a refusal cancels the receiver', () async {
      failWith(Exception('refused'));

      final result = await buy();

      expect(
        result,
        isA<Err<BuyOrder, BuyFailure>>().having(
          (e) => e.failure,
          'failure',
          isA<BuyUnexpectedFailure>(),
        ),
      );
      verify(() => receiver.cancel('receiver-1')).called(1);
    });
  });
}
