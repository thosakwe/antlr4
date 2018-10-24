import 'dart:typed_data';
import '../token.dart';
import '../util/interval_set.dart';
import '../util/pair.dart';
import 'atn.dart';
import 'atn_states.dart';
import 'atn_type.dart';
import 'lexer_actions.dart';
import 'transitions.dart';

class AtnDeserializationOptions {
  static final defaultOptions = new AtnDeserializationOptions();

  final bool isReadOnly;
  bool _verifyAtn = true;
  bool _generateRuleBypassTransitions = false;

  AtnDeserializationOptions(
      {AtnDeserializationOptions options, this.isReadOnly: true}) {
    if (options != null) {
      _verifyAtn = options.isVerifyAtn;
      _generateRuleBypassTransitions = options.isGenerateRuleBypassTransitions;
    }
  }

  bool get isVerifyAtn => _verifyAtn;

  void set isVerifyAtn(bool verifyAtn) {
    _throwIfReadOnly();
    _verifyAtn = verifyAtn;
  }

  bool get isGenerateRuleBypassTransitions => _generateRuleBypassTransitions;

  void set isGenerateRuleBypassTransitions(bool generateRuleBypassTransitions) {
    _throwIfReadOnly();
    _generateRuleBypassTransitions = generateRuleBypassTransitions;
  }

  void _throwIfReadOnly() {
    if (isReadOnly) {
      throw new StateError("The object is read only.");
    }
  }
}

enum UnicodeDeserializingMode { UNICODE_BMP, UNICODE_SMP }

class UnicodeDeserializer {
  // Wrapper for readInt() or readInt32()
  final int Function(List<int>, int) readUnicode;

  // Work around Java not allowing mutation of captured variables
  // by returning amount by which to increment p after each read
  final int Function() size;

  UnicodeDeserializer(this.readUnicode, this.size);
}

class AtnDeserializer {
  static const String _BASE_SERIALIZED_UUID =
      "33761B2D-78BB-4A43-8B0B-4F5BEE8AACF3";
  static const String _ADDED_PRECEDENCE_TRANSITIONS =
      "1DA0C57D-6C06-438A-9B27-10BCB3CE0F61";
  static const String _ADDED_LEXER_ACTIONS =
      "AADB8D7E-AEEF-4415-AD2B-8204D6CF042E";
  static const String _ADDED_UNICODE_SMP =
      "59627784-3BE5-417A-B9EB-8131A7286089";

  static const int SERIALIZED_VERSION = 3;

  static const String SERIALIZED_UUID = _ADDED_LEXER_ACTIONS;

  static const List<String> _SUPPORTED_UUIDS = const <String>[
    _BASE_SERIALIZED_UUID,
    _ADDED_PRECEDENCE_TRANSITIONS,
    _ADDED_LEXER_ACTIONS,
    _ADDED_UNICODE_SMP,
  ];

  final AtnDeserializationOptions _deserializationOptions;

  AtnDeserializer([AtnDeserializationOptions deserializationOptions])
      : _deserializationOptions = (deserializationOptions != null)
            ? deserializationOptions
            : AtnDeserializationOptions.defaultOptions;

  static UnicodeDeserializer getUnicodeDeserializer(
      UnicodeDeserializingMode mode) {
    if (mode == UnicodeDeserializingMode.UNICODE_BMP) {
      int readUnicode(List<int> data, int p) {
        return data[p];
      }

      int size() {
        return 1;
      }

      return new UnicodeDeserializer(readUnicode, size);
    } else {
      int readUnicode(List<int> data, int p) {
        return data[p] | data[p + 1] << 16;
        //return toInt32(data, p);
      }

      int size() {
        return 2;
      }

      return new UnicodeDeserializer(readUnicode, size);
    }
  }

  int deserializeSets(List<int> data, int p, List<IntervalSet> sets,
      UnicodeDeserializer unicodeDeserializer) {
    int nsets = data[p++];
    for (int i = 0; i < nsets; i++) {
      int nintervals = data[p];
      p++;
      var set = new IntervalSet();
      sets.add(set);

      var containsEof = data[p++] != 0;
      if (containsEof) {
        set.add(-1, -1);
      }

      for (int j = 0; j < nintervals; j++) {
        int a = unicodeDeserializer.readUnicode(data, p);
        p += unicodeDeserializer.size();
        int b = unicodeDeserializer.readUnicode(data, p);
        p += unicodeDeserializer.size();
        set.add(a, b);
      }
    }
    return p;
  }

