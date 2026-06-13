# 🌿 Forest Carbon Management System
## Kế Hoạch Phát Triển Flutter - Nhóm 4 Người

---

## 📋 Tổng Quan Dự Án

| Thông tin | Chi tiết |
|---|---|
| Tên dự án | Forest Carbon Management System |
| Tech Stack | Flutter + Firebase |
| Số thành viên | 4 người |
| Mô hình phân công | 1 Frontend Lead + 3 Backend/Logic Dev |
| Kiến trúc | Module-based, Screen → Service → Firebase |

---

## ⚠️ Vấn Đề Với Plan Gốc & Lý Do Điều Chỉnh

Plan gốc phân chia theo module dọc (mỗi người làm 1 module từ UI → Service → Firebase). Điều này có **3 vấn đề lớn**:

1. **UI không thống nhất** → 4 người làm 4 style khác nhau, không đồng bộ `AppColors`, `CustomButton`, `CustomCard`.
2. **Conflict shared files** → `core/`, `routes/`, `theme/` bị nhiều người chạm vào.
3. **Khó review code** → Không ai có cái nhìn tổng thể về UI/UX toàn app.

### ✅ Giải Pháp: Tách Frontend & Backend/Logic

```
Frontend Lead (1 người)   →  Toàn bộ UI, Widget, Screen, Navigation
Backend Dev A (1 người)   →  Auth + User + Owner modules (Service + Model)
Backend Dev B (1 người)   →  Project + Map + Inventory modules (Service + Model)
Backend Dev C (1 người)   →  Logbook + Carbon + Dashboard + Report (Service + Model)
```

---

## 👥 Phân Công Chi Tiết

---

### 🎨 THÀNH VIÊN 1 — Frontend Lead

> **Trách nhiệm:** Xây dựng toàn bộ giao diện người dùng, hệ thống thiết kế, và điều hướng.

#### Phạm vi công việc

**1. Core System (Tuần 1 — Ưu tiên số 1)**

```
lib/core/
├── theme/
│   ├── app_colors.dart          # Toàn bộ màu sắc hệ thống
│   ├── app_text_styles.dart     # Typography với Google Fonts Poppins
│   └── app_theme.dart           # MaterialTheme config
├── constants/
│   ├── app_constants.dart       # padding=16, radius=12, ...
│   └── app_strings.dart         # Tất cả string dùng trong app
├── widgets/
│   ├── custom_button.dart       # Primary, Secondary, Outline variants
│   ├── custom_text_field.dart   # Input chuẩn có validation
│   ├── custom_card.dart         # Card chuẩn Material 3
│   ├── loading_overlay.dart     # Loading state toàn màn hình
│   ├── empty_state_widget.dart  # Khi không có dữ liệu
│   └── error_widget.dart        # Hiển thị lỗi
└── routes/
    ├── app_router.dart          # Toàn bộ route definitions
    └── route_names.dart         # Tên route constants
```

**2. Screens — Toàn bộ màn hình (Tuần 1-3)**

```
lib/modules/
├── auth/screens/
│   ├── login_screen.dart
│   └── forgot_password_screen.dart
├── owner/screens/
│   ├── owner_list_screen.dart
│   └── owner_detail_screen.dart
├── project/screens/
│   ├── project_list_screen.dart
│   ├── project_detail_screen.dart
│   └── project_form_screen.dart
├── map/screens/
│   └── map_screen.dart
├── inventory/screens/
│   ├── plot_list_screen.dart
│   └── plot_detail_screen.dart
├── logbook/screens/
│   ├── logbook_list_screen.dart
│   └── logbook_form_screen.dart
├── carbon/screens/
│   └── carbon_calculation_screen.dart
├── dashboard/screens/
│   └── dashboard_screen.dart
└── report/screens/
    └── report_screen.dart
```

**3. Widgets riêng cho từng module (Tuần 2-3)**

```
lib/modules/
├── dashboard/widgets/
│   ├── kpi_card_widget.dart
│   ├── area_by_province_chart.dart
│   ├── carbon_by_project_chart.dart
│   └── recent_activity_widget.dart
├── map/widgets/
│   ├── map_toolbar_widget.dart
│   └── polygon_info_panel.dart
├── carbon/widgets/
│   ├── biomass_result_card.dart
│   └── input_tree_form.dart
└── ... (tương tự cho các module khác)
```

