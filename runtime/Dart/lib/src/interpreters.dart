import '';
import 'package:meta/meta.dart';
import 'atn/atn.dart';
import 'atn/atn_simulator.dart';
import 'atn/atn_states.dart';
import 'atn/atn_type.dart';
import 'atn/contexts.dart';
import 'atn/transitions.dart';
import 'util/bit_set.dart';
import 'util/pair.dart';
import 'contexts.dart';
import 'dfa.dart';
import 'exceptions.dart';
import 'lexer.dart';
import 'input_stream.dart';
import 'parser.dart';
import 'token.dart';
import 'token_stream.dart';

class LexerInterpreter extends Lexer {
  final String grammarFileName;
  final Atn atn;

  final List<String> tokenNames;
  final List<String> ruleNames;
  final List<String> modeNames;

  final List<Dfa> decisionToDfa;
  final sharedContextCache = new PredictionContextCache();

  LexerInterpreter(this.grammarFileName, this.tokenNames, this.ruleNames,
      this.modeNames, Atn atn, ANTLRInputStream input)
      : decisionToDfa = new List<Dfa>(atn.numberOfDecisions),
        this.atn = atn,
        super(input) {
    if (atn.grammarType != AtnType.LEXER) {
      throw new ArgumentError("The ATN must be a lexer ATN.");
    }
    for (int i = 0; i < decisionToDfa.length; i++) {
      decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    interpreter =
        new LexerAtnSimulator(atn, decisionToDfa, sharedContextCache, this);
  }
}

/// A parser simulator that mimics what ANTLR's generated parser code does.
/// A [ParserAtnSimulator] is used to make predictions via
/// [Parser.adaptivePredict] but this class moves a pointer through the ATN to
/// simulate parsing. [ParserAtnSimulator] just makes us efficient rather than
/// having to backtrack, for example.
///
/// This properly creates parse trees even for left recursive rules.
///
/// We rely on the left recursive rule invocation and special predicate
/// transitions to make left recursive rules work.
///
class ParserInterpreter extends Parser {
  final String grammarFileName;
  final Atn atn;
  final BitSet pushRecursionContextStates;

  final List<Dfa> decisionToDfa;
  final sharedContextCache = new PredictionContextCache();

  final List<String> tokenNames;
  final List<String> ruleNames;

  final parentContextStack = new List<Pair<ParserRuleContext, int>>();

  ParserInterpreter(this.grammarFileName, this.tokenNames, this.ruleNames,
      Atn atn, TokenStream input)
      : decisionToDfa = new List<Dfa>(atn.numberOfDecisions),
        pushRecursionContextStates = new BitSet(),
        this.atn = atn,
        super(input) {
    for (int i = 0; i < decisionToDfa.length; i++) {
      decisionToDfa[i] = new Dfa(atn.getDecisionState(i), i);
    }
    // identify the ATN states where pushNewRecursionContext must be called
    for (AtnState state in atn.states) {
      if (state is! StarLoopEntryState) continue;
      if ((state as StarLoopEntryState).precedenceRuleDecision) {
        pushRecursionContextStates.set(state.stateNumber, true);
      }
    }
    // get atn simulator that knows how to do predictions
    interpreter =
        new ParserAtnSimulator(this, atn, decisionToDfa, sharedContextCache);
  }

  /// Begin parsing at [startRuleIndex].
  Future<ParserRuleContext> parse(int startRuleIndex) async {
    RuleStartState startRuleStartState = atn.ruleToStartState[startRuleIndex];
    var rootContext = new InterpreterRuleContext(
        null, AtnState.INVALID_STATE_NUMBER, startRuleIndex);
    if (startRuleStartState.isPrecedenceRule) {
      await enterRecursionRule(
          rootContext, startRuleStartState.stateNumber, startRuleIndex, 0);
    } else {
      await enterRule(
          rootContext, startRuleStartState.stateNumber, startRuleIndex);
    }
    while (true) {
      AtnState p = _getAtnState();
      switch (p.stateType) {
        case AtnState.RULE_STOP:
          // pop; return from rule
          if (context.isEmpty) {
            if (startRuleStartState.isPrecedenceRule) {
              ParserRuleContext result = context;
              var parentContext = parentContextStack.removeLast();
              await unrollRecursionContexts(parentContext.a);
              return result;
            } else {
              await exitRule();
              return rootContext;
            }
          }
          await _visitRuleStopState(p);
          break;
        default:
          await _visitState(p);
          break;
      }
    }
  }