  Atn deserialize(String data) => deserializeBytes(data.codeUnits);

  Atn deserializeBytes(List<int> data_) {
    var data = new Uint16List.fromList(data_);

    for (int i = 1; i < data.length; i++) {
      data[i] = (data[i] - 2);
    }

    int p = 0;
    int version = data[p++];
    if (version != SERIALIZED_VERSION) {
      throw new UnsupportedError("Could not deserialize ATN "
          "with version $version (expected $SERIALIZED_VERSION).");
    }
    var uuid = _toUuid(data.getRange(p, p + 8).toList());
    p += 8;
    if (!_SUPPORTED_UUIDS.contains(uuid)) {
      throw new UnsupportedError("Could not deserialize ATN "
          "with UUID $uuid (expected $SERIALIZED_UUID or a legacy UUID).");
    }
    bool supportsPrecedencePredicates =
        _isFeatureSupported(_ADDED_PRECEDENCE_TRANSITIONS, uuid);
    bool supportsLexerActions = _isFeatureSupported(_ADDED_LEXER_ACTIONS, uuid);
    AtnType grammarType = AtnType.values[data[p++]];
    int maxTokenType = data[p++];
    Atn atn = new Atn(grammarType, maxTokenType);

    // STATES
    var loopBackStateNumbers = new List<Pair<LoopEndState, int>>();
    var endStateNumbers = new List<Pair<BlockStartState, int>>();
    int nstates = data[p++];
    for (int i = 0; i < nstates; i++) {
      int stype = data[p++];
      // ignore bad type of states
      if (stype == AtnState.INVALID_TYPE) {
        atn.addState(null);
        continue;
      }
      var ruleIndex = data[p++];
      if (ruleIndex == 0xFFFF) {
        ruleIndex = -1;
      }

      AtnState s = _stateFactory(stype, ruleIndex);
      if (stype == AtnState.LOOP_END) {
        // special case
        int loopBackStateNumber = data[p++];
        loopBackStateNumbers.add(new Pair<LoopEndState, int>(
            s as LoopEndState, loopBackStateNumber));
      } else if (s is BlockStartState) {
        int endStateNumber = data[p++];
        endStateNumbers.add(new Pair<BlockStartState, int>(s, endStateNumber));
      }
      atn.addState(s);
    }

    // delay the assignment of loop back and end states until we
    // know all the state instances have been initialized
    for (var pair in loopBackStateNumbers) {
      pair.a.loopBackState = atn.states[pair.b];
    }

    for (var pair in endStateNumbers) {
      pair.a.endState = atn.states[pair.b] as BlockEndState;
    }

    int numNonGreedyStates = data[p++];
    for (int i = 0; i < numNonGreedyStates; i++) {
      int stateNumber = data[p++];
      (atn.states[stateNumber] as DecisionState).nonGreedy = true;
    }

    if (supportsPrecedencePredicates) {
      int numPrecedenceStates = data[p++];
      for (int i = 0; i < numPrecedenceStates; i++) {
        int stateNumber = data[p++];
        (atn.states[stateNumber] as RuleStartState).isLeftRecursiveRule = true;
      }
    }

    // RULES
    int nrules = data[p++];
    if (atn.grammarType == AtnType.LEXER) {
      atn.ruleToTokenType = new List<int>(nrules);
    }

    atn.ruleToStartState = new List<RuleStartState>(nrules);
    for (int i = 0; i < nrules; i++) {
      int s = data[p++];
      RuleStartState startState = atn.states[s];
      atn.ruleToStartState[i] = startState;
      if (atn.grammarType == AtnType.LEXER) {
        int tokenType = data[p++];
        if (tokenType == 0xFFFF) {
          tokenType = Token.EOF;
        }

        atn.ruleToTokenType[i] = tokenType;
        if (!_isFeatureSupported(_ADDED_LEXER_ACTIONS, uuid)) {
          // this piece of unused metadata was serialized prior to the
          // addition of LexerAction
          // ignore: unused_local_variable
          int actionIndexIgnored = data[p++];
        }
      }
    }

    atn.ruleToStopState = new List<RuleStopState>(nrules);
    for (AtnState state in atn.states) {
      if (state is RuleStopState) {
        atn
          ..ruleToStopState[state.ruleIndex] = state
          ..ruleToStartState[state.ruleIndex].stopState = state;
      }
    }
    // MODES
    int nmodes = data[p++];
    for (int i = 0; i < nmodes; i++) {
      var s = atn.states[data[p++]];
      atn.modeToStartState.add(s as TokensStartState);
    }

    // SETS
    List<IntervalSet> sets = new List<IntervalSet>();

    // First, read all sets with 16-bit Unicode code points <= U+FFFF.
    p = deserializeSets(data, p, sets,
        getUnicodeDeserializer(UnicodeDeserializingMode.UNICODE_BMP));

    // Next, if the ATN was serialized with the Unicode SMP feature,
    // deserialize sets with 32-bit arguments <= U+10FFFF.
    if (_isFeatureSupported(_ADDED_UNICODE_SMP, uuid)) {
      p = deserializeSets(data, p, sets,
          getUnicodeDeserializer(UnicodeDeserializingMode.UNICODE_SMP));
    }

    // EDGES
    int nedges = data[p++];
    for (int i = 0; i < nedges; i++) {
      int src = data[p];
      int trg = data[p + 1];
      int ttype = data[p + 2];
      int arg1 = data[p + 3];
      int arg2 = data[p + 4];
      int arg3 = data[p + 5];
      var trans = _edgeFactory(atn, ttype, src, trg, arg1, arg2, arg3, sets);
      var srcState = atn.states[src];
      srcState.addTransition(trans);
      p += 6;
    }

    // edges for rule stop states can be derived, so they aren't serialized
    for (AtnState state in atn.states) {
      for (int i = 0; i < state.numberOfTransitions; i++) {
        Transition t = state.transition(i);
        if (t is! RuleTransition) continue;

        var ruleTransition = t as RuleTransition;
        int outermostPrecedenceReturn = -1;
        if (atn.ruleToStartState[ruleTransition.target.ruleIndex]
            .isLeftRecursiveRule) {
          if (ruleTransition.precedence == 0) {
            outermostPrecedenceReturn = ruleTransition.target.ruleIndex;
          }
        }

        EpsilonTransition returnTransition = new EpsilonTransition(
            ruleTransition.followState, outermostPrecedenceReturn);
        atn.ruleToStopState[ruleTransition.target.ruleIndex]
            .addTransition(returnTransition);
      }
    }

    for (AtnState state in atn.states) {
      if (state is BlockStartState) {
        // we need to know the end state to set its start state
        if (state.endState == null)
          throw new StateError(
              'we need to know the end state to set its start state');
        // block end states can only be associated to a single block start state
        if (state.endState.startState != null)
          throw new StateError('block end states can'
              ' only be associated to a single block start state');
        state.endState.startState = state;
      }
      if (state is PlusLoopbackState) {
        for (int i = 0; i < state.numberOfTransitions; i++) {
          AtnState target = state.transition(i).target;
          if (target is PlusBlockStartState) target.loopBackState = state;
        }
      } else if (state is StarLoopbackState) {
        for (int i = 0; i < state.numberOfTransitions; i++) {
          AtnState target = state.transition(i).target;
          if (target is StarLoopEntryState) target.loopBackState = state;
        }
      }
    }
    // DECISIONS
    int ndecisions = data[p++];
    for (int i = 1; i <= ndecisions; i++) {
      var s = data[p++];
      var decState = atn.states[s] as DecisionState;

      atn.decisionToState.add(decState);
      decState.decision = i - 1;
    }

    // LEXER ACTIONS
    if (atn.grammarType == AtnType.LEXER) {
      if (supportsLexerActions) {
        atn.lexerActions = new List<LexerAction>(data[p++]);
        for (int i = 0; i < atn.lexerActions.length; i++) {
          LexerActionType actionType = LexerActionType.values[data[p++]];
          var data1 = data[p++];
          if (data1 == 0xFFFF) {
            data1 = -1;
          }

          var data2 = data[p++];
          if (data2 == 0xFFFF) {
            data2 = -1;
          }

          atn.lexerActions[i] = _lexerActionFactory(actionType, data1, data2);
        }
      } else {
        // for compatibility with older serialized ATNs, convert the old
        // serialized action index for action transitions to the new
        // form, which is the index of a LexerCustomAction
        List<LexerAction> legacyLexerActions = new List<LexerAction>();
        for (AtnState state in atn.states) {
          for (int i = 0; i < state.numberOfTransitions; i++) {
            Transition transition = state.transition(i);
            if (transition is! ActionTransition) continue;
            int ruleIndex = (transition as ActionTransition).ruleIndex;
            int actionIndex = (transition as ActionTransition).actionIndex;
            var lexerAction = new LexerCustomAction(ruleIndex, actionIndex);
            state.setTransition(
                i,
                new ActionTransition(transition.target, ruleIndex,
                    legacyLexerActions.length, false));
            legacyLexerActions.add(lexerAction);
          }
        }
        atn.lexerActions = legacyLexerActions;
      }
    }

    _markPrecedenceDecisions(atn);
    if (_deserializationOptions.isVerifyAtn) _verifyAtn(atn);

    if (_deserializationOptions.isGenerateRuleBypassTransitions &&
        atn.grammarType == AtnType.PARSER) {
      atn.ruleToTokenType = new List<int>(atn.ruleToStartState.length);
      for (int i = 0; i < atn.ruleToStartState.length; i++) {
        atn.ruleToTokenType[i] = atn.maxTokenType + i + 1;
      }
      for (int i = 0; i < atn.ruleToStartState.length; i++) {
        BasicBlockStartState bypassStart = new BasicBlockStartState();
        bypassStart.ruleIndex = i;
        atn.addState(bypassStart);

        BlockEndState bypassStop = new BlockEndState();
        bypassStop.ruleIndex = i;
        atn.addState(bypassStop);

        bypassStart.endState = bypassStop;
        atn.defineDecisionState(bypassStart);

        bypassStop.startState = bypassStart;

        AtnState endState;
        Transition excludeTransition = null;
        if (atn.ruleToStartState[i].isLeftRecursiveRule) {
          // wrap from the beginning of the rule to the StarLoopEntryState
          endState = null;
          for (AtnState state in atn.states) {
            if (state.ruleIndex != i) continue;
            if (state is! StarLoopEntryState) continue;
            AtnState maybeLoopEndState =
                state.transition(state.numberOfTransitions - 1).target;
            if (maybeLoopEndState is! LoopEndState) continue;
            if (maybeLoopEndState.epsilonOnlyTransitions &&
                maybeLoopEndState.transition(0).target is RuleStopState) {
              endState = state;
              break;
            }
          }
          if (endState == null) {
            throw new UnsupportedError("Couldn't "
                "identify final state of the precedence rule prefix section.");
          }
          excludeTransition =
              (endState as StarLoopEntryState).loopBackState.transition(0);
        } else {
          endState = atn.ruleToStopState[i];
        }
        // all non-excluded transitions that currently target end state
        // need to target blockEnd instead
        for (AtnState state in atn.states) {
          for (Transition transition in state.transitions) {
            if (transition == excludeTransition) continue;
            if (transition.target == endState) transition.target = bypassStop;
          }
        }
        // all transitions leaving the rule start state need to leave
        // blockStart instead
        while (atn.ruleToStartState[i].numberOfTransitions > 0) {
          Transition transition = atn.ruleToStartState[i].removeTransition(
              atn.ruleToStartState[i].numberOfTransitions - 1);
          bypassStart.addTransition(transition);
        }
        // link the new states
        atn.ruleToStartState[i]
            .addTransition(new EpsilonTransition(bypassStart));
        bypassStop.addTransition(new EpsilonTransition(endState));

        AtnState matchState = new BasicState();
        atn.addState(matchState);
        matchState.addTransition(
            new AtomTransition(bypassStop, atn.ruleToTokenType[i]));
        bypassStart.addTransition(new EpsilonTransition(matchState));
      }
      if (_deserializationOptions.isVerifyAtn) _verifyAtn(atn);
    }
    return atn;
  }

