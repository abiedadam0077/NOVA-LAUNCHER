import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/colors.dart';
import '../core/motion.dart';
import '../domain/core.dart';
import '../domain/providers.dart';

/// Splash with REAL initialization status — never a fixed artificial wait.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String _status = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _boot();
  }

  Future<void> _boot() async {
    final start = DateTime.now();
    setState(() => _status = 'storage');
    await NovaCore.instance.init();
    // Apply saved locale so the whole app boots localized.
    if (mounted) {
      ref.read(localeProvider.notifier).state = NovaCore.instance.prefs.locale;
    }
    final minShow = const Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(start);
    if (elapsed < minShow) {
      await Future<void>.delayed(minShow - elapsed);
    }
    if (!mounted) return;
    setState(() => _ready = true);
    await Future<void>.delayed(NovaMotion.scale(const Duration(milliseconds: 200)));
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: NovaColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/dashboard_bg.jpg',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.4),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _ctrl, curve: NovaMotion.springy),
                  child: FadeTransition(
                    opacity: _ctrl,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: NovaColors.electricBlue.withOpacity(0.45),
                            blurRadius: 42,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/nova_logo.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                ShaderMask(
                  shaderCallback: (r) => NovaColors.brandGradient.createShader(r),
                  child: const Text(
                    'NOVA LAUNCHER',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t('app.tagline'),
                  style: const TextStyle(color: NovaColors.textSecondary),
                ),
                const SizedBox(height: 42),
                if (!_ready)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  const Icon(Icons.check_circle_outline,
                      color: NovaColors.success),
                const SizedBox(height: 10),
                Text(
                  _ready ? t('common.success') : '${t('splash.init')} ${_statusLabel(t)}',
                  style: const TextStyle(
                      color: NovaColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 24),
                const Text(
                  'v0.1.0',
                  style: TextStyle(color: NovaColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String Function(String) t) {
    switch (_status) {
      case 'storage':
        return '…';
      default:
        return '…';
    }
  }
}