**4. Navigation & State Placeholder (Tuần 1)**

```dart
// Frontend tạo mock data để build UI mà không cần chờ Backend
// Ví dụ: dùng static List<ProjectModel> mockProjects = [...]
// Sau khi Backend xong, chỉ cần thay bằng Service call thật
```

#### Quy tắc bắt buộc

- Mọi màn hình phải dùng `AppColors`, KHÔNG hard-code màu.
- Mọi button phải dùng `CustomButton`.
- Mọi input phải dùng `CustomTextField`.
- Padding/margin dùng `AppConstants.defaultPadding` (16).
- Border radius dùng `AppConstants.borderRadius` (12).
- Phông chữ: Google Fonts Poppins, Material 3.

---

### 🔧 THÀNH VIÊN 2 — Backend Dev A

> **Trách nhiệm:** Module Auth, User Management, Forest Owner.

#### Phạm vi công việc

```
lib/
├── models/
│   ├── user_model.dart           # fromMap, toMap, copyWith
│   └── owner_model.dart          # fromMap, toMap, copyWith
├── services/
│   ├── auth_service.dart         # login, logout, forgotPassword (OTP)
│   ├── user_service.dart         # CRUD users, quản lý trạng thái
│   └── owner_service.dart        # CRUD owners, upload hồ sơ
└── modules/
    ├── auth/
    │   └── services/ (nếu cần logic riêng)
    └── owner/
        └── services/
```

#### Firestore Collections được giao

```
users/
  - uid (String)
  - fullName (String)
  - phone (String)
  - email (String)
  - role (String)           # admin | owner | worker
  - status (String)         # active | inactive | locked
  - createdAt (Timestamp)

owners/
  - ownerCode (String)
  - ownerName (String)
  - type (String)           # individual | company | cooperative
  - cccdOrGpkd (String)
  - address (String)
  - phone (String)
  - email (String)
  - attachments (List<String>)   # URLs file đính kèm
  - createdAt (Timestamp)
```

#### Models phải implement

```dart
class UserModel {
  // Fields...
  factory UserModel.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  UserModel copyWith({...});
}

class OwnerModel {
  // Fields...
  factory OwnerModel.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  OwnerModel copyWith({...});
}
```

#### Services phải implement

```dart
class AuthService {
  Future<UserCredential> login(String email, String password);
  Future<void> logout();
  Future<void> sendOtp(String email);
  Future<void> resetPassword(String email, String otp, String newPassword);
}

class UserService {
  Future<List<UserModel>> getUsers();
  Future<void> createUser(UserModel user);
  Future<void> updateUser(UserModel user);
  Future<void> updateStatus(String uid, String status);
}

class OwnerService {
  Future<List<OwnerModel>> getOwners();
  Future<void> createOwner(OwnerModel owner);
  Future<void> updateOwner(OwnerModel owner);
  Future<String> uploadDocument(String ownerId, File file, String docType);
}
```

---

### 🔧 THÀNH VIÊN 3 — Backend Dev B

> **Trách nhiệm:** Module Forest Project, GIS Map, Forest Inventory.

#### Phạm vi công việc

```
lib/
├── models/
│   ├── project_model.dart
│   ├── forest_boundary_model.dart
│   ├── plot_model.dart
│   └── tree_model.dart
├── services/
│   ├── project_service.dart
│   ├── map_service.dart
│   └── inventory_service.dart
└── modules/
    ├── project/services/
    ├── map/services/
    └── inventory/services/
```

#### Firestore Collections được giao

