import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // ProviderScope stores the state of every Riverpod provider. It must wrap
  // the whole application so any widget can read/watch providers.
  runApp(const ProviderScope(child: HomeAssistantApp()));
}
