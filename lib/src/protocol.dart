import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_smartconfig/src/aes.dart';
import 'package:esp_smartconfig/src/bottleneck.dart';
import 'package:esp_smartconfig/src/crc.dart';
import 'package:esp_smartconfig/src/provisioning_request.dart';
import 'package:esp_smartconfig/src/provisioning_response.dart';
import 'package:esp_smartconfig/src/exceptions.dart';
import 'package:loggerx/loggerx.dart';

/// Provisioning protocol
abstract class Protocol {
  /// Protocol name
  String get name;

  /// Network broadcast address
  static final broadcastAddress =
      InternetAddress.fromRawAddress(Uint8List.fromList([255, 255, 255, 255]));

  /// UDP port of Esp device
  static final devicePort = 7001;

  /// UDP socket used for sending and receiving packets
  late final RawDatagramSocket _socket;

  /// Index of protocol port
  late final int portIndex;

  /// Provisioning request
  late final ProvisioningRequest request;

  /// Protocol bottlenecker
  final bottleneck = Bottleneck(15);

  /// Logger
  late final Logger logger;

  /// List of the protocol [ports].
  /// Provisioner will take one port after the another and try to open it.
  /// After first successfully opened port provisioner will stop and set
  /// the [portIndex] of opened port
  List<int> get ports;

  /// Blocks that needs to be transmitted to device
  final blocks = <int>[];

  int _blockIndex = 0;

  final _responsesList = <ProvisioningResponse>[];

  /// Send block and return index of sent block.
  ///
  /// If sending is gonna be sent through the [bottleneck], and
  /// [bottleneck] has not pass, function will return null which means
  /// that block is not sent in [bottleneck] flow
  int? sendBlock({Bottleneck? bottleneck, Function()? onAllBlocksSent}) {
    int? sentBlockIndex;

    void _() {
      sentBlockIndex = _blockIndex;
      send(Uint8List(blocks[_blockIndex++]));

      if (_blockIndex >= blocks.length) {
        _blockIndex = 0;

        if (onAllBlocksSent != null) {
          onAllBlocksSent();
        }
      }
    }

    if (bottleneck != null) {
      bottleneck.flow(_);
    } else {
      _();
    }

    return sentBlockIndex;
  }

  /// Protocol installation
  void install(RawDatagramSocket socket, int portIndex,
      ProvisioningRequest request, Logger logger) {
    _socket = socket;
    this.portIndex = portIndex;
    this.request = request;
    this.logger = logger;
  }

  /// Prepare package, set variables, etc...
  void prepare() {}

  /// Loop is invoked by provisioner [timer]
  /// in very short [stepMs] intervals, typically 1-20 ms.
  void loop(int stepMs, Timer timer) {
    sendBlock(bottleneck: bottleneck);
  }

  /// Find response in [_responsesList] by [bssid]
  ProvisioningResponse? findResponse(ProvisioningResponse response) {
    for (var r in _responsesList) {
      if (r == response) {
        return r;
      }
    }

    return null;
  }

  /// Returns added response
  ///
  /// Throws [ProvisioningResponseAlreadyReceivedError] if same response already exists
  ProvisioningResponse addResponse(ProvisioningResponse response) {
    final foundResponse = findResponse(response);

    if (foundResponse != null) {
      throw ProvisioningResponseAlreadyReceivedError(
          "Response ($foundResponse) already received");
    }

    _responsesList.add(response);
    return response;
  }

  /// Sends a [buffer]
  int send(List<int> buffer) {
    return _socket.send(buffer, broadcastAddress, devicePort);
  }

  /// Receive data and returns response with device BSSID
  ///
  /// Throws [InvalidProvisioningResponseDataException] if data of received response is invalid
  ProvisioningResponse receive(Uint8List data) {
    if (data.length < 7) {
      throw InvalidProvisioningResponseDataException(
          "Invalid data ($data). Length should be at least 7 elements");
    }

    return ProvisioningResponse(Uint8List(6)..setAll(0, data.skip(1).take(6)));
  }

  /// Number of milliseconds since Unix epoch
  static int ms() => DateTime.now().millisecondsSinceEpoch;

  /// Number of milliseconds since Unix epoch
  int millis() => ms();

  /// Cast signed byte [s8] to unsigned byte [u8]
  int u8(int s8) => s8 & 0xFF;

  /// Cast signed 16 bit integer [s16] into unsigned 16 bit integer [u16]
  int u16(int s16) => s16 & 0xFFFF;

  /// Merge high/low nibbles into new unsigned byte
  int merge8(int high, int low) => u8((high << 4) | low);

  /// Spit unsigned [byte] to high and low nibbles
  Uint8List split8(int byte) =>
      Uint8List.fromList([(byte & 0xF0) >> 4, byte & 0x0F]);

  /// Merge two unsigned bytes ([high] and [low]) into new unsigned 16 bit integer
  int merge16(int high, int low) => u16((high << 8) | low);

  /// CRC of [data]
  int crc(Int8List data) => Crc.calculate(data);

  /// Returns encrypted [data] that is encrypted with the [key]
  Int8List encrypt(Int8List data, Int8List key) => Aes.encrypt(data, key);

  @override
  String toString() => name;
}
