import 'dart:io';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:loggerx/loggerx.dart';

void main() async {
  logging.level = LogLevel.verbose;

  final provisioner = EspProvisioner.espTouch2();

  provisioner.onResponse.listen((response) {
    log.info("\n"
        "\n---------------------------------------------------------\n"
        "Device ${response.deviceBssid} is connected to WiFi!"
        "\n---------------------------------------------------------\n");
  });

  try {
    await provisioner.start(EspProvisioningRequest.fromStrings(
      ssid: "Renault 1.9D",
      bssid: "f8:d1:11:bf:28:5c",
      password: "renault19",
      reservedData: "Hello from Dart",
    ));
  } catch (e, s) {
    log.error(e, s);
  }

  await Future.delayed(Duration(seconds: 10));
  provisioner.stop();

  exit(0);
}
