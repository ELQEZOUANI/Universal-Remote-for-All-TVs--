import 'package:flutter/widgets.dart';
import 'app_open_ad_manager.dart';

class AppLifecycleReactor extends StatefulWidget {
  final AppOpenAdManager appOpenAdManager;
  final Widget child;

  const AppLifecycleReactor({
    Key? key,
    required this.appOpenAdManager,
    required this.child,
  }) : super(key: key);

  @override
  State<AppLifecycleReactor> createState() => _AppLifecycleReactorState();
}

class _AppLifecycleReactorState extends State<AppLifecycleReactor>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.appOpenAdManager.showAdIfAvailable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
