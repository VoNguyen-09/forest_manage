# 🌿 Forest Carbon Platform — Tài liệu Đồ án Flutter
> Môn học: Lập trình Di động (Flutter)  
> Số thành viên: 4  
> Stack: Flutter (Web + Mobile) · Firebase · Cloudinary · flutter_map + OSM · Hive · pdf package

---

## Mục lục
1. [Tổng quan đề tài](#1-tổng-quan-đề-tài)
2. [Kiến trúc & Stack kỹ thuật](#2-kiến-trúc--stack-kỹ-thuật)
3. [Phân công công việc](#3-phân-công-công-việc)
4. [Quy tắc làm việc chung trên GitHub](#4-quy-tắc-làm-việc-chung-trên-github)
5. [Cấu trúc thư mục dự án](#5-cấu-trúc-thư-mục-dự-án)
6. [Cấu trúc Firestore](#6-cấu-trúc-firestore)
7. [Shared Models (bắt buộc dùng chung)](#7-shared-models-bắt-buộc-dùng-chung)
8. [Timeline 4 tuần](#8-timeline-4-tuần)
9. [Prompt cho từng thành viên](#9-prompt-cho-từng-thành-viên)
   - [Thành viên 1 — Frontend / UI Lead](#thành-viên-1--frontend--ui-lead)
   - [Thành viên 2 — GIS & Forest Data](#thành-viên-2--gis--forest-data)
   - [Thành viên 3 — Mobile App & Field Operations](#thành-viên-3--mobile-app--field-operations)
   - [Thành viên 4 — Carbon Engine & Backend](#thành-viên-4--carbon-engine--backend)
10. [Ràng buộc chung bắt buộc](#10-ràng-buộc-chung-bắt-buộc)
11. [Đánh giá stack kỹ thuật](#11-đánh-giá-stack-kỹ-thuật)

---

## 1. Tổng quan đề tài

### Mục tiêu
Xây dựng nền tảng quản lý dữ liệu rừng phục vụ hình thành dự án carbon, bao gồm:

- Số hóa dữ liệu rừng và quản lý chủ rừng
- Quản lý vùng rừng trên bản đồ GIS
- Thu thập dữ liệu hiện trường qua mobile app (có offline mode)
- Tính toán carbon sơ bộ (Biomass → Carbon Stock → CO₂e)
- Dashboard quản trị tổng hợp

### User Roles

| Role | Mô tả | Quyền |
|------|-------|-------|
| **Platform Admin** | Quản trị viên hệ thống | Toàn quyền: tạo tài khoản, duyệt dữ liệu, xem báo cáo |
| **Forest Owner** | Chủ rừng | Quản lý khu rừng sở hữu, xem carbon, theo dõi nhân viên |
| **Forest Worker** | Nhân viên hiện trường | Check-in GPS, cập nhật nhật ký, chụp hình, nhập số liệu cây |

### Các module chính

| Module | Mô tả |
|--------|-------|
| User Management | Đăng nhập, OTP, phân quyền |
| Forest Owner Management | Hồ sơ chủ rừng, loại hình |
| Forest Project Management | Dự án rừng theo chủ rừng |
| GIS Map Module | Bản đồ, vẽ polygon, upload shapefile |
| Forest Inventory | Điều tra rừng, plot sampling, tree data |
| Forest Logbook | Nhật ký hiện trường |
| Mobile App | Check-in GPS, offline mode |
| Carbon Calculation | Tính toán Biomass, Carbon, CO₂e |
| File Management | Upload/quản lý tài liệu |
| Dashboard | KPI, biểu đồ tổng hợp |
| Notifications | FCM, in-app |
| Reports | Xuất PDF báo cáo |

---

## 2. Kiến trúc & Stack kỹ thuật

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App                           │
│          (Web + Mobile — cùng 1 codebase)               │
├────────────────────┬────────────────────────────────────┤
│   flutter_map      │   fl_chart (Dashboard charts)      │
│   (OSM tiles)      │   pdf package (báo cáo)            │
│   geolocator       │   go_router (navigation)           │
│   Hive (offline)   │   image_picker / file_picker       │
├────────────────────┴────────────────────────────────────┤
│                  Firebase                               │
│   Auth · Firestore · FCM · (Storage optional)          │
├─────────────────────────────────────────────────────────┤
│              Cloudinary (media storage)                 │
│         Upload ảnh JPG/PNG, PDF, DOCX                   │
└─────────────────────────────────────────────────────────┘
```

### Pubspec dependencies (gợi ý)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.x
  firebase_auth: ^5.x
  cloud_firestore: ^5.x
  firebase_messaging: ^15.x

  # Map
  flutter_map: ^7.x
  latlong2: ^0.9.x

  # Storage / Media
  cloudinary_public: ^0.x
  image_picker: ^1.x
  file_picker: ^8.x

  # Offline
  hive: ^2.x
  hive_flutter: ^1.x

  # Navigation
  go_router: ^14.x

  # Charts
  fl_chart: ^0.x

  # PDF
  pdf: ^3.x
  printing: ^5.x

  # Location
  geolocator: ^13.x

  # Utils
  intl: ^0.19.x
  uuid: ^4.x
  cached_network_image: ^3.x
```

---

## 3. Phân công công việc

### Tổng quan nhanh

| | Thành viên 1 | Thành viên 2 | Thành viên 3 | Thành viên 4 |
|--|--|--|--|--|
| **Vai trò** | Frontend / UI Lead | GIS & Forest Data | Mobile & Field | Carbon & Backend |
| **Module chính** | Auth, Dashboard, Notif, Design System, File UI | Map, Polygon, Owner, Project | Mobile app, Logbook, Inventory, Offline | Carbon calc, PDF reports, Firestore rules |

### Chi tiết phân công

#### Thành viên 1 — Frontend / UI Lead

| Task | Mô tả | Tuần |
|------|-------|------|
| Design System | ThemeData, shared widgets, màu sắc, typography | 1 |
| Auth UI | Login, quên mật khẩu OTP, đổi mật khẩu | 1–2 |
| Dashboard (Admin) | KPI cards, fl_chart biểu đồ tỉnh/carbon/loài | 2 |
| Dashboard (Owner) | Diện tích, số cây, carbon, nhật ký gần nhất | 2 |
| Notification Center | FCM init, danh sách thông báo realtime | 3 |
| File Manager UI | Upload, preview, nhóm tài liệu | 3 |
| Account Management | CRUD tài khoản, trạng thái, phân quyền | 3 |


Nền tảng kiến trúc UI: Đã setup xong file constants.dart (quy chuẩn Strings, Routes) và Base UI (Colors, Theme, AppButton, AppCard).
Module Authentication: Đã code xong form Đăng nhập (login_screen), Quên mật khẩu (forgot_password_screen), và Đổi mật khẩu (change_password_screen) với đầy đủ validate form.
Module Dashboard:
Hoàn thiện UI Dashboard Admin tích hợp biểu đồ fl_chart (PieChart, BarChart hiển thị carbon, diện tích, cây trồng).
Hoàn thiện UI Dashboard Chủ Rừng có KPI Cards và list hiển thị nhật ký gần nhất.
Module File Manager: Dựng xong giao diện Quản lý tài liệu có tab lọc theo danh mục (Pháp lý, Hiện trường, Báo cáo...) và Popup giả lập tiến trình Upload file.
#### Thành viên 2 — GIS & Forest Data

| Task | Mô tả | Tuần |
|------|-------|------|
| GIS Map Module | flutter_map + OSM tiles, hiển thị markers | 1–2 |
| Polygon Drawing | Vẽ/sửa ranh giới, tính diện tích, lưu Firestore | 2 |
| GeoJSON/KML Upload | Parse và hiển thị shapefile lên map | 3 |
| Forest Owner CRUD | Danh sách, hồ sơ, loại (Individual/Company/Coop) | 2 |
| Forest Project CRUD | Tạo/sửa/xóa dự án, gán chủ rừng, trạng thái | 2–3 |
| Project Detail View | Xem tổng diện tích, polygon trên map | 3 |

#### Thành viên 3 — Mobile App & Field Operations

| Task | Mô tả | Tuần |
|------|-------|------|
| Mobile App Shell | Login, navigation mobile, responsive layout | 1 |
| Check-in GPS | geolocator, ghi lat/long/time, lưu Firestore | 2 |
| Offline Mode | Hive local storage, sync khi có internet | 2–3 |
| Forest Logbook | CRUD nhật ký, loại công việc, GPS đính kèm | 2–3 |
| Photo Upload | image_picker, upload Cloudinary, tối đa 10 ảnh | 2–3 |
| Forest Inventory | CRUD plot, nhập DBH/Height/Species/Quantity | 3 |
| Cloudinary Service | Service class upload ảnh/file, trả URL | 2 |

#### Thành viên 4 — Carbon Engine & Backend

| Task | Mô tả | Tuần |
|------|-------|------|
| Firestore Design | Thiết kế collections, indexes, security rules | 1 |
| Firebase Auth Setup | Custom claims role, OTP email flow | 1 |
| Carbon Calculation UI | Nhập liệu, công thức, hiển thị kết quả | 2 |
| Species Factor Config | Admin cấu hình hệ số loài cây | 2–3 |
| PDF Report — Forest Summary | Diện tích, loại cây, carbon | 3 |
| PDF Report — Inventory | Plot, DBH, Height, Quantity | 3 |
| PDF Report — Activity | Nhật ký hiện trường | 3 |
| Firestore Security Review | Kiểm tra rules cuối dự án | 4 |

---

## 4. Quy tắc làm việc chung trên GitHub

### 4.1 Cấu trúc branch

```
main                    ← production-ready, chỉ merge qua PR
├── develop             ← integration branch, mỗi tuần sync
├── feature/tv1-auth    ← Thành viên 1
├── feature/tv1-dashboard
├── feature/tv2-map
├── feature/tv2-owner
├── feature/tv3-mobile
├── feature/tv3-logbook
├── feature/tv4-carbon
└── feature/tv4-pdf
```

**Quy tắc đặt tên branch:**
```
feature/<tv_số>-<tên-module>
fix/<tv_số>-<mô-tả-bug>
chore/<mô-tả>
```

### 4.2 Quy tắc commit message

Sử dụng **Conventional Commits**:

```
feat(auth): add OTP email verification screen
fix(map): resolve polygon closing on tap
chore(deps): upgrade flutter_map to 7.0.1
docs(readme): update setup instructions
refactor(carbon): extract biomass formula to service
test(logbook): add unit test for sync logic
```

Format: `<type>(<scope>): <mô tả ngắn>`

**Types:** `feat` · `fix` · `chore` · `docs` · `refactor` · `test` · `style`

### 4.3 Pull Request (PR) rules

- **Mỗi feature = 1 PR** — không gộp nhiều module vào 1 PR
- **PR title** theo format: `[TV1] feat: Dashboard KPI cards`
- **Bắt buộc** ít nhất 1 thành viên khác review trước khi merge vào `develop`
- **Không được** push thẳng lên `main` hoặc `develop`
- PR phải pass checklist:
  - [ ] Code chạy không lỗi
  - [ ] Không có hardcode string (dùng constants)
  - [ ] Không commit file `.env`, `google-services.json`, `GoogleService-Info.plist`
  - [ ] Widget dùng shared components của TV1
  - [ ] Đã test trên cả mobile và web (nếu liên quan)

### 4.4 File bị cấm commit

Thêm vào `.gitignore`:

```gitignore
# Firebase
google-services.json
GoogleService-Info.plist

# Environment
.env
.env.*
lib/config/secrets.dart

# Flutter build
build/
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies

# IDE
.idea/
.vscode/settings.json
*.iml

# OS
.DS_Store
Thumbs.db
```

### 4.5 Code style rules (bắt buộc toàn nhóm)

```dart
// ✅ ĐÚNG — dùng const constructor
const MyWidget({super.key});

// ✅ ĐÚNG — dùng named parameters rõ ràng
ForestOwner(name: 'Nguyễn Văn A', type: OwnerType.individual);

// ✅ ĐÚNG — extract widget, không nest quá 3 cấp
class _OwnerCard extends StatelessWidget { ... }

// ❌ SAI — hardcode color
color: Color(0xFF4CAF50)
// ✅ ĐÚNG — dùng theme
color: Theme.of(context).colorScheme.primary

// ❌ SAI — hardcode string
Text('Quản lý chủ rừng')
// ✅ ĐÚNG — dùng constants
Text(AppStrings.forestOwnerManagement)
```

### 4.6 Sync workflow hàng tuần

```
M  i thứ 2 đầu tuần:
1. git checkout develop
2. git pull origin develop
3. git checkout feature/tv<x>-<module>
4. git merge develop          ← sync mới nhất vào branch của mình
5. Resolve conflict (nếu có)
6. Tiếp tục làm việc
```

---

## 5. Cấu trúc thư mục dự án

```
lib/
├── main.dart
├── app.dart                      # MaterialApp + go_router setup
│
├── config/
│   ├── router.dart               # TV1: go_router routes
│   ├── theme.dart                # TV1: ThemeData, colors, typography
│   └── constants.dart            # Strings, keys, enums
│
├── core/
│   ├── models/                   # TV4 tạo trước tuần 1 — KHÔNG tự ý sửa
│   │   ├── user_model.dart
│   │   ├── forest_owner_model.dart
│   │   ├── forest_project_model.dart
│   │   ├── log_entry_model.dart
│   │   ├── plot_data_model.dart
│   │   └── carbon_result_model.dart
│   ├── services/
│   │   ├── auth_service.dart     # TV4
│   │   ├── firestore_service.dart# TV4
│   │   ├── cloudinary_service.dart # TV3
│   │   ├── notification_service.dart # TV1
│   │   └── location_service.dart # TV3
│   └── utils/
│       ├── validators.dart
│       └── formatters.dart
│
├── features/
│   ├── auth/                     # TV1
│   │   ├── screens/
│   │   └── widgets/
│   ├── dashboard/                # TV1
│   │   ├── screens/
│   │   └── widgets/
│   ├── notification/             # TV1
│   ├── file_manager/             # TV1
│   ├── map/                      # TV2
│   │   ├── screens/
│   │   └── widgets/
│   ├── forest_owner/             # TV2
│   ├── forest_project/           # TV2
│   ├── logbook/                  # TV3
│   ├── inventory/                # TV3
│   ├── mobile_checkin/           # TV3
│   ├── carbon/                   # TV4
│   └── reports/                  # TV4
│
└── shared/
    ├── widgets/                  # TV1 — shared components
    │   ├── app_bar.dart
    │   ├── status_badge.dart
    │   ├── loading_overlay.dart
    │   ├── empty_state.dart
    │   └── confirm_dialog.dart
    └── extensions/
```

---

## 6. Cấu trúc Firestore

```
users/{userId}
  - uid, fullName, phone, email, role, status, createdAt

forestOwners/{ownerId}
  - ownerCode, ownerName, type, cccd, address, phone, email
  - attachments: [{ url, type, name }]

forestProjects/{projectId}
  - projectId, projectName, ownerId
  - province, district, commune
  - forestType, treeSpecies, yearPlanted, status
  - polygon: [{ lat, lng }]
  - totalAreaHa, perimeter
  - createdAt, updatedAt

plots/{plotId}
  - plotCode, projectId, gps: { lat, lng }, areaSqm
  - trees: [{ species, dbh, height, quantity }]
  - createdAt

logEntries/{entryId}
  - date, userId, projectId, plotId
  - gps: { lat, lng }, workType, description
  - photos: [url]
  - createdAt, syncedAt

carbonResults/{resultId}
  - projectId, plotId, calculatedAt
  - totalBiomassKg, carbonStockTon, co2eTon
  - breakdown: [{ species, dbh, height, quantity, biomassFactor, biomass }]

speciesFactors/{speciesId}
  - speciesName, factor
  - updatedBy, updatedAt

notifications/{notifId}
  - userId, title, body, type, relatedId, isRead, createdAt

files/{fileId}
  - projectId, ownerId, fileName, fileUrl, fileType
  - category (legal/project/field/survey), uploadedBy, createdAt
```

---

## 7. Shared Models (bắt buộc dùng chung)

> TV4 tạo tất cả models trong tuần 1. Các thành viên khác **không tự tạo model mới** mà phải dùng từ `lib/core/models/`. Muốn thêm field → tạo PR, tag TV4 review.

```dart
// lib/core/models/user_model.dart
enum UserRole { platformAdmin, forestOwner, forestWorker }
enum UserStatus { active, inactive, locked }

class UserModel {
  final String uid;
  final String fullName;
  final String phone;
  final String email;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  // ...fromJson, toJson, copyWith
}

// lib/core/models/forest_owner_model.dart
enum OwnerType { individual, company, cooperative }

class ForestOwnerModel {
  final String id;
  final String ownerCode;
  final String ownerName;
  final OwnerType type;
  final String cccd;
  final String address;
  // ...
}

// lib/core/models/log_entry_model.dart
enum WorkType { planting, care, fertilizing, growthCheck, patrol, firePrevention }

class LogEntryModel {
  final String id;
  final DateTime date;
  final String userId;
  final String projectId;
  final GpsPoint gps;
  final WorkType workType;
  final String description;
  final List<String> photoUrls;
  final bool isSynced; // Hive offline flag
  // ...
}
```

---

## 8. Timeline 4 tuần

### Tuần 1 — Setup & Foundation (cả nhóm)

| Thành viên | Việc phải hoàn thành cuối tuần 1 |
|------------|----------------------------------|
| **Tất cả** | Tạo GitHub repo, cài Flutter, clone project, chạy được app rỗng |
| **TV4** | Tạo Firebase project, enable Auth+Firestore+FCM, viết security rules cơ bản, tạo toàn bộ shared models, push lên `develop` |
| **TV1** | Setup go_router, ThemeData, shared widgets cơ bản (AppBar, Drawer, StatusBadge), tạo `config/` |
| **TV2** | Nghiên cứu flutter_map, chạy được bản đồ OSM cơ bản |
| **TV3** | Setup Hive, geolocator, image_picker, cloudinary_service skeleton |

**Milestone cuối tuần 1:** App chạy được, đăng nhập Firebase Auth thành công, bản đồ OSM hiển thị.

### Tuần 2 — Core Features

| Thành viên | Việc phải hoàn thành |
|------------|----------------------|
| **TV1** | Auth UI hoàn chỉnh (login, OTP), Dashboard Admin KPI cards + charts |
| **TV2** | Vẽ polygon + lưu Firestore, CRUD Forest Owner, CRUD Forest Project |
| **TV3** | Check-in GPS lưu Firestore, CRUD Logbook cơ bản, upload 1 ảnh Cloudinary |
| **TV4** | Carbon calculation form + công thức đầy đủ, Species Factor CRUD |

**Milestone cuối tuần 2:** Mỗi TV demo được tính năng chính của mình trước nhóm.

### Tuần 3 — Full Features + Integration

| Thành viên | Việc phải hoàn thành |
|------------|----------------------|
| **TV1** | Notification Center (FCM + Firestore), File Manager UI, Account Management |
| **TV2** | Upload GeoJSON/KML parse + hiển thị, giao diện Project Detail với map |
| **TV3** | Offline Hive + background sync, Inventory (Plot + Tree Data), upload 10 ảnh |
| **TV4** | 3 loại báo cáo PDF hoàn chỉnh, Firestore indexes, review security rules |

**Milestone cuối tuần 3:** Merge tất cả vào `develop`, integration test cơ bản.

### Tuần 4 — Polish, Testing & Báo cáo

| Thành viên | Việc phải hoàn thành |
|------------|----------------------|
| **Tất cả** | Fix bug sau integration, UI/UX polish, responsive test |
| **TV1** | Dashboard Owner role, final UI review toàn app |
| **TV4** | Final security audit, deploy rules lên Firebase |
| **Tất cả** | Viết báo cáo đồ án, chuẩn bị demo |

---

## 9. Prompt cho từng thành viên

---

### Thành viên 1 — Frontend / UI Lead

```
Bạn là Thành viên 1 trong nhóm 4 người làm đồ án Flutter "Forest Carbon Platform".
Vai trò của bạn: Frontend Lead — người thiết kế và xây dựng toàn bộ UI/UX cho ứng dụng.

=== STACK BẠN DÙNG ===
- Flutter (Web + Mobile, cùng codebase)
- Firebase Auth + Firestore (realtime listener)
- FCM (Firebase Cloud Messaging)
- go_router cho navigation
- fl_chart cho biểu đồ Dashboard
- Cloudinary (UI upload, logic do TV3 viết)

=== MODULE BẠN PHỤ TRÁCH ===
1. Design System: ThemeData, màu sắc (#2D6A4F xanh rừng chủ đạo), typography, shared widgets
2. Auth UI: Login (email/password), quên mật khẩu (OTP email), đổi mật khẩu
3. Dashboard Admin: KPI cards (tổng chủ rừng, dự án, ha, cây, tCO₂e), 3 biểu đồ fl_chart
4. Dashboard Forest Owner: Diện tích, số cây, carbon, nhật ký gần nhất
5. Notification Center: Danh sách thông báo realtime từ Firestore, FCM init
6. File Manager UI: Upload PDF/JPG/PNG/DOCX, nhóm tài liệu, preview
7. Account Management: CRUD user, gán role, đổi trạng thái

=== RÀNG BUỘC BẮT BUỘC ===
- Mọi widget TÙY CHỈNH phải để trong lib/shared/widgets/ để TV2, TV3, TV4 dùng lại
- Không hardcode màu — dùng Theme.of(context).colorScheme.*
- Không hardcode string — dùng AppStrings constants
- Shared widgets phải có đầy đủ named parameters, không widget nào phụ thuộc context ngoài build()
- Viết ThemeData và shared widgets TRƯỚC cuối ngày thứ 3 tuần 1 để các TV khác bắt đầu được
- Tất cả màn hình phải responsive: chạy tốt cả mobile (360px) và web (1280px)
- Dùng go_router, không dùng Navigator.push() trực tiếp
- Không merge code chưa test vào develop

=== QUY TẮC GITHUB ===
- Branch: feature/tv1-<tên-module> (vd: feature/tv1-auth, feature/tv1-dashboard)
- Commit: feat(auth): ..., fix(dashboard): ..., chore(theme): ...
- Mỗi module = 1 PR riêng, title: [TV1] feat: <tên>
- Phải có ít nhất 1 TV khác review PR trước khi merge vào develop
- Không commit: .env, google-services.json, secrets.dart
- Sync develop vào branch của mình mỗi đầu tuần

=== GIAO TIẾP VỚI TV KHÁC ===
- TV4 sẽ cho bạn UserModel, shared models — KHÔNG tự tạo model user
- Khi TV2, TV3 cần widget mới → họ tạo issue, bạn review và build shared widget
- Báo TV4 ngay nếu cần field Firestore mới để TV4 cập nhật rules
```

---

### Thành viên 2 — GIS & Forest Data

```
Bạn là Thành viên 2 trong nhóm 4 người làm đồ án Flutter "Forest Carbon Platform".
Vai trò của bạn: GIS & Forest Data — bản đồ, quản lý chủ rừng và dự án rừng.

=== STACK BẠN DÙNG ===
- Flutter Web + Mobile
- flutter_map + OpenStreetMap (KHÔNG dùng Google Maps — mất phí)
- latlong2 cho LatLng coordinates
- cloud_firestore để lưu polygon, owner, project
- file_picker để upload file GeoJSON/KML
- go_router (dùng routes TV1 đã định nghĩa)
- Shared widgets từ lib/shared/widgets/ (do TV1 build)

=== MODULE BẠN PHỤ TRÁCH ===
1. GIS Map Module:
   - Hiển thị bản đồ OSM với flutter_map
   - Vẽ polygon ranh giới rừng bằng tay (tap để thêm điểm, đóng polygon)
   - Hiển thị tổng diện tích (ha), chu vi (m), danh sách tọa độ
   - Lưu polygon [{lat, lng}] vào Firestore collection forestProjects

2. Shapefile Upload:
   - Cho phép upload file .geojson hoặc .kml
   - Parse file và hiển thị polygon lên bản đồ
   - Lưu polygon đã parse vào Firestore

3. Forest Owner Management:
   - Danh sách chủ rừng (có search, filter theo type)
   - CRUD hồ sơ chủ rừng: tên, CCCD/GPKD, địa chỉ, SĐT, email, loại (Individual/Company/Cooperative)
   - Đính kèm tài liệu (URL từ Cloudinary — TV3 đã viết CloudinaryService)

4. Forest Project Management:
   - CRUD dự án rừng, gán chủ rừng
   - Thông tin: tên, tỉnh/huyện/xã, loại rừng, loài cây, năm trồng
   - Quản lý trạng thái: Draft → Surveying → Active → Suspended
   - Xem polygon của dự án trên bản đồ
r

=== RÀNG BUỘC BẮT BUỘC ===
- KHÔNG dùng Google Maps API — chỉ dùng flutter_map + OSM (hoàn toàn miễn phí)
- KHÔNG tự tạo model — dùng ForestOwnerModel, ForestProjectModel từ lib/core/models/
- KHÔNG tự viết Firestore query phức tạp — báo TV4 nếu cần index mới
- Dùng shared widgets của TV1: AppBar, StatusBadge, LoadingOverlay, EmptyState
- Mọi Firestore write phải có error handling (try/catch + hiển thị lỗi cho user)
- Polygon phải validate: tối thiểu 3 điểm mới cho phép lưu
- Diện tích tính theo công thức Shoelace (Gauss) từ tọa độ lat/lng

=== QUY TẮC GITHUB ===
- Branch: feature/tv2-map, feature/tv2-owner, feature/tv2-project
- Commit: feat(map): add polygon drawing tool, fix(owner): resolve null CCCD
- PR title: [TV2] feat: Polygon drawing + area calculation
- Review TV1 hoặc TV4 trước khi merge
- Không commit: API keys, .env
- Sync develop mỗi đầu tuần (git merge develop vào branch của bạn)

=== GIAO TIẾP VỚI TV KHÁC ===
- TV4 sẽ cung cấp ForestOwnerModel, ForestProjectModel — dùng nguyên
- TV3 có CloudinaryService — gọi CloudinaryService.uploadFile() khi cần upload tài liệu Owner
- TV1 có shared widgets — dùng, không tự build duplicate
- Báo TV4 ngay khi cần Firestore composite index mới (ví dụ: query project theo ownerId + status)
```

---

### Thành viên 3 — Mobile App & Field Operations

```
Bạn là Thành viên 3 trong nhóm 4 người làm đồ án Flutter "Forest Carbon Platform".
Vai trò của bạn: Mobile App & Field Operations — ứng dụng di động cho nhân viên hiện trường.

=== STACK BẠN DÙNG ===
- Flutter Mobile (Android + iOS focus, nhưng vẫn chạy web được)
- geolocator cho GPS check-in
- Hive + hive_flutter cho offline local storage
- image_picker cho chụp/chọn ảnh
- file_picker cho chọn file upload
- Cloudinary (bạn viết CloudinaryService dùng chung cho cả nhóm)
- cloud_firestore để sync dữ liệu
- go_router (dùng routes TV1 định nghĩa)
- Shared widgets từ lib/shared/widgets/

=== MODULE BẠN PHỤ TRÁCH ===
1. Mobile App Shell:
   - Layout responsive cho mobile (bottom navigation bar)
   - Xử lý permission GPS và Camera trên Android/iOS
   - Connectivity check (có internet hay không)

2. GPS Check-in:
   - Ghi nhận vị trí hiện tại (lat, lng, accuracy, timestamp)
   - Lưu vào Firestore ngay nếu có mạng
   - Lưu vào Hive nếu offline, sync sau

3. Offline Mode (QUAN TRỌNG):
   - Hive box lưu: pending log entries, pending check-ins, pending tree data
   - Background sync: khi có internet → upload hết Hive data lên Firestore → xóa local
   - Hiển thị badge "Chưa đồng bộ (X mục)" trên UI

4. Forest Logbook:
   - CRUD nhật ký với loại công việc (enum WorkType)
   - Đính kèm GPS tự động khi tạo entry
   - Upload ảnh hiện trường: tối đa 10 ảnh/bản ghi, dùng Cloudinary
   - Hỗ trợ offline: lưu ảnh local path tạm, sync URL sau

5. Forest Inventory:
   - CRUD plot sampling (mã plot, GPS, diện tích)
   - Nhập tree data: loài, DBH (cm), Height (m), Quantity
   - Validate: DBH > 0, Height > 0, Quantity > 0

6. CloudinaryService (bạn VIẾT, cả nhóm DÙNG):
   - uploadImage(File file) → Future<String> (trả URL)
   - uploadFile(File file, {String folder}) → Future<String>
   - Đặt trong lib/core/services/cloudinary_service.dart
   - Dùng cloudinary_public package hoặc HTTP upload trực tiếp

=== RÀNG BUỘC BẮT BUỘC ===
- CloudinaryService phải viết xong và push lên develop trước cuối tuần 1 để TV2 dùng
- KHÔNG tự tạo model — dùng LogEntryModel, PlotDataModel từ lib/core/models/
- Hive box names phải là constants (tránh typo): HiveBoxes.pendingLogs, HiveBoxes.pendingCheckins
- Khi upload ảnh: compress ảnh về max 1MB trước khi upload (dùng flutter_image_compress hoặc image package)
- Permission handling: phải xử lý trường hợp user từ chối quyền GPS/Camera (hiện dialog giải thích)
- Offline data phải có timestamp để tránh duplicate khi sync
- Mọi Firestore write có try/catch, offline write có error fallback vào Hive

=== QUY TẮC GITHUB ===
- Branch: feature/tv3-mobile-shell, feature/tv3-logbook, feature/tv3-inventory, feature/tv3-offline
- Commit: feat(logbook): add photo upload with Cloudinary, fix(offline): resolve Hive sync duplicate
- PR title: [TV3] feat: Offline mode with Hive sync
- Review TV1 hoặc TV4 trước khi merge
- Không commit: Cloudinary API secret (dùng biến môi trường hoặc Firebase Remote Config)
- Sync develop mỗi đầu tuần

=== GIAO TIẾP VỚI TV KHÁC ===
- TV4 cung cấp LogEntryModel, PlotDataModel — dùng nguyên
- TV2 cần CloudinaryService.uploadFile() để upload tài liệu Owner — viết general đủ dùng cho cả 2
- TV1 có shared widgets — dùng, không tự build duplicate
- Báo TV4 khi cần Firestore index mới (ví dụ: query logEntries theo userId + date range)
```

---

### Thành viên 4 — Carbon Engine & Backend

```
Bạn là Thành viên 4 trong nhóm 4 người làm đồ án Flutter "Forest Carbon Platform".
Vai trò của bạn: Carbon Engine & Backend — tính toán carbon, xuất PDF, quản lý Firestore backend.

=== STACK BẠN DÙNG ===
- Firebase Auth (custom claims cho role)
- Cloud Firestore (design, rules, indexes)
- FCM (cấu hình server-side nếu cần Cloud Functions, hoặc Firestore trigger)
- pdf + printing packages cho xuất báo cáo
- Flutter UI cho Carbon Calculation module
- go_router (dùng routes TV1 định nghĩa)
- Shared widgets từ lib/shared/widgets/

=== MODULE BẠN PHỤ TRÁCH ===
1. Shared Models (TUẦN 1 — ƯU TIÊN SỐ 1):
   Tạo TẤT CẢ models trong lib/core/models/ và push lên develop trước thứ 4 tuần 1:
   - user_model.dart (UserModel, UserRole, UserStatus)
   - forest_owner_model.dart (ForestOwnerModel, OwnerType)
   - forest_project_model.dart (ForestProjectModel, ProjectStatus)
   - log_entry_model.dart (LogEntryModel, WorkType, GpsPoint)
   - plot_data_model.dart (PlotDataModel, TreeData)
   - carbon_result_model.dart (CarbonResultModel, SpeciesFactor)
   Mỗi model phải có: fromJson(), toJson(), copyWith()

2. Firebase Auth Setup:
   - Enable Email/Password auth trên Firebase Console
   - Custom claims: set role claim khi tạo user (Admin dùng Firebase Admin SDK hoặc Cloud Functions)
   - OTP email: dùng Firebase Auth sendPasswordResetEmail() làm flow OTP đơn giản
   - AuthService class: signIn, signOut, getCurrentUser, getUserRole

3. Firestore Backend:
   - Thiết kế collections theo cấu trúc đã định
   - Security rules: user chỉ đọc được data của mình, admin đọc tất cả
   - Composite indexes: (projectId + createdAt), (userId + date), (ownerId + status)
   - FirestoreService class: CRUD generic để các TV khác gọi

4. Carbon Calculation Module:
   Công thức:
     Biomass (kg) = (0.0509 × DBH² × Height) × SpeciesFactor × Quantity
     Carbon Stock (tC) = Biomass × 0.47 / 1000
     CO₂e (tCO₂e) = Carbon Stock × 3.67
   
   - Màn hình nhập liệu: chọn dự án/plot, xem tree data đã nhập (từ TV3)
   - Tự động tính khi đủ input, hiển thị breakdown theo loài
   - Lưu kết quả vào collection carbonResults

5. Species Factor Config (Admin only):
   - CRUD hệ số loài: Keo (0.48), Bạch đàn (0.47), Thông (0.50), ...
   - Lưu trong Firestore collection speciesFactors
   - Chỉ Platform Admin mới truy cập được màn hình này

6. PDF Reports (dùng pdf package):
   a) Forest Summary Report: tên dự án, chủ rừng, diện tích, loại cây, tổng carbon
   b) Forest Inventory Report: bảng plot với DBH/Height/Quantity từng loài
   c) Activity Report: nhật ký hiện trường theo date range

=== RÀNG BUỘC BẮT BUỘC ===
- Shared models PHẢI xong trước cuối ngày thứ 4 tuần 1 (deadline cứng cho cả nhóm)
- Mỗi model phải có fromJson() và toJson() đầy đủ (Firestore dùng Map<String, dynamic>)
- Firestore security rules KHÔNG được để rules allow read, write: if true; (cực kỳ nguy hiểm)
- Carbon formula phải tách ra CarbonCalculationService (không để logic trong widget)
- PDF layout phải có: logo/header dự án, bảng dữ liệu rõ ràng, footer trang số
- Không để Cloudinary API secret hay Firebase Admin key trong client code
- Validate tất cả input carbon: DBH và Height phải > 0, treeSpecies phải có trong speciesFactors
- Mọi Firestore security rules thay đổi phải test trước khi deploy

=== QUY TẮC GITHUB ===
- Branch: feature/tv4-models (TUẦN 1 ưu tiên), feature/tv4-carbon, feature/tv4-pdf, feature/tv4-firestore
- Commit: feat(models): add LogEntryModel with offline flag, fix(carbon): correct CO2e multiplier
- PR title: [TV4] feat: Shared models — tất cả TV cần review PR này
- PR models PHẢI có tất cả 3 TV còn lại review trước khi merge (vì ảnh hưởng toàn bộ)
- Không commit: firebase-adminsdk.json, service-account.json
- Sync develop mỗi đầu tuần

=== GIAO TIẾP VỚI TV KHÁC ===
- Sau khi push models lên develop: nhắn nhóm ngay để TV2, TV3 sync về
- Nếu TV khác cần thêm field vào model → họ tạo PR, bạn review (bạn là owner của models)
- Khi TV2 hoặc TV3 báo cần Firestore index mới → tạo index trên Firebase Console và update rules
- TV1 cần FirestoreService.streamNotifications() → bạn expose method đó
- Nếu dùng Cloud Functions cho role assignment: viết README hướng dẫn deploy
```

---

## 10. Ràng buộc chung bắt buộc

### Ràng buộc kỹ thuật

| # | Ràng buộc | Ai áp dụng |
|---|-----------|-----------|
| 1 | Không hardcode màu — dùng `Theme.of(context).colorScheme.*` | Tất cả |
| 2 | Không hardcode string — dùng constants trong `AppStrings` | Tất cả |
| 3 | Không tự tạo model — dùng từ `lib/core/models/` | TV1, TV2, TV3 |
| 4 | Không tự build widget đã có trong `lib/shared/widgets/` | TV2, TV3, TV4 |
| 5 | Dùng `go_router` — không gọi `Navigator.push()` trực tiếp | Tất cả |
| 6 | Mọi Firestore write phải có `try/catch` và hiển thị lỗi | Tất cả |
| 7 | Không commit secrets: `.env`, `google-services.json`, API keys | Tất cả |
| 8 | Mọi màn hình phải test trên cả mobile (360px) và web (1280px) | Tất cả |
| 9 | Không push thẳng vào `main` hoặc `develop` — dùng PR | Tất cả |
| 10 | PR phải được ít nhất 1 TV khác approve trước khi merge | Tất cả |

### Ràng buộc quy trình

- **Daily standup (khuyến nghị):** Mỗi ngày nhắn nhóm: "Hôm qua làm gì, hôm nay làm gì, bị block gì"
- **Conflict resolution:** Nếu 2 TV sửa cùng 1 file → người đến sau chịu trách nhiệm resolve conflict
- **Bug triage:** Bug ảnh hưởng module của TV nào → TV đó fix trong vòng 24h
- **Tuần 4 không thêm feature mới** — chỉ fix bug và polish

---

## 11. Đánh giá stack kỹ thuật

| Package/Service | License | Phí | Ghi chú |
|----------------|---------|-----|---------|
| Flutter SDK | BSD-3 | Miễn phí | ✅ |
| Firebase Auth | Google ToS | Free tier đủ dùng | ✅ 10K auth/tháng |
| Cloud Firestore | Google ToS | Free tier đủ dùng | ✅ 1GB storage, 50K read/ngày |
| Firebase Messaging | Google ToS | Miễn phí | ✅ |
| flutter_map | BSD-2 | Miễn phí | ✅ Thay thế hoàn hảo cho Google Maps |
| OpenStreetMap tiles | ODbL | Miễn phí | ✅ Không cần API key |
| Cloudinary | Cloudinary ToS | Free: 25GB, 25 credits | ⚠️ Đủ cho đồ án |
| Hive | Apache-2.0 | Miễn phí | ✅ |
| pdf package | Apache-2.0 | Miễn phí | ✅ |
| geolocator | MIT | Miễn phí | ✅ |
| fl_chart | MIT | Miễn phí | ✅ Khuyến nghị dùng |
| go_router | BSD-3 | Miễn phí | ✅ |

### Gợi ý thay thế nếu cần

- **Cloudinary → Firebase Storage:** Đơn giản hơn (cùng ecosystem), 5GB free — cân nhắc nếu Cloudinary phức tạp
- **fl_chart → syncfusion_flutter_charts:** Đẹp hơn nhưng cần license (miễn phí cho community)
- **Hive → sqflite:** Mạnh hơn cho structured data nhưng không hỗ trợ Flutter Web

---

*Tài liệu này được tạo cho đồ án môn Lập trình Di động (Flutter). Cập nhật lần cuối: 2025.*
