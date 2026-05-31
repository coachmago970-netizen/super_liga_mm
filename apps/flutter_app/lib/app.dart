import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "core/router.dart";
import "theme/app_theme.dart";

class SuperLigaMmApp extends ConsumerWidget {
  const SuperLigaMmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: "Super Liga M&M",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router
    );
  }
}
