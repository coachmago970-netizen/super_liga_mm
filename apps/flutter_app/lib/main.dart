import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "app.dart";
import "core/bootstrap.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bootstrapApp();
  runApp(const ProviderScope(child: SuperLigaMmApp()));
}
