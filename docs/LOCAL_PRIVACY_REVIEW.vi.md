# Atoll trên máy này: kiểm tra và bản riêng

Ngày kiểm tra: 04/11/2026. Source gốc: `0edae1b8ee28eb1e58832063ad88cc69ab762170`.

## Kết luận trong phạm vi đã kiểm tra

Chưa tìm thấy đường gửi dữ liệu cá nhân/token về máy chủ tác giả trong các luồng mạng đã rà soát. **Điều này không chứng minh phần mềm hoàn toàn không có hành vi đánh cắp dữ liệu.** Đây là kiểm tra source có trọng tâm, kiểm tra chữ ký và quan sát socket tại một thời điểm; không phải giám sát lưu lượng lâu dài hoặc dịch ngược toàn bộ ứng dụng.

Atoll có nhiều tính năng truy cập dữ liệu nhạy cảm ngoài việc hiển thị nhạc. Không nên xem ứng dụng này là công cụ chỉ đọc trạng thái phát nhạc.

## Những gì source thực hiện

| Tính năng | Dữ liệu đọc/gửi và điều kiện |
|---|---|
| LLM Usage Monitor | Mặc định tính năng tổng tắt; nếu bật thì các provider Claude/Codex/Cursor/Antigravity mặc định bật. Đọc log sử dụng và thông tin đăng nhập từ file, Keychain hoặc cơ sở dữ liệu ứng dụng. Token được dùng gọi API quota của dịch vụ tương ứng. Claude còn refresh token và ghi lại nguồn credential. Đây là quyền truy cập nhạy cảm, dù chưa thấy gửi token về tác giả. |
| Screen Assistant | Khi người dùng gửi tin, gửi tin nhắn và nội dung tệp/ảnh đính kèm tới nhà cung cấp AI đã chọn (Google/OpenAI/Anthropic/Groq hoặc endpoint local). Có công cụ chụp màn hình và ghi âm. Một số ảnh/âm thanh lưu trong Documents. API key của trợ lý được lưu bằng Defaults, không phải tất cả đều ở Keychain. |
| Clipboard | Mặc định bật và lưu lịch sử qua các lần mở ứng dụng. Có thể chứa dữ liệu nhạy cảm vừa sao chép. Luồng đã đọc lưu cục bộ; chưa thấy tự gửi clipboard lên Internet. |
| Thời tiết | Gửi tọa độ tới Open-Meteo để lấy dự báo/chất lượng không khí. Widget mặc định bật; vị trí còn phụ thuộc quyền macOS. |
| Nhạc/lời bài hát | Có truy vấn tên bài/nghệ sĩ, metadata hoặc ID bài tới iTunes/Spotify/lrclib/NetEase và tải artwork. Không chỉ đọc thông tin nhạc cục bộ. |
| Spotify Canvas | Có đăng nhập/cookie `sp_dc`, lấy token từ Spotify; tải bảng secret TOTP từ GitHub bên thứ ba `xyloflake/spot-secrets-go`. Luồng đã đọc gửi cookie tới Spotify, không tới URL bảng secret. |
| Cập nhật | Sparkle đọc appcast trên GitHub của dự án và tải bản cập nhật. Kiểm tra cập nhật tạo kết nối mạng, không phải bằng chứng đánh cắp dữ liệu. |
| Extensions/Shelf | Có RPC/XPC và chức năng chia sẻ tệp. Source hiện tại bind RPC vào `127.0.0.1` và `::1`, đồng thời kiểm tra peer; các chức năng vẫn cần được xem là quyền truy cập có sức ảnh hưởng. |

Các vị trí chính: `DynamicIsland/managers/LLMUsage/Quota/{ClaudeQuotaClient,CodexQuotaClient,CursorTokenStore,KeychainReader}.swift`, `AntigravityUsageProvider.swift`, `ScreenAssistantManager.swift`, `ClipboardManager.swift`, `LockScreenWeatherManager.swift`, `MusicManager.swift`, `SpotifyAuthManager.swift`, `services/Extensions/ExtensionRPCServer.swift`, `models/Constants.swift` và `Info.plist`.

## Bản 2.3.3 đã cài từ DMG

- `/Applications/Atoll.app` và ứng dụng trong DMG đều qua `codesign --verify --deep --strict`. Chữ ký hợp lệ không chứng minh ứng dụng không độc hại.
- SHA-256 executable đã cài trùng executable trong `Downloads/Atoll-2.3.3.dmg`: `ea6d4ace3555afce31f341182a173fd48b00cded42c4de05ac914cf41534edaa`.
- SHA-256 DMG: `bda40abaf9f5f8a69ede7bd838d5c1cc865e40dc5c8135bc1149413840003634`.
- Tiến trình gốc PID 5000 có socket `TCP *:9020 (LISTEN)` khi kiểm tra. Đây là bind wildcard thay vì chỉ loopback; khả năng máy khác truy cập còn phụ thuộc firewall và mạng. Source hiện tại đã sửa điều này. Không kiểm thử khai thác hoặc gửi lệnh điều khiển qua cổng.
- Không thấy socket Internet đã kết nối của tiến trình này trong lần chạy `lsof`. Quan sát đó không loại trừ kết nối trước/sau thời điểm kiểm tra, UDP ngắn hạn hoặc hoạt động qua dịch vụ hệ thống.
- Không có bằng chứng build tái lập để khẳng định binary DMG tương đương source checkout. `MediaRemoteAdapter.framework` và `NowPlayingTestClient` trong repo cũng là binary có sẵn; không được dịch ngược hoặc dựng lại từ source trong công việc này.

