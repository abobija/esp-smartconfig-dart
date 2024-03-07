<p align="center"><img src="https://github.com/abobija/esp-smartconfig-dart/raw/main/assets/img/esp_smartconfig_abstract.png" alt="esp_smartconfig" /></p>

<div align="center">
    <a href="https://pub.dev/packages/esp_smartconfig"><img src="https://img.shields.io/pub/v/esp_smartconfig?color=blue&logo=dart&style=for-the-badge" alt="pub version" /></a>
    <img src="https://img.shields.io/github/license/abobija/esp-smartconfig-dart?style=for-the-badge" alt="license" />
</div>

Dart implementation of [EspTouch](https://www.espressif.com/en/products/software/esp-touch/overview) provisioner. Supports Android, iOS, Windows, Linux and macOS.

## Implemented protocols

- EspTouch
- EspTouch V2

## Supported platforms

All non-web platforms are supported. Web platform is not supported mainly because browsers does not allow UDP communication.

> If you are going to use this library on Desktop platforms make sure that UDP port `18266` is open in firewall for incoming data.

##### Breaking Change iOS 14.6/16
The breaking change was implemented with 14.6. However, it seems to be the case that the mentioned problem only occurs on devices with iOS version 16. It results in the fact that no connection to the ESP can be established. 

**How to:**
- You need an Apple-Developer account
- After the Dev-Account has been approved, you have to make a request via this [form](https://developer.apple.com/contact/request/networking-multicast) to be allowed to use the Multicast Api.
- Then you can follow this [guide](https://developer.apple.com/forums/thread/663271?answerId=639455022#639455022) (new process)

## Demo video

[![Demo YouTube video](https://img.youtube.com/vi/yjxtwQ8Xpuo/mqdefault.jpg)](https://youtu.be/yjxtwQ8Xpuo)

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
