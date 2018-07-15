// Generated from Calculator.g4 by antlr4dart

part of calculator;

class CalculatorLexer extends Lexer {
  static const int T__0 = 1;

  static const String _serializedAtn = "\x03\u608b\ua72a\u8133\ub9ed\u417c"
      "\u3be7\u7786\u5964\x02\x03\x07\x08\x01\x04\x02\x09\x02\x03\x02\x03\x02"
      "\x02\x02\x03\x03\x03\x03\x02\x02\x02\x06\x02\x03\x03\x02\x02\x02\x03"
      "\x05\x03\x02\x02\x02\x05\x06\x07\x63\x02\x02\x06\x04\x03\x02\x02\x02"
      "\x03\x02\x02";

  final Atn atn = AtnSimulator.deserialize(_serializedAtn);

  final sharedContextCache = new PredictionContextCache();

  final List<String> modeNames = ["DEFAULT_MODE"];

  final List<String> tokenNames = ["'\\u0000'", "'\\u0001'"];

  final List<String> ruleNames = ["T__0"];

  CalculatorLexer(ANTLRInputStream input) : super(input) {
    var _decisionToDfa = new List<Dfa>(atn.numberOfDecisions);
    for (int i = 0; i < atn.numberOfDecisions; i++) {
      _decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter =
        new LexerAtnSimulator(atn, _decisionToDfa, sharedContextCache, this);
  }

  String get serializedAtn => _serializedAtn;

  String get grammarFileName => "Calculator.g4";
}
