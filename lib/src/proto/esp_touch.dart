import 'dart:async';

import 'package:esp_smartconfig/src/esp_provisioner.dart';
import 'package:esp_smartconfig/src/esp_provisioning_protocol.dart';

class EspTouchProvisioner extends EspProvisioner<EspTouch> {
  EspTouchProvisioner() : super(EspTouch());
}

class EspTouch extends EspProvisioningProtocol {
  @override
  void loop(int stepMs, Timer timer) {
    // TODO: implement esptouch_v1 loop
    throw UnimplementedError();
  }

  @override
  // TODO: implement esptouch_v1 ports
  List<int> get ports => throw UnimplementedError();
}