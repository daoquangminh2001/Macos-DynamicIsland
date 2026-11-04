# Dựng và đóng gói Atoll Local

Bản cài dành cho Apple Silicon (M1 trở lên), macOS 14.6 trở lên. Người dùng bản cài không cần Xcode.

## Một lệnh đóng gói

Trên máy Mac có Xcode và Metal Toolchain:

```sh
ruby scripts/build-release.rb
```

Script yêu cầu các thay đổi source đã được commit, dựng Release arm64 và tạo:

- `build/Atoll-Local-AppleSilicon.dmg`: app, liên kết Applications, hướng dẫn và source ZIP.
- `build/Atoll-Local-Source.zip`: source đúng revision và các nguồn Swift Package Manager đang dùng.

Các phụ thuộc được Swift Package Manager tải theo `Package.resolved`. Source ZIP có thư mục `DependencySources` để lưu nguồn phụ thuộc; các framework nhị phân có sẵn từ upstream vẫn được giữ trong project.

Nếu đã có một Release arm64 vừa được dựng từ cùng source:

```sh
ATOLL_BUILT_APP=/tmp/AtollReleaseDerivedData/Build/Products/Release/Atoll.app ruby scripts/build-release.rb
```

Bản đóng gói có bundle ID riêng `local.atoll.private`, áp dụng `scripts/offline.sb` trước khi chạy ứng dụng. Build app thông thường chưa gắn cờ `AtollLocalOfflineBuild` sẽ không bật chính sách đó. Script ưu tiên chứng chỉ Apple Development trên máy; nếu không có sẽ ký ad hoc. Có thể chỉ định chứng chỉ có sẵn bằng `ATOLL_SIGNING_IDENTITY`.

## Chữ ký trên máy khác

Gói hiện tại chưa được Apple notarize. Chữ ký Development/ad hoc phục vụ build nội bộ; để phân phối với trải nghiệm Gatekeeper thuận tiện, cần chứng chỉ Developer ID Application và notarization của Apple. Không đính kèm chứng chỉ riêng, khóa ký, cài đặt hay lịch sử người dùng vào DMG/source ZIP.

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

Các bài kiểm tra SwiftUI/AppKit cần macOS. Xem [ghi chép kiểm tra bản Local](LOCAL_PRIVACY_REVIEW.vi.md) để biết các giới hạn thực tế.

Giữ nguyên [LICENSE](../LICENSE), [NOTICE](../NOTICE), [COPYRIGHT_ASSETS](../COPYRIGHT_ASSETS), [TRADEMARKS](../TRADEMARKS) và các ghi nhận của phụ thuộc.