  static Transition _edgeFactory(Atn atn, int type, int src, int trg, int arg1,
      int arg2, int arg3, List<IntervalSet> sets) {
    AtnState target = atn.states[trg];
    switch (type) {
      case Transition.EPSILON:
        return new EpsilonTransition(target);
      case Transition.RANGE:
        if (arg3 != 0) return new RangeTransition(target, Token.EOF, arg2);
        return new RangeTransition(target, arg1, arg2);
      case Transition.RULE:
        return new RuleTransition(
            atn.states[arg1] as RuleStartState, arg2, arg3, target);
      case Transition.PREDICATE:
        return new PredicateTransition(target, arg1, arg2, arg3 != 0);
      case Transition.PRECEDENCE:
        return new PrecedencePredicateTransition(target, arg1);
      case Transition.ATOM:
        if (arg3 != 0) return new AtomTransition(target, Token.EOF);
        return new AtomTransition(target, arg1);
      case Transition.ACTION:
        return new ActionTransition(target, arg1, arg2, arg3 != 0);
      case Transition.SET:
        return new SetTransition(target, sets[arg1]);
      case Transition.NOT_SET:
        return new NotSetTransition(target, sets[arg1]);
      case Transition.WILDCARD:
        return new WildcardTransition(target);
    }
    throw new ArgumentError("The specified transition type is not valid.");
  }

