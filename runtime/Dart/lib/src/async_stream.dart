/*
import 'dart:collection';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'util/interval.dart';
import 'input_stream.dart';
import 'token.dart';

class ANTLRAsyncStream implements ANTLRInputStream {
  int _index = -1, _lastChar;
  Queue<_Marker> _markers = new Queue<_Marker>();
  Uint8ClampedList _buf;
  StreamQueue<int> _queue;

  final Stream<List<int>> stream;

  @override
  final int length;

  @override
  final String sourceName;

  @override
  int get index => index;

  ANTLRAsyncStream(this.stream,
      {@required this.length, @required this.sourceName}) {
    _queue = new StreamQueue<int>(stream.expand((x) => x));
  }

  @override
  Future close() {
    return _queue.cancel();
  }

  @override
  Future consume() async {
    _index++;

    if (_markers.isNotEmpty && _buf != null) {
      var m = _markers.first;

      if (_index >= m.startIndex && _index < (m.startIndex + _buf.length)) {
        return new Future.value();
      }
    }

    if (!await _queue.hasNext)
      return Token.EOF;

    var ch = _lastChar = await _queue.next;

    if (_markers.isNotEmpty) {
      if (_buf == null) {
        _buf = new Uint8ClampedList(1);
        _buf[0] = ch;
      } else {
        var len = _buf.length;
        var b = new Uint8ClampedList(len + 1);

        for (int i = 0; i < len; i++) b[i] = _buf[i];

        _buf = b..[len] = ch;
      }
    }
  }

  @override
  int lookAhead(int i) async {
    if (_markers.isNotEmpty && _buf != null) {
      var m = _markers.first;
      var idx = _index + i - 1;
      var endOfBuffer = m.startIndex + _buf.length - 1;

      /*
      print('First marker: ${m.startIndex}');
      print('Buffer length: ${_buf.length}');
      print('End of buffer: $endOfBuffer');
      print('Buffer: [' + new String.fromCharCodes(_buf) + ']');
      print('Current index: $_index');
      print('Looking ahead by: $i');
      print('Computed index: $idx');
      */

      if (idx >= m.startIndex && i <= endOfBuffer) {
        var effective = idx - _buf.length + 1;
        //print('Index within buffer: $effective');
        //print('Within buffer: ' + new String.fromCharCode(_buf[effective]));
        return _buf[effective];
      }

      var remaining = idx - (m.startIndex - _buf.length);
      var cur = _index;

      for (int j = 0; j < remaining; j++) {
        //print('Consuming $j');
        await consume();
      }

      _index = cur;
      return _buf[i];
    }

    if (i > 1)
      throw new StateError(
          'To peek ahead more than 1 character from an ANTLRAsyncStream, use ANTLRAsyncStream.mark.');

    if (!await _queue.hasNext)
      return Token.EOF;

    return await _queue.peek;
  }

  @override
  Future seek(int index) async {
    if (_markers.isNotEmpty) {
      var m = _markers.first;

      if (index < m.startIndex)
        throw new StateError(
            'Cannot seek to index $index, as it is not in the buffer.');

      if (index <= _index) {
        _index = index;
        return null;
      }

      var diff = index - _index;

      for (int i = 0; i < diff; i++)
        await consume();
    }

    if (_index > index)
      throw new StateError(
          'Cannot seek to index $index, as there is no buffer, and the current index is $_index.');
    else if (_index == index) return null;
    return await _queue.skip(index - _index);
  }

  @override
  int get mark {
    var marker = new _Marker(_index);
    _markers.addLast(marker);

    if (_lastChar != null) {
      _buf = new Uint8ClampedList(1);
      _buf[0] = _lastChar;
    }

    return _markers.length - 1;
  }

  @override
  Future release(int marker) {
    var m = _markers.removeLast();

    if (_markers.isEmpty) {
      _buf = null;
      _index = m.startIndex;
    }

    return new Future.value();
  }

  @override
  String getText(Interval interval) async {
    var marker = await mark;
    var buf = new StringBuffer();
    await seek(interval.a);

    for (int i = 0; i < interval.length; i++) {
      buf.writeCharCode(await lookAhead(0));
      await consume();
    }

    await release(marker);
    return buf.toString();
  }
}

class _Marker {
  final int startIndex;

  _Marker(this.startIndex);
}
*/