import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/colors.dart';
import '../core/motion.dart';
import '../domain/providers.dart';

/// App shell: Minecraft-inspired background + floating bottom navigation.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: NovaColors.bg,
      body: Stack(
        children: [
          // Ambient Minecraft-inspired backdrop (asset, lightweight).
          Positioned.fill(
            child: Image.asset(
              'assets/images/dashboard_bg.jpg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.35),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    NovaColors.bg.withOpacity(0.55),
                    NovaColors.bg.withOpacity(0.92),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: navigationShell),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 10),
                child: _FloatingNav(
                  index: navigationShell.currentIndex,
                  onSelect: navigationShell.goBranch,
                  labels: [
                    t('nav.home'),
                    t('nav.versions'),
                    t('nav.content'),
                    t('nav.account'),
                    t('nav.settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.index,
    required this.onSelect,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<String> labels;

  static const List<IconData> _icons = [
    Icons.space_dashboard_outlined,
    Icons.layers_outlined,
    Icons.widgets_outlined,
    Icons.person_outline,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xCC101830),
        border: Border.all(color: NovaColors.electricBlue.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(5, (i) {
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: NovaMotion.scale(NovaMotion.med),
                    curve: NovaMotion.standard,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: selected ? NovaColors.brandGradient : null,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: NovaMotion.scale(NovaMotion.fast),
                          child: Icon(
                            selected ? _icons[i] : _icons[i],
                            key: ValueKey(selected),
                            size: 22,
                            color: selected
                                ? NovaColors.bgDeep
                                : NovaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? NovaColors.bgDeep
                                : NovaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
