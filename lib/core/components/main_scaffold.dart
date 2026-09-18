import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/shelf/presentation/discovery_page.dart';
import '../../features/shelf/presentation/shelf_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../theme/soft_theme.dart';
import 'docked_bottom_bar.dart';

/// 主屏脚手架 (main_scaffold.dart)
/// 承载书架、发现、设置三大页面，底部悬浮毛玻璃三胶囊导航 Dock
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final colors = SoftTheme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '再按一次退出藏书阁',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: BorderSide(color: colors.border),
              ),
              elevation: 4.0,
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // 0. Modern Soft UI 环境光微晕染底图 (Calm Tech Ambient Glow)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    // 左上轻柔暖光微晕染
                    Positioned(
                      top: -60.0,
                      left: -60.0,
                      width: 240.0,
                      height: 240.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.isDark
                                  ? const Color(0xFFE5B76C)
                                      .withValues(alpha: 0.04)
                                  : const Color(0xFFFED7AA)
                                      .withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 右侧天青微晕染
                    Positioned(
                      top: 140.0,
                      right: -50.0,
                      width: 260.0,
                      height: 260.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.isDark
                                  ? const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.03)
                                  : const Color(0xFFBAE6FD)
                                      .withValues(alpha: 0.30),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1. 三大核心页面 IndexedStack
            IndexedStack(
              index: _currentIndex,
              children: [
                ShelfPage(
                  onNavigateToDiscovery: () =>
                      setState(() => _currentIndex = 1),
                ),
                const DiscoveryPage(),
                const SettingsPage(),
              ],
            ),

            // 2. Modern Soft UI 沉浸贴底毛玻璃底栏 (58px + safe area)
            DockedBottomBar(
              currentIndex: _currentIndex,
              colors: colors,
              onTabSelected: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
