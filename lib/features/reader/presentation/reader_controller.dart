import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_page_theme.dart';

class ReaderSettingsState {
  final double fontSize;
  final double lineHeight;
  final ReaderThemeOption theme;
  final PageTurnMode turnMode;

  const ReaderSettingsState({
    this.fontSize = 18.0,
    this.lineHeight = 30.0,
    this.theme = ReaderThemeOption.defaultTheme,
    this.turnMode = PageTurnMode.slide,
  });

  ReaderSettingsState copyWith({
    double? fontSize,
    double? lineHeight,
    ReaderThemeOption? theme,
    PageTurnMode? turnMode,
  }) {
    return ReaderSettingsState(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      theme: theme ?? this.theme,
      turnMode: turnMode ?? this.turnMode,
    );
  }
}

class ReaderSettingsNotifier extends StateNotifier<ReaderSettingsState> {
  ReaderSettingsNotifier() : super(const ReaderSettingsState());

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size, lineHeight: size * 1.68);
  }

  void setLineHeight(double height) {
    state = state.copyWith(lineHeight: height);
  }

  void setTheme(ReaderThemeOption theme) {
    state = state.copyWith(theme: theme);
  }

  void setTurnMode(PageTurnMode mode) {
    state = state.copyWith(turnMode: mode);
  }
}

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettingsState>((ref) {
  return ReaderSettingsNotifier();
});
