import 'dart:typed_data';

/// Esp CRC
abstract class EspCrc {
  static final _table = Int16List.fromList(List.generate(256, (index) {
    int remainder = index;

    for (int bit = 0; bit < 8; bit++) {
      if ((remainder & 0x01) != 0) {
        remainder = (remainder >> 1) ^ 0x8c;
      } else {
        remainder >>= 1;
      }
    }

    return remainder;
  }));

  /// Caclulate CRC out of raw [data] bytes
  static int calculate(Int8List data) {
    int value = 0x00;

    data.forEach((e) {
      value = _table[(e ^ value) & 0xff] ^ (value << 8);
    });

    return value & 0xff;
  }
}
