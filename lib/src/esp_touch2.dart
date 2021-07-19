import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:esp_smartconfig/src/esp_provisioning_crc.dart';
import 'package:esp_smartconfig/src/esp_provisioning_exception.dart';
import 'package:esp_smartconfig/src/esp_provisioning_protocol.dart';
import 'package:esp_smartconfig/src/esp_provisioning_request.dart';
import 'package:esp_smartconfig/src/esp_provisioning_response.dart';
import 'package:loggerx/src/logger.dart';

class EspTouch2 extends EspProvisioningProtocol {
  static final version = 0;

  static final _defaultSendIntervalMs =
      Duration(milliseconds: 15).inMilliseconds;
  static final _slowIntervalMs = Duration(milliseconds: 100).inMilliseconds;
  static final _slowIntervalThresholdMs = Duration(seconds: 20).inMilliseconds;

  @override
  List<int> get ports => [18266, 28266, 38266, 48266];

  int _stepCounter = 0;
  int _intervalMs = _defaultSendIntervalMs;

  late Int8List _buffer;
  int _blockPointer = 0;
  final _blocks = <int>[];

  var _isSsidEncoded = false;
  var _isPasswordEncoded = false;
  var _isReservedDataEncoded = false;

  int _ssidPaddingFactor = 6;
  int _passwordPaddingFactor = 6;
  int _reservedPaddingFactor = 6;

  bool get isSsidEncoded => _isSsidEncoded;
  bool get isPasswordEncoded => _isPasswordEncoded;
  bool get isReservedDataEncoded => _isReservedDataEncoded;

  int _headLength = 0;
  int _passwordLength = 0;
  int _passwordPaddingLength = 0;
  int _reservedDataLength = 0;
  int _reservedDataPaddingLength = 0;

  set isSsidEncoded(bool value) {
    _isSsidEncoded = value;
    _ssidPaddingFactor = value ? 5 : 6;
  }

  set isPasswordEncoded(bool value) {
    _isPasswordEncoded = value;
    _passwordPaddingFactor = value ? 5 : 6;
  }

  set isReservedDataEncoded(bool value) {
    _isReservedDataEncoded = value;
    _reservedPaddingFactor = value ? 5 : 6;
  }

  @override
  void setup(RawDatagramSocket socket, int portIndex,
      EspProvisioningRequest request, Logger logger) {
    super.setup(socket, portIndex, request, logger);

    final dataTmp = <int>[];

    dataTmp.addAll(_head());

    if (request.password != null) {
      _passwordLength = request.password!.length;
      dataTmp.addAll(request.password!);

      if (_isPasswordEncoded || _isReservedDataEncoded) {
        final padding = _padding(_passwordPaddingFactor, request.password);
        _passwordPaddingLength = padding.length;
        dataTmp.addAll(padding);
      }
    }

    if (request.reservedData != null) {
      _reservedDataLength = request.reservedData!.length;
      dataTmp.addAll(request.reservedData!);

      if (_isPasswordEncoded || _isReservedDataEncoded) {
        final padding = _padding(_reservedPaddingFactor, request.reservedData);
        _reservedDataPaddingLength = padding.length;
        dataTmp.addAll(padding);
      }
    }

    dataTmp.addAll(request.ssid);
    dataTmp.addAll(_padding(_ssidPaddingFactor, request.ssid));

    _buffer = Int8List.fromList(dataTmp);
    dataTmp.clear();

    logger.verbose("paddings "
        "password=$_passwordPaddingLength, "
        "reserved_data=$_reservedDataPaddingLength");

    logger.debug("package buffer $_buffer");

    int reservedDataBeginPos =
        _headLength + _passwordLength + _passwordPaddingLength;
    int ssidBeginPos =
        reservedDataBeginPos + _reservedDataLength + _reservedDataPaddingLength;
    int offset = 0;
    int count = 0;

    while (offset < _buffer.length) {
      int expectLength;
      bool tailIsCrc;

      if (count == 0) {
        tailIsCrc = false;
        expectLength = 6;
      } else {
        if (offset < reservedDataBeginPos) {
          tailIsCrc = !isPasswordEncoded;
          expectLength = _passwordPaddingFactor;
        } else if (offset < ssidBeginPos) {
          tailIsCrc = !isReservedDataEncoded;
          expectLength = _reservedPaddingFactor;
        } else {
          tailIsCrc = !isSsidEncoded;
          expectLength = _ssidPaddingFactor;
        }
      }

      final buf = Int8List(6);
      final read =
          Int8List.fromList(_buffer.skip(offset).take(expectLength).toList());
      buf.setAll(0, read);
      if (read.length <= 0) {
        break;
      }
      offset += read.length;

      final crc = EspProvisioningCrc.calculate(read);
      if (expectLength < buf.length) {
        buf.buffer.asByteData().setInt8(buf.length - 1, crc);
      }

      _createBlocksFor6Bytes(buf, count - 1, crc, tailIsCrc);
      count++;
    }

    _updateBlocksForSequencesLength(count);

    logger.verbose("blocks ${_blocks}");
  }

