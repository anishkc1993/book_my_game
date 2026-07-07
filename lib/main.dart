import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On web, use clean path-based URLs (no `#` fragment). Required so
  // shareable links like /turf/<id>/schedule actually resolve to the
  // matching route instead of landing on the default initial location
  // with the path stashed in the fragment.
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await injector.init();

  runApp(const BookMyGameApp());
}
