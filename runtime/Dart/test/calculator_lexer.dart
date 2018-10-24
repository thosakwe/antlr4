// Generated from Calculator.g4 by antlr4dart


part of calculator;


class CalculatorLexer extends Lexer {

  static const int T__0 = 1;
  static const List<int> _serializedAtnBytes = const <int>[
  		0x3, 0x608b, 0xa72a, 0x8133, 0xb9ed, 0x417c, 0x3be7, 0x7786, 0x5964, 
  		   0x2, 0x3, 0x7, 0x8, 0x1, 0x4, 0x2, 0x9, 0x2, 0x3, 0x2, 0x3, 0x2, 
  		   0x2, 0x2, 0x3, 0x3, 0x3, 0x3, 0x2, 0x2, 0x2, 0x6, 0x2, 0x3, 0x3, 
  		   0x2, 0x2, 0x2, 0x3, 0x5, 0x3, 0x2, 0x2, 0x2, 0x5, 0x6, 0x7, 0x63, 
  		   0x2, 0x2, 0x6, 0x4, 0x3, 0x2, 0x2, 0x2, 0x3, 0x2, 0x2, 
  ];

  final Atn atn = AtnSimulator.deserializeBytes(_serializedAtnBytes);
  final sharedContextCache = new PredictionContextCache();

  final List<String> modeNames = [
    "DEFAULT_MODE"
  ];

  final List<String> tokenNames = [
    "'\\u0000'", "'\\u0001'"
  ];

  final List<String> ruleNames = [
    "T__0"
  ];
  	
  CalculatorLexer(ANTLRInputStream input) : super(input) {
    var _decisionToDfa = new List<Dfa>(atn.numberOfDecisions);
    for (int i = 0; i < atn.numberOfDecisions; i++) {
      _decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter = new LexerAtnSimulator(atn, _decisionToDfa, sharedContextCache, this);
  }

  String get serializedAtn => new String.fromCharCodes(_serializedAtnBytes);

  String get grammarFileName => "Calculator.g4";
}