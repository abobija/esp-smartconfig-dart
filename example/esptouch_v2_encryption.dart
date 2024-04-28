import 'dart:io';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:loggerx/loggerx.dart';

void main() async {
  logging.level = LogLevel.debug;

  final provisioner = Provisioner.espTouchV2();

  provisioner.listen((response) {
    log.info("\n"
        "\n---------------------------------------------------------\n"
        "Device ($response) is connected to WiFi!"
        "\n---------------------------------------------------------\n");
  });

  try {
    await provisioner.start(ProvisioningRequest.fromStrings(
      ssid: "Renault 1.9D",
      bssid: "f8:d1:11:bf:28:5c", // optional
      password: "renault19",
      encryptionKey: "MySecretKey!6754",
    ));

    await Future.delayed(Duration(seconds: 5));
  } catch (e, s) {
    log.error(e, s);
  }

  provisioner.stop();
  exit(0);
}
