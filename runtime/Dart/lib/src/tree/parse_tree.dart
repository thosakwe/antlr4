import '../util/interval.dart';
import '../contexts.dart';
import '../token.dart';
import 'parse_tree_visitor.dart';

abstract class ParseTreeListener<T> {
  T visitTerminal(TerminalNode terminalNode);

  T visitErrorNode(ErrorNode errorNode);

  T enterEveryRule(ParserRuleContext context);

  T exitEveryRule(ParserRuleContext context);
}

/// The basic notion of a tree has a parent, a payload, and a list of children.
///
/// It is the most abstract class for all the trees used by antlr4dart.
abstract class Tree {
  /// The parent of this node.
  ///
  /// If `null`, then this node is the root of the tree.
  Tree get parent;

  /// Whatever object represents the data at this note. For example, for parse
  /// trees, the payload can be a [Token] representing a leaf node or a
  /// [RuleContext] object representing a rule invocation.
  ///
  /// For abstract syntax trees (ASTs), this is a [Token] object.
  Object get payload;

  /// How many children are there? If there is none, then this node represents
  /// a leaf node.
  int get childCount;

  /// If there are children, get the `i`th value indexed from `0`.
  Tree getChild(int i);

  /// Print out a whole tree, not just a node, in LISP format
  /// `(root child1..childN)` or just a node when this is a leaf.
  String toString();
}

/// A tree that knows about an interval in a token source is some kind of
/// syntax tree. Subclasses distinguish between parse trees and other kinds
/// of syntax trees we might want to create.
abstract class SyntaxTree extends Tree {
  /// Return an [Interval] indicating the index in the [TokenSource] of the
  /// first and last token associated with this subtree. If this node is a
  /// leaf, then the interval represents a single token.
  ///
  /// If source interval is unknown, this returns [Interval.invalid].
  Interval get sourceInterval;
}

/// An abstract class to access the tree of [RuleContext] objects created
/// during a parse that makes the data structure look like a simple parse
/// tree.
///
/// This node represents both internal nodes, rule invocations and leaf
/// nodes token matches.
///
/// The payload is either a [Token] or a [RuleContext] object.
abstract class ParseTree extends SyntaxTree {
  /// The [ParseTreeVisitor] needs a double dispatch method.
  T accept<T>(ParseTreeVisitor<T> visitor);

  /// Return the combined text of all leaf nodes. Does not get any
  /// off-channel tokens (if any) so won't return whitespace and
  /// comments if they are sent to parser on hidden channel.
  String get text;
}

abstract class RuleNode extends ParseTree {
  RuleContext get ruleContext;
}

class TerminalNode implements ParseTree {
  Token symbol;
  ParseTree parent;

  TerminalNode(this.symbol);

  Token get payload => symbol;

  int get childCount => 0;

  String get text => symbol.text;

  Interval get sourceInterval {
    if (symbol == null) return Interval.invalid;
    int tokenIndex = symbol.tokenIndex;
    return new Interval(tokenIndex, tokenIndex);
  }

  ParseTree getChild(int i) => null;

  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitTerminal(this);

  String toStringAsync() =>
      (symbol.type == Token.EOF) ? "<EOF>" : symbol.text;

  /// Use [toStringAsync] instead.
  @deprecated
  String toString() => (symbol.type == Token.EOF)
      ? "<EOF>"
      : "Token at ${symbol.line}:${symbol
          .charPositionInLine} ; use toStringAsync() to get token text";
}

/// Represents a token that was consumed during resynchronization rather than
/// during a valid match operation. For example, we will create this kind of a
/// node during single token insertion and deletion as well as during "consume
/// until error recovery set" upon no viable alternative exceptions.
class ErrorNode extends TerminalNode {
  ErrorNode(Token token) : super(token);

  T accept<T>(ParseTreeVisitor<T> visitor) => visitor.visitErrorNode(this);
}