  static AtnState _stateFactory(int type, int ruleIndex) {
    AtnState s;
    switch (type) {
      case AtnState.INVALID_TYPE:
        return null;
      case AtnState.BASIC:
        s = new BasicState();
        break;
      case AtnState.RULE_START:
        s = new RuleStartState();
        break;
      case AtnState.BLOCK_START:
        s = new BasicBlockStartState();
        break;
      case AtnState.PLUS_BLOCK_START:
        s = new PlusBlockStartState();
        break;
      case AtnState.STAR_BLOCK_START:
        s = new StarBlockStartState();
        break;
      case AtnState.TOKEN_START:
        s = new TokensStartState();
        break;
      case AtnState.RULE_STOP:
        s = new RuleStopState();
        break;
      case AtnState.BLOCK_END:
        s = new BlockEndState();
        break;
      case AtnState.STAR_LOOP_BACK:
        s = new StarLoopbackState();
        break;
      case AtnState.STAR_LOOP_ENTRY:
        s = new StarLoopEntryState();
        break;
      case AtnState.PLUS_LOOP_BACK:
        s = new PlusLoopbackState();
        break;
      case AtnState.LOOP_END:
        s = new LoopEndState();
        break;
      default:
        throw new ArgumentError("The specified state type $type is not valid.");
    }
    s.ruleIndex = ruleIndex;
    return s;
  }

