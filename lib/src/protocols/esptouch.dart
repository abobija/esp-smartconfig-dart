import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/protocol.dart';
import 'package:esp_smartconfig/src/provisioning_response.dart';
import 'package:loggerx/loggerx.dart';

class EspTouch extends Protocol {
  static final extraLen = 40;
  static final extraHeadLen = 5;
  static final ipLen = 4; // ipv4

  @override
  List<int> get ports => [18266];

  @override
  void setup(RawDatagramSocket socket, int portIndex,
      ProvisioningRequest request, Logger logger) {
    super.setup(socket, portIndex, request, logger);

    // guide blocks
    blocks.addAll([515, 514, 513, 512]);

    final dataCodes = _dataCodes();
    
    for(int i = 0; i < dataCodes.length / 2; i++) {
      blocks.add(extraLen + _join16(
        dataCodes[i * 2],
        dataCodes[i * 2 + 1]
      ));
    }
  }

  List<int> _dataCodes() {
    final pwdLen = request.password == null ? 0 : request.password!.length;

    final ssidCrc = crc(request.ssid);
    final bssidCrc = crc(request.bssid);

    final totalLen = extraHeadLen + ipLen + pwdLen + request.ssid.length;
    
    final dataCodes = <Uint8List>[];
    int xor = 0;
    int index = 0;

    for(var b in [totalLen, pwdLen, ssidCrc, bssidCrc]) {
      dataCodes.add(_dataCode(b, index++));
      xor ^= b;
    }

    index++; // skip xor place

    Uint8List(ipLen).forEach((octet) {
      xor ^= octet;
      dataCodes.add(_dataCode(0, index++));
    });

    if(request.password != null) {
      request.password!.forEach((b) {
        final u = u8(b);
        xor ^= u;
        dataCodes.add(_dataCode(u, index++));
      });
    }

    request.ssid.forEach((b) {
      int u = u8(b);
      xor ^= u;
      dataCodes.add(_dataCode(u, index++));
    });

    dataCodes.insert(4, _dataCode(xor, 4));

    var bssidIndex = totalLen;
    var bssidInsertIndex = extraHeadLen;
    request.bssid.forEach((b) {
      dataCodes.insert(bssidInsertIndex, _dataCode(u8(b), bssidIndex++));
      bssidInsertIndex += 4;
    });

    final spreaded = <int>[];

    while(dataCodes.isNotEmpty) {
      spreaded.addAll(dataCodes[0]);
      dataCodes.removeAt(0);
    }

    return spreaded;
  }

  Uint8List _dataCode(int u8, int index) {
    if(index > 127) {
      throw ArgumentError("Invalid index (> 127)");
    }

    final _data = _split(u8);
    final _crc = _split(crc(Int8List.fromList([u8, index])));

    return Uint8List.fromList([
      0x00,
      _join(_crc[0], _data[0]),
      0x01,
      index,
      0x00,
      _join(_crc[1], _data[1])
    ]);
  }

  /// Returns high/low nibbles of unsigned [byte]
  Uint8List _split(int byte) {
    return Uint8List.fromList([
      (byte & 0xF0) >> 4, byte & 0x0F
    ]);
  }

  /// Joins byte high/low nibbles into new unsigned byte
  int _join(int high, int low) => u8((high << 4) | low);

  /// Joins two usinged bytes [high] and [low] into usigned 16 bit integer
  int _join16(int high, int low) => u16((high << 8) | low);

  //Int8List _block(int len) 
  //  => Int8List.fromList(List.filled(len, 49));

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
