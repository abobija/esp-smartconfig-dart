/// Generic EspSmartconfig exception
abstract class EspSmartConfigException implements Exception {
  /// Message
  final String? message;

  EspSmartConfigException(this.message);

  @override
  String toString() => message ?? super.toString();
}

/// Generic provisioning exception
class ProvisioningException extends EspSmartConfigException {
  ProvisioningException([super.message]);
}

/// Error that will be thrown on try to add response
/// that already exists in the list of protocol responses
class ProvisioningResponseAlreadyReceivedError extends ProvisioningException {
  ProvisioningResponseAlreadyReceivedError([super.message]);
}

/// Invalid provisioning reponse exception
class InvalidProvisioningResponseDataException extends ProvisioningException {
  InvalidProvisioningResponseDataException([super.message]);
}
