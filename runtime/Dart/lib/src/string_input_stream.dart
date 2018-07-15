
import 'dart:math';
import 'util/interval.dart';
import 'input_stream.dart';
import 'token.dart';

/// An implementation of [ANTLRInputStream] that reads from a byte array.
class ANTLRByteArrayStream implements ANTLRInputStream {
  // The data being scanned
  List<int> _data;

  // 0..n-1 index into string of next char
  int _index = 0;

  String _str;

  /// Line number `1..n` within the input.
  int line = 1;

  /// What is name or source?
  String sourceName;

  ANTLRByteArrayStream(this._data);

  factory ANTLRByteArrayStream.fromString(String input) =>
      new ANTLRByteArrayStream(input.codeUnits).._str = input;

  /// The current input symbol index `0..n` where n indicates the last symbol
  /// has been read.
  ///
  /// The index is the index of char to be returned from `lookAhead(1)`.
  int get index => _index;

  int get length => _data.length;

  /// mark/release do nothing; we have entire buffer.
  int get mark => -1;

  /// Reset the source so that it's in the same state it was when the object
  /// was created *except* the data list is not touched.
  void reset() {
    _index = 0;
  }

  Future consume() {
    if (_index >= _data.length) {
      assert(lookAhead(1) == Token.EOF);
      throw new StateError("cannot consume EOF");
    }
    _index++;
    return new Future.value();
  }

  int lookAhead(int i) {
    if (i == 0) return 0; // undefined
    if (i < 0) {
      // e.g., translate lookAhead(-1) to use offset i = 0; then data[p - 1]
      i++;
      // invalid; no char before first char
      if ((_index + i - 1) < 0) return Token.EOF;
    }
    if ((_index + i - 1) >= _data.length) return Token.EOF;
    return _data[_index + i - 1];
  }

  int lookToken(int i) => lookAhead(i);

  Future close() => new Future.value();

  Future release(int marker) => new Future.value();

  Future seek(int index) {
    if (index <= _index) {
      _index = index; // just jump; don't update source state (line, ...)
      return new Future.value();
    }
    // seek forward, consume until p hits index or n (whichever comes first)
    index = min(index, _data.length);
    while (_index < index) consume();
    return new Future.value();
  }

  @override
  String getText(Interval interval) {
    int start = interval.a;
    int stop = interval.b;
    if (stop >= _data.length) stop = _data.length - 1;
    int count = stop - start + 1;
    if (start >= _data.length) return "";
    return
        new String.fromCharCodes(_data.getRange(start, start + count));
  }

  String toString() => _str ??= new String.fromCharCodes(_data);
}
