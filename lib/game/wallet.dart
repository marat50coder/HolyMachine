import 'package:flutter/foundation.dart';

/// Session-scoped FUNS balance. Shared between the game and the menu so quest
/// rewards and free-FUNS top-ups add to the same pot.
class Wallet extends ChangeNotifier {
  Wallet._();
  static final Wallet instance = Wallet._();

  double _balance = 1000;
  double get balance => _balance;

  void set(double value) {
    _balance = value < 0 ? 0 : value;
    notifyListeners();
  }

  void add(double amount) {
    _balance += amount;
    notifyListeners();
  }

  bool trySpend(double amount) {
    if (_balance < amount) return false;
    _balance -= amount;
    notifyListeners();
    return true;
  }
}
