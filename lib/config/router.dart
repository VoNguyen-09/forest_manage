import 'package:go_router/go_router.dart';
import 'package:forest_carbon_platform/config/constants.dart';
import 'package:forest_carbon_platform/features/auth/screens/login_screen.dart';
import 'package:forest_carbon_platform/features/dashboard/screens/dashboard_admin_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.login,
  routes: [
    // ── Auth ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),

    // ── Dashboard ──────────────────────────────────
    GoRoute(
      path: AppRoutes.dashboardAdmin,
      name: 'dashboardAdmin',
      builder: (context, state) => const DashboardAdminScreen(),
    ),
  ],

  // TODO: Add all routes as features are built
  // GoRoute(path: AppRoutes.dashboardOwner, ...)
  // GoRoute(path: AppRoutes.map, ...)
  // GoRoute(path: AppRoutes.forestOwners, ...)
  // GoRoute(path: AppRoutes.logbook, ...)
  // GoRoute(path: AppRoutes.inventory, ...)
  // GoRoute(path: AppRoutes.checkin, ...)
  // GoRoute(path: AppRoutes.carbon, ...)
  // GoRoute(path: AppRoutes.reports, ...)
  // GoRoute(path: AppRoutes.notifications, ...)
  // GoRoute(path: AppRoutes.fileManager, ...)
  // GoRoute(path: AppRoutes.accounts, ...)
);
