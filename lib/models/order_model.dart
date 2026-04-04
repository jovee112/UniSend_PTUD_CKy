import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { waitingCarrier, waitingDelivery, completed, cancelled }

class Location {
  const Location({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;

  factory Location.fromMap(Map<String, dynamic> map) {
    final lat = map['lat'] ?? map['latitude'];
    final lng = map['lng'] ?? map['longitude'];

    return Location(
      latitude: (lat as num?)?.toDouble() ?? 0,
      longitude: (lng as num?)?.toDouble() ?? 0,
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      // Keep compatibility with old payload keys.
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  double distanceTo(Location other) {
    const earthRadius = 6371;
    final lat1Rad = _toRad(latitude);
    final lat2Rad = _toRad(other.latitude);
    final deltaLatRad = _toRad(other.latitude - latitude);
    final deltaLngRad = _toRad(other.longitude - longitude);

    final a =
        (1 - math.cos(deltaLatRad)) / 2 +
        math.cos(lat1Rad) * math.cos(lat2Rad) * (1 - math.cos(deltaLngRad)) / 2;
    final c = 2 * math.asin(math.sqrt(a.clamp(0, 1)));
    return earthRadius * c;
  }

  static double _toRad(double degree) => degree * 3.14159265359 / 180;
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.senderId,
    required this.receiverId,
    required this.senderLocation,
    required this.receiverLocation,
    required this.createdBy,
    required this.status,
    required this.createdAt,
    required this.deadlineAt,
    this.carrierId,
    this.pickupLocation,
    this.deliveryLocation,
    this.updatedAt,
    this.isLate = false,
    this.lateFee = 0,
    this.canAccept,
    this.canMarkDelivered,
    this.canCancel,
    this.acceptDeniedReason,
    this.markDeliveredDeniedReason,
    this.cancelDeniedReason,
  });

  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String senderId;
  final String receiverId;
  final String? carrierId;
  final String createdBy;
  final Location senderLocation;
  final Location receiverLocation;
  final Location? pickupLocation;
  final Location? deliveryLocation;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime deadlineAt;
  final DateTime? updatedAt;
  final bool isLate;
  final num lateFee;
  final bool? canAccept;
  final bool? canMarkDelivered;
  final bool? canCancel;
  final String? acceptDeniedReason;
  final String? markDeliveredDeniedReason;
  final String? cancelDeniedReason;

  bool get hasCarrier => carrierId != null && carrierId!.trim().isNotEmpty;
  bool get isDeadlineExceeded => DateTime.now().isAfter(deadlineAt);

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return OrderModel.fromMap(data, fallbackId: doc.id);
  }

  factory OrderModel.fromMap(Map<String, dynamic> data, {String? fallbackId}) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? fallback;
      }
      return fallback;
    }

    final now = DateTime.now();
    final createdAt = parseDate(data['created_at'] ?? data['createdAt'], now);
    final deadlineAt = parseDate(
      data['deadline'] ?? data['deadline_at'] ?? data['deadlineAt'],
      now.add(const Duration(hours: 4)),
    );
    final updatedAtRaw = data['updated_at'] ?? data['updatedAt'];

    return OrderModel(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : (fallbackId ?? ''),
      title: (data['title'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      imageUrl:
          (data['image_url'] as String?) ?? (data['imageUrl'] as String?) ?? '',
      senderId:
          (data['sender_id'] as String?) ?? (data['senderId'] as String?) ?? '',
      receiverId:
          (data['receiver_id'] as String?) ??
          (data['receiverId'] as String?) ??
          '',
      carrierId:
          (data['carrier_id'] as String?) ?? (data['carrierId'] as String?),
      createdBy:
          (data['created_by'] as String?) ??
          (data['createdBy'] as String?) ??
          '',
      senderLocation: data['senderLocation'] is Map<String, dynamic>
          ? Location.fromMap(data['senderLocation'] as Map<String, dynamic>)
          : const Location(latitude: 0, longitude: 0),
      receiverLocation: data['receiverLocation'] is Map<String, dynamic>
          ? Location.fromMap(data['receiverLocation'] as Map<String, dynamic>)
          : const Location(latitude: 0, longitude: 0),
      pickupLocation: data['pickupLocation'] is Map<String, dynamic>
          ? Location.fromMap(data['pickupLocation'] as Map<String, dynamic>)
          : null,
      deliveryLocation: data['deliveryLocation'] is Map<String, dynamic>
          ? Location.fromMap(data['deliveryLocation'] as Map<String, dynamic>)
          : null,
      status: _parseOrderStatus(
        (data['status'] as String?) ?? 'waitingCarrier',
      ),
      createdAt: createdAt,
      deadlineAt: deadlineAt,
      updatedAt: updatedAtRaw == null ? null : parseDate(updatedAtRaw, now),
      isLate: (data['is_late'] as bool?) ?? (data['isLate'] as bool?) ?? false,
      lateFee: (data['late_fee'] as num?) ?? (data['lateFee'] as num?) ?? 0,
      canAccept: data['canAccept'] as bool?,
      canMarkDelivered: data['canMarkDelivered'] as bool?,
      canCancel: data['canCancel'] as bool?,
      acceptDeniedReason: data['acceptDeniedReason'] as String?,
      markDeliveredDeniedReason: data['markDeliveredDeniedReason'] as String?,
      cancelDeniedReason: data['cancelDeniedReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'sender_id': senderId,
      'senderId': senderId,
      'receiver_id': receiverId,
      'receiverId': receiverId,
      'carrier_id': carrierId,
      'carrierId': carrierId,
      'created_by': createdBy,
      'createdBy': createdBy,
      'senderLocation': senderLocation.toMap(),
      'receiverLocation': receiverLocation.toMap(),
      'pickupLocation': pickupLocation?.toMap(),
      'deliveryLocation': deliveryLocation?.toMap(),
      'status': status.name,
      'created_at': Timestamp.fromDate(createdAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': Timestamp.fromDate(deadlineAt),
      'deadlineAt': Timestamp.fromDate(deadlineAt),
      'updated_at': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'is_late': isLate,
      'isLate': isLate,
      'late_fee': lateFee,
      'lateFee': lateFee,
      'canAccept': canAccept,
      'canMarkDelivered': canMarkDelivered,
      'canCancel': canCancel,
      'acceptDeniedReason': acceptDeniedReason,
      'markDeliveredDeniedReason': markDeliveredDeniedReason,
      'cancelDeniedReason': cancelDeniedReason,
    };
  }

  OrderModel copyWith({
    String? title,
    String? description,
    String? imageUrl,
    String? senderId,
    String? receiverId,
    Location? senderLocation,
    Location? receiverLocation,
    String? carrierId,
    bool clearCarrier = false,
    Location? pickupLocation,
    Location? deliveryLocation,
    String? createdBy,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? deadlineAt,
    DateTime? updatedAt,
    bool? isLate,
    num? lateFee,
    bool? canAccept,
    bool? canMarkDelivered,
    bool? canCancel,
    String? acceptDeniedReason,
    String? markDeliveredDeniedReason,
    String? cancelDeniedReason,
  }) {
    return OrderModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderLocation: senderLocation ?? this.senderLocation,
      receiverLocation: receiverLocation ?? this.receiverLocation,
      carrierId: clearCarrier ? null : (carrierId ?? this.carrierId),
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      deadlineAt: deadlineAt ?? this.deadlineAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isLate: isLate ?? this.isLate,
      lateFee: lateFee ?? this.lateFee,
      canAccept: canAccept ?? this.canAccept,
      canMarkDelivered: canMarkDelivered ?? this.canMarkDelivered,
      canCancel: canCancel ?? this.canCancel,
      acceptDeniedReason: acceptDeniedReason ?? this.acceptDeniedReason,
      markDeliveredDeniedReason:
          markDeliveredDeniedReason ?? this.markDeliveredDeniedReason,
      cancelDeniedReason: cancelDeniedReason ?? this.cancelDeniedReason,
    );
  }

  static OrderStatus _parseOrderStatus(String status) {
    switch (status) {
      case 'waitingCarrier':
        return OrderStatus.waitingCarrier;
      case 'waitingDelivery':
        return OrderStatus.waitingDelivery;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.waitingCarrier;
    }
  }
}

typedef DeliveryOrder = OrderModel;

class OrderActorFlags {
  const OrderActorFlags({
    required this.isSender,
    required this.isReceiver,
    required this.isCarrier,
    required this.isCreator,
  });

  final bool isSender;
  final bool isReceiver;
  final bool isCarrier;
  final bool isCreator;

  bool get isParticipant => isSender || isReceiver || isCarrier;
}

class OrderPermissions {
  const OrderPermissions({
    required this.acceptAction,
    required this.markDeliveredAction,
    required this.cancelAction,
  });

  final OrderActionConstraint acceptAction;
  final OrderActionConstraint markDeliveredAction;
  final OrderActionConstraint cancelAction;

  bool get hasAnyVisibleAction =>
      acceptAction.isVisible ||
      markDeliveredAction.isVisible ||
      cancelAction.isVisible;

  bool get hasAnyEnabledAction =>
      acceptAction.isEnabled ||
      markDeliveredAction.isEnabled ||
      cancelAction.isEnabled;
}

class OrderActionConstraint {
  const OrderActionConstraint({
    required this.isVisible,
    required this.isEnabled,
    this.deniedReason,
  });

  final bool isVisible;
  final bool isEnabled;
  final String? deniedReason;
}

class OrderPolicy {
  static OrderActorFlags resolveActors({
    required OrderModel order,
    required String currentUserId,
  }) {
    final normalizedCurrentUserId = currentUserId.trim();

    bool isSameUser(String? userId) {
      if (normalizedCurrentUserId.isEmpty || userId == null) {
        return false;
      }
      return userId.trim() == normalizedCurrentUserId;
    }

    return OrderActorFlags(
      isSender: isSameUser(order.senderId),
      isReceiver: isSameUser(order.receiverId),
      isCarrier: isSameUser(order.carrierId),
      isCreator: isSameUser(order.createdBy),
    );
  }

  static OrderPermissions resolvePermissions({
    required OrderModel order,
    required String currentUserId,
  }) {
    final actors = resolveActors(order: order, currentUserId: currentUserId);
    final bool canAcceptByRole =
        !actors.isSender && !actors.isReceiver && !actors.isCarrier;
    final bool canAcceptByStatus = order.status == OrderStatus.waitingCarrier;
    final bool canAcceptByBackend = order.canAccept ?? true;

    final acceptAction = OrderActionConstraint(
      isVisible: canAcceptByRole && canAcceptByStatus,
      isEnabled: canAcceptByRole && canAcceptByStatus && canAcceptByBackend,
      deniedReason: canAcceptByRole && canAcceptByStatus && !canAcceptByBackend
          ? (order.acceptDeniedReason ?? 'Hệ thống chưa cho phép nhận đơn này.')
          : null,
    );

    final bool canMarkDeliveredByRole = actors.isCarrier;
    final bool canMarkDeliveredByStatus =
        order.status == OrderStatus.waitingDelivery;
    final bool canMarkDeliveredByBackend = order.canMarkDelivered ?? true;

    final markDeliveredAction = OrderActionConstraint(
      isVisible: canMarkDeliveredByRole && canMarkDeliveredByStatus,
      isEnabled:
          canMarkDeliveredByRole &&
          canMarkDeliveredByStatus &&
          canMarkDeliveredByBackend,
      deniedReason:
          canMarkDeliveredByRole &&
              canMarkDeliveredByStatus &&
              !canMarkDeliveredByBackend
          ? (order.markDeliveredDeniedReason ??
                'Hệ thống chưa cho phép hoàn tất đơn này.')
          : null,
    );

    final bool canCancelByRole =
        actors.isSender ||
        actors.isReceiver ||
        actors.isCarrier ||
        actors.isCreator;
    final bool canCancelByStatus =
        order.status == OrderStatus.waitingCarrier ||
        order.status == OrderStatus.waitingDelivery;
    final bool canCancelByBackend = order.canCancel ?? true;

    final cancelAction = OrderActionConstraint(
      isVisible: canCancelByRole && canCancelByStatus,
      isEnabled: canCancelByRole && canCancelByStatus && canCancelByBackend,
      deniedReason: canCancelByRole && canCancelByStatus && !canCancelByBackend
          ? (order.cancelDeniedReason ?? 'Hệ thống từ chối yêu cầu hủy đơn.')
          : null,
    );

    return OrderPermissions(
      acceptAction: acceptAction,
      markDeliveredAction: markDeliveredAction,
      cancelAction: cancelAction,
    );
  }
}
