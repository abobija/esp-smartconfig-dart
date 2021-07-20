import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';

/// Esp Advanced Encryption Standard
abstract class Aes {
  static final _iv = Uint8List(16);

  /// Encrypt data with the key
  static Int8List encrypt(Int8List data, Int8List key) {
    final cipher =
        PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESFastEngine()))
          ..init(
              true,
              PaddedBlockCipherParameters(
                  ParametersWithIV(KeyParameter(Uint8List.fromList(key)), _iv),
                  null));

    return Int8List.fromList(cipher.process(Uint8List.fromList(data)));
  }
}
