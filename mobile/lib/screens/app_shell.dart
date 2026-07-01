import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/hex.dart';
import '../theme/tokens.dart';
import '../widgets/update_sheet.dart';
import 'catalog_grid_screen.dart';
import 'home_screen.dart';
import 'menu_screen.dart';

/// Root shell: bottom tab bar hosting Home / Explore / Menu.
/// Runs a silent auto-update check on first launch.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.watch<AppState>().l;
    return Scaffold(
      body: DecoratedBox(
        decoration: T.screenBackground,
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              HomeScreen(onOpenExplore: () => setState(() => _index = 1)),
              const CatalogGridScreen(),
              const MenuScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          _NavItem(Icons.home_rounded, l.pick('หน้าแรก', 'Home')),
          _NavItem(Icons.travel_explore_rounded, l.pick('สำรวจ', 'Explore')),
          _NavItem(Icons.menu_rounded, l.pick('เมนู', 'Menu')),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xEB0E0B07),
        border: Border(top: BorderSide(color: T.hairline)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
      height: 66 + MediaQuery.of(context).viewPadding.bottom,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: _navTile(items[i], i == index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navTile(_NavItem item, bool active) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        HexBox(
          size: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? T.accent.withValues(alpha: 0.18) : Colors.transparent,
            ),
            child: Icon(item.icon, size: 15, color: active ? T.accent : const Color(0xFF5A5346)),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          item.label,
          style: AppTheme.body(9,
              weight: FontWeight.w600, color: active ? T.textPrimary : T.textInactive),
        ),
      ],
    );
  }
}
