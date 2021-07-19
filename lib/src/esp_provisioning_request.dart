import 'dart:convert';
import 'dart:typed_data';

/// Provisioning request
class EspProvisioningRequest {
  static final ssidLengthMax = 32;
  static final passwordLengthMax = 64;
  static final reservedDataLengthMax = 127;
  static final bssidLength = 6;

  /// SSID (max length: 32 bytes)
  final Int8List ssid;

  /// BSSID (fixed 6 bytes)
  final Int8List bssid;

  /// Password (max length: 64 bytes).
  /// Not required if WiFi network is Public (not protected)
  final Int8List? password;

  /// Reserved data (max length: 127 bytes)
  final Int8List? reservedData;

  EspProvisioningRequest({
    required this.ssid,
    required this.bssid,
    this.password,
    this.reservedData,
  }) {
    _validate();
  }

  void _validate() {
    if (ssid.length > ssidLengthMax) {
      throw ArgumentError("SSID length is greater than $ssidLengthMax");
    }

    if (bssid.length != bssidLength) {
      throw ArgumentError(
          "Invalid BSSID. Length should be $bssidLength. Got ${bssid.length}");
    }

    if (password != null && password!.length > passwordLengthMax) {
      throw ArgumentError("Password length is greater than $passwordLengthMax");
    }

    if (reservedData != null && reservedData!.length > reservedDataLengthMax) {
      throw ArgumentError(
          "ReservedData length is greater than $reservedDataLengthMax");
    }
  }

  /// Create request from string values
  ///
  /// [bssid] shoud be in format xx:xx:xx:xx:xx:xx
  factory EspProvisioningRequest.fromStrings({
    required String ssid,
    required String bssid,
    String? password,
    String? reservedData,
  }) {
    return EspProvisioningRequest(
      ssid: Int8List.fromList(utf8.encode(ssid)),
      bssid: Int8List.fromList(
          bssid.split(':').map((hex) => int.parse(hex, radix: 16)).toList()),
      password:
          password == null ? null : Int8List.fromList(utf8.encode(password)),
      reservedData: reservedData == null
          ? null
          : Int8List.fromList(utf8.encode(reservedData)),
    );
  }
}
