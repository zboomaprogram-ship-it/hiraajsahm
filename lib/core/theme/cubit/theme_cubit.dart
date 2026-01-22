import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/storage_service.dart';

// ============ THEME STATE ============
class ThemeState extends Equatable {
  final ThemeMode themeMode;

  const ThemeState({required this.themeMode});

  factory ThemeState.initial() {
    return const ThemeState(themeMode: ThemeMode.system);
  }

  ThemeState copyWith({ThemeMode? themeMode}) {
    return ThemeState(themeMode: themeMode ?? this.themeMode);
  }

  bool get isDarkMode => themeMode == ThemeMode.dark;
  bool get isLightMode => themeMode == ThemeMode.light;
  bool get isSystemMode => themeMode == ThemeMode.system;

  @override
  List<Object?> get props => [themeMode];
}

// ============ THEME CUBIT ============
class ThemeCubit extends Cubit<ThemeState> {
  final StorageService _storageService;

  ThemeCubit({required StorageService storageService})
    : _storageService = storageService,
      super(ThemeState.initial());

  /// Initialize theme from stored preference
  void loadTheme() {
    final storedMode = _storageService.getThemeMode();
    final themeMode = _themeModeFromInt(storedMode);
    emit(state.copyWith(themeMode: themeMode));
  }

  /// Toggle between light and dark mode
  void toggleTheme() {
    final newMode = state.isDarkMode ? ThemeMode.light : ThemeMode.dark;
    _setTheme(newMode);
  }

  /// Set theme to light mode
  void setLightMode() {
    _setTheme(ThemeMode.light);
  }

  /// Set theme to dark mode
  void setDarkMode() {
    _setTheme(ThemeMode.dark);
  }

  /// Set theme to system mode
  void setSystemMode() {
    _setTheme(ThemeMode.system);
  }

  /// Set specific theme mode
  void setThemeMode(ThemeMode mode) {
    _setTheme(mode);
  }

  void _setTheme(ThemeMode mode) {
    _storageService.saveThemeMode(_themeModeToInt(mode));
    emit(state.copyWith(themeMode: mode));
  }

  ThemeMode _themeModeFromInt(int value) {
    switch (value) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  int _themeModeToInt(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
      case ThemeMode.system:
        return 0;
    }
  }
}
