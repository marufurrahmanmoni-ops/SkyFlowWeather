import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/l10n/localizations.dart';
import 'core/theme.dart';
import 'data/models/settings.dart';
import 'features/shell/app_shell.dart';
import 'state/providers.dart';

class SkyFlowApp extends ConsumerWidget {
  const SkyFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(settingsProvider.select((s) => s.language));
    final use24h = ref.watch(settingsProvider.select((s) => s.use24h));
    final theme = AppTheme.dark();
    return MaterialApp(
      title: 'SkyFlow Weather',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      locale: language == AppLanguage.system ? null : Locale(language.name),
      supportedLocales: S.supportedLocales,
      // material_ui ships its own Material/Cupertino/Widgets delegates
      // (Bengali included).
      localizationsDelegates: const [S.delegate, ...GlobalMaterialLocalizations.delegates],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