## Bản Atoll Local

Bản riêng giữ ứng dụng và các điều khiển cục bộ, với sửa lỗi media và một launcher áp dụng sandbox trước khi nạp AtollCore hoặc thư viện của nó:

- Chặn socket IP của ứng dụng và tiến trình con, gồm cả localhost. Giữ giao tiếp Unix cục bộ cần cho giao diện macOS. Không còn RPC TCP hoạt động trong bản này.
- Chặn đọc/ghi các vị trí thông dụng: `.claude`, `.claude.json`, `.codex`, `.config/codex`, `.ssh`, `.aws`, Keychains, dữ liệu Cursor và Antigravity. Chặn một số dịch vụ Keychain qua Mach lookup.
- Dùng tham số UserDefaults cho từng lần chạy để tắt LLM monitor/từng provider, Screen Assistant, clipboard/lưu lịch sử, extensions/chia sẻ tệp, terminal, thời tiết, lời bài hát và cập nhật tự động. Các tham số này không sửa cài đặt của ứng dụng gốc.
- Bundle ID riêng `local.atoll.private`; không mang theo credential hoặc lịch sử của bản gốc. Được ký ad hoc tại máy này, không phải bản được Apple notarize.
- Tự đăng ký khởi động khi đăng nhập lần đầu. Khi đăng ký thành công, lưu dấu để không bật lại nếu sau đó bạn chủ động tắt “Launch at login” trong Settings → General. macOS sẽ chạy launcher được bảo vệ của bundle, không chạy trực tiếp AtollCore.

Giới hạn: profile không phải App Sandbox toàn diện, không cấm đọc mọi tệp trên máy và không bảo đảm chặn mọi hành động gián tiếp qua dịch vụ macOS hoặc ứng dụng khác. Không chạy trực tiếp `Contents/MacOS/AtollCore`, vì thao tác đó bỏ qua launcher. `sandbox-exec` là cơ chế cũ của macOS; bản này cần kiểm tra lại khi nâng cấp hệ điều hành. Tính năng cần mạng (đăng nhập Spotify, lời bài hát online, thời tiết, AI, LocalSend, cập nhật...) sẽ không hoạt động. Điều khiển nhạc cục bộ không làm ứng dụng phát nhạc mất mạng: chỉ Atoll bị giới hạn.

## Lỗi Nothing Playing

Chế độ tối giản dựng màn hình trống bất kể `autoHideInactiveNotchMediaPlayer`; sizing còn cộng chỗ lời bài hát dù không có phiên nhạc. Bản sửa áp dụng cùng điều kiện tự ẩn cho chế độ tối giản và thu chiều cao phần media về padding, vẫn giữ timer/reminder. Nếu tắt tự ẩn có chủ ý, màn hình Nothing Playing vẫn được giữ. Nhạc tạm dừng với metadata thật vẫn được xem là một phiên nhạc, như hành vi hiện có.

Kiểm tra hồi quy chạy hàm sizing thật với fixture không chạm dữ liệu người dùng: trước sửa báo `Idle player must collapse to padding, got 230.0`; sau sửa qua các trường hợp idle/active, notch/pill, lyrics, tắt controls, timer và reminder.

## Dựng lại và kiểm tra

```sh
ruby tests/test_idle_media_layout.rb
ruby tests/test_offline_profile.rb
python3 -m unittest discover -s tests -p 'test_*.py'
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DynamicIsland.xcodeproj -scheme DynamicIsland -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/AtollDerivedData \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
ruby scripts/package-offline.rb /tmp/AtollDerivedData/Build/Products/Debug/Atoll.app
```

Xcode cần Metal Toolchain cho SwiftTerm. Máy này đã tải thành phần đó. DerivedData đặt ngoài đường dẫn repo để tránh lỗi cache của Xcode với tên thư mục chứa `%20`.

Các test profile dùng credential giả và socket loopback tạm; không đọc token thật, không refresh token tài khoản người dùng.

## Kết quả trên máy này

- Build Debug thành công bằng Xcode 26.6; bản đóng gói chỉ dành cho kiến trúc máy hiện tại (Apple silicon).
- Kiểm tra layout và profile offline đều qua; 7 test Python qua.
- Bộ XCTest: lần đầu 275/276 qua, `AppleMusicControllerTests.testManualTrackArtworkHandoffDelaysPosterBy225Milliseconds` timeout. Test này qua khi chạy riêng; chạy lại toàn bộ đạt 276/276. Có dấu hiệu nhạy với thời gian/scheduler, không sửa test hoặc logic artwork ngoài phạm vi lỗi media trống.
- Ứng dụng đóng gói và bản cài đều qua kiểm tra chữ ký ad hoc `codesign --verify --deep --strict`.
- Đã cài `/Applications/Atoll Local.app`, chạy qua launcher và kiểm tra tiến trình thật: truy vấn sandbox báo `network-outbound` bị từ chối, trong khi tiến trình kiểm tra bên ngoài không bị chặn; `lsof` không có socket mạng của AtollCore. Helper MediaRemote cục bộ vẫn chạy.
- macOS Background Task Management ghi nhận `local.atoll.private`, URL `/Applications/Atoll Local.app`, trạng thái `enabled, allowed, notified`. Dấu đăng ký trong ứng dụng là `localLaunchAtLoginConfigured = true`. Đã thử thoát/mở lại ứng dụng; chưa reboot máy.
- Đã thoát bản Atoll gốc; vẫn giữ nguyên file `/Applications/Atoll.app` và DMG tải về. Không xóa lịch sử/credential của bản gốc. Bản riêng bật chế độ tối giản như cấu hình cũ; những dữ liệu/cài đặt nhạy cảm không được sao chép.

