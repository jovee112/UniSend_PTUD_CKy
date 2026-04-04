import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/user_session_service.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider({
    required OrderService orderService,
    required UserSessionService userSessionService,
  }) : _orderService = orderService,
       _userSessionService = userSessionService {
    _userSessionService.addListener(_onUserChanged);
    startListening();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _now = DateTime.now();
      notifyListeners();
    });
    _deadlineSyncTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      _orderService.markOverdueOrdersIfNeeded();
    });
  }

  final OrderService _orderService;
  final UserSessionService _userSessionService;

  StreamSubscription<List<OrderModel>>? _ordersSubscription;
  Timer? _countdownTicker;
  Timer? _deadlineSyncTicker;

  List<OrderModel> _orders = const <OrderModel>[];
  bool _isLoading = true;
  String? _error;
  DateTime _now = DateTime.now();
  final Set<String> _busyOrderIds = <String>{};

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get now => _now;

  bool isOrderBusy(String orderId) => _busyOrderIds.contains(orderId);

  void startListening() {
    if (_ordersSubscription != null) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    _ordersSubscription = _orderService.watchOrders().listen(
      (orders) {
        _orders = orders;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _ordersSubscription?.cancel();
    _ordersSubscription = null;
  }

  List<OrderModel> ordersByStatus(OrderStatus status) {
    return _orders
        .where((order) => order.status == status)
        .toList(growable: false);
  }

  Future<void> acceptOrder(String orderId, String currentUserId) async {
    await _runAction(
      orderId,
      () => _orderService.acceptOrder(orderId, currentUserId),
    );
  }

  Future<void> completeOrder(String orderId, String currentUserId) async {
    await _runAction(
      orderId,
      () => _orderService.completeOrder(orderId, currentUserId),
    );
  }

  Future<void> cancelOrder(String orderId, String currentUserId) async {
    await _runAction(
      orderId,
      () => _orderService.cancelOrder(orderId, currentUserId),
    );
  }

  Future<void> _runAction(
    String orderId,
    Future<void> Function() action,
  ) async {
    if (_busyOrderIds.contains(orderId)) {
      return;
    }

    _busyOrderIds.add(orderId);
    notifyListeners();

    try {
      await action();
    } finally {
      _busyOrderIds.remove(orderId);
      notifyListeners();
    }
  }

  void _onUserChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _userSessionService.removeListener(_onUserChanged);
    _countdownTicker?.cancel();
    _deadlineSyncTicker?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
