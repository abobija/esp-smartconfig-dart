import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_smartconfig/src/esp_provisioning_request.dart';
import 'package:esp_smartconfig/src/esp_provisioning_response.dart';
import 'package:loggerx/loggerx.dart';

/// Abstract SmartConfig protocol
abstract class EspProvisioningProtocol {
  static final broadcastAddress =
      InternetAddress.fromRawAddress(Uint8List.fromList([255, 255, 255, 255]));
  static final devicePort = 7001;

  late final RawDatagramSocket _socket;
  late final int portIndex;
  late final EspProvisioningRequest request;
  late final Logger logger;

  List<int> get ports;

  void setup(RawDatagramSocket socket, int portIndex,
      EspProvisioningRequest request, Logger logger) {
    _socket = socket;
    this.portIndex = portIndex;
    this.request = request;
    this.logger = logger;
  }

  void loop(int stepMs, Timer t);

  int send(List<int> buffer) {
    return _socket.send(buffer, broadcastAddress, devicePort);
  }

  EspProvisioningResponse receive(Uint8List data);
}
