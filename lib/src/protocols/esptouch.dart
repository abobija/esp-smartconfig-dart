import 'dart:typed_data';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/protocol.dart';

class EspTouch extends Protocol {
  static final _ipLen = 4; // ipv4
  static final _extraHeadLen = 5;
  static final _extraLen = 40;
  static final _dataCodeLen = 3;

  @override
  String get name => "EspTouch";

  late int _expectedResponseFirstByte;

  @override
  void prepare() {
    _expectedResponseFirstByte =
        request.ssid.length + (request.password?.length ?? 0) + 9;

    // guide blocks
    blocks.addAll([515, 514, 513, 512]);

    // data blocks
    blocks.addAll(_dataCodes());
  }

  List<int> _dataCodes() {
    final pwdLen = request.password == null ? 0 : request.password!.length;
    final totalLen = _extraHeadLen + _ipLen + pwdLen + request.ssid.length;

    final dataCodes = <int>[];
    int xor = 0;
    int index = 0;

    [
      [totalLen, pwdLen, crc(request.ssid), crc(request.bssid)],
      Protocol.broadcastAddress.rawAddress,
      request.password ?? [],
      request.ssid,
    ].forEach((data) => data.forEach((byte) {
          xor ^= byte;
          dataCodes.addAll(_dataCode(u8(byte), index++));
          if (index == 4) {
            // skip xor place
            index++;
          }
        }));

    // insert xor
    dataCodes.insertAll(4 * _dataCodeLen, _dataCode(xor, 4));

    var bssidIndex = totalLen;
    var bssidInsertIndex = _extraHeadLen * _dataCodeLen;
    request.bssid.forEach((b) {
      dataCodes.insertAll(bssidInsertIndex, _dataCode(u8(b), bssidIndex++));
      bssidInsertIndex += 4 * _dataCodeLen;
    });

    return dataCodes;
  }

  Uint16List _dataCode(int u8, int index) {
    if (index > 127) {
      throw ArgumentError("Invalid index (> 127)");
    }

    final _data = split8(u8);
    final _crc = split8(crc(Int8List.fromList([u8, index])));

    return Uint16List.fromList([
      merge8(_crc[0], _data[0]),
      merge16(0x01, index),
      merge8(_crc[1], _data[1]),
    ].map((e) => e + _extraLen).toList());
  }

  /// Receive data and returns response with device BSSID and IP address
  ///
  /// Throws [InvalidProvisioningResponseDataException] if received data is not valid
  @override
  ProvisioningResponse receive(Uint8List data) {
    final response = super.receive(data);

    if (data[0] != _expectedResponseFirstByte) {
      throw InvalidProvisioningResponseDataException(
          "Invalid data($data): [0] != $_expectedResponseFirstByte}");
    }

    if (data.length >= 11) {
      // there is IP address
      response.ipAddress = Uint8List(4)..setAll(0, data.skip(7).take(4));
    }

    return response;
  }
}
