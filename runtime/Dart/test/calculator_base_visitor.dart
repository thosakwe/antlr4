// Generated from Calculator.g4 by antlr4dart

part of calculator;


/// This class provides an empty implementation of [CalculatorVisitor],
/// which can be extended to create a visitor which only needs to handle
/// a subset of the available methods.
///
/// [T] is the return type of the visit operation. Use `void` for
/// operations with no return type.
class CalculatorBaseVisitor<T> extends ParseTreeVisitor<T> implements CalculatorVisitor<T> {
  /// The default implementation returns the result of calling
  /// [visitChildren] on [context].
  T visitExpr(ExprContext context) => visitChildren(context);
}