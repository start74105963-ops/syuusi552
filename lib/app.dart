import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/home/home_screen.dart';
import 'features/records/record_form_screen.dart';
import 'features/records/records_screen.dart';
import 'features/settings/settings_screen.dart';

class SlotManagerApp extends StatelessWidget {
  const SlotManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'スロット収支管理',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja', 'JP')],
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0=ホーム 1=履歴 2=分析 3=設定
  int _pageIndex = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    RecordsScreen(),
    AnalysisScreen(),
    SettingsScreen(),
  ];

  // ナビバーのインデックス（2=FABなのでずれる）
  int get _navIndex => _pageIndex >= 2 ? _pageIndex + 1 : _pageIndex;

  void _onNavTap(int navI) {
    if (navI == 2) return; // FAB は別ハンドラ
    final pageI = navI > 2 ? navI - 1 : navI;
    setState(() => _pageIndex = pageI);
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RecordFormScreen(initialDate: DateTime.now()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: _pages),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _navIndex,
        onTap: _onNavTap,
        onAdd: () => _openForm(context),
      ),
    );
  }
}

// ─── カスタムボトムナビ ────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(navI: 0, icon: Icons.home_outlined,    activeIcon: Icons.home,      label: 'ホーム',  selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(navI: 1, icon: Icons.history_outlined, activeIcon: Icons.history,   label: '履歴',    selectedIndex: selectedIndex, onTap: onTap),
              _AddButton(onTap: onAdd),
              _NavItem(navI: 3, icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: '分析',  selectedIndex: selectedIndex, onTap: onTap),
              _NavItem(navI: 4, icon: Icons.settings_outlined, activeIcon: Icons.settings,  label: '設定',   selectedIndex: selectedIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int navI;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.navI,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex == navI;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(navI),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
