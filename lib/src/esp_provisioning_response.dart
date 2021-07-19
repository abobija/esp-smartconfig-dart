import 'dart:typed_data';

import 'package:esp_smartconfig/src/esp_provisioning_request.dart';

/// Provisioning response
class EspProvisioningResponse {
  /// Connected device BSSID
  final Uint8List deviceBssid;

  EspProvisioningResponse(this.deviceBssid) {
    if (deviceBssid.length != EspProvisioningRequest.bssidLength) {
      throw ArgumentError("Invalid BSSID");
    }
  }

  /// Equality by using [deviceBssid]
  bool operator ==(Object result) {
    if (result is EspProvisioningResponse) {
      for (int i = 0; i < deviceBssid.length; i++) {
        if (deviceBssid[i] != result.deviceBssid[i]) {
          return false;
        }
      }

      return true;
    }

    return false;
  }

  @override
  int get hashCode => super.hashCode;
}
