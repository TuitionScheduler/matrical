abstract class Cacheable {
  String serialize();
  static Cacheable deserialize(String source) {
    throw UnimplementedError('deserialize must be implemented');
  }
}
