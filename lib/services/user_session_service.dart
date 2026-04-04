import 'package:flutter/foundation.dart';

class UserSessionService extends ChangeNotifier {
  UserSessionService({required String initialUserId})
    : _currentUserId = initialUserId.trim().isEmpty
          ? 'local_user'
          : initialUserId.trim();

  String _currentUserId;
  String _currentAccountId = '';

  String get currentUserId => _currentUserId;
  String get currentAccountId => _currentAccountId;

  void setCurrentUserId(String userId) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || normalizedUserId == _currentUserId) {
      return;
    }

    _currentUserId = normalizedUserId;
    notifyListeners();
  }

  void setCurrentAccountId(String accountId) {
    final normalizedAccountId = accountId.trim();
    if (normalizedAccountId == _currentAccountId) {
      return;
    }

    _currentAccountId = normalizedAccountId;
    notifyListeners();
  }
}
