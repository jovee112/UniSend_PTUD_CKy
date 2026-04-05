# HƯỚNG DẪN SỬ DỤNG VÀ LƯU Ý KHI ĐƯA MÃ NGUỒN LÊN GIT

Tài liệu này được viết lại từ cấu trúc và logic hiện tại của project UniSend. Nội dung tập trung vào cách chạy ứng dụng, các chức năng đang có trong code, và đặc biệt là những điểm cần chú ý khi đưa mã nguồn lên Git.

## 1. Tổng quan project

UniSend là ứng dụng Flutter gồm 4 tab chính:

1. Bản đồ
2. Đơn hàng
3. Trò chuyện
4. Hồ sơ

Các thành phần chính đang dùng trong project:

1. Firebase Auth để đăng ký và đăng nhập.
2. Firestore để lưu hồ sơ, đơn hàng và dữ liệu chat.
3. Supabase Storage để lưu ảnh đơn hàng và ảnh liên quan.
4. GPS và OpenStreetMap để lấy vị trí và chọn địa chỉ trên bản đồ.

## 2. Cách chạy ứng dụng

### 2.1. Chạy bình thường

1. Mở terminal tại thư mục gốc của project.
2. Chạy `flutter pub get`.
3. Chạy `flutter run`.

### 2.2. Chạy nhanh để test giao diện

1. Chạy `flutter run --dart-define=BYPASS_LOGIN=true`.
2. Chế độ này bỏ qua màn hình đăng nhập và vào thẳng màn chính.

### 2.3. Lưu ý khi chạy thật

Nếu cấu hình Firebase sai, ứng dụng sẽ hiển thị màn lỗi cấu hình thay vì tự chuyển sang chế độ local.

## 3. Luồng sử dụng chính của người dùng

1. Người dùng mở ứng dụng.
2. Nếu chưa đăng nhập, người dùng đăng ký hoặc đăng nhập bằng email và mật khẩu.
3. Sau khi vào app, người dùng thao tác qua 4 tab chính.
4. Mỗi tab tương ứng với một nhóm chức năng riêng.

## 4. Chức năng theo từng tab

### 4.1. Tab Bản đồ

Tab Bản đồ dùng để xem vị trí, chọn địa chỉ và tạo đơn.

Chức năng chính:

1. Xin quyền GPS và lấy vị trí hiện tại.
2. Hiển thị bản đồ OpenStreetMap.
3. Xem danh sách đơn gần khu vực đang đứng.
4. Mở form tạo đơn hàng mới.

#### Tạo đơn hàng mới

Khi tạo đơn, người dùng cần:

1. Nhập tiêu đề đơn.
2. Nhập mã người nhận.
3. Chọn ảnh món hàng.
4. Chọn địa chỉ lấy hàng.
5. Chọn địa chỉ giao hàng.
6. Nhấn tạo đơn.

Hệ thống sẽ:

1. Upload ảnh lên Supabase.
2. Tạo bản ghi đơn trên Firestore.
3. Lưu đầy đủ vị trí lấy và giao hàng.

### 4.2. Tab Đơn hàng

Tab Đơn hàng dùng để theo dõi và xử lý vòng đời đơn hàng.

Các trạng thái hiển thị:

1. Chờ nhận đơn
2. Chờ giao hàng
3. Hoàn thành
4. Đã hủy

Chức năng chính:

1. Xem danh sách đơn theo thời gian thực.
2. Theo dõi hạn giao và thời gian đếm ngược.
3. Nhận đơn nếu có quyền.
4. Hoàn tất giao nếu là carrier của đơn.
5. Hủy đơn nếu có quyền hợp lệ.
6. Đổi deadline nếu có quyền sửa.

### 4.3. Tab Trò chuyện

Tab Trò chuyện dùng để giao tiếp theo từng đơn hàng.

Chức năng chính:

1. Xem danh sách phòng chat của người dùng hiện tại.
2. Chọn một phòng chat để xem nội dung.
3. Gửi tin nhắn văn bản.
4. Gửi ảnh trong chat.
5. Rời khỏi phòng chat nếu cần.

### 4.4. Tab Hồ sơ

