import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/protocol.dart';
import 'package:esp_smartconfig/src/protocols/esptouch.dart';
import 'package:esp_smartconfig/src/protocols/esptouch_v2.dart';
import 'package:loggerx/loggerx.dart';

final _logger = Logger.findOrCreate('esp_smartconfig');

/// Provisioner
class Provisioner {
  /// Protocol
  final Protocol _protocol;

  /// Provisioning isolate
  Isolate? _isolate;

  /// Provisioner running indicator
  bool get running => _isolate != null;

  /// Responses stream controller
  final _streamCtrl = StreamController<ProvisioningResponse>();

  /// Constructor for new EspProvisioner with desired [protocol]
  Provisioner._(this._protocol);

  /// Provisioner with [EspTouchV2] protocol
  factory Provisioner.espTouchV2() {
    return Provisioner._(EspTouchV2());
  }

  /// Provisioner with [EspTouch] protocol
  factory Provisioner.espTouch() {
    return Provisioner._(EspTouch());
  }

  /// Subscribe to provisioner events stream
  StreamSubscription<ProvisioningResponse> listen(
      void Function(ProvisioningResponse)? onData,
      {Function? onError,
      void Function()? onDone}) {
    return _streamCtrl.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: true,
    );
  }

  /// Start provisioning using [request]
  ///
  /// Provisioning will not stop automatically.
  /// It needs to be stopped manually by calling [stop] method
  Future<void> start(ProvisioningRequest request) async {
    if (running) {
      throw ProvisioningException("Provisioning already runing");
    }

    final completer = Completer<void>();
    final rPort = ReceivePort();

    final worker =
        _EspWorker(request: request, logger: _logger, protocol: _protocol);

    rPort.listen((event) {
      if (event is _EspWorkerEvent) {
        switch (event.type) {
          case _EspWorkerEventType.init:
            (event.data as SendPort).send(worker);
            break;
          case _EspWorkerEventType.exception:
            _logger.error(event.data);

            if (!completer.isCompleted) {
              // failed to start provisioner
              completer.completeError(event.data);
            } else {
              _streamCtrl.sink.addError(event.data);

              // stop provisioning on any runtime error
              stop();
            }
            break;
          case _EspWorkerEventType.started:
            _logger.info("Provisioning started");
            completer.complete();
            break;
          case _EspWorkerEventType.response:
            _logger.info("Received response (${event.data}");
            if (!_streamCtrl.isClosed) _streamCtrl.sink.add(event.data);
            break;
        }
      } else {
        _logger.warning("Unhandled message from isolate: $event");
      }
    });

    _isolate = await Isolate.spawn(_provisioningIsolate, rPort.sendPort);
    return completer.future;
  }

  static void _provisioningIsolate(SendPort sPort) {
    final rPort = ReceivePort();

    rPort.listen((data) {
      if (data is _EspWorker) {
        _startProvisioning(data, sPort);
      }
    });

    sPort.send(_EspWorkerEvent.init(rPort.sendPort));
  }

  static void _startProvisioning(_EspWorker worker, SendPort sPort) async {
    final request = worker.request;
    final logger = worker.logger;
    final protocol = worker.protocol;

    logger.debug("$protocol povisioning");

    logger.debug("---------- Request ----------");
    logger.debug("ssid ${request.ssid}");
    logger.debug("bssid ${request.bssid}");
    logger.debug("pwd ${request.password}");
    logger.debug("rData ${request.reservedData}");
    logger.debug("encriptionKey ${request.encryptionKey}");
    logger.debug("-----------------------------");

    int p = 0;
    RawDatagramSocket? socket;

    final ports = protocol.ports;
    for (; p < ports.length; p++) {
      try {
        logger.debug("Creating UDP socket on port ${ports[p]}");

        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          ports[p],
          reuseAddress: true,
        );

        socket.broadcastEnabled = true;

        socket.listen(
          (event) {
            if (event != RawSocketEvent.read) {
              return;
            }

            final pkg = socket!.receive();

            if (pkg == null) {
              return;
            }

            try {
              final response = protocol.receive(pkg.data);

              if (protocol.findResponse(response) != null) {
                // Same response already received
                return;
              }

              protocol.addResponse(response);
              sPort.send(_EspWorkerEvent.result(response));
            } catch (e) {
              sPort.send(_EspWorkerEvent.exception("Invalid response: $e"));
            }
          },
          onError: (err, s) {
            logger.error("Socket error", err, s);
            sPort.send(_EspWorkerEvent.exception("Socket error: $err"));
          },
          cancelOnError: true,
        );

        logger.debug("UDP socket on port ${ports[p]} successfully created");
        break;
      } catch (e) {
        sPort.send(_EspWorkerEvent.exception("UDP port bind failed: $e"));
        return;
      }
    }

    if (socket == null) {
      sPort.send(_EspWorkerEvent.exception("Create UDP socket failed"));
      return;
    }

    // Install and prepare protocol
    protocol
      ..install(socket, p, request, logger)
      ..prepare();

    logger.verbose("blocks ${protocol.blocks}");

    // Protocol loop function execution in short time intervals
    final tmrDuration = Duration(milliseconds: 5);
    Timer.periodic(
        tmrDuration, (t) => protocol.loop(tmrDuration.inMilliseconds, t));

    sPort.send(_EspWorkerEvent.started());
  }

  /// Stop provisioning that is previously started with [start] method
  void stop() {
    if (!_streamCtrl.isClosed) {
      _streamCtrl.close();
    }

    if (running) {
      _logger.debug("Destroying isolate");
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }

    _logger.info("Provisioning stopped");
  }
}

class _EspWorker {
  final ProvisioningRequest request;
  final Logger logger;
  final Protocol protocol;

  const _EspWorker({
    required this.request,
    required this.logger,
    required this.protocol,
  });
}

enum _EspWorkerEventType {
  init,
  exception,
  started,
  response,
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
        _EspWorkerEventType.exception, ProvisioningException(message));
  }

  factory _EspWorkerEvent.started() {
    return _EspWorkerEvent(_EspWorkerEventType.started);
  }

  factory _EspWorkerEvent.result(ProvisioningResponse result) {
    return _EspWorkerEvent(_EspWorkerEventType.response, result);
  }
}
