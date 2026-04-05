# UniSend - Tài liệu UI/UX và logic Order hiện tại

Tài liệu này mô tả trạng thái code hiện tại của ứng dụng, tập trung vào:

1. Logic user id
2. Logic màn hình đơn hàng
3. Cách UI ràng buộc thao tác theo dữ liệu

Phạm vi tài liệu: chỉ mô tả UI/UX và logic hiển thị trên ứng dụng. Không chỉnh sửa và không mở rộng phần Firebase.

## 1. Tổng quan giao diện

Ứng dụng dùng Material 3, hỗ trợ theme sáng/tối, và điều hướng chính qua 4 tab:

1. Bản đồ
2. Đơn hàng
3. Trò chuyện
4. Hồ sơ

Luồng vào app:

1. Nếu xác thực sẵn sàng: theo luồng đăng nhập bình thường.
2. Nếu chạy bypass/UI-only: vào thẳng màn hình chính để thao tác giao diện.

## 2. Trạng thái dữ liệu đơn hàng hiện tại

Đã xóa toàn bộ dữ liệu test seed sẵn trong service đơn hàng.

Hệ quả hiện tại:

1. Màn danh sách đơn khởi tạo rỗng.
2. Đơn mới xuất hiện khi người dùng tạo đơn từ form tạo đơn.
3. Không còn bộ ORD-DEMO hoặc danh sách user demo được nạp sẵn khi khởi động.

## 3. Logic user id hiện tại

### 3.1 Nguồn current user

`current_user_id` được lấy theo thứ tự:

1. UID Firebase nếu có phiên đăng nhập.
2. Nếu không có phiên đăng nhập, dùng định danh local trung tính là `local_user`.

### 3.2 Khi tạo đơn

Form tạo đơn hỗ trợ 2 trường hợp:

1. Tạo đơn thường: người dùng hiện tại là người gửi.
2. Tạo đơn hộ: cho phép nhập người gửi khác.

Luôn lưu thêm `created_by` bằng người dùng hiện tại để truy vết người tạo thao tác.

### 3.3 Về ảnh đơn

Ảnh trong giai đoạn hiện tại phục vụ hiển thị UI và không dùng để gán quyền thao tác đơn hàng.

## 4. Logic phân quyền thao tác Order

### 4.1 Suy ra vai trò động từ dữ liệu

Không gán vai trò cố định cho user. Vai trò được suy ra động bằng cách so sánh `current_user_id` với:

1. `sender_id`
2. `receiver_id`
3. `carrier_id`
4. `created_by`

### 4.2 Điều kiện hiển thị và cho phép thao tác

Mỗi thao tác được ràng buộc bởi 3 lớp dữ liệu:

1. Vai trò suy ra từ id (ai được phép nhìn thấy nút).
2. Trạng thái đơn (`order_status`).
3. Cờ backend-style trên đơn (`canAccept`, `canMarkDelivered`, `canCancel`).

Hành vi UI:

1. Nếu không hợp lệ theo role hoặc trạng thái: ẩn nút.
2. Nếu hợp lệ nhưng backend từ chối: hiện nút ở trạng thái disable và ưu tiên hiển thị lý do từ chối.

## 5. Trình bày Order Card hiện tại

Order Card đã được tối giản theo hướng dễ đọc:

1. Chỉ hiển thị 1 trạng thái chính cho mỗi đơn.
2. Không hiển thị trực tiếp các field kỹ thuật như `created_by`, `sender_id`, `receiver_id`, `carrier_id`.
3. Chỉ giữ 1 thông điệp ngắn theo ngữ cảnh vai trò và trạng thái.
4. Ưu tiên nhận diện bằng màu sắc và icon thay vì nhiều dòng chữ.

## 6. Tóm tắt luồng thao tác hiện tại

1. Vào app và chọn tab Đơn hàng.
2. Nếu chưa có dữ liệu, màn hình hiển thị empty state theo từng trạng thái.
3. Tạo đơn từ tab Bản đồ qua form tạo đơn.
4. Quay lại tab Đơn hàng để theo dõi và thao tác theo quyền được suy ra từ dữ liệu.

## 7. Ghi chú phạm vi

Tài liệu này được cập nhật theo logic code hiện tại và việc loại bỏ dữ liệu test đã thêm, không thay đổi phần Firebase.

## 8. Cấu trúc thư mục `lib`

