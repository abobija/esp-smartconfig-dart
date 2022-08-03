import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Esp Advanced Encryption Standard
abstract class Aes {
  static final _iv = Uint8List(16);

  /// Encrypt data with the key
  static Int8List encrypt(Int8List data, Int8List key) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
          ..init(
              true,
              PaddedBlockCipherParameters(
                  ParametersWithIV(KeyParameter(Uint8List.fromList(key)), _iv),
                  null));

    return Int8List.fromList(cipher.process(Uint8List.fromList(data)));
  }
}
