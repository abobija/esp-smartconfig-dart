import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/esp_provisioning_exception.dart';
import 'package:esp_smartconfig/src/esp_provisioning_package.dart';
import 'package:esp_smartconfig/src/esp_provisioning_response.dart';
import 'package:loggerx/loggerx.dart';

final _logger = Logger.findOrCreate('esp_smartconfig');

/// Provisioner
class EspProvisioner {
  static final version = 0;
  static final _devicePort = 7001;
  static final _ports = [18266, 28266, 38266, 48266];

  /// Protocol
  final EspSmartConfigProtocol protocol;

  final _worker = _EspWorker();

  static final _defaultSendInterval = Duration(milliseconds: 15);
  static final _slowSendInterval = Duration(milliseconds: 100);
  static final _slowSendIntervalActivationThreshold = Duration(seconds: 20);

  final _results = <EspProvisioningResponse>[];

  final _onDeviceConnectedCtrl = StreamController<EspProvisioningResponse>();

  /// Stream of responses
  Stream<EspProvisioningResponse> get onResponse =>
      _onDeviceConnectedCtrl.stream;

  /// Constructor for new EspProvisioner
  ///
  /// [protocol] - Provisioning protocol (default is EspTouchV2)
  EspProvisioner({this.protocol = EspSmartConfigProtocol.espTouchV2});

  void _addResult(EspProvisioningResponse result) {
    if (_results.contains(result)) {
      return;
    }

    _results.add(result);
    _onDeviceConnectedCtrl.sink.add(result);
  }

  /// Start provisioning using [request]
  ///
  /// Provisioning will not stop automatically.
  /// It needs to be stopped manually by calling [stop] method
  Future<void> start(EspProvisioningRequest request) async {
    if (_worker.isolate != null) {
      throw Exception("Provisioning already runing");
    }

    final completer = Completer<void>();
    final rPort = ReceivePort();

    rPort.listen((data) {
      if (data is _EspWorkerEvent) {
        switch (data.type) {
          case _EspWorkerEventType.init:
            _worker.port = data.data;
            _worker.port!.send(_logger);
            _worker.port!.send(request);
            break;
          case _EspWorkerEventType.exception:
            _worker.destroy();

            if (!completer.isCompleted) {
              completer.completeError(data);
            }
            break;
          case _EspWorkerEventType.started:
            completer.complete();
            break;
          case _EspWorkerEventType.result:
            _addResult(data.data);
            break;
        }
      } else {
        _logger.debug("Unhandled message from isolate: $data");
      }
    });

    _worker.isolate = await Isolate.spawn(_provisioningIsolate, rPort.sendPort);
    return completer.future;
  }

  static void _provisioningIsolate(SendPort sPort) {
    final rPort = ReceivePort();
    Logger? _logger;

    rPort.listen((data) {
      if (data is Logger) {
        _logger = data;
      } else if (data is EspProvisioningRequest) {
        _startProvisioning(data, sPort, rPort, _logger!);
      }
    });

    sPort.send(_EspWorkerEvent.init(rPort.sendPort));
  }

