# Atoll Local

Phiên bản Atoll được tùy chỉnh cho máy Mac của Minh, với lịch sử Git riêng và không chạy các workflow phát hành/đồng bộ của dự án gốc.

## Các thay đổi chính

- Nền kính và bố cục nối liền với cụm camera, điều chỉnh chuyển động khi rê chuột.
- Phiên video trình duyệt ngừng phát tự ẩn sau 10 giây.
- Tiện ích cục bộ có công tắc bật/tắt; menu tiện ích dùng bảng bật lên.
- Home có nội dung thay thế khi tắt Calendar: hẹn giờ đang chạy hoặc đồng hồ, trạng thái và pet mèo xám tròn dạng pixel.
- Bản đóng gói Local chặn kết nối IP và một số đường dẫn thông tin đăng nhập; các chức năng cần mạng bị giới hạn.

## Dựng bản Local

Cần macOS và Xcode; SwiftTerm cần Metal Toolchain được cài trong Xcode. Các thư viện bên ngoài được Swift Package Manager tải theo file `Package.resolved`. Tài nguyên animation đã nằm trực tiếp trong repo, không cần Git LFS.

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DynamicIsland.xcodeproj -scheme DynamicIsland -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AtollDerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=local.atoll.validation build

ruby scripts/package-offline.rb /tmp/AtollDerivedData/Build/Products/Debug/Atoll.app
```

Script đóng gói cần chứng chỉ Apple Development hợp lệ trong Keychain, hoặc `ATOLL_SIGNING_IDENTITY` trỏ đến chứng chỉ ký có sẵn. Kết quả nằm ở `build/Atoll Local.app`.

**Chính sách offline chỉ được kích hoạt trong bản được đóng gói bằng script này.** App build thông thường chưa được gắn cờ `AtollLocalOfflineBuild`.

## Kiểm tra

```sh
ruby tests/test_idle_media_layout.rb
ruby tests/test_browser_session.rb
ruby tests/test_local_preferences.rb
ruby tests/test_download_settings.rb
ruby tests/test_utility_navigation.rb
ruby tests/test_idle_pet.rb
ruby tests/test_idle_pet_render.rb
ruby tests/test_offline_profile.rb
python3 -m unittest discover -s tests -p 'test_*.py'
```

Các kiểm tra SwiftUI/AppKit cần chạy trên macOS. Chi tiết thay đổi và những giới hạn đã kiểm tra: [Báo cáo bản Local](docs/LOCAL_PRIVACY_REVIEW.vi.md).

## Nguồn gốc và giấy phép

Dựa trên [Ebullioscopic/Atoll](https://github.com/Ebullioscopic/Atoll), snapshot gốc `0edae1b8ee28eb1e58832063ad88cc69ab762170`, và phần mềm từ boring.notch. Giữ nguyên các ghi nhận tác giả trong source và các tệp [LICENSE](LICENSE), [NOTICE](NOTICE), [COPYRIGHT_ASSETS](COPYRIGHT_ASSETS), [TRADEMARKS](TRADEMARKS). Mã nguồn áp dụng GPL v3 theo giấy phép đi kèm; tài nguyên có ghi nhận riêng trong các tệp này.
