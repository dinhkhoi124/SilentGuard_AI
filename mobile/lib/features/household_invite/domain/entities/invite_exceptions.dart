// lib/features/household_invite/domain/entities/invite_exceptions.dart

class InviteUserNotFoundException implements Exception {
  const InviteUserNotFoundException();
}

class InviteAlreadyMemberException implements Exception {
  const InviteAlreadyMemberException();
}

class InviteAlreadyPendingException implements Exception {
  const InviteAlreadyPendingException();
}