  static void _startProvisioning(EspProvisioningRequest request, SendPort sPort,
      ReceivePort rPort, Logger _logger) async {
    _logger.info("Provisioning starting...");

    _logger.debug("ssid ${request.ssid}");
    _logger.debug("bssid ${request.bssid}");
    _logger.debug("pwd ${request.password}");
    _logger.debug("rData ${request.reservedData}");

    int p = 0;
    RawDatagramSocket? _socket;

    for (; p < _ports.length; p++) {
      try {
        _logger.debug("Creating UDP socket on port ${_ports[p]}");

        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _ports[p],
          reuseAddress: true,
        );

        _socket.broadcastEnabled = true;

        _socket.listen(
          (event) {
            switch (event) {
              case RawSocketEvent.read:
                final pkg = _socket!.receive();

                if (pkg == null || pkg.data.length < 7) {
                  _logger.warning(
                      "Received invalid EspTouch response: ${pkg!.data}");
                  break;
                }

                final deviceBssid = Uint8List(6);
                deviceBssid.setAll(0, pkg.data.skip(1).take(6));

                _logger.verbose(
                    "Received EspTouch response, device bssid $deviceBssid");

                sPort.send(_EspWorkerEvent.result(
                    EspProvisioningResponse(deviceBssid)));
                break;
            }
          },
          onError: (err, s) {
            _logger.error("Socket error", err, s);
            sPort.send(_EspWorkerEvent.exception("Socket error: $err"));
          },
          cancelOnError: true,
        );

        _logger.debug(
            "UDP socket on port ${_ports[p]} has been successfully created");
        break;
      } catch (e) {
        sPort.send(_EspWorkerEvent.exception("UDP port bind failed: $e"));
        return;
      }
    }

    if (_socket == null) {
      final ev = _EspWorkerEvent.exception("Create UDP socket failed");
      _logger.error(ev.data);
      sPort.send(ev);
      return;
    }

    final pkg = EspProvisioningPackage(request, p);

    _logger.verbose("blocks");
    _logger.verbose(pkg.blocks.map((e) => e.length));

    InternetAddress broadcastAddress = InternetAddress.fromRawAddress(
        Uint8List.fromList([255, 255, 255, 255]));

    int blockIdx = 0;
    int msStep = 5;
    int counter = 0;
    int intervalMs = _defaultSendInterval.inMilliseconds;
    int slowIntervalMs = _slowSendInterval.inMilliseconds;
    int slowIntervalThresholdMs =
        _slowSendIntervalActivationThreshold.inMilliseconds;

    Timer.periodic(Duration(milliseconds: msStep), (t) {
      if (++counter * msStep < intervalMs) {
        return;
      }

      counter = 0;

      if (blockIdx < pkg.blocks.length) {
        _socket!.send(pkg.blocks[blockIdx++], broadcastAddress, _devicePort);
      } else {
        blockIdx = 0;

        _logger.verbose("Package with ${pkg.blocks.length} blocks was sent");

        if (intervalMs != slowIntervalMs &&
            t.tick * msStep >= slowIntervalThresholdMs) {
          intervalMs = slowIntervalMs;
          _logger.debug("Switched to slow interval of ${slowIntervalMs}ms");
        }
      }
    });

    _logger.info("Provisioning started");

    sPort.send(_EspWorkerEvent.started());
  }

  /// Stop provisioning previously started with [start] method
  void stop() {
    _worker.destroy();
    _onDeviceConnectedCtrl.close();
    _logger.info("Provisioning stopped");
  }
}

class _EspWorker {
  Isolate? isolate;
  SendPort? port;

  void destroy() {
    if (isolate == null) {
      _logger.debug("Isolate already destroyed");
    } else {
      _logger.debug("Destroying isolate");
      isolate!.kill(priority: Isolate.immediate);
      isolate = null;
    }

    port = null;
  }
}

enum _EspWorkerEventType {
  init,
  exception,
  started,
  result,
}

class _EspWorkerEvent {
  final _EspWorkerEventType type;
  final dynamic data;

  const _EspWorkerEvent(this.type, [this.data]);

  factory _EspWorkerEvent.init(SendPort port) {
    return _EspWorkerEvent(_EspWorkerEventType.init, port);
  }

  factory _EspWorkerEvent.exception(
    String message,
  ) {
    return _EspWorkerEvent(
        _EspWorkerEventType.exception, EspProvisioningException(message));
  }

  factory _EspWorkerEvent.started() {
    return _EspWorkerEvent(_EspWorkerEventType.started);
  }

  factory _EspWorkerEvent.result(EspProvisioningResponse result) {
    return _EspWorkerEvent(_EspWorkerEventType.result, result);
  }
}