```
projects/
  - projectId (String)
  - projectName (String)
  - ownerId (String)         # ref đến owners/
  - province (String)
  - district (String)
  - commune (String)
  - forestType (String)
  - treeSpecies (String)
  - yearPlanted (int)
  - status (String)          # draft | surveying | active | suspended
  - createdAt (Timestamp)

forest_boundaries/
  - projectId (String)
  - coordinates (List<Map>) # [{lat, lng}, ...]
  - totalArea (double)       # ha
  - perimeter (double)       # km
  - uploadedFileUrl (String) # shp/geojson/kml
  - createdAt (Timestamp)

plots/
  - plotCode (String)
  - projectId (String)
  - gpsLat (double)
  - gpsLng (double)
  - area (double)
  - createdAt (Timestamp)

trees/
  - plotId (String)
  - species (String)
  - dbh (double)             # Diameter at Breast Height (cm)
  - height (double)          # m
  - quantity (int)
  - createdAt (Timestamp)
```

#### Services phải implement

```dart
class ProjectService {
  Future<List<ProjectModel>> getProjects({String? ownerId});
  Future<void> createProject(ProjectModel project);
  Future<void> updateProject(ProjectModel project);
  Future<void> updateStatus(String projectId, String status);
}

class MapService {
  Future<void> savePolygon(String projectId, List<LatLng> coords);
  Future<ForestBoundaryModel?> getBoundary(String projectId);
  Future<void> uploadShapefile(String projectId, File file);
  double calculateArea(List<LatLng> coords);
}

class InventoryService {
  Future<List<PlotModel>> getPlots(String projectId);
  Future<void> createPlot(PlotModel plot);
  Future<List<TreeModel>> getTrees(String plotId);
  Future<void> createTree(TreeModel tree);
}
```

**Package cần thêm:**
```yaml
dependencies:
  google_maps_flutter: ^2.5.0
  # hoặc
  flutter_map: ^6.0.0       # Mapbox/OpenStreetMap
  geolocator: ^10.0.0
  file_picker: ^6.0.0
```

---

### 🔧 THÀNH VIÊN 4 — Backend Dev C

> **Trách nhiệm:** Module Logbook, Carbon Calculation, Dashboard, Report PDF, Notification.

#### Phạm vi công việc

```
lib/
├── models/
│   ├── logbook_model.dart
│   ├── carbon_result_model.dart
│   └── notification_model.dart
├── services/
│   ├── logbook_service.dart
│   ├── carbon_service.dart
│   ├── dashboard_service.dart
│   ├── report_service.dart
│   └── notification_service.dart
└── modules/
    ├── logbook/services/
    ├── carbon/services/
    ├── dashboard/services/
    └── report/services/
```

#### Firestore Collections được giao

```
logbooks/
  - logbookId (String)
  - projectId (String)
  - userId (String)
  - date (Timestamp)
  - workType (String)       # planting | care | fertilizing | inspection | patrol | fire_prevention
  - gpsLat (double)
  - gpsLng (double)
  - description (String)
  - photoUrls (List<String>)
  - createdAt (Timestamp)

carbon_results/
  - resultId (String)
  - projectId (String)
  - plotId (String)
  - species (String)
  - dbh (double)
  - height (double)
  - quantity (int)
  - speciesFactor (double)
  - biomassKg (double)
  - carbonStockTon (double)
  - co2EquivalentTon (double)
  - calculatedAt (Timestamp)
```

#### Services phải implement

```dart
class LogbookService {
  Future<List<LogbookModel>> getLogbooks({String? projectId, String? userId});
  Future<void> createLogbook(LogbookModel logbook);
  Future<List<String>> uploadPhotos(String logbookId, List<File> photos);
  // max 10 ảnh/bản ghi
}

class CarbonService {
  // Công thức: Biomass = DBH × Height × Quantity × SpeciesFactor
  // Carbon Stock = Biomass × 0.47 / 1000 (tấn)
  // CO2e = Carbon Stock × 3.67
  double calculateBiomass(double dbh, double height, int qty, double factor);
  double calculateCarbonStock(double biomassKg);
  double calculateCO2Equivalent(double carbonStockTon);
  Future<void> saveResult(CarbonResultModel result);
  Future<List<CarbonResultModel>> getResults(String projectId);
  // Lấy species factor từ Firestore config
  Future<double> getSpeciesFactor(String species);
}

class DashboardService {
  Future<Map<String, dynamic>> getPlatformKPIs();
  // Returns: totalOwners, totalProjects, totalAreaHa, totalTrees, totalCO2e
  Future<Map<String, double>> getAreaByProvince();
  Future<Map<String, double>> getCarbonByProject();
  Future<Map<String, int>> getTreesBySpecies();
}

class ReportService {
  Future<File> generateForestSummaryReport(String projectId);
  Future<File> generateInventoryReport(String projectId);
  Future<File> generateActivityReport(String projectId, DateRange range);
}

class NotificationService {
  Future<void> sendNotification(String userId, String type, String message);
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
}
```

