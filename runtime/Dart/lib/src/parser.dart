
import 'dart:collection';
import 'package:bignum/bignum.dart';
import 'package:meta/meta.dart';
import 'atn/atn.dart';
import 'atn/atn_deserializer.dart';
import 'atn/atn_simulator.dart';
import 'atn/atn_states.dart';
import 'atn/transitions.dart';
import 'tree/parse_tree.dart';
import 'tree/parse_tree_walker.dart';
import 'util/interval_set.dart';
import 'contexts.dart';
import 'dfa.dart';
import 'error_strategy.dart';
import 'exceptions.dart';
import 'input_stream.dart';
import 'recognizer.dart';
import 'token.dart';
import 'token_stream.dart';

abstract class Parser extends Recognizer<Token, ParserAtnSimulator> {
  // To be used in shift left workaroud for dart2js
  final BIG_ONE = BigInt.ONE;
  final BIG_ZERO = BigInt.ZERO;

  // The input source.
  TokenStream _input;

  // When trace = true is called, a reference to the TraceListener is
  // stored here so it can be easily removed in a later call to
  // trace = false. The listener itself is implemented as a parser
  // listener so this field is not directly used by other parser methods.
  TraceListener _tracer;

  // The list of ParseTreeListener listeners registered to receive
  // events during the parse.
  List<ParseTreeListener> _parseListeners;

  // The number of syntax errors reported during parsing. This value is
  // incremented each time notifyErrorListeners is called.
  int _syntaxErrors;

  List<int> _precedenceStack;

  // This field maps from the serialized ATN string to the deserialized
  // ATN with bypass alternatives.
  static final _bypassAltsAtnCache = new HashMap<String, Atn>();

  /// The [ParserRuleContext] object for the currently executing rule.
  ///
  /// This is always non-null during the parsing process.
  ParserRuleContext context;

  /// The error handling strategy for the parser. The default value is a new
  /// instance of [DefaultErrorStrategy].
  ErrorStrategy errorHandler = new DefaultErrorStrategy();

  /// Specifies whether or not the parser should construct a parse tree during
  /// the parsing process. The default value is `true`.
  bool buildParseTree = true;

  Parser(TokenStream input) {
    _precedenceStack = new List<int>();
    _precedenceStack.add(0);
    inputStream = input;
  }

  String get sourceName => _input.sourceName;

  /// Return the precedence level for the top-most precedence rule, or `-1` if
  /// the parser context is not nested within a precedence rule.
  int get precedence => _precedenceStack.isEmpty ? -1 : _precedenceStack.last;

  /// During a parse is sometimes useful to listen in on the rule entry and exit
  /// events as well as token matches. This is for quick and dirty debugging.
  void set trace(bool trace) {
    if (!trace) {
      removeParseListener(_tracer);
      _tracer = null;
    } else {
      if (_tracer != null)
        removeParseListener(_tracer);
      else
        _tracer = new TraceListener(this);
      addParseListener(_tracer);
    }
  }

  /// Trim the internal lists of the parse tree during parsing to conserve
  /// memory.
  ///
  /// This property is set to `false` by default for a newly constructed parser.
  ///
  /// [trimParseTrees] is `true` to trim the capacity of the
  /// [ParserRuleContext.children] list to its size after a rule is parsed.
  void set trimParseTree(bool trimParseTrees) {
    if (trimParseTrees) {
      if (trimParseTree) return;
      addParseListener(TrimToSizeListener.INSTANCE);
    } else {
      removeParseListener(TrimToSizeListener.INSTANCE);
    }
  }

  /// Return `true` if the [ParserRuleContext.children] list is trimmed
  /// using the default [TrimToSizeListener] during the parse process.
  bool get trimParseTree {
    return parseListeners.contains(TrimToSizeListener.INSTANCE);
  }

  /// Gets the number of syntax errors reported during parsing. This value is
  /// incremented each time [notifyErrorListeners] is called.
  int get numberOfSyntaxErrors => _syntaxErrors;

