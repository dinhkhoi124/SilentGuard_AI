import 'package:equatable/equatable.dart';

enum SessionFailureKind {
  backendUnavailable,
  unauthorized,
  forbidden,
  other,
} // FIX: classify backend warm-up separately from real auth failures.

class SessionFailure extends Equatable {
  const SessionFailure(
    this.message, {
    this.kind = SessionFailureKind.other,
  }); // FIX: carry a typed failure kind without changing existing call sites.

  final String message;
  final SessionFailureKind
  kind; // FIX: let AuthNotifier/Home logic branch without parsing localized text.

  @override
  List<Object?> get props => [message, kind]; // FIX: equality must include the typed failure kind.
}
