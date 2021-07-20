import 'dart:async';

import 'package:esp_smartconfig/src/provisioner.dart';
import 'package:esp_smartconfig/src/protocol.dart';

class EspTouchProvisioner extends Provisioner<EspTouch> {
  EspTouchProvisioner() : super(EspTouch());
}

// TODO: implement esptouch
class EspTouch extends Protocol {
  @override
  void loop(int stepMs, Timer timer) {
    // TODO: implement esptouch loop
    throw UnimplementedError();
  }

  @override
  // TODO: implement esptouch ports
  List<int> get ports => throw UnimplementedError();
}