  TokenFactory get tokenFactory {
    return _input.tokenProvider.tokenFactory;
  }

  /// Tell our token source and error strategy about a new way to create tokens.
  void set tokenFactory(@checked TokenFactory factory) {
    _input.tokenProvider.tokenFactory = factory;
  }

  TokenStream get inputStream => _input;

  /// Set the token source and reset the parser.
  void set inputStream(@checked ANTLRInputStream input) {
    _input = null;
    reset();
    _input = input;
  }

  /// Match needs to return the current input symbol, which gets put
  /// into the label for the associated token ref; e.g., x=ID.
  Token get currentToken => _input.lookToken(1);

  /// Computes the set of input symbols which could follow the current parser
  /// state and context, as given by [state] and [context], respectively.
  IntervalSet get expectedTokens => atn.getExpectedTokens(state, context);

  IntervalSet get expectedTokensWithinCurrentRule {
    Atn atn = interpreter.atn;
    AtnState s = atn.states[state];
    return atn.nextTokensInSameRule(s);
  }

  ParserRuleContext get ruleContext => context;

  /// Return List<String> of the rule names in your parser instance
  ///  leading up to a call to the current rule.  You could override if
  ///  you want more details such as the file/line info of where
  ///  in the ATN a rule is invoked.
  ///
  ///  This is very useful for error messages.
  List<String> get ruleInvocationStack => getRuleInvocationStack(context);

  /// Get a rule's index (i.e., `RULE_ruleName` field) or -1 if not found.
  int getRuleIndex(String ruleName) {
    int ruleIndex = ruleIndexMap[ruleName];
    return ruleIndex != null ? ruleIndex : -1;
  }

  /// Reset the parser's state.
  void reset() {
    if (inputStream != null) inputStream.seek(0);
    errorHandler.reset(this);
    context = null;
    _syntaxErrors = 0;
    trace = false;
    _precedenceStack.clear();
    _precedenceStack.add(0);
    if (interpreter != null) interpreter.reset();
  }

  /// Match current input symbol against [ttype]. If the symbol type matches,
  /// [ErrorStrategy.reportMatch] and [consume] are called to complete the
  /// match process.
  ///
  /// If the symbol type does not match, [ErrorStrategy.recoverInline] is
  /// called on the current error strategy to attempt recovery. If
  /// [buildParseTree] is `true` and the token index of the symbol returned by
  /// [ErrorStrategy.recoverInline] is `-1`, the symbol is added to
  /// the parse tree by calling [ParserRuleContext.addErrorNode].
  ///
  /// [ttype] is the token type to match.
  ///
  /// Return the matched symbol.
  ///
  /// A [RecognitionException] occurs when the current input symbol did not
  /// match [ttype] and the error strategy could not recover from the
  /// mismatched symbol.
  Token match(int ttype) {
    Token token =  currentToken;
    if (token.type == ttype) {
      errorHandler.reportMatch(this);
      consume();
    } else {
      token =  errorHandler.recoverInline(this);
      if (buildParseTree && token.tokenIndex == -1) {
        // we must have conjured up a new token during single token insertion
        // if it's not the current symbol
        context.addErrorNode(token);
      }
    }
    return token;
  }

  /// Match current input symbol as a wildcard. If the symbol type matches
  /// (i.e. has a value greater than 0), [ErrorStrategy.reportMatch]
  /// and [consume] are called to complete the match process.
  ///
  /// If the symbol type does not match, [ErrorStrategy.recoverInline] is
  /// called on the current error strategy to attempt recovery. If
  /// [buildParseTree] is `true` and the token index of the symbol returned by
  /// [ErrorStrategy.recoverInline] is `-1`, the symbol is added to
  /// the parse tree by calling [ParserRuleContext.addErrorNode].
  ///
  /// Return the matched symbol.
  ///
  /// A [RecognitionException] occurs when the current input symbol did not
  /// match a wildcard and the error strategy could not recover from the
  /// mismatched symbol.
  Token matchWildcard() {
    Token token =  currentToken;
    if (token.type > 0) {
      errorHandler.reportMatch(this);
      consume();
    } else {
      token =  errorHandler.recoverInline(this);
      if (buildParseTree && token.tokenIndex == -1) {
        // we must have conjured up a new token during single token insertion
        // if it's not the current symbol
        context.addErrorNode(token);
      }
    }
    return token;
  }

