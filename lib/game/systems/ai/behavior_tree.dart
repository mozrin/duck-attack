enum NodeStatus { success, failure, running }

abstract class Node {
  NodeStatus tick(double dt);
}

class Selector extends Node {
  Selector(this.children);
  final List<Node> children;

  @override
  NodeStatus tick(double dt) {
    for (final node in children) {
      final status = node.tick(dt);
      if (status != NodeStatus.failure) {
        return status;
      }
    }
    return NodeStatus.failure;
  }
}

class Sequence extends Node {
  Sequence(this.children);
  final List<Node> children;

  @override
  NodeStatus tick(double dt) {
    for (final node in children) {
      final status = node.tick(dt);
      if (status != NodeStatus.success) {
        return status;
      }
    }
    return NodeStatus.success;
  }
}

class ActionNode extends Node {
  ActionNode(this.action);
  final NodeStatus Function(double dt) action;

  @override
  NodeStatus tick(double dt) => action(dt);
}

class ConditionNode extends Node {
  ConditionNode(this.condition);
  final bool Function() condition;

  @override
  NodeStatus tick(double dt) {
    return condition() ? NodeStatus.success : NodeStatus.failure;
  }
}
