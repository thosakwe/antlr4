import 'package:antlr/antlr.dart';
import 'package:test/test.dart';

void main() {
  test('deserialize from string', () {
    // This is an ATN string from a simple grammar compiled to Java.
    new AtnDeserializer().deserialize(
        "\x03\u608b\ua72a\u8133\ub9ed\u417c\u3be7\u7786\u5964\x02\x03\t\b\x01\x04\x02\t\x02\x03" +
            "\x02\x03\x02\x03\x02\x03\x02\x02\x02\x03\x03\x03\x03\x02\x02\x02\b\x02\x03\x03\x02\x02\x02\x03\x05\x03\x02\x02\x02\x05\6\7c\x02\x02" +
            "\x06\x07\x07d\x02\x02\x07\b\x07e\x02\x02\b\x04\x03\x02\x02\x02\x03\x02\x02");
  });

  test('deserialize from bytes', () {
    // This is the same ATN, compiled to C++
    new AtnDeserializer().deserializeBytes([
      0x3,
      0x608b,
      0xa72a,
      0x8133,
      0xb9ed,
      0x417c,
      0x3be7,
      0x7786,
      0x5964,
      0x2,
      0x3,
      0x9,
      0x8,
      0x1,
      0x4,
      0x2,
      0x9,
      0x2,
      0x3,
      0x2,
      0x3,
      0x2,
      0x3,
      0x2,
      0x3,
      0x2,
      0x2,
      0x2,
      0x3,
      0x3,
      0x3,
      0x3,
      0x2,
      0x2,
      0x2,
      0x8,
      0x2,
      0x3,
      0x3,
      0x2,
      0x2,
      0x2,
      0x3,
      0x5,
      0x3,
      0x2,
      0x2,
      0x2,
      0x5,
      0x6,
      0x7,
      0x63,
      0x2,
      0x2,
      0x6,
      0x7,
      0x7,
      0x64,
      0x2,
      0x2,
      0x7,
      0x8,
      0x7,
      0x65,
      0x2,
      0x2,
      0x8,
      0x4,
      0x3,
      0x2,
      0x2,
      0x2,
      0x3,
      0x2,
      0x2
    ]);
  });
}
