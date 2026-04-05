# UniSend

Tài liệu này mô tả cấu trúc thư mục trong `lib` của dự án UniSend để dễ tra cứu nhanh các lớp chính của ứng dụng.

## Cấu trúc `lib`

```text
lib/
	main.dart
	models/
		1.gitkeep
		order.dart
		order_model.dart
	providers/
		chat_provider.dart
		order_provider.dart
	services/
		auth_service.dart
		chat_service.dart
		firestore_service.dart
		location_service.dart
		order_service.dart
		storage_service.dart
		user_session_service.dart
	views/
		auth/
			login_screen.dart
			register_screen.dart
		main/
			chat_screen.dart
			main_navigation.dart
			map_screen.dart
			order_list_screen.dart
			profile_screen.dart
	widgets/
		common/
			chat_bubble.dart
			order_card.dart
			user_avatar.dart
```

## Vai trò từng thư mục

`main.dart` là điểm vào của ứng dụng.

`models` chứa các lớp dữ liệu và mô hình nghiệp vụ liên quan đến đơn hàng.

`providers` quản lý trạng thái cho các luồng chính như chat và order.

`services` gom các lớp xử lý dữ liệu, xác thực, lưu trữ, vị trí và giao tiếp với Firebase hoặc nguồn dữ liệu liên quan.

`views` chứa toàn bộ màn hình giao diện, chia theo nhóm `auth` và `main`.

`widgets/common` chứa các widget dùng chung trong nhiều màn hình.

## Ghi chú nhanh

Các thư mục trong `views/main` đại diện cho 4 tab chính của ứng dụng: bản đồ, đơn hàng, trò chuyện và hồ sơ.

Nhóm `widgets/common` đang giữ các thành phần tái sử dụng cho UI như avatar người dùng, bong bóng chat và thẻ đơn hàng.

## Hướng dẫn lấy code từ GitHub

1. Mở terminal và chuyển đến thư mục bạn muốn lưu dự án.
2. Clone repository từ GitHub.
3. Chuyển vào thư mục dự án vừa tải về.

Ví dụ:

```bash
git clone https://github.com/jovee112/UniSend_PTUD_CKy.git
cd UniSend_PTUD_CKy
```

## Hướng dẫn chạy ứng dụng

1. Cài Flutter và đảm bảo môi trường hoạt động bình thường.
2. Chạy lệnh lấy dependency.
3. Mở emulator hoặc kết nối thiết bị thật.
4. Chạy ứng dụng.

Ví dụ:

```bash
flutter pub get
flutter run
```

Nếu muốn chạy trên Android emulator, bạn có thể khởi động emulator trước rồi mới chạy `flutter run`.
