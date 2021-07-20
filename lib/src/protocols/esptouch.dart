import 'dart:async';
import 'dart:typed_data';

import 'package:esp_smartconfig/src/protocol.dart';
import 'package:esp_smartconfig/src/provisioning_response.dart';

class EspTouch extends Protocol {
  @override
  List<int> get ports => [18266];

  @override
  void loop(int stepMs, Timer timer) {
    // TODO: implement esptouch loop
    throw UnimplementedError();
  }

  @override
  ProvisioningResponse receive(Uint8List data) {
    // TODO: implement esptouch receive
    throw UnimplementedError();
  }
}