**Package cần thêm:**
```yaml
dependencies:
  pdf: ^3.10.0
  printing: ^5.11.0
  firebase_messaging: ^14.0.0
  flutter_local_notifications: ^16.0.0
```

---

## 📅 Timeline Đề Xuất (4 Tuần)

```
TUẦN 1: Setup & Foundation
│
├── Frontend Lead:
│   ├── Setup dự án Flutter + Firebase
│   ├── Tạo core/theme/ (AppColors, AppTextStyles, AppTheme)
│   ├── Tạo core/widgets/ (CustomButton, CustomTextField, CustomCard)
│   ├── Tạo core/routes/ (AppRouter)
│   └── Tạo core/constants/ (AppConstants)
│
├── Backend A: UserModel, OwnerModel, AuthService skeleton
├── Backend B: ProjectModel, PlotModel, TreeModel skeleton
└── Backend C: LogbookModel, CarbonResultModel skeleton

TUẦN 2: Core Screens & Services
│
├── Frontend Lead:
│   ├── Login Screen, Forgot Password Screen
│   ├── Dashboard Screen (dùng mock data)
│   ├── Owner List/Detail Screen
│   └── Project List/Detail Screen
│
├── Backend A: AuthService hoàn thiện, UserService, OwnerService
├── Backend B: ProjectService, MapService (polygon logic)
└── Backend C: LogbookService, CarbonService (công thức)

TUẦN 3: Feature Screens & Integration
│
├── Frontend Lead:
│   ├── Map Screen (tích hợp Google Maps)
│   ├── Inventory Screens (Plot, Tree)
│   ├── Logbook Screen + Camera upload
│   ├── Carbon Calculation Screen
│   └── Connect UI với Services thật (thay mock data)
│
├── Backend A: Upload document, quản lý status
├── Backend B: Shapefile upload, inventory CRUD
└── Backend C: Dashboard aggregation, PDF reports

TUẦN 4: Polish & Testing
│
├── Frontend Lead:
│   ├── Report Screen
│   ├── Notification UI
│   ├── Responsive & edge cases
│   └── Final UI review toàn app
│
├── Backend A: Testing Auth + Owner
├── Backend B: Testing Map + Inventory
└── Backend C: Testing Carbon + Reports + Notifications
```

---

## 🔄 Quy Trình Làm Việc Nhóm

### Git Branch Strategy

```
main
├── develop
│   ├── feature/frontend-core         (Frontend Lead)
│   ├── feature/auth-owner-services   (Backend A)
│   ├── feature/project-map-services  (Backend B)
│   └── feature/logbook-carbon-report (Backend C)
```

### Quy tắc hợp tác

| Tình huống | Quy tắc |
|---|---|
| Cần widget mới | Backend yêu cầu Frontend tạo, không tự tạo |
| Cần field mới trong Model | Thảo luận nhóm trước khi thêm |
| Thay đổi route | Frontend Lead quyết định |
| Thay đổi AppColors | Frontend Lead quyết định |
| Thêm Collection mới | Phải thông báo cả nhóm |

### API Contract giữa Frontend và Backend

Frontend chỉ gọi Service, không gọi Firebase trực tiếp:

```dart
// ✅ ĐÚNG — trong screen
final projects = await ProjectService().getProjects();

// ❌ SAI — trong screen
final snapshot = await FirebaseFirestore.instance.collection('projects').get();
```

Backend phải cung cấp Service với interface rõ ràng trước khi Frontend tích hợp.

---

