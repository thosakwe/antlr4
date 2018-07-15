// Generated from Calculator.g4 by antlr4dart

part of calculator;


/// This abstract class defines a complete listener for a parse tree produced by
/// [CalculatorParser].
abstract class CalculatorListener extends ParseTreeListener {

  /// Enter a parse tree produced by [CalculatorParser.expr].
  /// [context] is the parse tree.
   void enterExpr(ExprContext context);

  /// Exit a parse tree produced by [CalculatorParser.expr].
  /// [context] is the parse tree.
  void exitExpr(ExprContext context);
}