Không kiểm thử phát nhạc thật, mọi ứng dụng nhạc hoặc tương tác GUI đầy đủ trên máy này. Bài kiểm tra lỗi media là kiểm tra sizing với fixture; cần bạn xác nhận cảm nhận giao diện trong sử dụng thực tế. Bản private dùng bundle ID riêng nên quyền macOS cũ không tự chuyển sang: chỉ cấp những quyền cần cho tính năng bạn sử dụng.

## Cập nhật: gỡ bản gốc, phiên browser và tác vụ nhanh

- Theo yêu cầu tiếp theo, đã chuyển `/Applications/Atoll.app` và DMG gốc trong Downloads vào Thùng rác; không xóa dữ liệu người dùng cũ.
- MediaRemote trên máy thực sự vẫn trả một phiên Safari `playing = true`, nhưng anchor đã cũ hơn thời lượng 163 giây của video rất nhiều. Controller cũ còn có thể biến anchor cũ thành thời gian hiện tại khi nhận chuyển trạng thái playing.
- Bản sửa kiểm tra anchor gốc trước bước đó. Với browser đã biết, phiên đang được báo phát nhưng đã vượt quá thời lượng hữu hạn hơn 5 giây được xóa. Kiểm tra lại mỗi giây ngay cả khi không có sự kiện mới. Giữ nguyên nhạc tạm dừng, livestream không có thời lượng và các ứng dụng nhạc native. Không đọc tab/lịch sử browser. **Đây không phải bộ dò đóng tab tức thời:** nếu browser vẫn báo trạng thái cũ và thời lượng chưa hết, metadata chung chưa đủ để xác định tab đã đóng; browser phát lặp mà không cập nhật anchor cũng có thể bị ẩn nhầm.
- Bổ sung menu nhanh của Atoll Local: khóa màn hình; giữ máy thức 30 phút/1 giờ/đến khi tắt; hẹn giờ 5/15/25/60 phút, tạm dừng/tiếp tục/dừng. Hẹn giờ đang chạy không bị ghi đè bằng preset mới. Dùng lại CaffeinateManager và TimerManager của dự án. Khóa màn hình dùng entry point hệ thống sẵn có trên máy, có báo lỗi nếu hệ điều hành bỏ API đó.
- Helper MediaRemote được dừng khi thoát ứng dụng; đã dọn những helper cũ bị orphan từ bản trước.
- Test hồi quy browser đã fail trước sửa, pass sau sửa. Layout/profile test vẫn pass. Bộ XCTest hiện tại chạy 276/276 pass. Kiểm tra entry khóa màn hình tồn tại cả bên trong profile; không thực sự khóa máy trong lúc kiểm tra. Chưa thử thao tác GUI cả ba tác vụ hay reboot.

## Cập nhật: mất biểu tượng và khung nghỉ trống

Đã quan sát cả bản trong Applications và bản mở trực tiếp từ DMG cùng chạy. Bản mới ngăn tạo thêm instance theo bundle ID. Đã thoát bản DMG và tháo volume đó.

Kiểm tra đúng tiến trình bằng Accessibility cho thấy menu của executable đã đổi tên AtollCore nằm ngoài màn hình ở `(-1, 944)`. Đã bỏ launcher đổi tên executable, giữ nguyên tên Atoll và áp dụng sandbox trực tiếp tại `AtollEntryPoint.main` trước khi dựng SwiftUI App. Sau sửa, biểu tượng mountain xuất hiện trên ảnh chụp và Accessibility trả tọa độ trong màn hình `(956, 4)`. Nhận định ban đầu quy mất biểu tượng cho IPC là quá sớm: icon nhìn thấy trong một lần kiểm tra trung gian thuộc test host, không phải bản local. Profile hiện chặn riêng IP outbound/inbound/bind và giữ Unix IPC; test kiểm tra TCP, UDP, listener IP, tiến trình con và Unix IPC được phép.

Khung nghỉ tối giản trước đó chỉ còn padding 28 điểm nên trống. Bản mới dành 72 điểm cho hàng tác vụ nhanh, với chữ trắng/giao diện tối trên nền notch đen. Timer/reminder vẫn giữ nguyên. Test sizing đã fail ở chiều cao 28 trước sửa và pass ở 72 sau sửa; 276 XCTest vẫn pass.

Theo phản hồi người dùng muốn thấy menu/tab đầy đủ, đã đặt `enableMinimalisticUI = false` cho bản đang cài. Các tác vụ nhanh vẫn có trong menu biểu tượng Atoll. Các đoạn mô tả AtollCore/launcher phía trên là lịch sử bản cũ: bản hiện tại chạy executable chuẩn `Contents/MacOS/Atoll`, policy được nạp trước khi tạo App, cài đặt nhạy cảm vẫn được ép tắt bằng volatile argument domain. Có thể xuất hiện lại hộp thoại quyền macOS sau thay đổi executable; quyền do người dùng quyết định.

