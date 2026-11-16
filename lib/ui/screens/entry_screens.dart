/// First things a person sees: the animated splash, the one-time welcome
/// pages, and the gate that decides between them and the home screen.
library;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../widgets/animated_bits.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Shows the splash until the data has loaded, then either the welcome pages
/// (first launch) or the home screen.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final Widget child;
    if (!_splashDone || !state.ready || !state.authReady) {
      child = SplashScreen(
        key: const ValueKey<String>('splash'),
        onFinished: () {
          if (mounted) setState(() => _splashDone = true);
        },
      );
    } else if (state.needsLogin) {
      child = const LoginScreen(key: ValueKey<String>('login'));
    } else if (state.needsOnboarding) {
      child = const OnboardingScreen(key: ValueKey<String>('onboarding'));
    } else {
      child = const HomeScreen(key: ValueKey<String>('home'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _logoScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.45, curve: Curves.easeOutBack)),
    );
    _logoFade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.3, curve: Curves.easeOut));
    _textFade = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7, curve: Curves.easeOut));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_notified) {
        _notified = true;
        widget.onFinished();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(scale: _logoScale, child: const AppLogo(size: 132)),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: <Widget>[
                  Text(
                    'ChitMate',
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Save together. Receive in turn.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;
}

const List<_Slide> _slides = <_Slide>[
  _Slide(
    Icons.groups_rounded,
    'Save together, receive in turn',
    'Everyone puts the same amount in every month. Each month one chit receives '
        'the whole pool, until every chit has had its turn.',
  ),
  _Slide(
    Icons.pie_chart_rounded,
    'Share a chit, split it fairly',
    'Can\'t cover a full chit? Share one with others, in any split. When a shared '
        'chit wins, the money is divided by the shares.',
  ),
  _Slide(
    Icons.how_to_vote_rounded,
    'Vote, draw or agree',
    'Pick the month\'s chit by vote, by agreement or by a random draw that never '
        'repeats a winner and never favours anyone.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();
  int _page = 0;
  bool _saving = false;
  String? _error;

  int get _lastPage => _slides.length; // the name page comes after the slides

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _lastPage) {
      await _pages.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    final state = AppScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await state.completeOnboarding(_name.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onLast = _page == _lastPage;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: <Widget>[
                  const AppLogo(size: 40),
                  const SizedBox(width: 10),
                  Text('ChitMate',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, color: scheme.primary)),
                  const Spacer(),
                  if (!onLast)
                    TextButton(
                      onPressed: () => _pages.animateToPage(
                        _lastPage,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: <Widget>[
                  for (final s in _slides) _SlidePage(slide: s),
                  _NamePage(controller: _name, error: _error, onSubmit: _next),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var i = 0; i <= _lastPage; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? scheme.primary : scheme.primary.withAlpha(60),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(onLast ? 'Get started' : 'Next', key: ValueKey<bool>(onLast)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FadeSlide(
            child: Container(
              width: 168,
              height: 168,
              decoration: const BoxDecoration(gradient: AppColors.hero, shape: BoxShape.circle),
              child: Icon(slide.icon, size: 76, color: Colors.white),
            ),
          ),
          const SizedBox(height: 36),
          FadeSlide(
            index: 1,
            child: Text(slide.title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          FadeSlide(
            index: 2,
            child: Text(slide.body,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _NamePage extends StatelessWidget {
  const _NamePage({required this.controller, required this.error, required this.onSubmit});

  final TextEditingController controller;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(height: 24),
          FadeSlide(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.tertiary.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.waving_hand_rounded, size: 56, color: AppColors.goldDark),
            ),
          ),
          const SizedBox(height: 28),
          FadeSlide(
            index: 1,
            child: Text('What should we call you?',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          FadeSlide(
            index: 2,
            child: Text(
              'You will be the organiser (admin) of the groups you create. Your name '
              'appears next to the updates you post.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlide(
            index: 3,
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              maxLength: 40,
              onSubmitted: (_) => onSubmit(),
              decoration: appInput(context, label: 'Your name').copyWith(errorText: error),
            ),
          ),
        ],
      ),
    );
  }
}
