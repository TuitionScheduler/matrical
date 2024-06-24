/// Enum representing the different results of a cache retrieval operation.
enum CacheResultType { keyNotFound, foundOffline, foundExpired, foundData }

/// A class representing the result of a cache retrieval operation, including
/// the data type, cache date, and the data itself if available.
/// When receiving a Cache Result, check the type of the result
/// (ie. through switch case) prior to accessing the [data] property
/// as accessing it on a [CacheResultType.keyNotFound] type will throw a [StateError].
class CacheResult<T> {
  /// The type of cache result, indicating whether data was found, expired, etc.
  final CacheResultType type;

  /// The date and time when the data was cached, or null if not applicable.
  final DateTime? dataCacheDate;

  /// The cached data, or null if not found or applicable.
  final T? _data;

  /// Constructs a [CacheResult] indicating that the requested key was not found.
  CacheResult.notFound()
      : type = CacheResultType.keyNotFound,
        dataCacheDate = null,
        _data = null;

  /// Constructs a [CacheResult] for expired data, requiring [dataCacheDate] and [data].
  CacheResult.expired({required this.dataCacheDate, required T data})
      : type = CacheResultType.foundExpired,
        _data = data;

  /// Constructs a [CacheResult] for data found offline, requiring [dataCacheDate] and [data].
  CacheResult.offline({required this.dataCacheDate, required T data})
      : type = CacheResultType.foundOffline,
        _data = data;

  /// Constructs a [CacheResult] for successfully found data, requiring [dataCacheDate] and [data].
  CacheResult.found({required this.dataCacheDate, required T data})
      : type = CacheResultType.foundData,
        _data = data;

  /// Safely access the data with a non-nullable return type. Use this method after ensuring
  /// that data is available (e.g., after checking the result type is not keyNotFound).
  /// Throws if data is null, thus should be used when you are sure data exists.
  T get data {
    if (_data == null) {
      throw StateError('Attempted to access null data on a CacheResult');
    }
    return _data;
  }
}

/// An interface defining the operations of a cache service.
abstract class ICacheService {
  /// Stores the given [value] associated with the specified [key] in the cache.
  /// Uses [value].toString() for serialization. An optional [dateObtained] can
  /// specify when the data was originally obtained.
  Future<bool> store<T>(String key, T value, {DateTime? dateObtained});

  /// Retrieves the data associated with the specified [key] from the cache.
  /// Requires a [deserializer] function to convert the stored string back into
  /// the desired data type. An optional [expiration] date can specify when the
  /// cached data should be considered expired. If [clearWhenExpired] is true,
  /// expired data will be automatically cleared from the cache.
  Future<CacheResult<T>> retrieve<T>(
      String key, T Function(String) deserializer,
      {DateTime? expiration, bool clearWhenExpired = true});

  /// Deletes the data associated with the specified [key] from the cache.
  Future<bool> delete(String key);
}