## Cập nhật: biểu tượng tác vụ trên header

Theo yêu cầu tiếp theo, khóa màn hình và hẹn giờ được đưa thành nút biểu tượng cạnh Awake và Settings trên header notch; bỏ nhóm tác vụ tùy chỉnh khỏi menu bar. Nút hẹn giờ mở TimerPopover sẵn có, vẫn giữ tab Timer. Nút khóa dùng chung hàm khóa màn hình hiện có.

Awake không bị disable: kiểm tra Accessibility trả `enabled = true`; thử bật thực tế thấy `pmset -g assertions` ghi nhận `NoDisplaySleepAssertion` của tiến trình Atoll với tên `Atoll is keeping this Mac awake`. Popover trước đó thừa hưởng màu xám từ header nên trông như bị vô hiệu hóa. Đã đặt lại màu chữ theo `.primary` cho Awake và TimerPopover; biểu tượng cốc chuyển vàng khi đang bật. Khởi động lại để cài bản mới kết thúc phiên thử giữ thức; người dùng chọn thời lượng để bật lại. Bộ XCTest sau thay đổi này vẫn 276/276 pass.

Khi kiểm tra khởi động lại, sample tiến trình cho thấy main thread mắc trong `DownloadManager.init → requestDownloadsPermissionIfNeeded → contentsOfDirectory → open`. Đã tắt `enableDownloadListener` trong volatile policy của bản local và chỉ xin/đọc Downloads khi listener thực sự được bật; bản upstream vẫn giữ hành vi mặc định khi tính năng bật. Bộ XCTest sau guard khởi động tiếp tục đạt 276/276. Bản local không tự theo dõi thư mục tải xuống.

## Hiệu ứng kính

Bản local có công tắc **Hiệu ứng kính** tại Settings → General, mặc định bật và được lưu qua các lần mở ứng dụng. Thay đổi áp dụng ngay cho notch đang mở, các nút header và popover Awake/Timer. Nền local dùng NSVisualEffectView với material hudWindow, blending behindWindow và giao diện darkAqua trên các phiên bản macOS được hỗ trợ. Viền sáng mảnh và nền tối giữ độ tương phản của chữ. Notch đóng vẫn giữ nền đen để hòa vào camera. Tắt công tắc trả về nền phẳng; Reduce Transparency của macOS cũng tắt độ trong theo cài đặt hệ thống.

Đã kiểm tra ảnh giao diện khi bật kính; công tắc General được bật/tắt trực tiếp qua Accessibility, xác nhận giá trị lưu đổi 0/1 trong cùng PID của ứng dụng. Kết thúc kiểm tra để công tắc bật. Bộ XCTest của bản có công tắc đạt 276/276; chữ ký ad hoc được kiểm tra lại sau đóng gói.


## Cập nhật kính mờ và độ tương phản (04/11/2026)

Thay nền LocalGlassSurface bằng vật liệu kính mờ AppKit, giảm lớp phủ đen từ 42–50% xuống 16–24%, và đổi màu mặc định của header từ xám sang trắng 90% khi bật kính local. Giữ nền đặc khi bật Reduce Transparency. Không dùng đường dẫn NSGlassEffectView/CAFilter cho nền local này.

Build và 276/276 XCTest qua; ba kiểm tra Ruby (layout, profile offline, phiên browser) qua. Bản trong Applications đã được cập nhật và xác minh chữ ký. Chưa xác nhận trực quan đầy đủ: trong lúc công cụ điều khiển giao diện hoạt động, notch hiển thị HUD ghi màn hình thay cho bảng nội dung.


## Cập nhật phối hợp hệ thống, browser và độ trong (04/11/2026)

- Bản Local tắt riêng `enableScreenRecordingDetection` trong chính sách runtime: Atoll không tự chiếm notch hoặc tạo nút dừng ghi hình khi công cụ chụp/chia sẻ màn hình hoạt động. Chỉ báo và điều khiển ghi hình của macOS vẫn do hệ thống quản lý.
- Theo lựa chọn người dùng, phiên browser không phát hoặc có playbackRate bằng 0 tự ẩn sau 10 giây. Áp dụng cả khi thiếu thời lượng. Giữ baseline metadata/ảnh của adapter để các diff tiếp tục phát có thể khôi phục nội dung; phiên mới bắt đầu lại thời gian chờ. Không áp dụng timeout tạm dừng này cho player native.
- Đây là chính sách ẩn media ngừng phát, không phải phát hiện tab đóng: MediaRemote vẫn cung cấp metadata Safari cũ sau khi tab đã đóng. Không đọc tab, lịch sử hoặc yêu cầu quyền browser mới.
- Giảm độ đậm của vật liệu nền xuống 62%, lớp phủ đen xuống 6–10% để màu nền xuyên qua rõ hơn. Độ mờ cũng giảm theo độ đậm vật liệu; Reduce Transparency vẫn dùng nền đặc.