  bool precedencePredicate(@checked RuleContext localctx, int precedence) {
    return precedence >= _precedenceStack.last;
  }

  List<ParseTreeListener> get parseListeners {
    return _parseListeners == null ? <ParseTreeListener>[] : _parseListeners;
  }

  /// For debugging and other purposes.
  List<String> get dfaStrings {
    List<String> s = new List<String>();
    for (int d = 0; d < interpreter.decisionToDfa.length; d++) {
      Dfa dfa = interpreter.decisionToDfa[d];
      s.add(dfa.toString(tokenNames));
    }
    return s;
  }

  /// Registers [listener] to receive events during the parsing process.
  ///
  /// To support output-preserving grammar transformations (including but not
  /// limited to left-recursion removal, automated left-factoring, and
  /// optimized code generation), calls to listener methods during the parse
  /// may differ substantially from calls made by [ParseTreeWalker.DEFAULT]
  /// used after the parse is complete. In particular, rule entry and exit
  /// events may occur in a different order during the parse than after the
  /// parser. In addition, calls to certain rule entry methods may be omitted.
  ///
  /// [listener] is the listener to add.
  ///
  /// Throws [NullThrownError] if [listener] is `null`.
  void addParseListener(ParseTreeListener listener) {
    if (listener == null) throw new NullThrownError();
    if (_parseListeners == null) {
      _parseListeners = new List<ParseTreeListener>();
    }
    _parseListeners.add(listener);
  }

  /// Remove [listener] from the list of parse listeners.
  ///
  /// If [listener] is `null` or has not been added as a parse listener, this
  /// method does nothing.
  ///
  /// [listener] is the listener to remove.
  void removeParseListener(ParseTreeListener listener) {
    if (_parseListeners != null &&
        _parseListeners.remove(listener) &&
        _parseListeners.isEmpty) {
      _parseListeners = null;
    }
  }

  /// Remove all parse listeners.
  void removeParseListeners() {
    _parseListeners = null;
  }

  // Notify any parse listeners of an exit rule event.
  void triggerExitRuleEvent() {
    // reverse order walk of listeners
    if (_parseListeners != null) {
      for (int i = _parseListeners.length - 1; i >= 0; i--) {
        ParseTreeListener listener = _parseListeners[i];
        context.exitRule(listener);
        listener.exitEveryRule(context);
      }
    }
  }

  void notifyErrorListeners(String msg,
      [Token offendingToken, RecognitionException e]) {
    offendingToken = offendingToken ?? currentToken;
    _syntaxErrors++;
    int line = -1;
    int charPositionInLine = -1;
    line = offendingToken.line;
    charPositionInLine = offendingToken.charPositionInLine;
    errorListenerDispatch.syntaxError(
        this, offendingToken, line, charPositionInLine, msg, e);
  }

  /// Consume and return the [currentToken] current symbol.
  ///
  /// E.g., given the following input with `A` being the current
  /// lookahead symbol, this function moves the cursor to `B` and returns
  /// `A`.
  ///
  ///      A B
  ///      ^
  ///
  /// If the parser is not in error recovery mode, the consumed symbol is added
  /// to the parse tree using [ParserRuleContext.addChild], and
  /// [ParseTreeListener.visitTerminal] is called on any parse listeners.
  /// If the parser **is** in error recovery mode, the consumed symbol is
  /// added to the parse tree using [ParserRuleContext.addErrorNode],
  /// and [ParseTreeListener.visitErrorNode] is called on any parse listeners.
  Token consume() {
    Token token =  currentToken;
    if (token.type != Token.EOF)  inputStream.consume();
    bool hasListener = _parseListeners != null && !_parseListeners.isEmpty;
    if (buildParseTree || hasListener) {
      if (errorHandler.inErrorRecoveryMode(this)) {
        ErrorNode node = context.addErrorNode(token);
        if (_parseListeners != null) {
          for (ParseTreeListener listener in _parseListeners) {
            listener.visitErrorNode(node);
          }
        }
      } else {
        TerminalNode node = context.addChild(token);
        if (_parseListeners != null) {
          for (ParseTreeListener listener in _parseListeners) {
            listener.visitTerminal(node);
          }
        }
      }
    }
    return token;
  }