Tab Hồ sơ dùng để quản lý thông tin cá nhân.

Chức năng chính:

1. Xem thông tin hồ sơ.
2. Cập nhật avatar.
3. Cập nhật thông tin liên hệ.
4. Xác thực tài khoản.
5. Đổi giao diện sáng hoặc tối.

## 5. Những điểm cần chú ý khi đưa mã nguồn lên Git

Đây là phần quan trọng nhất khi thầy nhắc “chú ý mã nguồn đưa lên git”.

### 5.1. Chỉ đẩy mã nguồn cần thiết

1. Chỉ commit file code, file cấu hình cần thiết và tài liệu.
2. Không đẩy file sinh tự động như build cache, log, thư mục tạm, file biên dịch.
3. Kiểm tra `.gitignore` trước khi push.

### 5.2. Không để lộ dữ liệu nhạy cảm

1. Không đưa key bí mật, token, mật khẩu thật lên Git nếu không cần thiết.
2. File cấu hình riêng từng máy hoặc từng môi trường nên được xử lý cẩn thận.
3. Với project này, cần chú ý các thông tin Firebase và Supabase trong code nguồn.

### 5.3. Trạng thái repo phải sạch

1. Code trên Git nên ở trạng thái chạy được.
2. Trước khi push nên kiểm tra không còn lỗi build hoặc lỗi phân tích.
3. Nên có README hoặc hướng dẫn chạy rõ ràng để người khác clone về dùng được.

### 5.4. Kiểm tra tài nguyên ảnh và asset

1. Ảnh dùng trong app phải được thêm đúng vào asset.
2. Đổi hoặc thêm logo thì phải kiểm tra lại đường dẫn và khai báo trong `pubspec.yaml`.
3. Nếu tạo icon app cho Android/iOS, cần chạy lại tool sinh icon sau khi thay ảnh.

### 5.5. Đảm bảo nội dung tài liệu đúng với code

1. Tài liệu trong repo phải phản ánh đúng trạng thái hiện tại của code.
2. Nếu đổi luồng chức năng, cần cập nhật lại file hướng dẫn và báo cáo liên quan.
3. Không để tài liệu mô tả tính năng đã xóa hoặc không còn tồn tại.

## 6. Quan hệ giữa các chức năng chính

1. Đăng ký và đăng nhập là điều kiện đầu vào để vào hệ thống.
2. Bản đồ là nơi khởi tạo luồng tạo đơn và tìm đơn gần vị trí.
3. Đơn hàng là nơi xử lý vòng đời đơn và các hành động như nhận, hoàn tất, hủy.
4. Trò chuyện phụ thuộc vào đơn hàng đã tồn tại và phòng chat được tạo từ đơn.
5. Hồ sơ cá nhân liên kết với session người dùng và ảnh hưởng tới thông tin hiển thị trong app.

## 7. Các lỗi thường gặp

1. Lỗi Firebase: kiểm tra cấu hình Android/iOS/Web.
2. Lỗi tải ảnh: kiểm tra Supabase bucket và quyền upload.
3. Lỗi GPS: kiểm tra quyền vị trí và dịch vụ định vị.
4. Không thấy đơn: kiểm tra đơn đã tạo thành công trên Firestore hay chưa.
5. Không thấy phòng chat: kiểm tra đơn đã được nhận thành công và user có trong participants hay không.

## 8. Checklist kiểm tra trước khi nộp Git

1. Chạy `flutter pub get`.
2. Chạy `flutter run` để kiểm tra app.
3. Kiểm tra README và file hướng dẫn đã đúng nội dung mới.
4. Đảm bảo không commit file rác hoặc file sinh tạm.
5. Xem lại các file có chứa thông tin cấu hình để tránh lộ dữ liệu không cần thiết.

## 9. Kết luận

Khi đưa mã nguồn lên Git, điều cần chú ý nhất là: chỉ đẩy mã nguồn cần thiết, không lộ dữ liệu nhạy cảm, repo phải chạy được và tài liệu phải khớp với code hiện tại. Với UniSend, các chức năng chính xoay quanh đăng nhập, tạo đơn, xử lý đơn, chat theo đơn và quản lý hồ sơ.
