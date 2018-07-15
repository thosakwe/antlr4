// Generated from Calculator.g4 by antlr4dart

part of calculator;

class CalculatorParser extends Parser {
  static const int EOF = Token.EOF;

  static const int RULE_EXPR = 0;

  static const int T__0 = 1;

  static const String _serializedAtn = "\x03\u608b\ua72a\u8133\ub9ed\u417c"
      "\u3be7\u7786\u5964\x03\x03\x07\x04\x02\x09\x02\x03\x02\x03\x02\x03\x02"
      "\x02\x02\x03\x02\x02\x02\x02\x05\x02\x04\x03\x02\x02\x02\x04\x05\x07"
      "\x03\x02\x02\x05\x03\x03\x02\x02\x02\x02";

  final Atn atn = AtnSimulator.deserialize(_serializedAtn);

  final PredictionContextCache sharedContextCache =
      new PredictionContextCache();

  final List<String> tokenNames = ["<INVALID>", "'a'"];

  final List<String> ruleNames = ["expr"];
  CalculatorParser(TokenStream input) : super(input) {
    var _decisionToDfa = new List<Dfa>(atn.numberOfDecisions);
    for (int i = 0; i < atn.numberOfDecisions; i++) {
      _decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter =
        new ParserAtnSimulator(this, atn, _decisionToDfa, sharedContextCache);
  }

  String get serializedAtn => _serializedAtn;

  String get grammarFileName => "Calculator.g4";
  ExprContext expr() {
    var localContext = new ExprContext(context, state);
    enterRule(localContext, 0, RULE_EXPR);
    try {
      enterOuterAlt(localContext, 1);
      state = 2;
      match(T__0);
    } on RecognitionException catch (re) {
      localContext.exception = re;
      errorHandler.reportError(this, re);
      errorHandler.recover(this, re);
    } finally {
      exitRule();
    }
    return localContext;
  }
}

class ExprContext extends ParserRuleContext {
  ExprContext(ParserRuleContext parent, int invokingState)
      : super(parent, invokingState);

  int get ruleIndex => CalculatorParser.RULE_EXPR;

  void enterRule(ParseTreeListener listener) {
    if (listener is CalculatorListener) listener.enterExpr(this);
  }

  void exitRule(ParseTreeListener listener) {
    if (listener is CalculatorListener) listener.exitExpr(this);
  }

  T accept<T>(ParseTreeVisitor<T> visitor) {
    if (visitor is CalculatorVisitor<T>)
      return visitor.visitExpr(this);
    else
      return visitor.visitChildren(this);
  }
}
