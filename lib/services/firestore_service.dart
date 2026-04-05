import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';

/// Service for Firestore CRUD and realtime reads.
class FirestoreService {
  static bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Collections
  static const String ordersCollection = 'orders';
  static const String usersCollection = 'users';
  static const String messagesCollection = 'messages';
  static const String ratingsCollection = 'ratings';

  // ===== ORDER OPERATIONS =====

  /// Stream all orders, newest first.
  Stream<List<DeliveryOrder>> watchAllOrders() {
    if (!isFirebaseReady) {
      debugPrint(
        'watchAllOrders skipped: Firebase chưa được khởi tạo (No default app).',
      );
      return Stream<List<DeliveryOrder>>.value(const <DeliveryOrder>[]);
    }

    return _firestore
        .collection(ordersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => _mapDocToOrder(doc))
              .toList(growable: false),
        );
  }

  /// Create a new order.
  Future<String> createOrder(DeliveryOrder order) async {
    try {
      final docRef = _firestore.collection(ordersCollection).doc(order.id);
      final data = order.toMap();
      data['updatedAt'] = Timestamp.now();

      await docRef.set(data);
      return order.id;
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Read an order by ID.
  Future<DeliveryOrder?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore
          .collection(ordersCollection)
          .doc(orderId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return _mapDocToOrder(doc);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  /// Read orders by role.
  Future<List<DeliveryOrder>> getUserOrders(
    String userId, {
    String role = 'sender',
  }) async {
    try {
      Query<Map<String, dynamic>> query;

      switch (role) {
        case 'sender':
          query = _firestore
              .collection(ordersCollection)
              .where('senderId', isEqualTo: userId);
          break;
        case 'receiver':
          query = _firestore
              .collection(ordersCollection)
              .where('receiverId', isEqualTo: userId);
          break;
        case 'carrier':
          query = _firestore
              .collection(ordersCollection)
              .where('carrierId', isEqualTo: userId);
          break;
        default:
          throw Exception('Invalid role');
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => _mapDocToOrder(doc))
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting user orders: $e');
      return <DeliveryOrder>[];
    }
  }

  /// Read orders by status.
  Future<List<DeliveryOrder>> getOrdersByStatus(String status) async {
    try {
      final querySnapshot = await _firestore
          .collection(ordersCollection)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => _mapDocToOrder(doc))
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting orders by status: $e');
      return <DeliveryOrder>[];
    }
  }

  /// Read available orders near a carrier.
  Future<List<DeliveryOrder>> getAvailableOrdersNearby(
    Location userLocation, {
    double radiusKm = 5.0,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(ordersCollection)
          .where('status', isEqualTo: 'waitingCarrier')
          .get();

      final orders = querySnapshot.docs
          .map((doc) => _mapDocToOrder(doc))
          .toList(growable: false);

      return orders
          .where((order) {
            final pickupLocation = order.pickupLocation ?? order.senderLocation;
            final deliveryLocation =
                order.deliveryLocation ?? order.receiverLocation;
            final pickupDistance = userLocation.distanceTo(pickupLocation);
            final deliveryDistance = userLocation.distanceTo(deliveryLocation);

            return pickupDistance <= radiusKm && deliveryDistance <= radiusKm;
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error getting nearby orders: $e');
      return <DeliveryOrder>[];
    }
  }

  /// Update order status.
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'status': newStatus,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  /// Accept an order and assign carrier.
  Future<void> acceptOrder(String orderId, String carrierId) async {
    try {
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'carrierId': carrierId,
        'status': 'waitingDelivery',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error accepting order: $e');
      rethrow;
    }
  }

  /// Update sender/receiver locations before an order is accepted.
  Future<void> updateOrderLocations({
    required String orderId,
    required String actorUserId,
    required Location senderLocation,
    required Location receiverLocation,
  }) async {
    final docRef = _firestore.collection(ordersCollection).doc(orderId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Không tìm thấy đơn hàng để cập nhật địa chỉ.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'waitingCarrier';
        final carrierId = (data['carrierId'] as String?)?.trim() ?? '';
        final createdBy = (data['createdBy'] as String?)?.trim() ?? '';
        final senderId = (data['senderId'] as String?)?.trim() ?? '';
        final actorId = actorUserId.trim();

        final canEditByRole =
            actorId.isNotEmpty && (actorId == createdBy || actorId == senderId);
        if (!canEditByRole) {
          throw StateError('Bạn không có quyền sửa địa chỉ đơn này.');
        }

        final canEditByOrderState =
            status == 'waitingCarrier' && carrierId.isEmpty;
        if (!canEditByOrderState) {
          throw StateError(
            'Đơn đã có người nhận hoặc không còn ở trạng thái chờ nhận.',
          );
        }

        transaction.update(docRef, {
          'senderLocation': senderLocation.toMap(),
          'receiverLocation': receiverLocation.toMap(),
          'updatedAt': Timestamp.now(),
        });
      });
    } catch (e) {
      debugPrint('Error updating order locations: $e');
      rethrow;
    }
  }

  /// Update pickup location and move to waitingDelivery.
  Future<void> updatePickupLocation(
    String orderId,
    Location pickupLocation,
  ) async {
    try {
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'pickupLocation': pickupLocation.toMap(),
        'status': 'waitingDelivery',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating pickup location: $e');
      rethrow;
    }
  }

  /// Update delivery location and mark completed.
  Future<void> updateDeliveryLocation(
    String orderId,
    Location deliveryLocation,
  ) async {
    try {
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'deliveryLocation': deliveryLocation.toMap(),
        'status': 'completed',
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating delivery location: $e');
      rethrow;
    }
  }

  /// Update delivery deadline.
  Future<void> updateOrderDeadline(String orderId, DateTime deadlineAt) async {
    try {
      final timestamp = Timestamp.fromDate(deadlineAt);
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'deadline': timestamp,
        'deadlineAt': timestamp,
        'deadline_at': timestamp,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating order deadline: $e');
      rethrow;
    }
  }

  /// Cancel an order.
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    try {
      await _firestore.collection(ordersCollection).doc(orderId).update({
        'status': 'cancelled',
        'cancelReason': reason?.trim().isEmpty == true ? null : reason?.trim(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      rethrow;
    }
  }

  /// Watch a single order in real time.
  Stream<DeliveryOrder?> watchOrder(String orderId) {
    if (!isFirebaseReady) {
      debugPrint(
        'watchOrder skipped: Firebase chưa được khởi tạo (No default app).',
      );
      return Stream<DeliveryOrder?>.value(null);
    }

    return _firestore.collection(ordersCollection).doc(orderId).snapshots().map(
      (doc) {
        if (!doc.exists) {
          return null;
        }
        return _mapDocToOrder(doc);
      },
    );
  }

  // ===== USER OPERATIONS =====

  /// Create or update a user profile.
  Future<void> saveUserProfile({
    required String userId,
    required String name,
    required String email,
    required bool isVerified,
    String? accountId,
    String? avatarUrl,
    String? phone,
    String? address,
    String? birthday,
    double? rating,
    int? ratingCount,
    double? ratingSum,
    int? totalDeliveries,
  }) async {
    try {
      final normalizedUserId = userId.trim();
      final normalizedAccountId = accountId?.trim().isEmpty == true
          ? null
          : accountId?.trim();

      if (normalizedAccountId != null) {
        final isTaken = await isAccountIdTaken(
          normalizedAccountId,
          excludeUserId: normalizedUserId,
        );
        if (isTaken) {
          throw StateError('Mã tài khoản đã tồn tại.');
        }
      }

      final data = <String, dynamic>{
        'id': normalizedUserId,
        'accountId': normalizedAccountId,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'birthday': birthday,
        'avatarUrl': avatarUrl,
        'isVerified': isVerified,
        'updatedAt': Timestamp.now(),
      };

      if (rating != null) {
        data['rating'] = rating;
      }
      if (ratingCount != null) {
        data['ratingCount'] = ratingCount;
      }
      if (ratingSum != null) {
        data['ratingSum'] = ratingSum;
      }
      if (totalDeliveries != null) {
        data['totalDeliveries'] = totalDeliveries;
      }

      await _firestore
          .collection(usersCollection)
          .doc(normalizedUserId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }

  /// Read a user profile.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return doc.data();
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  /// Read the rating count stored on the user document.
  Future<int> getUserRatingCount(String userId) async {
    try {
      final normalizedUserId = userId.trim();
      if (normalizedUserId.isEmpty) {
        return 0;
      }

      final doc = await _firestore
          .collection(usersCollection)
          .doc(normalizedUserId)
          .get();

      if (!doc.exists) {
        return 0;
      }

      final data = doc.data() ?? <String, dynamic>{};
      return (data['ratingCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting user rating count: $e');
      return 0;
    }
  }

  /// Read a user profile by account code.
  Future<Map<String, dynamic>?> getUserProfileByAccountId(
    String accountId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('accountId', isEqualTo: accountId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    } catch (e) {
      debugPrint('Error getting user profile by accountId: $e');
      return null;
    }
  }

  /// Check if a username already exists.
  Future<bool> isUserNameTaken(String name) async {
    try {
      final snapshot = await _firestore
          .collection(usersCollection)
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  /// Check if an account code already exists for another user.
  Future<bool> isAccountIdTaken(
    String accountId, {
    String? excludeUserId,
  }) async {
    try {
      final normalizedAccountId = accountId.trim();
      if (normalizedAccountId.isEmpty) {
        return false;
      }

      final snapshot = await _firestore
          .collection(usersCollection)
          .where('accountId', isEqualTo: normalizedAccountId)
          .limit(10)
          .get();

      return snapshot.docs.any((doc) => doc.id != excludeUserId);
    } catch (e) {
      debugPrint('Error checking accountId: $e');
      return false;
    }
  }

  /// Check if a phone number already exists for another user.
  Future<bool> isPhoneTaken(String phone, {String? excludeUserId}) async {
    try {
      final normalizedPhone = phone.trim();
      if (normalizedPhone.isEmpty) {
        return false;
      }

      final snapshot = await _firestore
          .collection(usersCollection)
          .where('phone', isEqualTo: normalizedPhone)
          .limit(10)
          .get();

      return snapshot.docs.any((doc) => doc.id != excludeUserId);
    } catch (e) {
      debugPrint('Error checking phone number: $e');
      return false;
    }
  }

  /// Save bank account data.
  Future<void> saveUserBankAccount({
    required String userId,
    required String accountNumber,
    required String bankName,
  }) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).set({
        'bankAccountNumber': accountNumber,
        'bankName': bankName,
        'bankUpdatedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving bank account: $e');
      rethrow;
    }
  }

  /// Save verification image.
  Future<void> saveUserVerification({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).set({
        'verificationImageUrl': imageUrl,
        'verificationStatus': 'pending',
        'verificationSubmittedAt': Timestamp.now(),
        'verificationUpdatedAt': Timestamp.now(),
        'isVerified': false,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving verification: $e');
      rethrow;
    }
  }

  // ===== MESSAGE OPERATIONS =====

  /// Send a chat message.
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String message,
  }) async {
    try {
      final messageRef = _firestore
          .collection(ordersCollection)
          .doc(orderId)
          .collection(messagesCollection)
          .doc();

      await messageRef.set({
        'id': messageRef.id,
        'senderId': senderId,
        'message': message,
        'createdAt': Timestamp.now(),
        'delivered': false,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Read chat messages.
  Future<List<Map<String, dynamic>>> getMessages(
    String orderId, {
    int limit = 50,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(ordersCollection)
          .doc(orderId)
          .collection(messagesCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// Watch chat messages in real time.
  Stream<List<Map<String, dynamic>>> watchMessages(String orderId) {
    if (!isFirebaseReady) {
      debugPrint(
        'watchMessages skipped: Firebase chưa được khởi tạo (No default app).',
      );
      return Stream<List<Map<String, dynamic>>>.value(
        const <Map<String, dynamic>>[],
      );
    }

    return _firestore
        .collection(ordersCollection)
        .doc(orderId)
        .collection(messagesCollection)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ===== RATING OPERATIONS =====

  /// Save a rating and update the target user's average directly.
  Future<void> saveRating({
    required String orderId,
    required String ratedUserId,
    required String raterUserId,
    required double rating,
    String? comment,
  }) async {
    try {
      final normalizedOrderId = orderId.trim();
      final normalizedRatedUserId = ratedUserId.trim();
      final normalizedRaterUserId = raterUserId.trim();
      if (normalizedOrderId.isEmpty ||
          normalizedRatedUserId.isEmpty ||
          normalizedRaterUserId.isEmpty) {
        throw ArgumentError('Thiếu thông tin đánh giá.');
      }
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Điểm đánh giá phải nằm trong khoảng từ 1 đến 5.');
      }

      final ratingRef = _firestore
          .collection(ordersCollection)
          .doc(normalizedOrderId)
          .collection(ratingsCollection)
          .doc(normalizedRaterUserId);

      final userRef = _firestore
          .collection(usersCollection)
          .doc(normalizedRatedUserId);

      await _firestore.runTransaction((transaction) async {
        final existingRatingSnapshot = await transaction.get(ratingRef);
        final userSnapshot = await transaction.get(userRef);

        final existingRatingData = existingRatingSnapshot.data();
        final previousRating = (existingRatingData?['rating'] as num?)
            ?.toDouble();
        final createdAt = existingRatingSnapshot.exists
            ? (existingRatingData?['createdAt'] as Timestamp?) ??
                  Timestamp.now()
            : Timestamp.now();

        final userData = userSnapshot.data() ?? <String, dynamic>{};
        final hasRatingStats =
            userData.containsKey('ratingCount') ||
            userData.containsKey('ratingSum');
        final currentCount = (userData['ratingCount'] as num?)?.toInt() ?? 0;
        final currentSum =
            (userData['ratingSum'] as num?)?.toDouble() ??
            ((userData['rating'] as num?)?.toDouble() ?? 0.0) * currentCount;

        double nextSum;
        int nextCount;

        if (!hasRatingStats || currentCount <= 0) {
          nextCount = 1;
          nextSum = rating;
        } else if (previousRating == null) {
          nextCount = currentCount + 1;
          nextSum = currentSum + rating;
        } else {
          nextCount = currentCount;
          nextSum = currentSum + rating - previousRating;
        }

        final nextAverage = nextCount > 0 ? nextSum / nextCount : rating;

        transaction.set(ratingRef, {
          'orderId': normalizedOrderId,
          'ratedUserId': normalizedRatedUserId,
          'raterUserId': normalizedRaterUserId,
          'rating': rating,
          'comment': comment,
          'createdAt': createdAt,
          'updatedAt': Timestamp.now(),
        });

        transaction.set(userRef, {
          'rating': nextAverage,
          'ratingCount': nextCount,
          'ratingSum': nextSum,
          'updatedAt': Timestamp.now(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Error saving rating: $e');
      rethrow;
    }
  }

  // ===== HELPER METHODS =====

  /// Convert a Firestore document to an order model.
  DeliveryOrder _mapDocToOrder(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DeliveryOrder.fromMap(
      doc.data() ?? <String, dynamic>{},
      fallbackId: doc.id,
    );
  }
}
