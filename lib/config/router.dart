import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/features/auth/screens/login_screen.dart';
import 'package:forest_carbon_platform/features/dashboard/screens/dashboard_admin_screen.dart';
import 'package:forest_carbon_platform/features/dashboard/screens/dashboard_owner_screen.dart';
import 'package:forest_carbon_platform/features/file_manager/screens/file_manager_screen.dart';
import 'package:forest_carbon_platform/features/auth/screens/forgot_password_screen.dart';
import 'package:forest_carbon_platform/features/auth/screens/change_password_screen.dart';
// ── TV4 — Carbon Engine & Reports ─────────────────────────────────────────────
import 'package:forest_carbon_platform/features/carbon/screens/carbon_calculation_screen.dart';
import 'package:forest_carbon_platform/features/carbon/screens/species_factor_screen.dart';
import 'package:forest_carbon_platform/features/reports/screens/reports_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    // ── Auth ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    // Route đổi mật khẩu, trong thực tế có thể cần đặt trong một ShellRoute hoặc nested route sau khi login
    GoRoute(
      path: '/change-password',
      name: 'changePassword',
      builder: (context, state) => const ChangePasswordScreen(),
    ),

    // ── Dashboard ──────────────────────────────────
    GoRoute(
      path: AppRoutes.dashboardAdmin,
      name: 'dashboardAdmin',
      builder: (context, state) => const DashboardAdminScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboardOwner,
      name: 'dashboardOwner',
      builder: (context, state) => const DashboardOwnerScreen(),
    ),
    
    // ── File Manager ────────────────────────────────
    GoRoute(
      path: AppRoutes.fileManager,
      name: 'fileManager',
      builder: (context, state) => const FileManagerScreen(),
    ),

    // ── TV4 — Carbon Calculation ────────────────────
    GoRoute(
      path: AppRoutes.carbon,
      name: 'carbon',
      builder: (context, state) => const CarbonCalculationScreen(),
    ),

    // ── TV4 — Species Factor Config (Admin only) ────
    GoRoute(
      path: AppRoutes.speciesFactors,
      name: 'speciesFactors',
      builder: (context, state) => const SpeciesFactorScreen(),
    ),

    // ── TV4 — PDF Reports ───────────────────────────
    GoRoute(
      path: AppRoutes.reports,
      name: 'reports',
      builder: (context, state) => const ReportsScreen(),
    ),
  ],

  // TODO: Add all routes as features are built
  // GoRoute(path: AppRoutes.map, ...)
  // GoRoute(path: AppRoutes.forestOwners, ...)
  // GoRoute(path: AppRoutes.logbook, ...)
  // GoRoute(path: AppRoutes.inventory, ...)
  // GoRoute(path: AppRoutes.checkin, ...)
  // GoRoute(path: AppRoutes.notifications, ...)
  // GoRoute(path: AppRoutes.accounts, ...)
);
