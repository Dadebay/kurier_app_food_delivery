import 'dart:convert';

/// A change the courier made while the phone had no signal.
///
/// Slide 8 of the proposal: "статусы копятся в телефоне и уходят на сервер,
/// когда связь появится". Every write the courier performs goes through this
/// queue, online or not — so there is exactly one code path and nothing can be
/// lost between them.
class PendingAction {
  PendingAction({
    required this.id,
    required this.kind,
    required this.path,
    required this.body,
    this.method = 'POST',
    required this.createdAt,
    this.attempts = 0,
  });

  final String id;
  final PendingActionKind kind;

  /// Endpoint this action replays against.
  final String path;
  final Map<String, dynamic> body;
  final String method;
  final DateTime createdAt;

  /// Bumped on every failed flush, shown in the sync banner for diagnostics.
  int attempts;

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
    id: json['id'] as String,
    kind: PendingActionKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => PendingActionKind.status,
    ),
    path: json['path'] as String,
    body: Map<String, dynamic>.from(json['body'] as Map),
    method: json['method'] as String? ?? 'POST',
    createdAt: DateTime.parse(json['created_at'] as String),
    attempts: json['attempts'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'path': path,
    'body': body,
    'method': method,
    'created_at': createdAt.toIso8601String(),
    'attempts': attempts,
  };

  String encode() => jsonEncode(toJson());

  static PendingAction decode(String raw) =>
      PendingAction.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

enum PendingActionKind {
  /// "забрал / еду / доставил"
  status,

  /// Cash + change confirmation.
  cash,

  /// Live position ping.
  ping,

  /// On shift / free toggle.
  shift,
}