  @override
  void loop(int stepMs, Timer timer) {
    if (++_stepCounter * stepMs < _intervalMs) {
      return;
    }

    _stepCounter = 0;

    if (_blockPointer < _blocks.length) {
      send(Int8List(_blocks[_blockPointer++]));
    } else {
      _blockPointer = 0;

      logger.verbose("Package with ${_blocks.length} blocks was sent");

      if (_intervalMs != _slowIntervalMs &&
          timer.tick * stepMs >= _slowIntervalThresholdMs) {
        _intervalMs = _slowIntervalMs;
        logger.debug("Switched to slow interval of ${_slowIntervalMs}ms");
      }
    }
  }

  @override
  EspProvisioningResponse receive(Uint8List data) {
    if (data.length < 7) {
      throw EspProvisioningException(
          "Invalid data ($data). Length should at least 7 elements");
    }

    final deviceBssid = Uint8List(6);
    deviceBssid.setAll(0, data.skip(1).take(6));

    return EspProvisioningResponse(deviceBssid);
  }

  Int8List _head() {
    final headTmp = <int>[];

    isSsidEncoded = _isDataEncoded(request.ssid);
    headTmp.add(request.ssid.length | (_isSsidEncoded ? 0x80 : 0));

    if (request.password == null) {
      headTmp.add(0);
    } else {
      isPasswordEncoded = _isDataEncoded(request.password!);
      headTmp.add(request.password!.length | (_isPasswordEncoded ? 0x80 : 0));
    }

    if (request.reservedData == null) {
      headTmp.add(0);
    } else {
      isReservedDataEncoded = _isDataEncoded(request.reservedData!);
      headTmp.add(
          request.reservedData!.length | (_isReservedDataEncoded ? 0x80 : 0));
    }

    headTmp.add(EspProvisioningCrc.calculate(request.bssid));

    final flag = (1) // bit0 : 1-ipv4, 0-ipv6
        |
        ((0) << 1) // bit1 bit2 : 00-no crypt, 01-crypt
        |
        ((portIndex & 0x03) << 3) // bit3 bit4 : app port
        |
        ((EspTouch2.version & 0x03) << 6); // bit6 bit7 : version

    headTmp.add(flag);

    headTmp.add(EspProvisioningCrc.calculate(Int8List.fromList(headTmp)));
    _headLength = headTmp.length;

    return Int8List.fromList(headTmp);
  }

  void _updateBlocksForSequencesLength(int size) {
    _blocks[1] = _blocks[3] = _seqSizeBlock(size);
  }

  void _createBlocksFor6Bytes(
      Int8List buf, int sequence, int crc, bool tailIsCrc) {
    logger.verbose("buf=$buf, seq=$sequence, crc=$crc, tailIsCrc=$tailIsCrc");

    if (sequence == -1) {
      // first sequence
      final syncBlock = _syncBlock();

      _blocks.addAll([
        syncBlock,
        0,
        syncBlock,
        0,
      ]);
    } else {
      final seqBlock = _seqBlock(sequence);

      _blocks.addAll([
        seqBlock,
        seqBlock,
        seqBlock,
      ]);
    }

    for (int bit = 0; bit < (tailIsCrc ? 7 : 8); bit++) {
      int data = (buf[5] >> bit & 1) |
          ((buf[4] >> bit & 1) << 1) |
          ((buf[3] >> bit & 1) << 2) |
          ((buf[2] >> bit & 1) << 3) |
          ((buf[1] >> bit & 1) << 4) |
          ((buf[0] >> bit & 1) << 5);

      _blocks.add(_dataBlock(data, bit));
    }

    if (tailIsCrc) {
      _blocks.add(_dataBlock(crc, 7));
    }
  }

  int _syncBlock() => 1048;
  int _seqSizeBlock(int size) => 1072 + size - 1;
  int _seqBlock(int seq) => 128 + seq;
  int _dataBlock(int data, int idx) => ((idx << 7) | (1 << 6) | data);

  Int8List _padding(int factor, Int8List? data) {
    int length = factor - (data == null ? 0 : data.length) % factor;
    return Int8List(length < factor ? length : 0);
  }

  bool _isDataEncoded(Int8List data) {
    for (var b in data) {
      if (b < 0) {
        return true;
      }
    }

    return false;
  }
}
