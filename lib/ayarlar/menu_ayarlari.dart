import 'package:flutter/material.dart';

class MenuItem {
  final String id;
  final String labelKey;
  final IconData icon;
  final int? index;
  final List<MenuItem> children;

  const MenuItem({
    required this.id,
    required this.labelKey,
    required this.icon,
    this.index,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
}

class MenuAyarlari {
  static const List<MenuItem> menuItems = [
    MenuItem(
      id: 'home',
      labelKey: 'nav.home',
      icon: Icons.home_rounded,
      index: 0,
    ),

    MenuItem(
      id: 'trading_operations',
      labelKey: 'nav.trading_operations',
      icon: Icons.shopping_bag_rounded,
      children: [
        MenuItem(
          id: 'trading_operations.fast_sale',
          labelKey: 'nav.trading_operations.fast_sale',
          icon: Icons.flash_on_rounded,
          index: 23,
        ),
        MenuItem(
          id: 'trading_operations.make_purchase',
          labelKey: 'nav.trading_operations.make_purchase',
          icon: Icons.add_shopping_cart_rounded,
          index: 10,
        ),
        MenuItem(
          id: 'trading_operations.make_sale',
          labelKey: 'nav.trading_operations.make_sale',
          icon: Icons.point_of_sale_rounded,
          index: 11,
        ),
        MenuItem(
          id: 'trading_operations.retail_sale',
          labelKey: 'nav.trading_operations.retail_sale',
          icon: Icons.storefront_rounded,
          index: 12,
        ),
      ],
    ),
    MenuItem(
      id: 'orders_quotes',
      labelKey: 'nav.orders_quotes',
      icon: Icons.assignment_rounded,
      children: [
        MenuItem(
          id: 'orders_quotes.orders',
          labelKey: 'nav.orders_quotes.orders',
          icon: Icons.shopping_cart_checkout_rounded,
          index: 18,
        ),
        MenuItem(
          id: 'orders_quotes.quotes',
          labelKey: 'nav.orders_quotes.quotes',
          icon: Icons.request_quote_rounded,
          index: 19,
        ),
      ],
    ),
    MenuItem(
      id: 'products_warehouses',
      labelKey: 'nav.products_warehouses',
      icon: Icons.inventory_2_rounded,
      children: [
        MenuItem(
          id: 'products_warehouses.products',
          labelKey: 'nav.products_warehouses.products',
          icon: Icons.inventory_rounded,
          index: 7,
        ),
        MenuItem(
          id: 'products_warehouses.productions',
          labelKey: 'nav.products_warehouses.productions',
          icon: Icons.precision_manufacturing_rounded,
          index: 8,
        ),
        MenuItem(
          id: 'products_warehouses.warehouses',
          labelKey: 'nav.products_warehouses.warehouses',
          icon: Icons.warehouse_rounded,
          index: 6,
        ),
      ],
    ),
    MenuItem(
      id: 'accounts',
      labelKey: 'nav.accounts',
      icon: Icons.account_balance_wallet_rounded,
      index: 9,
    ),
    MenuItem(
      id: 'cash_bank',
      labelKey: 'nav.cash_bank',
      icon: Icons.account_balance_rounded,
      children: [
        MenuItem(
          id: 'cash_bank.cash',
          labelKey: 'nav.cash_bank.cash',
          icon: Icons.payments_rounded,
          index: 13,
        ),
        MenuItem(
          id: 'cash_bank.banks',
          labelKey: 'nav.cash_bank.banks',
          icon: Icons.account_balance_rounded,
          index: 15,
        ),
        MenuItem(
          id: 'cash_bank.credit_cards',
          labelKey: 'nav.cash_bank.credit_cards',
          icon: Icons.credit_card_rounded,
          index: 16,
        ),
      ],
    ),
    MenuItem(
      id: 'checks_notes',
      labelKey: 'nav.checks_notes',
      icon: Icons.receipt_long_rounded,
      children: [
        MenuItem(
          id: 'checks_notes.checks',
          labelKey: 'nav.checks_notes.checks',
          icon: Icons.description_rounded,
          index: 14,
        ),
        MenuItem(
          id: 'checks_notes.notes',
          labelKey: 'nav.checks_notes.notes',
          icon: Icons.note_alt_rounded,
          index: 17,
        ),
      ],
    ),
    MenuItem(
      id: 'personnel_user',
      labelKey: 'nav.personnel_user',
      icon: Icons.people_alt_rounded,
      index: 1,
    ),
    MenuItem(
      id: 'expenses',
      labelKey: 'nav.expenses',
      icon: Icons.money_off_rounded,
      index: 100,
    ),
    MenuItem(
      id: 'print_settings',
      labelKey: 'nav.print_settings',
      icon: Icons.print_rounded,
      index: 101,
    ),
    MenuItem(
      id: 'settings',
      labelKey: 'nav.settings',
      icon: Icons.settings_rounded,
      children: [
        MenuItem(
          id: 'settings.roles',
          labelKey: 'nav.settings.roles_permissions',
          icon: Icons.admin_panel_settings_rounded,
          index: 2,
        ),
        MenuItem(
          id: 'settings.company',
          labelKey: 'nav.settings.company',
          icon: Icons.business_rounded,
          index: 3,
        ),
        MenuItem(
          id: 'settings.modules',
          labelKey: 'nav.settings.modules',
          icon: Icons.view_module_rounded,
          index: 22,
        ),
        MenuItem(
          id: 'settings.general',
          labelKey: 'nav.settings.general',
          icon: Icons.tune_rounded,
          index: 4,
        ),
        MenuItem(
          id: 'settings.ai',
          labelKey: 'nav.settings.ai',
          icon: Icons.psychology_rounded,
          index: 20,
        ),
        MenuItem(
          id: 'settings.database_backup',
          labelKey: 'nav.settings.database_backup',
          icon: Icons.storage_rounded,
          index: 50,
        ),
        MenuItem(
          id: 'settings.language',
          labelKey: 'nav.settings.language',
          icon: Icons.language_rounded,
          index: 5,
        ),
      ],
    ),
  ];

  static MenuItem? findByIndex(int index) {
    MenuItem? search(MenuItem item) {
      if (item.index == index) return item;
      for (final child in item.children) {
        final found = search(child);
        if (found != null) return found;
      }
      return null;
    }

    for (final item in menuItems) {
      final found = search(item);
      if (found != null) return found;
    }
    return null;
  }
}
