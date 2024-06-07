part of hive;

const _builtinTypes = {
  bool: _TypeHandler<bool>.builtin(),
  num: _TypeHandler<num>.builtin(),
  String: _TypeHandler<String>.builtin(),
  List: _TypeHandler<List<dynamic>>.builtin(),
  Map: _TypeHandler<Map<String, dynamic>>.builtin(),
};

class _TypeRegistry {
  final Map<int, _TypeHandler<dynamic>> _registry = {};
  final Map<Type, _TypeHandler<dynamic>> _reverseRegistry = {..._builtinTypes};

  void register<T>(int typeId, T? Function(dynamic json) fromJson) {
    if (T == dynamic) {
      throw ArgumentError('Cannot register dynamic type.');
    }

    final handler = _TypeHandler<T>(typeId, fromJson);
    _registry[typeId] = handler;
    _reverseRegistry[T] = handler;
  }

  T fromJson<T>(int? typeId, dynamic json) {
    dynamic value = json;
    if (typeId != null) {
      final handler = _registry[typeId];
      if (handler == null) {
        throw StateError(
          'Type is not registered. Did you forget to register it?',
        );
      }
      if (json is Map<String, dynamic> || json is List) {
        value = handler.fromJson(json);
      } else {
        throw ArgumentError('Type mismatch. Expected Map<String,dynamic> '
            'but got ${json.runtimeType}.');
      }
    }

    if (value is T) {
      return value;
    } else {
      throw ArgumentError(
        'Type mismatch. Expected $T but got ${value.runtimeType}.',
      );
    }
  }

  int? findTypeId(dynamic value) {
    final handler = _reverseRegistry[value.runtimeType];
    if (handler != null) {
      return handler.typeId;
    }

    for (final MapEntry(key: type, value: handler)
        in _reverseRegistry.entries) {
      if (handler.handlesValue(value)) {
        _reverseRegistry[type] = handler;
        return handler.typeId;
      }
    }

    return null;
  }

  void reset() {
    _registry.clear();
    _reverseRegistry.clear();
    _reverseRegistry.addAll(_builtinTypes);
  }
}

T? _noop<T>(dynamic json) {
  throw UnimplementedError();
}

class _TypeHandler<T> {
  const _TypeHandler(this.typeId, this.fromJson);

  const _TypeHandler.builtin()
      : typeId = null,
        fromJson = _noop;

  final int? typeId;

  final T? Function(dynamic json) fromJson;

  bool handlesValue(dynamic value) {
    return value is T;
  }
}
