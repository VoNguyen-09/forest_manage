// ═══════════════════════════════════════════════════════════════════════════
//  AppStrings — Mọi chuỗi UI phải dùng từ đây, không hardcode trong widget
// ═══════════════════════════════════════════════════════════════════════════
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'Forest Carbon Platform';

  // Auth
  static const String login = 'Đăng nhập';
  static const String email = 'Email';
  static const String password = 'Mật khẩu';
  static const String forgotPassword = 'Quên mật khẩu?';
  static const String otpLogin = 'Đăng nhập bằng OTP';
  static const String logout = 'Đăng xuất';
  static const String otpSent = 'Mã OTP đã gửi vào email của bạn';

  // Nav
  static const String dashboard = 'Tổng quan';
  static const String map = 'Bản đồ';
  static const String logbook = 'Nhật ký';
  static const String inventory = 'Điều tra rừng';
  static const String checkin = 'Check-in GPS';
  static const String carbon = 'Tính toán Carbon';
  static const String reports = 'Báo cáo';
  static const String notifications = 'Thông báo';
  static const String fileManager = 'Quản lý tài liệu';
  static const String accountManagement = 'Quản lý tài khoản';

  // Forest Owner
  static const String forestOwnerManagement = 'Quản lý chủ rừng';
  static const String addOwner = 'Thêm chủ rừng';
  static const String ownerName = 'Tên chủ rừng';
  static const String ownerCode = 'Mã chủ rừng';
  static const String ownerType = 'Loại hình';

  // Forest Project
  static const String forestProjectManagement = 'Quản lý dự án rừng';
  static const String addProject = 'Thêm dự án';
  static const String projectName = 'Tên dự án';
  static const String forestType = 'Loại rừng';
  static const String treeSpecies = 'Loài cây';
  static const String yearPlanted = 'Năm trồng';

  // GIS
  static const String drawPolygon = 'Vẽ ranh giới';
  static const String uploadShapefile = 'Tải lên shapefile';
  static const String totalArea = 'Tổng diện tích';
  static const String perimeter = 'Chu vi';

  // Inventory
  static const String plotCode = 'Mã ô mẫu';
  static const String plotArea = 'Diện tích ô (m²)';
  static const String species = 'Loài cây';
  static const String dbh = 'Đường kính (DBH cm)';
  static const String height = 'Chiều cao (m)';
  static const String quantity = 'Số lượng (cây)';

  // Carbon
  static const String biomass = 'Sinh khối (kg)';
  static const String carbonStock = 'Trữ lượng Carbon (tC)';
  static const String co2Equivalent = 'CO₂ Tương đương (tCO₂e)';
  static const String speciesFactor = 'Hệ số loài';
  static const String calculate = 'Tính toán';

  // Common actions
  static const String save = 'Lưu';
  static const String cancel = 'Hủy';
  static const String delete = 'Xóa';
  static const String edit = 'Chỉnh sửa';
  static const String add = 'Thêm';
  static const String search = 'Tìm kiếm';
  static const String filter = 'Lọc';
  static const String upload = 'Tải lên';
  static const String download = 'Tải xuống';
  static const String confirm = 'Xác nhận';
  static const String retry = 'Thử lại';
  static const String sync = 'Đồng bộ';
  static const String viewDetail = 'Xem chi tiết';

  // Status
  static const String active = 'Hoạt động';
  static const String inactive = 'Không hoạt động';
  static const String locked = 'Đã khóa';
  static const String draft = 'Nháp';
  static const String surveying = 'Đang khảo sát';
  static const String suspended = 'Tạm dừng';
  static const String pendingSync = 'Chưa đồng bộ';

  // Offline
  static const String offlineMode = 'Đang ngoại tuyến';
  static const String pendingItems = 'mục chưa đồng bộ';
  static const String syncSuccess = 'Đồng bộ thành công';
  static const String syncFailed = 'Đồng bộ thất bại';

  // Errors
  static const String errorGeneral = 'Có lỗi xảy ra. Vui lòng thử lại.';
  static const String errorNoInternet = 'Không có kết nối internet';
  static const String errorPermission = 'Cần cấp quyền để tiếp tục';
  static const String errorEmpty = 'Chưa có dữ liệu';
  static const String errorInvalidInput = 'Dữ liệu không hợp lệ';

  // Validation
  static const String fieldRequired = 'Trường này là bắt buộc';
  static const String invalidEmail = 'Email không hợp lệ';
  static const String invalidNumber = 'Phải là số dương';
  static const String minPolygonPoints = 'Cần ít nhất 3 điểm để tạo vùng';
}

// ── Route names ──────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otpLogin = '/otp-login';
  static const String dashboardAdmin = '/dashboard/admin';
  static const String dashboardOwner = '/dashboard/owner';
  static const String dashboardWorker = '/dashboard/worker';
  static const String map = '/map';
  static const String forestOwners = '/forest-owners';
  static const String forestOwnerAdd = '/forest-owners/add';
  static const String forestOwnerDetail = '/forest-owners/:id';
  static const String forestWorkers = '/forest-workers';
  static const String adminForestWorkers = '/admin/forest-workers';
  static const String forestProjects = '/forest-projects';
  static const String forestProjectAdd = '/forest-projects/add';
  static const String forestProjectDetail = '/forest-projects/:id';
  static const String logbook = '/logbook';
  static const String logbookAdd = '/logbook/add';
  static const String inventory = '/inventory';
  static const String inventoryAdd = '/inventory/add';
  static const String checkin = '/checkin';
  static const String carbon = '/carbon';
  static const String speciesFactors = '/species-factors';
  static const String reports = '/reports';
  static const String notifications = '/notifications';
  static const String fileManager = '/files';
  static const String accounts = '/accounts';
  static const String assignWorkers = '/forest-projects/assign';
}

// ── Hive Box Names ────────────────────────────────────────────────────────────
class HiveBoxes {
  HiveBoxes._();
  static const String pendingLogs = 'pending_logs';
  static const String pendingCheckins = 'pending_checkins';
  static const String pendingTreeData = 'pending_tree_data';
  static const String userCache = 'user_cache';
}

// ── Firestore Collections ─────────────────────────────────────────────────────
class FirestoreCollections {
  FirestoreCollections._();
  static const String users = 'users';
  static const String forestOwners = 'forestOwners';
  static const String forestProjects = 'forestProjects';
  static const String plots = 'plots';
  static const String logEntries = 'logEntries';
  static const String carbonResults = 'carbonResults';
  static const String speciesFactors = 'speciesFactors';
  static const String notifications = 'notifications';
  static const String files = 'files';
  static const String workerLocations = 'workerLocations';
}