  static void _checkCondition(bool condition, String message) {
    if (!condition) {
      throw new StateError(message);
    }
  }

  static String _toUuid(List<int> data) {
    //print(data);
    //var leastSigBits = _toLong(data);
    //var mostSigBits = _toLong(data, 4);

    BigInt leastSigBits = _toInt(data);
    BigInt mostSigBits = _toInt(data, 4);
    String uuid = "${_digits(mostSigBits >> 32, 8)}-"
        "${_digits(mostSigBits >> 16, 4)}-"
        "${_digits(mostSigBits, 4)}-"
        "${_digits(leastSigBits >> 48, 4)}-"
        "${_digits(leastSigBits, 12)}";
    return uuid.toUpperCase();
  }

  // Analyze the StarLoopEntryState states in the specified ATN to set the
  // StarLoopEntryState.precedenceRuleDecision field to the correct value.
  //
  // atn is the ATN.
  void _markPrecedenceDecisions(Atn atn) {
    for (AtnState state in atn.states) {
      if (state is! StarLoopEntryState) continue;
      // We analyze the ATN to determine if this ATN decision state is the
      // decision for the closure block that determines whether a
      // precedence rule should continue or complete.
      if (atn.ruleToStartState[state.ruleIndex].isLeftRecursiveRule) {
        AtnState maybeLoopEndState =
            state.transition(state.numberOfTransitions - 1).target;
        if (maybeLoopEndState is LoopEndState) {
          if (maybeLoopEndState.epsilonOnlyTransitions &&
              maybeLoopEndState.transition(0).target is RuleStopState) {
            (state as StarLoopEntryState).precedenceRuleDecision = true;
          }
        }
      }
    }
  }

  LexerAction _lexerActionFactory(LexerActionType type, int data1, int data2) {
    switch (type) {
      case LexerActionType.CHANNEL:
        return new LexerChannelAction(data1);
      case LexerActionType.CUSTOM:
        return new LexerCustomAction(data1, data2);
      case LexerActionType.MODE:
        return new LexerModeAction(data1);
      case LexerActionType.MORE:
        return LexerMoreAction.INSTANCE;
      case LexerActionType.POP_MODE:
        return LexerPopModeAction.INSTANCE;
      case LexerActionType.PUSH_MODE:
        return new LexerPushModeAction(data1);
      case LexerActionType.SKIP:
        return LexerSkipAction.INSTANCE;
      case LexerActionType.TYPE:
        return new LexerTypeAction(data1);
      default:
        throw new ArgumentError(
            "The specified lexer action type $type is not valid.");
    }
  }