Xác minh bản cập nhật: build và 276/276 XCTest qua; kiểm tra Ruby cho browser, layout và profile offline qua; chữ ký bản Applications hợp lệ. Kiểm tra GUI sau khởi động lại: bảng Home mở được khi công cụ điều khiển màn hình hoạt động, không còn HUD ghi hình Atoll, metadata Safari cũ không còn trong cây Accessibility. Ảnh chụp riêng cửa sổ không đủ xác nhận màu wallpaper xuyên qua; chưa thử đóng một tab video mới hoặc phát lại một video thật.


## Cập nhật phản hồi và lịch (04/11/2026)

Bản Local giới hạn chờ hover ở 120 ms (trước mặc định 300 ms), spring mở 260 ms/đóng 240 ms (trước 420/450 ms), header xuất hiện cùng lúc thay vì delay thêm 100 ms. Đây là thay đổi thời gian phản hồi có chủ đích, chưa phải số đo FPS hay benchmark độ trễ đầu-cuối.

StandaloneCalendarView dùng một task theo ngày được chọn thay cho các lệnh tải cùng ngày ở onAppear/onChange. Khi căn ngày ban đầu, bỏ animation cuộn thứ hai 240 ms trong lúc notch đang mở. Bỏ hai gradient đen hình chữ nhật, thay bằng alpha mask mép cuộn và clip bo góc 10 pt. Chữ phụ/weekday sáng hơn; phần chú thích lịch có bóng mảnh riêng, không phủ tối nền kính hoặc tạo shadow cho toàn bộ ảnh/control.


## Kính mềm theo ảnh tham chiếu (04/11/2026)

Thay vật liệu hudWindow của LocalGlassSurface bằng lớp titlebar behindWindow nhẹ (22%) và glassEffect(.clear, in: shape) công khai của SwiftUI trên macOS 26. Viền phản sáng thay đổi theo hướng, không dùng ảnh nền chụp cố định, CAFilter hoặc NSGlassEffectView private cho đường dẫn này. Lớp tối 14–24% hỗ trợ chữ trắng mà vẫn giữ màu của nền xuyên qua. macOS cũ dùng behindWindow cùng viền; Reduce Transparency và tắt kính vẫn dùng nền đặc. Áp dụng cho notch mở và các popover dùng LocalGlassSurface.


## Sửa chuyển chế độ Minimalistic và thanh tác vụ (04/11/2026)

Khi bật/tắt Minimalistic, tính lại kích thước nội dung bằng cùng luồng open() đang dùng cho cửa sổ, gồm các màn hình phụ đang mở. Bật Minimalistic chuyển về Home để không mang chiều cao Notes/Clipboard/Timer từ chế độ thường sang. Hàng tác vụ lúc nghỉ dùng biểu tượng khóa, giữ thức, timer và cài đặt; tên nằm trong tooltip và accessibilityLabel. Menu thời lượng vẫn giữ chữ để chọn đúng tác vụ, không tự thực thi khi hover. Khung idle 340×64 pt, nút 32 pt. Kiểm tra sizing đã fail trước sửa và pass sau sửa; timer/reminder vẫn cộng chiều cao đúng. Bộ XCTest 276/276 qua.


Theo yêu cầu thu gọn tiếp: trạng thái Minimalistic chỉ có tác vụ dùng viên thuốc 240×56 pt, không dành chỗ cho header pin/camera trong nội dung. Cửa sổ nằm ngay dưới safeArea camera với khe 2 pt. Nội dung tác vụ có chiều cao riêng 32 pt, không cộng lặp chiều cao shell/header gây cắt đáy. Khi có player, timer hoặc reminder, dùng lại bố cục đủ chỗ cho nội dung tương ứng. Chuyển chiều cao khi xuất hiện/ẩn media dùng animation 180 ms. Kiểm tra sizing (idle/active, notch/pill, timer/reminder) và 276 XCTest đều qua.


## Sửa vị trí camera và chữ HUD (04/11/2026)

open() cập nhật notchSize/notchState trước khi yêu cầu đặt lại cửa sổ: điều kiện vị trí floating surface không còn đọc nhầm trạng thái đóng của frame trước. Trong Minimalistic, thông báo volume/brightness/backlight dùng bề mặt riêng 240×56 dưới safeArea camera, kể cả khi notch đang đóng. Một hàng biểu tượng, tên ngắn và phần trăm dùng fixedSize/monospacedDigit cho số; không áp dụng hiệu ứng chữ chuyển/blur của bố cục notch cũ.

Kiểm tra sizing có volume, brightness, backlight và nhạc; 276 XCTest qua. Kiểm tra GUI thực tế thấy “Độ sáng 40%” đầy đủ trong viên thuốc, không cắt chữ. Công cụ điều khiển không hỗ trợ phím XF86AudioRaiseVolume nên chưa tự kích được một lần tăng âm lượng bằng phím media. Chưa kiểm tra trên màn hình ngoài hoặc mọi mức scale.


## Thay đổi cuối: viên thuốc ôm tai thỏ (04/11/2026)

