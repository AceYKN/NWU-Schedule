import 'package:flutter/material.dart';

import '../../../app/theme/campus_design.dart';

class CampusNavigation extends StatelessWidget {
  const CampusNavigation({
    required this.design,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final CampusDesign design;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: design.rule, width: .6)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 68,
            elevation: 0,
            backgroundColor: design.paper,
            surfaceTintColor: Colors.transparent,
            indicatorColor: design.accent.withValues(alpha: .08),
            indicatorShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            iconTheme:
                WidgetStateProperty.resolveWith((states) => IconThemeData(
                      size: 21,
                      color: states.contains(WidgetState.selected)
                          ? design.accent
                          : design.ink,
                    )),
            labelTextStyle: WidgetStateProperty.resolveWith((states) => design
                .heading(11)
                .copyWith(
                    color: states.contains(WidgetState.selected)
                        ? design.accent
                        : design.ink)),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined), label: '日程'),
              NavigationDestination(
                  icon: Icon(Icons.view_week_outlined), label: '時間割'),
              NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined), label: '暦'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined), label: '設定'),
            ],
          ),
        ),
      );
}
