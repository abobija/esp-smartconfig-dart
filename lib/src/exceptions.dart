/// General EspSmartconfig exception
abstract class EspSmartConfigException implements Exception {
  /// Message
  final String? message;

  EspSmartConfigException(this.message);

  @override
  String toString() => message ?? super.toString();
}

class ProvisioningException extends EspSmartConfigException {
  ProvisioningException([String? message]) : super(message);
}

class ProvisioningResponseAlreadyReceivedError extends ProvisioningException {
  ProvisioningResponseAlreadyReceivedError([String? message]) : super(message);
}

class InvalidProvisioningResponseDataException extends ProvisioningException {
  InvalidProvisioningResponseDataException([String? message]) : super(message);
}
