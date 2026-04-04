import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/order_model.dart';

class OrderActionException implements Exception {
  const OrderActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OrderService {
  OrderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String ordersCollection = 'orders';
  static const String chatRoomsCollection = 'chat_rooms';

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection(ordersCollection);

  Stream<List<OrderModel>> watchOrders() {
    return _ordersRef.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map(OrderModel.fromFirestore)
          .toList(growable: false);
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<void> acceptOrder(String orderId, String currentUserId) async {
    final actorId = currentUserId.trim();
    if (actorId.isEmpty) {
      throw const OrderActionException('Thiếu thông tin người dùng hiện tại.');
    }

    final orderRef = _ordersRef.doc(orderId);
    final roomRef = _firestore.collection(chatRoomsCollection).doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final roomSnapshot = await transaction.get(roomRef);
      if (!snapshot.exists) {
        throw const OrderActionException('Không tìm thấy đơn hàng.');
      }

      final order = OrderModel.fromFirestore(snapshot);
      final actors = OrderPolicy.resolveActors(
        order: order,
        currentUserId: actorId,
      );

      if (order.status != OrderStatus.waitingCarrier) {
        throw const OrderActionException(
          'Đơn không còn ở trạng thái chờ nhận.',
        );
      }
      if (order.hasCarrier) {
        throw const OrderActionException('Đơn đã có người nhận trước đó.');
      }
      if (actors.isSender || actors.isReceiver) {
        throw const OrderActionException(
          'Người gửi/nhận không được phép nhận đơn này.',
        );
      }

      final now = Timestamp.now();
      transaction.update(orderRef, {
        'carrier_id': actorId,
        'carrierId': actorId,
        'status': OrderStatus.waitingDelivery.name,
        'updated_at': now,
        'updatedAt': now,
      });

      final participants = <String>{
        order.senderId,
        order.receiverId,
        actorId,
      }.where((e) => e.trim().isNotEmpty).toList(growable: false);
      if (!roomSnapshot.exists) {
        transaction.set(roomRef, {
          'id': roomRef.id,
          'order_id': order.id,
          'participants': participants,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        transaction.update(roomRef, {
          'participants': participants,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> completeOrder(String orderId, String currentUserId) async {
    final actorId = currentUserId.trim();
    if (actorId.isEmpty) {
      throw const OrderActionException('Thiếu thông tin người dùng hiện tại.');
    }

    final orderRef = _ordersRef.doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw const OrderActionException('Không tìm thấy đơn hàng.');
      }

      final order = OrderModel.fromFirestore(snapshot);
      if (order.status != OrderStatus.waitingDelivery) {
        throw const OrderActionException(
          'Đơn chưa ở trạng thái có thể hoàn tất.',
        );
      }
      if ((order.carrierId ?? '').trim() != actorId) {
        throw const OrderActionException(
          'Chỉ người nhận giao mới có thể hoàn tất đơn.',
        );
      }

      final now = Timestamp.now();
      transaction.update(orderRef, {
        'status': OrderStatus.completed.name,
        'updated_at': now,
        'updatedAt': now,
      });
    });
  }

  Future<void> cancelOrder(String orderId, String currentUserId) async {
    final actorId = currentUserId.trim();
    if (actorId.isEmpty) {
      throw const OrderActionException('Thiếu thông tin người dùng hiện tại.');
    }

    final orderRef = _ordersRef.doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      if (!snapshot.exists) {
        throw const OrderActionException('Không tìm thấy đơn hàng.');
      }

      final order = OrderModel.fromFirestore(snapshot);
      final actors = OrderPolicy.resolveActors(
        order: order,
        currentUserId: actorId,
      );

      if (!(actors.isSender ||
          actors.isReceiver ||
          actors.isCarrier ||
          actors.isCreator)) {
        throw const OrderActionException('Bạn không có quyền hủy đơn này.');
      }

      final isCancellable =
          order.status == OrderStatus.waitingCarrier ||
          order.status == OrderStatus.waitingDelivery;
      if (!isCancellable) {
        throw const OrderActionException(
          'Chỉ có thể hủy đơn đang chờ nhận hoặc đang giao.',
        );
      }

      final now = Timestamp.now();
      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'updated_at': now,
        'updatedAt': now,
      });
    });
  }

  Future<void> markOverdueOrdersIfNeeded() async {
    try {
      final snapshot = await _ordersRef
          .where('status', whereIn: const ['waitingCarrier', 'waitingDelivery'])
          .get();

      final now = DateTime.now();
      final updates = <Future<void>>[];
      for (final doc in snapshot.docs) {
        final order = OrderModel.fromFirestore(doc);
        if (order.status == OrderStatus.completed ||
            order.status == OrderStatus.cancelled) {
          continue;
        }
        if (order.isLate) {
          continue;
        }
        if (!now.isAfter(order.deadlineAt)) {
          continue;
        }

        final lateMinutes = now.difference(order.deadlineAt).inMinutes;
        final simulatedFee = (lateMinutes / 10).ceil() * 1000;

        updates.add(
          doc.reference.update({
            'is_late': true,
            'isLate': true,
            'late_fee': simulatedFee,
            'lateFee': simulatedFee,
            'updated_at': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }),
        );
      }

      if (updates.isNotEmpty) {
        await Future.wait(updates);
      }
    } catch (error, stackTrace) {
      debugPrint('markOverdueOrdersIfNeeded error: $error\n$stackTrace');
    }
  }
}