Phần `lib` của project được tổ chức theo hướng tách rõ entrypoint, dữ liệu, state, nghiệp vụ và UI:

1. `main.dart`: điểm khởi động ứng dụng, khởi tạo Firebase, Supabase, theme, provider và điều hướng đăng nhập / màn hình chính.
2. `models/`: chứa các model dữ liệu của đơn hàng, hiện có `order.dart` và `order_model.dart`.
3. `providers/`: quản lý state cho các luồng chính như đơn hàng và chat.
4. `services/`: chứa các service làm việc với session người dùng, auth, Firestore, Supabase storage, vị trí, đơn hàng và chat.
5. `views/auth/`: các màn hình đăng nhập và đăng ký.
6. `views/main/`: các màn hình chính của ứng dụng như bản đồ, danh sách đơn, chat, hồ sơ và navigation tổng.
7. `widgets/common/`: các widget dùng chung như `order_card`, `chat_bubble`, `user_avatar`.

## 9. Cách khởi chạy ứng dụng sau khi lấy code từ GitHub

Sau khi clone project về máy, chạy theo các bước sau:

1. Mở terminal tại thư mục gốc của project.
2. Chạy `flutter pub get` để tải dependency.
3. Chạy `flutter run` để mở ứng dụng trên thiết bị hoặc emulator đang kết nối.
4. Nếu muốn chạy nhanh và bỏ qua đăng nhập để test giao diện, dùng `flutter run --dart-define=BYPASS_LOGIN=true`.
5. Nếu chạy trên web, có thể chỉ định thêm device như `flutter run -d chrome`.

Nếu app dừng ở màn hình lỗi cấu hình Firebase, hãy kiểm tra lại cấu hình Firebase theo nền tảng đang chạy. Ứng dụng hiện khởi tạo Firebase và Supabase ngay khi mở app.

## 10. Luồng ứng dụng theo code hiện tại

Luồng chạy thực tế của app hiện tại như sau:

1. `main.dart` khởi tạo `Firebase`, `Supabase`, `UserSessionService`, `OrderService`, `ChatService`, `OrderProvider` và `ChatProvider`.
2. Nếu cấu hình Firebase lỗi, app dừng ở màn hình cảnh báo cấu hình. Nếu bật `BYPASS_LOGIN=true`, app vào thẳng màn hình chính.
3. Nếu không bypass, app dùng trạng thái đăng nhập của Firebase để quyết định hiển thị `LoginScreen` hay `MainNavigation`.
4. `LoginScreen` chỉ thực hiện đăng nhập bằng email và mật khẩu. `RegisterScreen` kiểm tra email `@gmail.com`, tạo tài khoản mới và lưu hồ sơ user vào Firestore.
5. Sau khi vào app, `MainNavigation` giữ 4 tab bằng `IndexedStack`: Bản đồ, Đơn hàng, Trò chuyện và Hồ sơ.
6. Tab Bản đồ lấy vị trí hiện tại, tải các đơn gần khu vực đang đứng, cho phép nhận đơn nhanh và mở form tạo đơn.
7. Form tạo đơn yêu cầu ảnh, mã người nhận, nội dung đơn, địa chỉ lấy hàng và địa chỉ giao hàng; sau đó upload ảnh và tạo bản ghi đơn mới.
8. Tab Đơn hàng lấy dữ liệu từ `OrderProvider`, tự lọc theo user hiện tại và account id, rồi chia theo các trạng thái chờ nhận, chờ giao, hoàn thành và đã hủy.
9. Khi người dùng nhận đơn, hoàn tất đơn, đổi deadline hoặc hủy đơn, thao tác được chạy qua `OrderProvider` rồi đẩy xuống service; sau khi nhận đơn thành công, app mở luôn room chat của đơn đó.
10. Tab Trò chuyện đọc danh sách room theo user hiện tại, tự chọn room đầu tiên nếu chưa chọn, hiển thị tin nhắn theo room đang mở và hỗ trợ gửi text hoặc ảnh.
11. Tab Hồ sơ tải dữ liệu user từ Firestore, đồng bộ `accountId` vào session service, cho phép đổi theme và xử lý các thao tác hồ sơ, avatar, xác thực.

Tóm lại, luồng chính của app là: khởi tạo dịch vụ nền -> xác thực hoặc bypass -> vào `MainNavigation` -> thao tác qua 4 tab dựa trên dữ liệu thật từ Firebase / Firestore / Supabase.
