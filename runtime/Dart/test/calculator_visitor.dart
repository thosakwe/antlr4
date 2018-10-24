// Generated from Calculator.g4 by antlr4dart


part of calculator;


/// This abstract class defines a complete generic visitor for a parse tree
/// produced by [CalculatorParser].
///
/// [T] is the eturn type of the visit operation. Use `void` for
/// operations with no return type.
abstract class CalculatorVisitor<T> extends ParseTreeVisitor<T> {
  /// Visit a parse tree produced by [CalculatorParser.expr].
  /// [context] is the parse tree.
  /// Return the visitor result.
  T visitExpr(ExprContext context);
}