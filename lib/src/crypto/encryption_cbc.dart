import 'dart:typed_data';

import 'package:hive/src/crypto/aes.dart';
import 'package:hive/src/crypto/cipher.dart';

class EncryptionCBC implements Cipher {
  Uint8List _cbcV;

  @override
  void init(Uint8List iv) {
    _cbcV = Uint8List.fromList(iv);
  }

  @override
  void processBlock(List<List<int>> workingKey, Uint8List inp, int inpOff,
      Uint8List out, int outOff) {
    // XOR the cbcV and the input, then encrypt the cbcV
    for (var i = 0; i < blockSize; i++) {
      _cbcV[i] ^= inp[inpOff + i];
    }

    AESEngine.encryptBlock(workingKey, _cbcV, 0, out, outOff);

    // copy ciphertext to cbcV
    _cbcV.setRange(0, blockSize, out, outOff);
  }
}