  static void _verifyAtn(Atn atn) {
    // verify assumptions
    for (AtnState state in atn.states) {
      if (state == null) continue;
      _checkCondition(
          state.onlyHasEpsilonTransitions || (state.numberOfTransitions <= 1),
          'ATN state must have either only epsilon transitions, or 0 or 1 total transitions.');
      if (state is PlusBlockStartState)
        _checkCondition(state.loopBackState != null,
            'PlusBlockStartState cannot have a null loopBackState.');
      if (state is StarLoopEntryState) {
        _checkCondition(state.loopBackState != null,
            'StarLoopEntryState cannot have a null loopBackState.');
        _checkCondition(state.numberOfTransitions == 2,
            'StarLoopEntryState must have exactly 2 transitions.');
        if (state.transition(0).target is StarBlockStartState) {
          _checkCondition(state.transition(1).target is LoopEndState,
              'StarLoopEntryState must have a transition at index 1 whose target is a LoopEndState.');
          _checkCondition(
              !state.nonGreedy, 'StartLoopEntryState cannot be non-greedy.');
        } else if (state.transition(0).target is LoopEndState) {
          _checkCondition(state.transition(1).target is StarBlockStartState,
              'StarLoopEntryState must have a transition at index 1 whose target is a StarBlockStartState.');
          _checkCondition(
              state.nonGreedy, 'StartLoopEntryState must be non-greedy.');
        } else {
          throw new StateError('');
        }
      }
      if (state is StarLoopbackState) {
        _checkCondition(state.numberOfTransitions == 1,
            'StarLoopbackState must have exactly 1 transition.');
        _checkCondition(state.transition(0).target is StarLoopEntryState,
            'StarLoopbackEntryState must have a transition at index 0 whose target is a StarLoopEntryState.');
      }
      if (state is LoopEndState)
        _checkCondition(state.loopBackState != null,
            'LoopEndState cannot have a null loopBackState.');
      if (state is RuleStartState)
        _checkCondition(state.stopState != null,
            'RuleStartState cannot have a null stopState.');
      if (state is BlockStartState)
        _checkCondition(state.endState != null,
            'BlockStartState cannot have a null endState.');
      if (state is BlockEndState)
        _checkCondition(state.startState != null,
            'BlockEndState cannot have a null startState.');
      if (state is DecisionState) {
        _checkCondition(
            state.numberOfTransitions <= 1 || state.decision >= 0,
            'DecisionState must have <= 1 transitions, OR have a decision >= 0.\n' +
                'numberOfTransitions was ${state.numberOfTransitions}, decision was ${state.decision}.');
      } else {
        _checkCondition(
            state.numberOfTransitions <= 1 || state is RuleStopState,
            'AtnState must have <= 1 transitions, OR be a RuleStopState.' +
                'numberOfTransitions was ${state.numberOfTransitions}.');
      }
    }
  }

  static BigInt _toInt(List<int> data, [int offset = 0]) {
    var mask = BigInt.parse('00000000FFFFFFFF', radix: 16);
    var lowOrder =
        new BigInt.from(data[offset] | (data[offset + 1] << 16)) & mask;
    var highOrder =
        new BigInt.from(data[offset + 2] | data[offset + 3] << 16) << 32;
    return lowOrder | highOrder;
  }

  static String _digits(BigInt paramLong, int paramInt) {
    var left = new BigInt.from(1 << paramInt * 4);
    String hex = ((left | paramLong & left - BigInt.one)).toRadixString(16);
    return hex.substring(hex.length - paramInt);
  }

  /*
  static String _digits(int paramLong, int paramInt) {
    var left = 1 << paramInt * 4;
    String hex = ((left | paramLong & left - 1)).toRadixString(16);
    return hex.substring(hex.length - paramInt);
  }
  */

  // Determines if a particular serialized representation of an ATN supports
  // a particular feature, identified by the uuid used for serializing
  // the ATN at the time the feature was first introduced.
  //
  // feature is the uuid marking the first time the feature was
  // supported in the serialized ATN.
  // actualUuid is the uuid of the actual serialized ATN which is
  // currently being deserialized.
  // Return true if the actualUuid value represents a serialized ATN
  // at or after the feature identified by feature was introduced;
  // otherwise, false.
  static bool _isFeatureSupported(String feature, String actualUuid) {
    int featureIndex = _SUPPORTED_UUIDS.indexOf(feature);
    if (featureIndex < 0) return false;
    return _SUPPORTED_UUIDS.indexOf(actualUuid) >= featureIndex;
  }
}
