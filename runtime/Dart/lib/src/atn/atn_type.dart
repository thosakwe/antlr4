/// Represents the type of recognizer an ATN applies to.
class AtnType {
  /// A lexer grammar.
  static const AtnType LEXER = const AtnType._internal('LEXER');

  /// A parser grammar.
  static const AtnType PARSER = const AtnType._internal('PARSER');

  static const Map<int, AtnType> values = const {0: LEXER, 1: PARSER};

  final String name;

  const AtnType._internal(this.name);

  String toString() => name;
}
