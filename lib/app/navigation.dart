import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Handles both a pushed page and a page opened directly by a notification.
void popOrGo(BuildContext context, String fallback) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}