  void addContextToParseTree() {
    ParserRuleContext parent = context.parent;
    // add current context to parent if we have a parent
    if (parent != null) parent.addChild(context);
  }

  /// Always called by generated parsers upon entry to a rule. Access field
  /// [context] get the current context.
  Future enterRule(ParserRuleContext localctx, int state, int ruleIndex) {
    this.state = state;
    context = localctx;
    context.start =  _input.lookToken(1);
    if (buildParseTree) addContextToParseTree();
    if (_parseListeners != null) _triggerEnterRuleEvent();
  }

  Future exitRule() {
    context.stop =  _input.lookToken(-1);
    // trigger event on context, before it reverts to parent
    if (_parseListeners != null) triggerExitRuleEvent();
    state = context.invokingState;
    context = context.parent as ParserRuleContext;
  }

  void enterOuterAlt(ParserRuleContext localctx, int altNum) {
    // if we have new localctx, make sure we replace existing ctx
    // that is previous child of parse tree
    if (buildParseTree && context != localctx) {
      ParserRuleContext parent = context.parent;
      if (parent != null) {
        parent.removeLastChild();
        parent.addChild(localctx);
      }
    }
    context = localctx;
  }

  Future enterRecursionRule(ParserRuleContext localctx, int state,
      int ruleIndex, int precedence) {
    this.state = state;
    _precedenceStack.add(precedence);
    context = localctx;
    context.start =  _input.lookToken(1);
    // simulates rule entry for left-recursive rules
    if (_parseListeners != null) _triggerEnterRuleEvent();
  }

  /// Like [enterRule] but for recursive rules.
  Future pushNewRecursionContext(
      ParserRuleContext localctx, int state, int ruleIndex) {
    ParserRuleContext previous = context;
    previous.parent = localctx;
    previous.invokingState = state;
    previous.stop =  _input.lookToken(-1);
    context = localctx;
    context.start = previous.start;
    if (buildParseTree) context.addChild(previous);
    // simulates rule entry for left-recursive rules
    if (_parseListeners != null) _triggerEnterRuleEvent();
  }

  Future unrollRecursionContexts(ParserRuleContext parentctx) {
    _precedenceStack.removeLast();
    context.stop =  _input.lookToken(-1);
    ParserRuleContext retctx = context; // save current ctx (return value)
    // unroll so context is as it was before call to recursive method
    if (_parseListeners != null) {
      while (context != parentctx) {
        triggerExitRuleEvent();
        context = context.parent as ParserRuleContext;
      }
    } else {
      context = parentctx;
    }
    // hook into tree
    retctx.parent = parentctx;
    // add return ctx into invoking rule's tree
    if (buildParseTree && parentctx != null) parentctx.addChild(retctx);
  }

  ParserRuleContext getInvokingContext(int ruleIndex) {
    ParserRuleContext parent = context;
    while (parent != null) {
      if (parent.ruleIndex == ruleIndex) return parent;
      parent = parent.parent as ParserRuleContext;
    }
    return null;
  }

