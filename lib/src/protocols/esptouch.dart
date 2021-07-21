import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/protocol.dart';
import 'package:esp_smartconfig/src/provisioning_response.dart';
import 'package:loggerx/loggerx.dart';

class EspTouch extends Protocol {
  static final _ipLen = 4; // ipv4
  static final _extraHeadLen = 5;
  static final _extraLen = 40;
  static final _dataCodeLen = 3;
  static final _guideLen = 4;
  static final _guideSendingDurationMs = 2000;
  static final _dataSendingDurationMs = 4000;
  static final _iterationDataLen = 3;
  final _guideBN = BottleNeck(30);
  final _dataBN = BottleNeck(17);

  @override
  String get name => "EspTouch";

  @override
  List<int> get ports => [18266];

  late int _expectedResponseFirstByte;
  int _previousMs = 0;

  /// Pointer to data block which needs to be sent next
  int _dataPointer = 0;

  Iterable<int> get _guide => blocks.take(_guideLen);

  Iterable<int> _data(int start) =>
      blocks.skip(_guideLen).skip(start).take(_iterationDataLen);

  @override
  void setup(RawDatagramSocket socket, int portIndex,
      ProvisioningRequest request, Logger logger) {
    super.setup(socket, portIndex, request, logger);

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

    for (var b in [totalLen, pwdLen, crc(request.ssid), crc(request.bssid)]) {
      dataCodes.addAll(_dataCode(b, index++));
      xor ^= b;
    }

    index++; // skip xor place

    Protocol.broadcastAddress.rawAddress.forEach((octet) {
      xor ^= octet;
      dataCodes.addAll(_dataCode(octet, index++));
    });

    if (request.password != null) {
      request.password!.forEach((b) {
        final u = u8(b);
        xor ^= u;
        dataCodes.addAll(_dataCode(u, index++));
      });
    }

    request.ssid.forEach((b) {
      int u = u8(b);
      xor ^= u;
      dataCodes.addAll(_dataCode(u, index++));
    });

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

  @override
  void loop(int stepMs, Timer timer) {
    final ms = millis();
    final diffMs = ms - _previousMs;

    if (diffMs >= _dataSendingDurationMs) {
      _previousMs = millis();
      _dataPointer = 0;
    } else if (diffMs >= _guideSendingDurationMs) {
      // send data
      _dataBN.exec(() {
        _data(_dataPointer).forEach((b) => send(Uint8List(b)));
        _dataPointer =
            (_dataPointer + _iterationDataLen) % (blocks.length - _guideLen);
      });
    } else {
      // send guide
      _guideBN.exec(() {
        _guide.forEach((b) => send(Uint8List(b)));
      });
    }
  }

  @override
  ProvisioningResponse receive(Uint8List data) {
    if (data.length != 11 || data[0] != _expectedResponseFirstByte) {
      throw InvalidProvisioningResponseDataException(
          "Invalid data($data) {.length != 11 || [0] != $_expectedResponseFirstByte}");
    }

    return ProvisioningResponse(Uint8List(6)..setAll(0, data.skip(1).take(6)),
        ipAddress: Uint8List(4)..setAll(0, data.skip(7).take(4)));
  }
}