Theo yêu cầu mới, bỏ cách dịch cả cửa sổ xuống dưới camera. Shell neo tại mép trên như notch; chỉ nội dung chừa vùng camera. minimalisticCameraReservedHeight lấy max(safeAreaInsets.top, auxiliaryTopLeftArea.height), cộng bleed và khe 2 pt. Màn hình thực tế có camera 32 pt, bleed 4 pt, nên reserve 38 pt; cửa sổ Y=-4 và hàng tác vụ bắt đầu ở Y=34, dưới camera 2 pt. Trạng thái tác vụ 240×82 pt trên máy này; màn hình không notch thu còn 240×44. HUD thêm phần trống camera tương tự. Kích thước cửa sổ đo thực tế 240×98 gồm shadow/bleed, Y=-4 đúng với thiết kế ôm camera.

Đã sửa AppDelegate.shared sang tham chiếu weak được đăng ký ở applicationDidFinishLaunching để các lệnh điều chỉnh cửa sổ không phụ thuộc việc NSApplication.delegate có được SwiftUI bọc qua proxy hay không. Bộ sizing bao phủ camera reserve có/không notch, HUD và media; 276 XCTest qua. Đã kiểm tra ảnh bốn nút nằm dưới khoảng trống camera và đo frame live. Chưa thử trên nhiều máy hoặc màn hình ngoài.


Tinh chỉnh tỷ lệ theo phản hồi tiếp theo: viên thuốc tác vụ dài 268 pt, phần dưới camera còn 36 pt (hàng nút 28 + đệm 8), tổng 74 pt trên màn hình có reserve 38 pt. HUD dài 268 pt, hàng chữ 36 pt + đệm 8; giữ nguyên vùng camera. Build và bộ kiểm tra sizing qua; thay đổi này chỉ chỉnh tỷ lệ, không chạy lại toàn bộ XCTest vì không đổi logic tác vụ.


## Đổi thiết kế sang liền mạch với camera

Theo quyết định mới nhất, bỏ hình viên thuốc cho bề mặt Minimalistic trên màn hình có tai thỏ. Dùng NotchShape nối sát mép trên, góc trên 6 pt/góc dưới 18 pt; bỏ inset và khoảng nổi của kiểu island cho bề mặt này. Vẫn dành vùng camera ở phía trên nội dung để các biểu tượng và HUD nằm dưới tai thỏ. Giữ tỷ lệ gọn 330×70 trên màn hình đang dùng. Build và kiểm tra sizing qua; cài lại bằng bản sao sạch và xác minh chữ ký.

## Rê chuột và công tắc tiện ích (04/11/2026)

Bản Local chuyển Clipboard, lưu lịch sử Clipboard và Downloads từ khóa runtime sang lựa chọn cục bộ: chỉ đặt tắt khi chưa có giá trị lưu, sau đó tôn trọng công tắc và giữ qua khởi động lại. Không tự bật các tiện ích này. Profile chặn IP và credential không đổi; Screen Assistant vẫn không khả dụng và Cài đặt hiện giải thích rõ vì cần mạng. Những hạn chế khác của bản offline phía trên vẫn áp dụng.

DownloadManager giữ AnyCancellable của publisher cài đặt, sửa lỗi subscription bị hủy ngay sau init nên công tắc không điều khiển monitor khi ứng dụng đang chạy. Bỏ lần contentsOfDirectory đồng bộ dư thừa lúc khởi động; scan thực tế đã chạy trên hàng đợi utility. Hàng tác vụ nhanh trong Minimalistic quan sát enableCaffeinate/showCaffeinateIcon/enableTimerFeature thay vì luôn hiển thị và tự bật lại Caffeinate.

Hover local dùng smooth 0.28 giây thay cho bouncy; giới hạn thời gian chờ mở giảm từ 0.12 xuống 0.06 giây, spring mở/đóng 0.34/0.30 giây để chuyển tiếp ít gắt hơn. Thay đổi không chỉnh đường dẫn animation của bản upstream.

Minimalistic bổ sung biểu tượng Clipboard/Chọn màu khi bật tính năng và cho hiện icon; hỗ trợ panel/popover sẵn có. Chế độ Clipboard dạng tab dùng panel khi ở Minimalistic vì giao diện này không có tab. Kích thước 330×70 giữ nguyên, tối đa sáu biểu tượng 28 pt vẫn vừa hàng. Các popover dùng cờ giữ mở hiện có, xóa cờ khi đóng hoặc ẩn nút.

Kiểm tra chính sách lựa chọn local và vòng đời subscription Downloads qua fixture độc lập không đọc dữ liệu người dùng. 50 XCTest liên quan Downloads/Clipboard/Caffeinate qua; kiểm tra sizing và profile offline qua.

Lệnh Settings… vốn được khai báo nhưng chưa gắn vào Scene; đã gắn commands và phím Command–, để mở Cài đặt trực tiếp. Đây cũng là lối kiểm tra khi notch đang đóng.

Xác minh giao diện bản đã cài: Command–, mở Cài đặt; Downloads chuyển on→off→on, tùy chọn phụ khóa/mở theo; Clipboard chuyển on→off→on và trạng thái theo dõi Active khi bật. Giữ nguyên giá trị bật của hai tiện ích từ trước khi thử, giữ lưu lịch sử qua khởi động lại ở off. Screen Assistant hiển thị công tắc disabled và lý do offline đúng. Chưa đo độ mượt bằng frame timing hoặc thử hover trên mọi màn hình/scale.

## Rà toàn bộ tiện ích và truy cập trong Minimalistic

