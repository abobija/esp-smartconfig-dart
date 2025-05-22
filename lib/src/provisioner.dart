import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:esp_smartconfig/esp_smartconfig.dart';
import 'package:esp_smartconfig/src/protocol.dart';
import 'package:esp_smartconfig/src/protocols/esptouch.dart';
import 'package:esp_smartconfig/src/protocols/esptouch_v2.dart';
import 'package:logging/logging.dart';

/// Provisioner
class Provisioner {
  static final _logger = Logger("Provisioner");

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

    final worker = _EspWorker(request: request, protocol: _protocol);

    rPort.listen((event) {
      if (event is! _EspWorkerEvent) {
        _logger.warning("Event received from Isolate has incorrect type");
      } else if (event is _EspWorkerInitEvent) {
        event.sendPort.send(worker);
      } else if (event is _EspWorkerProvisioningStartEvent) {
        _logger.fine("${worker.protocol} povisioning");
        _logger.finer("---------- Request ----------");
        _logger.finer("ssid ${request.ssid}");
        _logger.finer("bssid ${request.bssid}");
        _logger.finer("pwd ${request.password}");
        _logger.finer("rData ${request.reservedData}");
        _logger.finer("encriptionKey ${request.encryptionKey}");
        _logger.finer("-----------------------------");
      } else if (event is _EspWorkerProvisioningStartedEvent) {
        _logger.fine("Provisioning started");
        _logger.finest("Blocks ${worker.protocol.blocks}");
        completer.complete();
      } else if (event is _EspWorkerResponseEvent) {
        _logger.fine("Received response (${event.response}");
        if (!_streamCtrl.isClosed) {
          _streamCtrl.sink.add(event.response);
        }
      } else if (event is _EspWorkerErrorEvent) {
        _logger.severe(event.message, event.error, event.stackTrace);

        final err = event.error ?? event.message ?? "ProvisioningError";

        if (!completer.isCompleted) {
          // failed to start provisioner
          completer.completeError(err, event.stackTrace);
        } else {
          _streamCtrl.sink.addError(err, event.stackTrace);

          // stop provisioning on any runtime error
          stop();
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

    sPort.send(_EspWorkerInitEvent(rPort.sendPort));
  }

  static void _startProvisioning(_EspWorker worker, SendPort sPort) async {
    sPort.send(_EspWorkerProvisioningStartEvent());

    final request = worker.request;
    final protocol = worker.protocol;

    int p = 0;
    RawDatagramSocket? socket;

    final ports = protocol.ports;
    for (; p < ports.length; p++) {
      try {
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
              sPort.send(_EspWorkerResponseEvent(response));
            } catch (err, st) {
              sPort.send(_EspWorkerErrorEvent("Invalid response", err, st));
            }
          },
          onError: (err, st) {
            sPort.send(_EspWorkerErrorEvent("Socket error", err, st));
          },
          cancelOnError: true,
        );

        break;
      } catch (err, st) {
        sPort.send(_EspWorkerErrorEvent("UDP port bind failed", err, st));
      }
    }

    if (socket == null) {
      sPort.send(_EspWorkerErrorEvent("Create UDP socket failed"));
      return;
    }

    // Install and prepare protocol
    protocol
      ..install(socket, p, request)
      ..prepare();

    // Protocol loop function execution in short time intervals
    final tmrDuration = Duration(milliseconds: 5);
    Timer.periodic(
        tmrDuration, (t) => protocol.loop(tmrDuration.inMilliseconds, t));

    sPort.send(_EspWorkerProvisioningStartedEvent());
  }

  /// Stop provisioning that is previously started with [start] method
  void stop() {
    if (!_streamCtrl.isClosed) {
      _streamCtrl.close();
    }

    if (running) {
      _logger.finer("Destroying isolate");
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
    }

    _logger.fine("Provisioning stopped");
  }
}

class _EspWorker {
  final ProvisioningRequest request;
  final Protocol protocol;

  const _EspWorker({
    required this.request,
    required this.protocol,
  });
}

abstract class _EspWorkerEvent {}

class _EspWorkerInitEvent extends _EspWorkerEvent {
  final SendPort sendPort;

  _EspWorkerInitEvent(this.sendPort);
}

class _EspWorkerProvisioningStartEvent extends _EspWorkerEvent {}

class _EspWorkerProvisioningStartedEvent extends _EspWorkerEvent {}

class _EspWorkerResponseEvent extends _EspWorkerEvent {
  final ProvisioningResponse response;

  _EspWorkerResponseEvent(this.response);
}

class _EspWorkerErrorEvent extends _EspWorkerEvent {
  final Object? message;
  final Object? error;
  final StackTrace? stackTrace;

  _EspWorkerErrorEvent(this.message, [this.error, this.stackTrace]);
}
