/// The SEPA rail of a EUR payout.
enum SepaPaymentProcessor {
  regular('REGULAR_SEPA'),
  confidential('CONFIDENTIAL_SEPA');

  /// The wire value.
  final String value;

  const SepaPaymentProcessor(this.value);
}