Theo phản hồi tiếp theo, phạm vi được mở rộng khỏi Clipboard/Downloads: ghi chú, lịch, gương camera, kệ tệp, thống kê hệ thống, hẹn giờ, giữ máy thức, chọn màu và Terminal. Settings của bản Local không còn ẩn các trang cấu hình khi bật Minimalistic. Nút … đưa các tiện ích được bật vào menu; các màn hình ghi chú/kệ tệp/thống kê/hẹn giờ/Terminal mở lại các view hiện có với chiều rộng tiêu chuẩn và vùng tránh camera, có nút trở về. Lịch/gương dùng popover. Nút … cũng có trên header khi đang phát nhạc.

TabSelectionView quan sát đầy đủ các cờ tính năng bằng @Default, cập nhật tab ngay khi bật/tắt và chuyển khỏi tab không còn tồn tại. Tắt Clipboard dừng monitor/đóng panel; tắt chọn màu đóng panel và không nhận mẫu trễ sau khi đã tắt. Tắt Terminal kết thúc shell của Atoll, đồng bộ trạng thái phím tắt và trở về home. Terminal trở thành lựa chọn cục bộ mặc định tắt nếu chưa có giá trị lưu; không bị ép tắt mỗi lần khởi động. Kết nối IP và các đường dẫn credential vẫn bị chặn cả trong tiến trình con.

Các tính năng bị khóa còn lại có lý do ngay dưới công tắc: AI/LLM quota, extensions, thời tiết, lời bài hát; recording detection vẫn khóa để tránh tranh chấp với tác vụ hệ thống theo yêu cầu trước đó. Không mở lại mạng hoặc đọc credential để khôi phục các mục này.

Menu native giữ notch mở khi đang chọn. Sau khi chọn một màn hình tiện ích, view model giữ mở cho đến khi con trỏ vào khung hoặc người dùng bấm ngoài; token độc lập với popover để không gỡ nhầm yêu cầu giữ mở của trình bày khác. Bộ test hồi quy sizing bao phủ các màn hình tiện ích; fixture navigation kiểm tra giữ mở và bảo toàn token khác. Bộ XCTest sau thay đổi logic: 276/276 qua. Thay đổi câu mô tả UI sau đó chỉ chạy build.

### Sửa tiếp menu tiện ích theo phản hồi thực tế

Menu … dạng NSMenu vẫn có trường hợp không thấy lựa chọn. Bản cuối thay riêng … bằng Button mở popover SwiftUI, danh sách nút chữ trắng có icon, chiều rộng 250 pt/chiều cao tối đa vùng xem 340 pt và cuộn khi cần; luôn có Cài đặt nên không bị bảng rỗng. Popover dùng một token giữ mở cho cả danh sách/lịch/gương; bỏ bộ quan sát NSMenu vừa thêm. Các menu preset Awake/Timer cũ không đổi.

Rà luồng chọn tiện ích tìm thấy didSet của coordinator còn ép mọi currentView về home khi Minimalistic bật. Bản Local nay cho phép các view cục bộ đã nêu; bản upstream và các view AI/extensions vẫn giữ hạn chế. Test hồi quy chạy policy production cho từng view và kiểm tra token navigation/popover độc lập.

Trang Lịch đưa Show calendar và Enable reminder live activity ra khỏi nhánh yêu cầu quyền, cho phép tắt/bật hiển thị ngay cả khi chưa cấp quyền. Chỉ dữ liệu sự kiện/lựa chọn tài khoản vẫn phụ thuộc quyền macOS. Trong lần kiểm tra giao diện, trạng thái quyền chuyển từ denied sang Full Access do thao tác bên ngoài công cụ; không tự bấm Request Access/cấp quyền bằng công cụ.

Kiểm tra GUI công tắc: Color Picker off→on→off, Stats off→on→off, Shelf on→off→on, Timer on→off→on, Keep Awake on→off→on; Terminal on→off→on; Notes off→on. Clipboard/Downloads đã thử ở bản trước. Chưa bắt đầu một phiên timer, shell hoặc camera thật để kiểm tra trong lần này.

Xác minh cuối bản popover đã cài: AX trả đủ các nút Clipboard, Giữ máy thức, Lịch, Ghi chú, Kệ tệp, Hẹn giờ, Terminal, Cài đặt; ảnh chụp thấy chữ/icon trong bảng bật lên. Chọn Ghi chú mở đúng view Notes, thấy nút Trang chính/Paste/Add và No notes yet; không còn bị ép về home. Đã đưa Enable Notes về off sau thử, các cờ Color Picker/Stats/Shelf/Timer/Keep Awake/Terminal giữ lại giá trị trước thử. Minimalistic đang bật trong luồng kiểm tra menu theo phản hồi mới nhất. Show calendar đã thử on→off→on sau khi có quyền, và hai công tắc chính luôn có trong source trước nhánh quyền.

Build/test cuối cho popover + coordinator + Calendar: 276/276 XCTest qua; fixture policy routing/navigation qua. Đã cài lại Applications và xác minh chữ ký.

## Home khi tắt Calendar

Bố cục chuẩn trước đây chỉ dựng các cột player/calendar/mirror; khi player tự ẩn và cả hai mục còn lại tắt, Home vẫn được chọn nhưng không có nội dung. Bản Local bổ sung phần thay thế: hẹn giờ đang hoạt động (nếu tính năng timer bật), sau đó hàng tác vụ nhanh khi không có tác vụ đang chạy. Nhạc/calendar/mirror đang hiển thị vẫn theo bố cục trước. Quan sát showMirror và enableMinimalisticUI bằng @Default để cập nhật tức thời; Home luôn có trong danh sách tab Local và bộ đếm kích thước vì nay luôn có nội dung thay thế.

