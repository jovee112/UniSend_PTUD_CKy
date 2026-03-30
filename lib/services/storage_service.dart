import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  // Khởi tạo client Supabase
  final _supabase = Supabase.instance.client;
  final _auth = FirebaseAuth.instance;

  /// Hàm upload ảnh dùng chung cho toàn bộ dự án
  /// [file]: File ảnh lấy từ ImagePicker
  /// [isAvatar]: true nếu là ảnh thẻ SV (vào bucket avatars), false nếu là ảnh đơn hàng (vào bucket orders)
  Future<String?> uploadImage(
      {required File file, bool isAvatar = false, String? orderId}) async {
    try {
      // 1. Xác định bucket
      final String bucketName = isAvatar ? 'avatars' : 'orders';

      // 2. Lấy UID người dùng hiện tại (từ Firebase Auth)
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) throw 'Người dùng chưa đăng nhập';

      // 3. Tạo đường dẫn file: userId/timestamp.jpg để tránh trùng lặp và dễ quản lý
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
      final String path = "$userId/$fileName";

      // 4. Chuẩn bị metadata theo policy
      final Map<String, String> metadata = {'user_id': userId};
      if (!isAvatar) {
        // Với ảnh đơn hàng bắt buộc có orderId theo policy
        if (orderId == null) throw 'orderId is required for order images';
        metadata['order_id'] = orderId;
      }

      // 5. Thực hiện upload lên Supabase Storage kèm metadata
      await _supabase.storage.from(bucketName).upload(
            path,
            file,
            fileOptions: FileOptions(
                cacheControl: '3600', upsert: false, metadata: metadata),
          );

      // 6. Lấy URL để sử dụng:
      // - Nếu là avatars (public), có thể lấy public URL.
      // - Nếu là orders (private), tạo signed URL tạm thời.
      String url;
      if (isAvatar) {
        url = _supabase.storage.from(bucketName).getPublicUrl(path);
      } else {
        // thời hạn 1 giờ (3600s)
        url = await _supabase.storage
            .from(bucketName)
            .createSignedUrl(path, 3600);
      }

      debugPrint('--- Upload thành công: $url');
      return url;
    } catch (e) {
      debugPrint('--- Lỗi StorageService: $e');
      return null;
    }
  }
}
