import 'dart:io';

import 'printer.dart';
import 'reader.dart' as reader;
import 'types.dart';

enum ArgsMode { exact, at_least, at_most }

MalException malArgcException(
  String func_name,
  int expeted_argc,
  List<MalType> args, {
  ArgsMode mode = ArgsMode.exact,
}) {
  return MalException(
    MalString(
      "$func_name expects ${mode.name} $expeted_argc integers, got ${args.length} args: $args",
    ),
  );
}

MalException malArgvException(String err_msg) {
  return MalException(MalString(err_msg));
}

Map<String, MalBuiltin> ns = <String, MalBuiltin>{
  '+': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalInt(a + b);
    }
    throw malArgcException('+', 2, args);
  }),
  '-': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalInt(a - b);
    }
    throw malArgcException('-', 2, args);
  }),
  '*': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalInt(a * b);
    }
    throw malArgcException('*', 2, args);
  }),
  '/': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalInt(a ~/ b);
    }
    throw malArgcException('/', 2, args);
  }),
  'list': MalBuiltin((List<MalType> args) => MalList(args.toList())),
  'list?': MalBuiltin((List<MalType> args) => MalBool(args.single is MalList)),
  'empty?': MalBuiltin((List<MalType> args) {
    if (args case [MalIterable a]) {
      return MalBool(a.elements.isEmpty);
    }
    throw malArgcException('empty?', 1, args);
  }),
  'count': MalBuiltin((List<MalType> args) {
    if (args case [MalIterable a]) {
      return MalInt(a.elements.length);
    }
    throw malArgcException('count', 1, args);
  }),
  '=': MalBuiltin((List<MalType> args) {
    if (args case [final a, final b]) {
      return MalBool(a == b);
    }
    throw malArgcException('=', 2, args);
  }),
  '<': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalBool(a < b);
    }
    throw malArgcException('<', 2, args);
  }),
  '<=': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalBool(a <= b);
    }
    throw malArgcException('<=', 2, args);
  }),
  '>': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalBool(a > b);
    }
    throw malArgcException('>', 2, args);
  }),
  '>=': MalBuiltin((List<MalType> args) {
    if (args case [MalInt(value: int a), MalInt(value: int b)]) {
      return MalBool(a >= b);
    }
    throw malArgcException('>=', 2, args);
  }),
  'pr-str': MalBuiltin((List<MalType> args) {
    return MalString(
      args.map((a) => pr_str(a, print_readably: true)).join(' '),
    );
  }),
  'str': MalBuiltin((List<MalType> args) {
    return MalString(args.map((a) => pr_str(a, print_readably: false)).join());
  }),
  'prn': MalBuiltin((List<MalType> args) {
    print(args.map((a) => pr_str(a, print_readably: true)).join(' '));
    return MalNil();
  }),
  'println': MalBuiltin((List<MalType> args) {
    print(args.map((a) => pr_str(a, print_readably: false)).join(' '));
    return MalNil();
  }),
  'read-string': MalBuiltin((List<MalType> args) {
    if (args case [MalString code]) {
      return reader.read_str(code.value);
    }
    throw malArgcException('read-string', 1, args);
  }),
  'slurp': MalBuiltin((List<MalType> args) {
    if (args case [MalString fileName]) {
      final file = File(fileName.value);
      return MalString(file.readAsStringSync());
    }
    throw malArgcException('slurp', 1, args);
  }),
  'atom': MalBuiltin((List<MalType> args) {
    if (args case [final value]) {
      return MalAtom(value);
    }
    throw malArgcException('atom', 1, args);
  }),
  'atom?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalAtom _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('atom?', 1, args),
    };
  }),
  'deref': MalBuiltin((List<MalType> args) {
    if (args case [MalAtom(:final value)]) {
      return value;
    }
    throw malArgcException('deref', 1, args);
  }),
  'reset!': MalBuiltin((List<MalType> args) {
    if (args case [MalAtom atom, final newValue]) {
      atom.value = newValue;
      return newValue;
    }
    throw malArgcException('reset!', 2, args);
  }),
  'swap!': MalBuiltin((List<MalType> args) {
    if (args case [MalAtom atom, MalCallable func, ...final fnArgs]) {
      final result = func.call([atom.value, ...fnArgs]);
      atom.value = result;
      return result;
    }
    throw malArgcException('swap!', 3, args, mode: .at_least);
  }),
  'cons': MalBuiltin((List<MalType> args) {
    if (args case [final x, MalIterable xs]) {
      return MalList([x]..addAll(xs));
    }
    throw malArgcException('cons', 2, args);
  }),
  'concat': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [] => MalList([]),
      final List<MalType> lst when lst.every((x) => x is MalIterable) =>
        MalList(lst.cast<MalIterable>().expand((e) => e).toList()),
      _ => throw malArgvException("concat needs all args iterable"),
    };
  }),
  'vec': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalVector vector] => vector,
      [MalList list] => MalVector(list.elements),
      _ => throw MalException(MalString("vec: wrong arguments")),
    };
  }),
  'nth': MalBuiltin((List<MalType> args) {
    if (args case [MalIterable indexable, MalInt(value: final i)]) {
      if (0 <= i && i < indexable.length) {
        return indexable[i];
      }
      throw malArgvException("out of range");
    }
    throw malArgcException('nth', 2, args);
  }),
  'first': MalBuiltin((List<MalType> args) {
    if (args case [MalIterable list]) {
      return list.isEmpty ? MalNil() : list.first;
    }
    throw malArgcException('first', 1, args);
  }),
  'rest': MalBuiltin((List<MalType> args) {
    if (args case [MalIterable list]) {
      return MalList(list.isEmpty ? [] : list.sublist(1));
    }
    throw malArgcException('rest', 1, args);
  }),
  'throw': MalBuiltin((List<MalType> args) {
    throw MalException(args.first);
  }),
  'nil?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalNil _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('nil?', 1, args),
    };
  }),
  'true?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalBool(:final value)] => MalBool(value),
      [_] => MalBool(false),
      _ => throw malArgcException('true?', 1, args),
    };
  }),
  'false?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalBool(:final value)] => MalBool(!value),
      [_] => MalBool(false),
      _ => throw malArgcException('false?', 1, args),
    };
  }),
  'symbol': MalBuiltin((List<MalType> args) {
    if (args case [MalString(:final value)]) {
      return MalSymbol(value);
    }
    throw malArgcException('symbol', 1, args);
  }),
  'symbol?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalSymbol _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('symbol?', 1, args),
    };
  }),
  'keyword': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalKeyword first] => first,
      [MalString(:final value)] => MalKeyword(value),
      _ => throw malArgcException('keyword', 1, args),
    };
  }),
  'keyword?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalKeyword _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('keyword?', 1, args),
    };
  }),
  'number?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalInt _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('number?', 1, args),
    };
  }),
  'fn?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalCallable(:final isMacro)] when !isMacro => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('fn?', 1, args),
    };
  }),
  'macro?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalCallable(:final isMacro)] when isMacro => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('macro?', 1, args),
    };
  }),
  'vector': MalBuiltin((List<MalType> args) {
    return MalVector(args);
  }),
  'vector?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalVector _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('vector?', 1, args),
    };
  }),
  'hash-map': MalBuiltin((List<MalType> args) {
    return MalHashMap.fromSequence(args);
  }),
  'map?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalHashMap _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('map?', 1, args),
    };
  }),
  'assoc': MalBuiltin((List<MalType> args) {
    if (args case [MalHashMap map, ...final rest]) {
      var assoc = MalHashMap.fromSequence(rest);
      var newMap = Map<MalType, MalType>.from(map.value);
      newMap.addAll(assoc.value);
      return MalHashMap(newMap);
    }
    throw malArgcException('assoc', 3, args, mode: .at_least);
  }),
  'dissoc': MalBuiltin((List<MalType> args) {
    if (args case [MalHashMap map, ...final rest]) {
      var newMap = Map<MalType, MalType>.from(map.value);
      for (var key in rest) {
        newMap.remove(key);
      }
      return MalHashMap(newMap);
    }
    throw malArgcException('dissoc', 2, args, mode: .at_least);
  }),
  'get': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalHashMap map, final key] => map.value[key] ?? MalNil(),
      [MalNil _, final _] => MalNil(),
      _ => throw malArgcException('get', 2, args),
    };
  }),
  'contains?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalHashMap map, final key] => MalBool(map.value.containsKey(key)),
      _ => throw malArgcException('contains?', 2, args),
    };
  }),
  'keys': MalBuiltin((List<MalType> args) {
    return MalList((args.first as MalHashMap).value.keys.toList());
  }),
  'vals': MalBuiltin((List<MalType> args) {
    return MalList((args.first as MalHashMap).value.values.toList());
  }),
  'sequential?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalVector _ || MalList _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('sequential?', 1, args),
    };
  }),
  'readline': MalBuiltin((List<MalType> args) {
    if (args case [MalString(value: final message)]) {
      stdout.write(message);
      final input = stdin.readLineSync();
      if (input == null) return MalNil();
      return MalString(input);
    }
    throw malArgcException('readline', 1, args);
  }),
  'time-ms': MalBuiltin((List<MalType> args) {
    assert(args.isEmpty);
    return MalInt(DateTime.now().millisecondsSinceEpoch);
  }),
  'conj': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalList collection, ...final elements] => MalList(
        elements.reversed.toList()..addAll(collection.elements),
      ),
      [MalVector collection, ...final elements] => MalVector(
        collection.elements.toList()..addAll(elements),
      ),
      _ => throw throw MalException(MalString('"conj" takes a list or vector')),
    };
  }),
  'string?': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalString _] => MalBool(true),
      [_] => MalBool(false),
      _ => throw malArgcException('vector?', 1, args),
    };
  }),
  'seq': MalBuiltin((List<MalType> args) {
    return switch (args) {
      [MalIterable it] when it.isEmpty => MalNil(),
      [MalString(value: final s)] when s.isEmpty => MalNil(),
      [MalNil nil] => nil,
      [MalList lst] => lst,
      [MalVector(:final elements)] => MalList(elements),
      [MalString(value: final s)] when !s.isEmpty => MalList(
        s.split("").map((s) => MalString(s)).toList(),
      ),
      _ => throw MalException(MalString('bad argument to "seq"')),
    };
  }),
  'map': MalBuiltin((List<MalType> args) {
    if (args case [MalCallable fn, MalIterable list]) {
      return MalList(list.map((e) => fn.call([e])).toList());
    }
    throw malArgcException('map', 2, args);
  }),
  'apply': MalBuiltin((List<MalType> args) {
    if (args case [MalCallable func, ...var newArgs, MalIterable argList]) {
      newArgs.addAll(argList);
      return func.call(newArgs);
    }
    throw malArgcException('apply', 2, args);
  }),
  'meta': MalBuiltin((List<MalType> args) {
    if (args case [final arg]) {
      return arg.meta ?? MalNil();
    }
    throw malArgcException('meta', 1, args);
  }),
  'with-meta': MalBuiltin((List<MalType> args) {
    if (args case [final evaled, final meta]) {
      var evaledWithMeta = evaled.clone();
      evaledWithMeta.meta = meta;
      return evaledWithMeta;
    }
    throw malArgcException('with-meta', 2, args);
  }),
};
