import 'package:bb_mobile/features/exchange/data/models/api_key_model.dart';
import 'package:bb_mobile/features/exchange/domain/entities/exchange_api_key.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_api_key_failure.dart';
import 'package:primitives/primitives.dart';

abstract final class ExchangeApiKeyMapper {
  static Result<ExchangeApiKey, ExchangeApiKeyFailure> toDomain(
    ExchangeApiKeyModel model,
  ) => ExchangeApiKey.create(
    id: model.id,
    key: model.key,
    name: model.name,
    userId: model.userId,
    isActive: model.isActive,
    createdAt: model.createdAt,
    updatedAt: model.updatedAt,
    lastUsedAt: model.lastUsedAt,
    expiresAt: model.expiresAt,
  );

  static ExchangeApiKeyModel toModel(ExchangeApiKey value) =>
      ExchangeApiKeyModel(
        id: value.id,
        key: value.key,
        name: value.name,
        userId: value.userId,
        isActive: value.isActive,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
        lastUsedAt: value.lastUsedAt,
        expiresAt: value.expiresAt,
      );
}
