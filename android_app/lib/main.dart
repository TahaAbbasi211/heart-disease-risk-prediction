// main.dart
//
// Entry point for BIOVANTA · HEART V2.0.0 — 100% offline dual-mode heart risk app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'heart_model.dart';
import 'l10n/strings.dart';
import 'ui/instrument_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
  if (systemLocale.languageCode == 'fa') {
    appLocaleNotifier.value = const Locale('fa');
  }
  runApp(const HeartRiskApp());
}

class HeartRiskApp extends StatelessWidget {
  const HeartRiskApp({
    super.key,
    this.model,
    this.initialTab = 0,
  });

  final HeartModel? model;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocaleNotifier,
      builder: (context, locale, _) {
        final isPersian = locale.languageCode == 'fa';
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: appThemeModeNotifier,
          builder: (context, themeMode, _) {
            final platformBrightness =
                WidgetsBinding.instance.platformDispatcher.platformBrightness;
            final isDark = switch (themeMode) {
              ThemeMode.dark => true,
              ThemeMode.light => false,
              ThemeMode.system => platformBrightness == Brightness.dark,
            };
            final overlay = SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarDividerColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: MaterialApp(
                onGenerateTitle: (ctx) => AppStrings.of(ctx).s('launcherLabel'),
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(Brightness.light, isPersian: isPersian),
                darkTheme: buildAppTheme(Brightness.dark, isPersian: isPersian),
                themeMode: themeMode,
                locale: locale,
                supportedLocales: kSupportedLocales,
                localizationsDelegates: const [
                  AppStringsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: InstrumentShell(
                  model: model,
                  initialTab: initialTab,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
