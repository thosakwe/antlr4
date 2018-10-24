import 'dart:collection';
import 'dart:math';
import 'package:collection/collection.dart';
import '../util/bit_set.dart';
import '../util/double_key_map.dart';
import 'atn.dart';
import 'atn_config.dart';
import 'atn_simulator.dart';
import 'atn_states.dart';
import 'contexts.dart';
import 'semantic_context.dart';

/// Specialized [Set]`<`[AtnConfig]`>` that can track info about the set,
/// with support for combining similar configurations using a
/// graph-structured stack.
class AtnConfigSet extends DelegatingList<AtnConfig> {
  // Indicates that the set of configurations is read-only. Do not allow any
  // code to manipulate the set; DFA states will point at the sets and they
  // must not change. This does not protect the other fields; in particular,
  // conflictingAlts is set after we've made this readonly.
  bool _readonly = false;

  int _cachedHashCode = -1;
  BitSet conflictingAlts;

  /// All configs but hashed by (s, i, _, pi) not including context. Wiped out
  /// when we go readonly as this set becomes a DFA state.
  HashSet configLookup;

  /// Used in parser and lexer. In lexer, it indicates we hit a pred while
  /// computing a closure operation.
  bool hasSemanticContext = false;

  bool dipsIntoOuterContext = false;

  int uniqueAlt = 0;

  /// Indicates that this configuration set is part of a full context
  /// LL prediction. It will be used to determine how to merge `$`. With SLL
  /// it's a wildcard whereas it is not for LL context merge.
  final bool fullCtx;

  AtnConfigSet([this.fullCtx = true]) : super([]) {
    configLookup = new HashSet();
  }

  factory AtnConfigSet.from(AtnConfigSet other) {
    return new AtnConfigSet(other.fullCtx)
      ..configLookup = new HashSet()
      ..addAll(other)
      ..uniqueAlt = other.uniqueAlt
      ..conflictingAlts = other.conflictingAlts
      ..hasSemanticContext = other.hasSemanticContext
      ..dipsIntoOuterContext = other.dipsIntoOuterContext;
  }

  /// Track the elements as they are added to the set.
  @deprecated
  List<AtnConfig> get configs => this;

  /// Return a List holding list of
  @deprecated
  List<AtnConfig> get elements => configs;

  Set<AtnState> get states {
    return new Set<AtnState>.from(map((s) => s.state));
  }

  List<SemanticContext> get predicates {
    List<SemanticContext> preds = new List<SemanticContext>();
    for (AtnConfig c in this) {
      if (c.semanticContext != SemanticContext.NONE) {
        preds.add(c.semanticContext);
      }
    }
    return preds;
  }

  int get hashCode {
    if (_readonly) {
      if (_cachedHashCode == -1) {
        forEach((c) => _cachedHashCode += _hashCode(c));
        _cachedHashCode &= 0xFFFFFFFF;
      }
      return _cachedHashCode;
    }
    int hash = -1;
    forEach((c) => hash += _hashCode(c));
    return hash & 0xFFFFFFFF;
  }

  //int get length => length;

  //bool get isEmpty => isEmpty;

  //Iterator<AtnConfig> get iterator => iterator;

  bool get isReadonly => _readonly;

  void set isReadonly(bool readonly) {
    _readonly = readonly;
    configLookup = null; // can't mod, no need for lookup cache
  }

  /// Gets the complete set of represented alternatives for the
  /// configuration set.
  BitSet get alts {
    BitSet alts = new BitSet();
    for (AtnConfig config in this) {
      alts.set(config.alt, true);
    }
    return alts;
  }

  void optimizeConfigs(AtnSimulator interpreter) {
    if (_readonly) throw new StateError("This set is readonly");
    if (configLookup.isEmpty) return;
    for (AtnConfig config in this) {
      config.context = interpreter.getCachedContext(config.context);
    }
  }

  bool addAll(Iterable configs) {
    forEach((c) => add(c));
    return false;
  }

  /// Adding a new config means merging contexts with existing configs for
  /// `(s, i, pi, _)`, where `s` is the [AtnConfig.state], `i` is the
  /// [AtnConfig.alt], and `pi` is the [AtnConfig.semanticContext].
  ///
  /// This method updates [dipsIntoOuterContext] and [hasSemanticContext]
  /// when necessary.
  bool add(AtnConfig config,
      [DoubleKeyMap<PredictionContext, PredictionContext, PredictionContext>
          mergeCache]) {
    if (_readonly) throw new StateError("This set is readonly");
    if (config.semanticContext != SemanticContext.NONE)
      hasSemanticContext = true;
    if (config.reachesIntoOuterContext > 0) dipsIntoOuterContext = true;
    AtnConfig existing = configLookup.lookup(config);
    if (existing == null) {
      // we added this new one
      configLookup.add(config);
      _cachedHashCode = -1;
      add(config); // track order here
      return true;
    }
    // a previous (s,i,pi,_), merge with it and save result
    bool rootIsWildcard = !fullCtx;
    var merged = PredictionContext.merge(
        existing.context, config.context, rootIsWildcard, mergeCache);
    // no need to check for existing.context, config.context in cache
    // since only way to create new graphs is "call rule" and here. We
    // cache at both places.
    existing
      ..reachesIntoOuterContext =
          max(existing.reachesIntoOuterContext, config.reachesIntoOuterContext)
      ..context = merged; // replace context; no need to alt mapping
    return true;
  }

  bool operator ==(Object other) {
    return other is AtnConfigSet &&
        _equalConfigs(other) &&
        fullCtx == other.fullCtx &&
        uniqueAlt == other.uniqueAlt &&
        conflictingAlts == other.conflictingAlts &&
        hasSemanticContext == other.hasSemanticContext &&
        dipsIntoOuterContext == other.dipsIntoOuterContext;
  }

  bool contains(Object o) {
    if (configLookup == null) {
      throw new UnsupportedError(
          "This method is not implemented for readonly sets.");
    }
    return configLookup.contains(o);
  }

  void clear() {
    if (_readonly) throw new StateError("This set is readonly");
    clear();
    _cachedHashCode = -1;
    configLookup.clear();
  }

  String toString() {
    StringBuffer sb = new StringBuffer()..write(this);
    if (hasSemanticContext)
      sb..write(",hasSemanticContext=")..write(hasSemanticContext);
    if (uniqueAlt != Atn.INVALID_ALT_NUMBER)
      sb..write(",uniqueAlt=")..write(uniqueAlt);
    if (conflictingAlts != null)
      sb..write(",conflictingAlts=")..write(conflictingAlts);
    if (dipsIntoOuterContext) sb..write(",dipsIntoOuterContext");
    return sb.toString();
  }

  bool _equalConfigs(List<AtnConfig> cfgs) {
    if (cfgs.length != length) return false;
    for (int i = 0; i < length; i++) {
      if (this[i] != cfgs[i]) return false;
    }
    return true;
  }

  int _hashCode(AtnConfig other) {
    int hashCode = 7;
    hashCode = 31 * hashCode + other.state.stateNumber;
    hashCode = 31 * hashCode + other.alt;
    hashCode = 31 * hashCode + other.semanticContext.hashCode;
    return hashCode;
  }
}
