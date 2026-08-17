import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class GradientScaffold extends StatelessWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.safeArea = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: appBar != null ? _buildAppBar(appBar!) : null,
          body: safeArea
              ? SafeArea(bottom: false, child: body)
              : body,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(PreferredSizeWidget original) {
    if (original is AppBar) {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: original.title,
        leading: original.leading,
        actions: original.actions,
        centerTitle: original.centerTitle ?? true,
        titleTextStyle: original.titleTextStyle ?? const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      );
    }
    return original;
  }
}
