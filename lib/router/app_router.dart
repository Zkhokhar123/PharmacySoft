import 'package:go_router/go_router.dart';

import '../features/categories/categories_screen.dart';
import '../features/customers/customer_ledger_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/inventory/medicine_detail_screen.dart';
import '../features/inventory/medicine_form_screen.dart';
import '../features/purchases/purchase_form_screen.dart';
import '../features/purchases/purchases_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/sales/invoice_screen.dart';
import '../features/sales/pos_screen.dart';
import '../features/sales/sales_history_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/suppliers/supplier_ledger_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../shared/widgets/app_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        // 0 — Dashboard
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/dashboard',
              builder: (c, s) => const DashboardScreen()),
        ]),
        // 1 — Inventory
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/inventory',
            builder: (c, s) => const InventoryScreen(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (c, s) => MedicineDetailScreen(
                    medicineId: s.pathParameters['id']!),
              ),
              GoRoute(
                path: 'form',
                builder: (c, s) => MedicineFormScreen(
                    medicineId: s.uri.queryParameters['id']),
              ),
            ],
          ),
        ]),
        // 2 — POS
        StatefulShellBranch(routes: [
          GoRoute(path: '/pos', builder: (c, s) => const PosScreen()),
        ]),
        // 3 — Sales history
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/sales',
            builder: (c, s) => const SalesHistoryScreen(),
            routes: [
              GoRoute(
                path: 'invoice/:id',
                builder: (c, s) => InvoiceScreen(
                  saleId: s.pathParameters['id']!,
                  autoPrint: s.uri.queryParameters['autoPrint'] == 'true',
                ),
              ),
            ],
          ),
        ]),
        // 4 — Purchases
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/purchases',
            builder: (c, s) => const PurchasesScreen(),
            routes: [
              GoRoute(
                path: 'form',
                builder: (c, s) => PurchaseFormScreen(
                  initialMedicineId: s.uri.queryParameters['medicineId'],
                ),
              ),
            ],
          ),
        ]),
        // 5 — Customers & Credit  ← NEW
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/customers',
            builder: (c, s) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'ledger/:id',
                builder: (c, s) => CustomerLedgerScreen(
                    customerId: s.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        // 6 — Suppliers
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/suppliers',
            builder: (c, s) => const SuppliersScreen(),
            routes: [
              GoRoute(
                path: 'ledger/:id',
                builder: (c, s) => SupplierLedgerScreen(
                    supplierId: s.pathParameters['id']!),
              ),
            ],
          ),
        ]),
        // 7 — Categories
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/categories',
              builder: (c, s) => const CategoriesScreen()),
        ]),
        // 8 — Expenses
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/expenses',
              builder: (c, s) => const ExpensesScreen()),
        ]),
        // 9 — Reports
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/reports', builder: (c, s) => const ReportsScreen()),
        ]),
        // 10 — Settings
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/settings',
              builder: (c, s) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);
