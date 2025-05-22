import 'dart:typed_data';

import 'package:esp_smartconfig/src/protocol.dart';

class EspTouchV2 extends Protocol {
  static final version = 0;

  @override
  String get name => "EspTouch V2";

  @override
  List<int> get ports => [18266, 28266, 38266, 48266];

  late Int8List _buffer;

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

  bool get willEncrypt =>
      request.encryptionKey != null &&
      (request.password != null || request.reservedData != null);

  @override
  void prepare() {
    final dataTmp = <int>[];

    dataTmp.addAll(_head());

    if (willEncrypt) {
      final plainData = <int>[];

      if (request.password != null) {
        plainData.addAll(request.password!);
      }

      if (request.reservedData != null) {
        plainData.addAll(request.reservedData!);
      }

      final encryptedData =
          encrypt(Int8List.fromList(plainData), request.encryptionKey!);

      plainData.clear();

      isPasswordEncoded = true;
      _passwordLength = encryptedData.length;
      dataTmp.addAll(encryptedData);

      final padding = _padding(_passwordPaddingFactor, encryptedData);
      _passwordPaddingLength = padding.length;
      dataTmp.addAll(padding);
    } else {
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
          final padding =
              _padding(_reservedPaddingFactor, request.reservedData);
          _reservedDataPaddingLength = padding.length;
          dataTmp.addAll(padding);
        }
      }
    }

    dataTmp.addAll(request.ssid);
    dataTmp.addAll(_padding(_ssidPaddingFactor, request.ssid));

    _buffer = Int8List.fromList(dataTmp);
    dataTmp.clear();

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
      if (read.isEmpty) {
        break;
      }
      offset += read.length;

      final checksum = crc(read);
      if (expectLength < buf.length) {
        buf.buffer.asByteData().setInt8(buf.length - 1, checksum);
      }

      _createBlocksFor6Bytes(buf, count - 1, checksum, tailIsCrc);
      count++;
    }

    _updateBlocksForSequencesLength(count);
  }

  Int8List _head() {
    final headTmp = <int>[];

    isSsidEncoded = isEncoded(request.ssid);
    headTmp.add(request.ssid.length | (_isSsidEncoded ? 0x80 : 0));

    if (request.password == null) {
      headTmp.add(0);
    } else {
      isPasswordEncoded = isEncoded(request.password!);
      headTmp.add(request.password!.length | (_isPasswordEncoded ? 0x80 : 0));
    }

    if (request.reservedData == null) {
      headTmp.add(0);
    } else {
      isReservedDataEncoded = isEncoded(request.reservedData!);
      headTmp.add(
          request.reservedData!.length | (_isReservedDataEncoded ? 0x80 : 0));
    }

    headTmp.add(crc(request.bssid));

    final flag = (1) // bit0 : 1-ipv4, 0-ipv6
        |
        ((willEncrypt ? 0x01 : 0x00) << 1) // bit1 bit2 : 00-no crypt, 01-crypt
        |
        ((portIndex & 0x03) << 3) // bit3 bit4 : app port
        |
        ((EspTouchV2.version & 0x03) << 6); // bit6 bit7 : version

    headTmp.add(flag);

    headTmp.add(crc(Int8List.fromList(headTmp)));
    _headLength = headTmp.length;

    return Int8List.fromList(headTmp);
  }

  void _updateBlocksForSequencesLength(int size) {
    blocks[1] = blocks[3] = _seqSizeBlock(size);
  }

  void _createBlocksFor6Bytes(
      Int8List buf, int sequence, int crc, bool tailIsCrc) {
    if (sequence == -1) {
      // first sequence
      final syncBlock = _syncBlock();

      blocks.addAll([
        syncBlock,
        0,
        syncBlock,
        0,
      ]);
    } else {
      final seqBlock = _seqBlock(sequence);

      blocks.addAll([
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

      blocks.add(_dataBlock(data, bit));
    }

    if (tailIsCrc) {
      blocks.add(_dataBlock(crc, 7));
    }
  }

  int _syncBlock() => 1048;
  int _seqSizeBlock(int size) => 1072 + size - 1;
  int _seqBlock(int seq) => 128 + seq;
  int _dataBlock(int data, int idx) => ((idx << 7) | (1 << 6) | data);

  Int8List _padding(int factor, Int8List? data) {
    final length = factor - (data?.length ?? 0) % factor;
    return Int8List(length < factor ? length : 0);
  }
}
