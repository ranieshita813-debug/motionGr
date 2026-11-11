import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Clean, elegant light theme palette for splash
const Color _splashBg = Color(0xFFFFFFFF);
const Color _splashText = Color(0xFF111111);
const Color _splashAccent = Color(0xFF00C4D6);
const Color _splashSubtext = Color(0xFF8E8E93);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _logoFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.30, 0.75, curve: Curves.easeOut),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.30, 0.75, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run(reduceMotion: MediaQuery.of(context).disableAnimations);
  }

  Future<void> _run({required bool reduceMotion}) async {
    if (reduceMotion) {
      _c.value = 1;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } else {
      await _c.forward();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: _splashBg,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: _splashBg,
      ),
      child: Scaffold(
        backgroundColor: _splashBg,
        body: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo with clean scale and fade
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: SvgPicture.asset(
                          'assets/logos/logo.svg',
                          colorFilter: const ColorFilter.mode(
                            _splashText,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Wordmark and tagline
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Text(
                                'motion',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: _splashText,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              Text(
                                'Gr',
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: _splashAccent,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'VIDEO EDITOR & MOTION GRAPHICS',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _splashSubtext,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
