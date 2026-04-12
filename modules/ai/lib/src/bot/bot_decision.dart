class BotDecision {
  final String action;
  final double priority;
  final Map<String, dynamic> params;

  BotDecision(this.action, this.priority, [this.params = const {}]);
}
