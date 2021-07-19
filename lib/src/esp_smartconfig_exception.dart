/// General EspSmartconfig exception
abstract class EspSmartConfigException implements Exception {
  /// Message
  final String message;

  EspSmartConfigException(this.message);

  @override
  String toString() => message;
}