Bộ XCTest 276/276 qua, fixture sizing qua. Đã cài lại và xác minh chữ ký. Kiểm tra GUI với chính cấu hình hiện tại enableMinimalisticUI=off, showCalendar=off, showMirror=off và không có nhạc: Home hiển thị hàng nút Khóa/Clipboard/Awake/Tiện ích/Cài đặt, thấy nút Home trên header. Không thay đổi các tùy chọn đó. Không bắt đầu timer để thử nhánh hẹn giờ trong lần kiểm tra này.

## Home có pet và nội dung bổ sung

Theo yêu cầu tiếp theo, vùng Home nghỉ của bản Local được bố trí thành đồng hồ/ngày tháng ở trái, mèo pixel ở giữa, trạng thái pin/giữ máy thức bên phải và hàng tác vụ dưới đường ngăn mảnh. Chỉ dùng dữ liệu/thành phần sẵn có và SwiftUI Canvas, không thêm thư viện hay nguồn tải tài nguyên. Home có nhạc/lịch/camera hoặc hẹn giờ đang chạy vẫn ưu tiên nội dung đó.

Mèo có chu kỳ đi 5 giây, nghỉ 2 giây rồi quay lại, hoạt ảnh chân 8 bước/giây với lịch vẽ giới hạn 12 fps. Đường đi giới hạn theo bề rộng vùng giữa, không lấn cột đồng hồ/trạng thái hoặc hàng nút. Bấm vùng mèo để nhảy và hiện tim trong 1.4 giây; công việc phản ứng bị hủy cùng view. Giảm chuyển động dừng đi/nhảy, vẫn có phản hồi tim tĩnh. Timeline pet dừng khi notch đóng; đồng hồ cập nhật mỗi phút, không tạo timer manager toàn cục. Có công tắc Pet trong Home ở General, mặc định bật cho tính năng mới, có mục tìm kiếm cài đặt. Pet chỉ nằm trong Home nghỉ ở giao diện đầy đủ; không tăng kích thước Minimalistic.

Kiểm tra motion production bằng fixture độc lập: các chiều rộng 0/40/84/120/330/640/1024, không vượt biên, dừng nghỉ, đổi hướng liên tục và khép chu kỳ; kích thước sprite 28×17 kiểm tra đúng. Bộ XCTest của bản pet đạt 276/276; bố cục đồng hồ/trạng thái bổ sung sau đó đã build thành công và chạy lại fixture motion/sizing. GUI bản Applications xác nhận công tắc on→off→on, đồng hồ/ngày tháng/trạng thái/pet đủ chỗ; hai ảnh khác thời điểm thấy mèo ở vị trí khác nhau, bấm mèo thấy nhảy và tim. Không đo frame time/CPU dài hạn hoặc đổi thiết lập Giảm chuyển động của hệ thống để thử. Chữ ký bản đã cài được xác minh.

Pet được đổi theo yêu cầu sang mèo Anh lông dài màu xám: đầu/má tròn, mõm ngắn, tai nhỏ hồng, ria trắng, mắt vàng đồng, ngực sáng xù và đuôi dày, hai bàn chân ngắn. Chỉ thay sprite/palette/nhãn truy cập; chu kỳ và tương tác giữ nguyên. Build và kiểm tra motion/kích thước sprite qua, GUI bản cài xác nhận diện mạo xám mới. Không chạy lại toàn bộ XCTest cho thay đổi thuần hình vẽ này.

## Mèo tròn pixel và gỡ hàng tác vụ bị lặp

Theo phản hồi kế tiếp, bỏ toàn bộ hàng LocalQuickActionsMenu lặp ở dưới Home và đường ngăn, giữ các nút có sẵn trên header. Nút … duy nhất của Home nghỉ chuyển sang cạnh tiêu đề Trạng thái. Đồng hồ/trạng thái giữ nguyên; vùng pet cao 100 pt trong hàng 120 pt.

Sau bản pixel nhìn nghiêng chưa đạt, chuyển hình mèo sang chibi nhìn chính diện: thân tròn, má lớn, tai nhỏ, mắt to có ánh sáng, mũi hồng và bàn chân ngắn, đuôi cuộn sát người. Người dùng duyệt dáng này và yêu cầu trở lại pixel: bản cuối giữ nét/dáng vừa duyệt, render một lần năm frame trong suốt 48×50 (bốn frame đi, một frame nghỉ), phóng bằng nearest neighbor. Không vẽ lại sprite mỗi tick; chỉ chọn frame rồi di chuyển. Bản dùng ảnh có dự phòng vẽ trực tiếp khi renderer không trả được ảnh.

Kiểm tra renderer production trả đủ năm frame 48×50 không rỗng, motion regression qua và build thành công. GUI bản Applications thấy mèo pixel tròn, đúng một nút Tiện ích và không còn hàng Khóa/Clipboard/Awake/Cài đặt bị lặp ở dưới. Chữ ký được xác minh. Không chạy lại toàn bộ XCTest cho thay đổi hình vẽ/bố cục này.
