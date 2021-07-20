/// General EspSmartconfig exception
abstract class EspSmartConfigException implements Exception {
  /// Message
  final String? message;

  EspSmartConfigException(this.message);

  @override
  String toString() => message ?? super.toString();
}

class EspProvisioningException extends EspSmartConfigException {
  EspProvisioningException([String? message]) : super(message);
}

class ResponseAlreadyReceivedError extends EspProvisioningException {
  ResponseAlreadyReceivedError([String? message]) : super(message);
}

class InvalidResponseDataException extends EspProvisioningException {
  InvalidResponseDataException([String? message]) : super(message);
}