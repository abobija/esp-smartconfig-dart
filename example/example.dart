import 'dart:io';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.message}');
  });

  final provisioner = Provisioner.espTouch();

  provisioner.listen((response) {
    Logger.root.info("\n"
        "\n---------------------------------------------------------\n"
        "Device ($response) is connected to WiFi!"
        "\n---------------------------------------------------------\n");
  });

  try {
    await provisioner.start(ProvisioningRequest.fromStrings(
      ssid: "Renault 1.9D",
      bssid: "f8:d1:11:bf:28:5c", // optional
      password: "renault19",
    ));

    await Future.delayed(Duration(seconds: 10));
  } catch (e, s) {
    Logger.root.shout("Error", e, s);
  }

  provisioner.stop();
  exit(0);
}
