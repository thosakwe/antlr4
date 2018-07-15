import '../contexts.dart';
import 'parse_tree.dart';

class ParseTreeWalker {
  static final ParseTreeWalker DEFAULT = new ParseTreeWalker();

  void walk(ParseTreeListener listener, ParseTree tree) {
    if (tree is ErrorNode) {
      listener.visitErrorNode(tree);
      return;
    } else if (tree is TerminalNode) {
      listener.visitTerminal(tree);
      return;
    }
    enterRule(listener, tree as RuleNode);
    int n = tree.childCount;
    for (int i = 0; i < n; i++) {
      walk(listener, tree.getChild(i) as ParseTree);
    }
    exitRule(listener, tree as RuleNode);
  }

  void enterRule(ParseTreeListener listener, RuleNode ruleNode) {
    ParserRuleContext context = (ruleNode as ParserRuleContext).ruleContext;
    listener.enterEveryRule(context);
    context.enterRule(listener);
  }

  void exitRule(ParseTreeListener listener, RuleNode ruleNode) {
    ParserRuleContext context = (ruleNode as ParserRuleContext).ruleContext;
    context.exitRule(listener);
    listener.exitEveryRule(context);
  }
}
