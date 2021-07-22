import 'package:esp_smartconfig/src/protocol.dart';

/// Bottlenecker
class Bottleneck {
  /// Tightness in milliseconds
  late int _tightness;
  int _timeOfPreviousPass = 0;

  /// Constructor of [Bottleneck] with desired [tightness] in milliseconds
  Bottleneck(int tightness) {
    _tightness = tightness;
  }

  /// Pass the function through the bottleneck
  void flow(Function fn) {
    final ms = Protocol.ms();

    if (_tightness > ms - _timeOfPreviousPass) {
      return;
    }

    fn();
    _timeOfPreviousPass = ms;
  }
}
