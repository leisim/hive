import 'dart:typed_data';

import 'package:hive/src/crypto/aes.dart';
import 'package:hive/src/crypto/cipher.dart';
import 'package:hive/src/util/uint8_list_extension.dart';

class DecryptionCBC implements Cipher {
  Uint8List _cbcV;
  Uint8List _cbcNextV;

  @override
  void init(Uint8List iv) {
    _cbcV = iv;
  }

  @override
  void processBlock(List<List<int>> workingKey, Uint8List inp, int inpOff,
      Uint8List out, int outOff) {
    _cbcNextV = inp.view(inpOff, AESEngine.blockSize);

    AESEngine.decryptBlock(workingKey, inp, inpOff, out, outOff);

    // XOR the cbcV and the output
    for (var i = 0; i < AESEngine.blockSize; i++) {
      out[outOff + i] ^= _cbcV[i];
    }

    // swap the back up buffer into next position
    var tmp = _cbcV;
    _cbcV = _cbcNextV;
    _cbcNextV = tmp;
  }
}