## 📦 Packages Cần Thiết

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^2.24.0
  firebase_auth: ^4.15.0
  cloud_firestore: ^4.13.0
  firebase_storage: ^11.5.0
  firebase_messaging: ^14.7.0

  # UI
  google_fonts: ^6.1.0

  # Map
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0

  # Charts (Dashboard)
  fl_chart: ^0.65.0

  # File & Image
  image_picker: ^1.0.4
  file_picker: ^6.1.1

  # PDF Report
  pdf: ^3.10.7
  printing: ^5.11.3

  # Local Storage (Offline Mode)
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # Notification
  flutter_local_notifications: ^16.2.0

  # Utils
  intl: ^0.18.1
  uuid: ^4.2.1
```

---

## 🏗️ Cấu Trúc Thư Mục Hoàn Chỉnh

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart       # padding=16, radius=12
│   │   └── app_strings.dart
│   ├── theme/
│   │   ├── app_colors.dart          # ← Frontend Lead, KHÔNG ai sửa
│   │   ├── app_text_styles.dart     # ← Frontend Lead, KHÔNG ai sửa
│   │   └── app_theme.dart
│   ├── routes/
│   │   ├── app_router.dart          # ← Frontend Lead, KHÔNG ai sửa
│   │   └── route_names.dart
│   └── widgets/                     # ← Frontend Lead, KHÔNG ai sửa
│       ├── custom_button.dart
│       ├── custom_text_field.dart
│       ├── custom_card.dart
│       ├── loading_overlay.dart
│       └── empty_state_widget.dart
│
├── models/                          # ← Backend devs tạo
│   ├── user_model.dart
│   ├── owner_model.dart
│   ├── project_model.dart
│   ├── forest_boundary_model.dart
│   ├── plot_model.dart
│   ├── tree_model.dart
│   ├── logbook_model.dart
│   └── carbon_result_model.dart
│
├── services/                        # ← Backend devs tạo
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── owner_service.dart
│   ├── project_service.dart
│   ├── map_service.dart
│   ├── inventory_service.dart
│   ├── logbook_service.dart
│   ├── carbon_service.dart
│   ├── dashboard_service.dart
│   ├── report_service.dart
│   └── notification_service.dart
│
└── modules/
    ├── auth/
    │   └── screens/                 # ← Frontend Lead
    ├── owner/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── project/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── map/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── inventory/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── logbook/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── carbon/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    ├── dashboard/
    │   ├── screens/                 # ← Frontend Lead
    │   └── widgets/                 # ← Frontend Lead
    └── report/
        └── screens/                 # ← Frontend Lead
```

---

## ✅ Checklist Trước Khi Tạo Code

### Frontend Lead — Checklist

- [ ] Màu lấy từ `AppColors`? Không hard-code?
- [ ] Button dùng `CustomButton`?
- [ ] Input dùng `CustomTextField`?
- [ ] Padding/margin dùng constant?
- [ ] File > 300 dòng? → Tách widget
- [ ] Có dùng mock data rõ ràng để Backend dễ thay?

### Backend Dev — Checklist

- [ ] Model có đủ `fromMap()`, `toMap()`, `copyWith()`?
- [ ] Field name là camelCase?
- [ ] Không gọi Firebase trực tiếp trong UI?
- [ ] Chỉ thao tác collection được giao?
- [ ] Không thay đổi schema collection của người khác?
- [ ] Không sửa `core/`, `routes/`, `theme/`?

---

## 🚀 Điểm Mạnh Của Plan Điều Chỉnh

| Plan Gốc (module dọc) | Plan Mới (frontend/backend tách) |
|---|---|
| 4 người làm UI → không đồng nhất | 1 người làm UI → hoàn toàn thống nhất |
| Dễ conflict `core/`, `theme/` | Frontend Lead owns toàn bộ `core/` |
| Backend dev mất thời gian làm UI | Backend dev tập trung vào logic, service |
| Khó review UI toàn app | Frontend Lead có cái nhìn tổng thể |
| Sprint planning phức tạp | Ranh giới rõ ràng, ít phụ thuộc |

---

*Tài liệu này được tạo cho đề tài cuối kỳ môn Flutter — Forest Carbon Management System*
