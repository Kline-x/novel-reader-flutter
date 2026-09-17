import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/components/main_scaffold.dart';
import 'core/theme/soft_theme.dart';

import 'core/theme/theme_provider.dart';

import 'features/local_books/services/local_book_service.dart';
import 'features/local_books/services/wifi_transfer_server.dart';
import 'features/reader/data/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预热持久化阅读设置
  await StorageService.init();

  // 绑定局域网 WiFi 传书与本地图书自动解析入架
  WifiTransferServer().onFileReceived = (file) async {
    await LocalBookService().importFile(file);
  };

  // 设置全局统一的透明沉浸式系统状态栏与手势底栏 (edgeToEdge)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: NovelReaderApp(),
    ),
  );
}

class NovelReaderApp extends ConsumerWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(softColorsProvider);

    // 动态联动状态栏与导航栏图标明暗 (解决 T5 深色背景白图标，浅色背景黑图标)
    final iconBrightness = colors.isDark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: colors.isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );

    return SoftTheme(
      colors: colors,
      child: MaterialApp(
        title: '藏书阁',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: colors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: colors.accent,
            surface: colors.surface,
            brightness: colors.isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        home: const MainScaffold(),
      ),
    );
  }
}
