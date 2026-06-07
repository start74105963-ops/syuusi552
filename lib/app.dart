import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/analysis/analysis_screen.dart';
import 'features/home/home_screen.dart';
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
  int _pageIndex = 0;

  final _pages = const <Widget>[
    HomeScreen(),
    AnalysisScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _pageIndex, children: _pages),
      bottomNavigationBar: Container(
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
                _NavItem(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'ホーム', selected: _pageIndex == 0, onTap: () => setState(() => _pageIndex = 0)),
                _NavItem(index: 1, icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: '分析', selected: _pageIndex == 1, onTap: () => setState(() => _pageIndex = 1)),
                _NavItem(index: 2, icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '設定', selected: _pageIndex == 2, onTap: () => setState(() => _pageIndex = 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 24,
                color: selected ? AppColors.primary : AppColors.onSurfaceMuted),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
                )),
          ],
        ),
      ),
    );
  }
}
