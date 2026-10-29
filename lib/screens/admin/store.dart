import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/admin_header.dart';
import '../../core/widgets/app_background.dart';



//TODO 

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppBackground(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                AdminHeader(title: AppLocalizations.t('admin.panel.store'))
              ],
            ),
          ),
        ),
      ),
    );
  }
}