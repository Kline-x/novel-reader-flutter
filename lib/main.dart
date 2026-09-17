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

  // 设置透明沉浸式系统状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
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
