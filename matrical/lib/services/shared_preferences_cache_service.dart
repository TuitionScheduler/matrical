import 'package:matrical/models/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesCacheService implements ICacheService {
  static final SharedPreferencesCacheService _instance =
      SharedPreferencesCacheService();

  static SharedPreferencesCacheService getInstance() {
    return _instance;
  }

  @override
  Future<bool> store<T>(String key, T value, {DateTime? dateObtained}) async {
    final prefs = await SharedPreferences.getInstance();
    String serializedDate = (dateObtained ?? DateTime.now()).toIso8601String();
    String serializedData = value.toString();
    List<String> dateWithData = [serializedDate, serializedData];
    return await prefs.setStringList(key, dateWithData);
  }

  @override
  Future<CacheResult<T>> retrieve<T>(
      String key, T Function(String data) deserializer,
      {DateTime? expiration, bool clearWhenExpired = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? dateWithData = prefs.getStringList(key);
    if (dateWithData == null) {
      return CacheResult.notFound();
    }
    final DateTime? storedDate = DateTime.tryParse(dateWithData.first);
    T parsedData = deserializer(dateWithData.last);
    if (expiration != null) {
      if (storedDate == null || storedDate.compareTo(expiration) < 0) {
        if (clearWhenExpired) await prefs.remove(key);
        return CacheResult.expired(dataCacheDate: storedDate, data: parsedData);
      } else {
        return CacheResult.found(dataCacheDate: storedDate, data: parsedData);
      }
    }
    return CacheResult.offline(dataCacheDate: storedDate, data: parsedData);
  }

  @override
  Future<bool> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(key);
  }
}