  Future enterRecursionRule(@checked ParserRuleContext localctx, int state,
      int ruleIndex, int precedence) {
    parentContextStack
        .add(new Pair<ParserRuleContext, int>(context, localctx.invokingState));
    return enterRecursionRule(localctx, state, ruleIndex, precedence);
  }

  AtnState _getAtnState() => atn.states[state];

  Future _visitState(AtnState antState) async {
    int edge;
    if (antState.numberOfTransitions > 1) {
      edge = await interpreter.adaptivePredict(
          inputStream, (antState as DecisionState).decision, context);
    } else {
      edge = 1;
    }
    var transition = antState.getTransition(edge - 1);
    switch (transition.serializationType) {
      case Transition.EPSILON:
        if (pushRecursionContextStates.get(antState.stateNumber) &&
            (transition.target is! LoopEndState)) {
          var ctx = new InterpreterRuleContext(parentContextStack.last.a,
              parentContextStack.last.b, context.ruleIndex);
          await pushNewRecursionContext(
              ctx,
              atn.ruleToStartState[antState.ruleIndex].stateNumber,
              context.ruleIndex);
        }
        break;
      case Transition.ATOM:
        match((transition as AtomTransition).especialLabel);
        break;
      case Transition.RANGE:
      case Transition.SET:
      case Transition.NOT_SET:
        if (!transition.matches(
            await inputStream.lookAhead(1), Token.MIN_USER_TOKEN_TYPE, 65535)) {
          errorHandler.recoverInline(this);
        }
        matchWildcard();
        break;
      case Transition.WILDCARD:
        matchWildcard();
        break;
      case Transition.RULE:
        RuleStartState ruleStartState = transition.target;
        int ruleIndex = ruleStartState.ruleIndex;
        var ctx = new InterpreterRuleContext(
            context, antState.stateNumber, ruleIndex);
        if (ruleStartState.isPrecedenceRule) {
          await enterRecursionRule(ctx, ruleStartState.stateNumber, ruleIndex,
              (transition as RuleTransition).precedence);
        } else {
          await enterRule(ctx, transition.target.stateNumber, ruleIndex);
        }
        break;
      case Transition.PREDICATE:
        PredicateTransition predicateTransition = transition;
        if (!semanticPredicate(context, predicateTransition.ruleIndex,
            predicateTransition.predIndex)) {
          throw new FailedPredicateException(this, await currentToken);
        }
        break;
      case Transition.ACTION:
        ActionTransition actionTransition = transition;
        action(
            context, actionTransition.ruleIndex, actionTransition.actionIndex);
        break;
      case Transition.PRECEDENCE:
        var pred = (transition as RuleTransition).precedence;
        if (!precedencePredicate(context, pred)) {
          throw new FailedPredicateException(
              this, await currentToken, "precpred(context, $pred)");
        }
        break;
      default:
        throw new UnsupportedError("Unrecognized ATN transition type.");
    }
    state = transition.target.stateNumber;
  }

  Future _visitRuleStopState(AtnState p) async {
    RuleStartState ruleStartState = atn.ruleToStartState[p.ruleIndex];
    if (ruleStartState.isPrecedenceRule) {
      var parentContext = parentContextStack.removeLast();
      await unrollRecursionContexts(parentContext.a);
      state = parentContext.b;
    } else {
      await exitRule();
    }
    RuleTransition ruleTransition = atn.states[state].getTransition(0);
    state = ruleTransition.followState.stateNumber;
  }
}
