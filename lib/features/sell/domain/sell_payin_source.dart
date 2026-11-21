import 'package:bb_mobile/features/exchange/domain/entities/order.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';

final class SellPayinSource {
  final Wallet? wallet;
  final OrderBitcoinNetwork network;

  SellPayinSource.wallet(Wallet selectedWallet)
    : wallet = selectedWallet,
      network = selectedWallet.isLiquid
          ? OrderBitcoinNetwork.liquid
          : OrderBitcoinNetwork.bitcoin;

  const SellPayinSource.external(this.network) : wallet = null;
}
