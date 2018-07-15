import 'package:antlr/antlr.dart';
import 'package:charcode/ascii.dart';
import 'package:test/test.dart';

const String jfk =
    'Ask not what your country can do for you, but what you can do for your country.';

main() {
  ANTLRByteArrayStream byteArrayStream() =>
      new ANTLRByteArrayStream.fromString(jfk);

  testInputStream('ByteArray', byteArrayStream);
}

void testInputStream(String type, ANTLRInputStream Function() createStream) {
  group('ANTLR${type}Stream', () {
    ANTLRInputStream inputStream;

    setUp(() {
      inputStream = createStream();
    });

    test('lookahead(1)', () async {
      expect(await inputStream.lookAhead(1), $A);
    });

    group('marked', () {
      int marker;

      setUp(() async {
        // Read 'Ask ', stop at 'n'

        for (int i = 0; i < 4; i++) {
          await inputStream.consume();
        }

        marker = await inputStream.mark;
      });

      tearDown(() => inputStream.release(marker));

      test('seek within range', () async {
        await inputStream.seek(6);
        await inputStream.seek(4);
        print(new String.fromCharCode(await inputStream.lookAhead(1)));
        expect(await inputStream.lookAhead(1), $n);
      });

      test('seek out of range', () async {
        await inputStream.seek(6);
        print(new String.fromCharCode(await inputStream.lookAhead(1)));
        expect(await inputStream.lookAhead(1), $t);
      });
    });

//    if (createStream is _CreateAsyncStream) {
//      test('lookahead(5) without mark throws state error', () async {
//        expect(() => inputStream.lookAhead(4), throwsStateError);
//      });
//    } else {
//      test('lookahead(5)', () async {
//        expect(await inputStream.lookAhead(5), $n);
//      });
//    }
  });
}