  /// Checks whether or not [symbol] can follow the current state in the ATN.
  ///
  /// The behavior of this method is equivalent to the following, but is
  /// implemented such that the complete context-sensitive follow set does not
  /// need to be explicitly constructed.
  ///
  ///      return expectedTokens.contains(symbol);
  ///
  /// [symbol] is the symbol type to check.
  ///
  /// Return `true` if [symbol] can follow the current state in the ATN,
  /// otherwise `false`.
  bool isExpectedToken(int symbol) {
    Atn atn = interpreter.atn;
    ParserRuleContext ctx = context;
    AtnState s = atn.states[state];
    IntervalSet following = atn.nextTokensInSameRule(s);
    if (following.contains(symbol)) return true;
    if (!following.contains(Token.EPSILON)) return false;
    while (ctx != null &&
        ctx.invokingState >= 0 &&
        following.contains(Token.EPSILON)) {
      AtnState invokingState = atn.states[ctx.invokingState];
      RuleTransition rt = invokingState.getTransition(0);
      following = atn.nextTokensInSameRule(rt.followState);
      if (following.contains(symbol)) return true;
      ctx = ctx.parent as ParserRuleContext;
    }
    if (following.contains(Token.EPSILON) && symbol == Token.EOF) return true;
    return false;
  }

  List<String> getRuleInvocationStack(RuleContext p) {
    List<String> stack = new List<String>();
    while (p != null) {
      // compute what follows who invoked us
      int ruleIndex = p.ruleIndex;
      if (ruleIndex < 0)
        stack.add("n/a");
      else
        stack.add(ruleNames[ruleIndex]);
      p = p.parent;
    }
    return stack;
  }

  /// The ATN with bypass alternatives is expensive to create so we create it
  /// lazily.
  ///
  /// Throws UnsupportedError if the current parser does not
  /// implement the [serializedAtn] property.
  Atn getAtnWithBypassAlts() {
    Atn result = _bypassAltsAtnCache[serializedAtn];
    if (result == null) {
      var deserializationOptions = new AtnDeserializationOptions();
      deserializationOptions.isGenerateRuleBypassTransitions = true;
      result = new AtnDeserializer(deserializationOptions)
          .deserialize(serializedAtn);
      _bypassAltsAtnCache[serializedAtn] = result;
    }
    return result;
  }

  /*
  // For debugging and other purposes.
  String _dumpDfa([bool toStdOut = true]) {
    bool seenOne = false;
    StringBuffer sb = new StringBuffer();
    for (int d = 0; d < interpreter.decisionToDfa.length; d++) {
      Dfa dfa = interpreter.decisionToDfa[d];
      if (dfa.states.isNotEmpty) {
        if (seenOne) sb.writeln('');
        sb
          ..write("Decision ")
          ..write(dfa.decision)
          ..writeln(":")
          ..write(dfa.toString(tokenNames));
        seenOne = true;
      }
    }
    if (toStdOut) print(sb);
    return sb.toString();
  }*/

  // Notify any parse listeners of an enter rule event.
  void _triggerEnterRuleEvent() {
    for (ParseTreeListener listener in _parseListeners) {
      listener.enterEveryRule(context);
      context.enterRule(listener);
    }
  }
}

class TraceListener implements ParseTreeListener {
  final Parser _parser;

  TraceListener(this._parser);

  Future enterEveryRule(ParserRuleContext ctx) {
    print("enter   ${_parser.ruleNames[ctx.ruleIndex]}, "
        "lookToken(1)=${ ( _parser._input.lookToken(1)).getText()}");
  }

  void visitTerminal(TerminalNode node) {
    print("consume ${node.symbol} rule "
        "${_parser.ruleNames[_parser.context.ruleIndex]}");
  }

  void visitErrorNode(ErrorNode node) {}

  Future exitEveryRule(ParserRuleContext ctx) {
    print("exit    ${_parser.ruleNames[ctx.ruleIndex]}"
        ", lookToken(1)=${ ( _parser._input.lookToken(1)).getText()}");
  }
}

class TrimToSizeListener implements ParseTreeListener {
  static final TrimToSizeListener INSTANCE = new TrimToSizeListener();

  void enterEveryRule(ParserRuleContext ctx) {}

  void visitTerminal(TerminalNode node) {}

  void visitErrorNode(ErrorNode node) {}

  void exitEveryRule(ParserRuleContext ctx) {
    if (ctx.children is List) {
      ctx.children.removeWhere((c) => c == null);
    }
  }
}
