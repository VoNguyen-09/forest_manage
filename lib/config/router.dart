import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/core/models/forest_owner_model.dart';
import 'package:forest_carbon_platform/core/models/forest_project_model.dart';
import 'package:forest_carbon_platform/features/auth/screens/login_screen.dart';
import 'package:forest_carbon_platform/features/dashboard/screens/dashboard_admin_screen.dart';
import 'package:forest_carbon_platform/features/dashboard/screens/dashboard_owner_screen.dart';
import 'package:forest_carbon_platform/features/worker/screens/worker_dashboard_screen.dart';
import 'package:forest_carbon_platform/features/file_manager/screens/file_manager_screen.dart';
import 'package:forest_carbon_platform/features/notifications/screens/notification_screen.dart';
import 'package:forest_carbon_platform/features/accounts/screens/account_management_screen.dart';
import 'package:forest_carbon_platform/features/auth/screens/otp_login_screen.dart';
import 'package:forest_carbon_platform/features/carbon/screens/carbon_calculation_screen.dart';
import 'package:forest_carbon_platform/features/carbon/screens/species_factor_screen.dart';
import 'package:forest_carbon_platform/features/reports/screens/reports_screen.dart';
import 'package:forest_carbon_platform/features/forest_owners/screens/forest_owners_screen.dart';
import 'package:forest_carbon_platform/features/forest_owners/screens/forest_owner_form_screen.dart';
import 'package:forest_carbon_platform/features/forest_workers/screens/forest_workers_screen.dart';
import 'package:forest_carbon_platform/features/accounts/screens/admin_forest_workers_screen.dart';
import 'package:forest_carbon_platform/features/forest_projects/screens/forest_projects_screen.dart';
import 'package:forest_carbon_platform/features/forest_projects/screens/forest_project_form_screen.dart';
import 'package:forest_carbon_platform/features/forest_projects/screens/assign_workers_screen.dart';
import 'package:forest_carbon_platform/features/map/screens/map_screen.dart';

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
      path: AppRoutes.otpLogin,
      name: 'otpLogin',
      builder: (context, state) => const OtpLoginScreen(),
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
    GoRoute(
      path: AppRoutes.dashboardWorker,
      name: 'dashboardWorker',
      builder: (context, state) => const WorkerDashboardScreen(),
    ),

    // ── File Manager ────────────────────────────────
    GoRoute(
      path: AppRoutes.fileManager,
      name: 'fileManager',
      builder: (context, state) => const FileManagerScreen(),
    ),

    // ── Notifications ───────────────────────────────
    GoRoute(
      path: AppRoutes.notifications,
      name: 'notifications',
      builder: (context, state) => const NotificationScreen(),
    ),

    // ── Accounts ────────────────────────────────────
    GoRoute(
      path: AppRoutes.accounts,
      name: 'accounts',
      builder: (context, state) => const AccountManagementScreen(),
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

    // ── Forest Owners ──────────────────────────────
    GoRoute(
      path: AppRoutes.forestOwners,
      name: 'forestOwners',
      builder: (context, state) => const ForestOwnersScreen(),
    ),
    GoRoute(
      path: AppRoutes.forestOwnerAdd,
      name: 'forestOwnerAdd',
      builder: (context, state) {
        final owner = state.extra as ForestOwnerModel?;
        return ForestOwnerFormScreen(owner: owner);
      },
    ),

    // ── Forest Workers ─────────────────────────────
    GoRoute(
      path: AppRoutes.forestWorkers,
      name: 'forestWorkers',
      builder: (context, state) => const ForestWorkersScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminForestWorkers,
      name: 'adminForestWorkers',
      builder: (context, state) => const AdminForestWorkersScreen(),
    ),

    // ── Forest Projects ─────────────────────────────
    GoRoute(
      path: AppRoutes.forestProjects,
      name: 'forestProjects',
      builder: (context, state) => const ForestProjectsScreen(),
    ),
    GoRoute(
      path: AppRoutes.forestProjectAdd,
      name: 'forestProjectAdd',
      builder: (context, state) {
        final project = state.extra as ForestProjectModel?;
        return ForestProjectFormScreen(project: project);
      },
    ),
    GoRoute(
      path: AppRoutes.assignWorkers,
      name: 'assignWorkers',
      builder: (context, state) {
        final project = state.extra as ForestProjectModel;
        return AssignWorkersScreen(project: project);
      },
    ),

    // ── Map ─────────────────────────────────────────
    GoRoute(
      path: AppRoutes.map,
      name: 'map',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final isSelectingForForm =
            extra?['isSelectingForForm'] as bool? ?? false;
        final initialPolygon = extra?['initialPolygon'];
        return MapScreen(
          isSelectingForForm: isSelectingForForm,
          initialPolygon: initialPolygon,
        );
      },
    ),
  ],

  // TODO: Add remaining routes as features are built
  // GoRoute(path: AppRoutes.forestOwnerDetail, ...)
  // GoRoute(path: AppRoutes.forestProjectDetail, ...)
  // GoRoute(path: AppRoutes.logbook, ...)
  // GoRoute(path: AppRoutes.inventory, ...)
  // GoRoute(path: AppRoutes.checkin, ...)
  // GoRoute(path: AppRoutes.notifications, ...)
  // GoRoute(path: AppRoutes.accounts, ...)
);
