import 'package:antlr/antlr.dart';
import 'package:test/test.dart';
import 'calculator.dart';

main() {
  test('ctx', () async {
    var input = new ANTLRByteArrayStream.fromString('a');
    var lexer = new CalculatorLexer(input);
    var tokens = new CommonTokenStream(lexer);
    var parser = new CalculatorParser(tokens);
    var expr = parser.expr();
    print(await expr.getText());
    input.close();
  });
}
