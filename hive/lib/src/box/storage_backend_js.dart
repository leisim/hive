import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/box/box_options.dart';
import 'package:hive/src/box/box_impl.dart';
import 'package:hive/src/box/storage_backend.dart';
import 'package:hive/src/crypto_helper.dart';
import 'package:hive/src/frame.dart';
import 'package:meta/meta.dart';

Future<BoxImpl> openBox(
    HiveInterface hive, String name, BoxOptions options) async {
  var db = await window.indexedDB.open(name, version: 1, onUpgradeNeeded: (e) {
    Database db = e.target.result;
    if (!db.objectStoreNames.contains('box')) {
      db.createObjectStore('box');
    }
  });

  CryptoHelper crypto;
  if (options.encrypted) {
    crypto = CryptoHelper(Uint8List.fromList(options.encryptionKey));
  }

  var backend = StorageBackendJs(db, crypto);
  var box = BoxImpl(hive, name, options, backend);
  backend._registry = box;

  await box.initialize();

  return box;
}

class StorageBackendJs extends StorageBackend {
  final Database _db;
  final CryptoHelper _crypto;

  TypeRegistry _registry;

  StorageBackendJs(this._db, this._crypto);

  String get path => null;

  @visibleForTesting
  dynamic encodeValue(dynamic value) {
    var noEncodingNeeded = _crypto == null &&
        (value is num ||
            value is bool ||
            value is String ||
            value is List<num> ||
            value is List<bool> ||
            value is List<String>);

    if (noEncodingNeeded) {
      return value;
    } else {
      var writer = BinaryWriterImpl(_registry);
      Frame(null, value).encodeBody(writer, false, _crypto.encryptor);
      return writer.output().buffer;
    }
  }

  @visibleForTesting
  dynamic decodeValue(dynamic value) {
    if (value is ByteBuffer) {
      var reader = BinaryReaderImpl(Uint8List.view(value), _registry);
      return Frame.decodeBody(reader, false, true, _crypto.decryptor).value;
    } else {
      return value;
    }
  }

  ObjectStore getStore(bool write, [String box = 'box']) {
    return _db
        .transaction(box, write ? 'readwrite' : 'readonly')
        .objectStore(box);
  }

  Future<List<String>> getKeys() {
    var completer = Completer<List<String>>();
    var request = getStore(false).getAllKeys(null);
    request.onSuccess.listen((_) {
      var keys = request.result.cast<String>();
      completer.complete(keys);
    });
    request.onError.listen((_) {
      completer.completeError(request.error);
    });
    return completer.future;
  }

  Future<List<dynamic>> getValues() {
    var completer = Completer<List<dynamic>>();
    var request = getStore(false).getAll(null);
    request.onSuccess.listen((_) {
      List values = request.result.map(decodeValue).toList();
      completer.complete(values);
    });
    request.onError.listen((_) {
      completer.completeError(request.error);
    });
    return completer.future;
  }

  @override
  Future<int> initialize(Map<String, BoxEntry> entries, bool cache) async {
    var keys = await getKeys();
    if (cache) {
      var values = await getValues();
      for (var i = 0; i < keys.length; i++) {
        entries[keys[i]] = BoxEntry(values[i], null, null);
      }
    } else {
      for (var i = 0; i < keys.length; i++) {
        entries[keys[i]] = BoxEntry(null, null, null);
      }
    }

    return 0;
  }

  @override
  Future<dynamic> readValue(String key, int offset) async {
    var value = await getStore(false).getObject(key);
    return decodeValue(value);
  }

  @override
  Future<Map<String, dynamic>> readAll(Iterable<String> keys) async {
    return Map.fromIterables(keys, await getValues());
  }

  @override
  Future<BoxEntry> writeFrame(Frame frame, bool cache) async {
    if (frame.deleted) {
      await getStore(true).delete(frame.key);
    } else {
      await getStore(true).put(encodeValue(frame.value), frame.key);
    }
    return BoxEntry(cache ? frame.value : null, -1, -1);
  }

  @override
  Future<List<BoxEntry>> writeFrames(List<Frame> frames, bool cache) async {
    var store = getStore(true);
    var entries = List<BoxEntry>(frames.length);
    for (var frame in frames) {
      if (frame.deleted) {
        await store.delete(frame.key);
      } else {
        await store.put(encodeValue(frame.value), frame.key);
      }
      entries.add(BoxEntry(cache ? frame.value : null, -1, -1));
    }
    return entries;
  }

  @override
  Future<Map<String, BoxEntry>> compact(Map<String, BoxEntry> entries) {
    return Future.value(entries);
  }

  @override
  Future clear() {
    return getStore(true).clear();
  }

  @override
  Future close() {
    _db.close();
    return Future.value();
  }

  @override
  Future deleteFromDisk() {
    return window.indexedDB.deleteDatabase(_db.name);
  }
}
