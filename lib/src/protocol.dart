import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:esp_smartconfig/src/aes.dart';
import 'package:esp_smartconfig/src/crc.dart';
import 'package:esp_smartconfig/src/provisioning_request.dart';
import 'package:esp_smartconfig/src/provisioning_response.dart';
import 'package:esp_smartconfig/src/exceptions.dart';
import 'package:loggerx/loggerx.dart';

/// Provisioning protocol
abstract class Protocol {
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

  /// Logger
  late final Logger logger;

  /// List of the protocol [ports].
  /// Provisioner will take one port after the another and try to open it.
  /// After first successfully opened port provisioner will stop and set
  /// the [portIndex] of opened port
  List<int> get ports;

  /// Protocol setup.
  /// Prepare package, set variables, etc...
  void setup(RawDatagramSocket socket, int portIndex,
      ProvisioningRequest request, Logger logger) {
    _socket = socket;
    this.portIndex = portIndex;
    this.request = request;
    this.logger = logger;
  }

  /// Loop is invoked by provisioner [timer] in very short [stepMs] intervals, typically 1-10 ms.
  /// This is good place to send data
  void loop(int stepMs, Timer timer);

  /// Sends a data [buffer]
  int send(List<int> buffer) {
    return _socket.send(buffer, broadcastAddress, devicePort);
  }

  /// Returns [data] CRC
  int crc(Int8List data) {
    return Crc.calculate(data);
  }

  /// Returns encrypted [data] that is encrypted with the [key]
  Int8List encrypt(Int8List data, Int8List key) {
    return Aes.encrypt(data, key);
  }
}

/// Provisioning protocol that can receive responses from Esp devices
abstract class EspResponseableProtocol {
  final _responsesList = <ProvisioningResponse>[];

  /// Find response in [_responsesList] by [deviceBssid]
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
    if (findResponse(response) != null) {
      throw ProvisioningResponseAlreadyReceivedError(
          "Response with deviceBssid=${response.deviceBssidString} already received");
    }

    _responsesList.add(response);
    return response;
  }

  /// Receive data
  ///
  /// Throws [InvalidProvisioningResponseDataException] if data of received response is invalid
  ProvisioningResponse receive(Uint8List data);
}
