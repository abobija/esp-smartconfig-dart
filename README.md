# esp_smartconfig

[![pub version](https://img.shields.io/pub/v/esp_smartconfig?color=blue&logo=dart&style=for-the-badge)](https://pub.dev/packages/esp_smartconfig) ![license](https://img.shields.io/github/license/abobija/esp-smartconfig-dart?style=for-the-badge)

This is not yet another wrapper around Java and ObjectiveC libraries from Espressif. This library has been written completely from skratch in plain Dart and supports all **non-web** platforms.

## Implemented protocols

> *NOTE: All protocols currently supports only **broadcast** mode. Multicast coming soon...*

- EspTouch
- EspTouch V2

## Supported platforms

All non-web platforms are supported. Web platform is not supported mainly because browsers does not allow UDP communication.

> If you are going to use this library on Desktop platforms make sure that UDP port `18266` is open in firewall for incoming data.

## Example

*Several examples of using this library are available in [**example folder**](example).*

```dart
import 'package:esp_smartconfig/esp_smartconfig.dart';

final provisioner = Provisioner.espTouch();

provisioner.listen((response) {
    print("Device ${response.bssidText} connected to WiFi!");
});

try {
    await provisioner.start(ProvisioningRequest.fromStrings(
        ssid: "NETWORK NAME",
        bssid: "ROUTER BSSID",
        password: "NETWORK PASSWORD",
    ));

    // If you are going to use this library in Flutter
    // this is good place to show some Dialog and wait for exit
    //
    // Or simply you can delay with Future.delayed function
    await Future.delayed(Duration(seconds: 10));
} catch (e, s) {
    print(e);
}

// Provisioning does not have any timeout so it needs to be
// stopped manually
provisioner.stop();
```

## SmartConfig

The SmartConfig<sup>TM</sup> is a provisioning technology to connect a new Wi-Fi device to a Wi-Fi network.

The advantage of this technology is that the device does not need to directly know SSID or password of an Access Point (AP). Those information is provided using this library. This is particularly important to headless device and systems, due to their lack of a user interface.

## Author

GitHub: [abobija](https://github.com/abobija)<br>
Homepage: [abobija.com](https://abobija.com)

## License

[MIT](LICENSE)
