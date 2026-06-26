import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'xrex_home_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  XREX LANDING SCREEN
//  Uzay / X-Ray temalı SaaS giriş ekranı
// ══════════════════════════════════════════════════════════════════════════════

class XRexLandingScreen extends StatefulWidget {
  const XRexLandingScreen({super.key});

  @override
  State<XRexLandingScreen> createState() => _XRexLandingScreenState();
}

class _XRexLandingScreenState extends State<XRexLandingScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _scanCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _statCtrl;
  late final AnimationController _particleCtrl;

  // ─── Animations ───────────────────────────────────────────────────────────
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _heroSlide;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<Offset> _ctaSlide;
  late final Animation<double> _statFade;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _statValue; // 0.0 → 1.0 ile sayaçları drive eder

  // ─── State ────────────────────────────────────────────────────────────────
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();

    // ── Particle oluştur ──────────────────────────────────────────────────
    for (int i = 0; i < 90; i++) {
      _particles.add(_Particle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        radius: _rng.nextDouble() * 1.6 + 0.4,
        speed: _rng.nextDouble() * 0.12 + 0.02,
        opacity: _rng.nextDouble() * 0.6 + 0.15,
      ));
    }

    // ── Controllers ───────────────────────────────────────────────────────
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _ringCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _statCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    // ── Entry Animations ──────────────────────────────────────────────────
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));

    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)),
    );

    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic)),
    );

    _ctaSlide = Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.30, 0.90, curve: Curves.easeOutCubic)),
    );

    _statFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
    );

    _pulseAnim = Tween<double>(begin: 0.97, end: 1.035).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _statValue = CurvedAnimation(parent: _statCtrl, curve: Curves.easeOutExpo);

    // ── Başlat ────────────────────────────────────────────────────────────
    _entryCtrl.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _statCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _ringCtrl.dispose();
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _statCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, animation, __) => FadeTransition(
        opacity: animation,
        child: const XRexHomeScreen(),
      ),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF04080F),
      body: Stack(
        children: [
          // ── Katman 1: Uzay arka planı ──────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _SpaceBackgroundPainter()),
          ),

          // ── Katman 2: Parçacık alanı ───────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticleFieldPainter(
                  particles: _particles,
                  progress: _particleCtrl.value,
                ),
              ),
            ),
          ),

          // ── Katman 3: Scanline overlay ─────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ScanlinePainter(progress: _scanCtrl.value),
              ),
            ),
          ),

          // ── Katman 4: İçerik ───────────────────────────────────────────
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: size.height * 0.05),

                            // ── Tech badge ──────────────────────────────
                            SlideTransition(
                              position: _heroSlide,
                              child: const _XRexTechBadge(),
                            ),

                            const SizedBox(height: 36),

                            // ── Logo + Scan Ring ────────────────────────
                            SlideTransition(
                              position: _heroSlide,
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_ringCtrl, _scanCtrl, _pulseCtrl]),
                                builder: (_, __) => _XRexLogoRing(
                                  ringProgress: _ringCtrl.value,
                                  scanProgress: _scanCtrl.value,
                                  pulseScale: _pulseAnim.value,
                                ),
                              ),
                            ),

                            const SizedBox(height: 44),

                            // ── Başlık ──────────────────────────────────
                            SlideTransition(
                              position: _heroSlide,
                              child: Column(
                                children: [
                                  Text(
                                    'XREX',
                                    style: TextStyle(
                                      fontSize: size.width < 600 ? 56 : 72,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 14,
                                      shadows: [
                                        const Shadow(color: Color(0xFF06B6D4), blurRadius: 28),
                                        const Shadow(color: Color(0xFF22D3EE), blurRadius: 60),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'C A T A L O G',
                                    style: TextStyle(
                                      fontSize: size.width < 600 ? 11 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF22D3EE),
                                      letterSpacing: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Tagline ─────────────────────────────────
                            SlideTransition(
                              position: _subtitleSlide,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Column(
                                  children: [
                                    Text(
                                      'Fotoğraftan Kataloğa',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: size.width < 600 ? 22 : 28,
                                        fontWeight: FontWeight.w300,
                                        color: Colors.white.withValues(alpha: 0.92),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Yapay zeka ile ürün görsellerini saniyeler içinde\ndijital kataloğa dönüştür.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: size.width < 600 ? 13 : 15,
                                        fontWeight: FontWeight.w400,
                                        color: const Color(0xFF94A3B8),
                                        height: 1.7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 44),

                            // ── CTA Butonları ────────────────────────────
                            SlideTransition(
                              position: _ctaSlide,
                              child: AnimatedBuilder(
                                animation: _pulseAnim,
                                builder: (_, __) => _XRexCtaButtons(
                                  pulseScale: _pulseAnim.value,
                                  onStart: _navigateToHome,
                                ),
                              ),
                            ),

                            const SizedBox(height: 52),

                            // ── Özellik Şeridi ────────────────────────────
                            SlideTransition(
                              position: _ctaSlide,
                              child: const _XRexFeatureRow(),
                            ),

                            SizedBox(height: size.height * 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── İstatistik Barı ─────────────────────────────────────
                  FadeTransition(
                    opacity: _statFade,
                    child: AnimatedBuilder(
                      animation: _statValue,
                      builder: (_, __) => _XRexStatBar(progress: _statValue.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Üstteki teknik rozet
class _XRexTechBadge extends StatelessWidget {
  const _XRexTechBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF06B6D4).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF22D3EE).withValues(alpha: 0.9), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'NEURAL VISION ENGINE  ·  v2.0',
            style: TextStyle(
              color: Color(0xFF67E8F9),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo + animasyonlu X-Ray tarama halkası
class _XRexLogoRing extends StatelessWidget {
  final double ringProgress;
  final double scanProgress;
  final double pulseScale;

  const _XRexLogoRing({
    required this.ringProgress,
    required this.scanProgress,
    required this.pulseScale,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış parlayan halkalar
          CustomPaint(
            size: const Size(180, 180),
            painter: _ScanRingPainter(progress: ringProgress),
          ),
          // İç X-Ray çizgisi
          CustomPaint(
            size: const Size(180, 180),
            painter: _ScanLinePainter(progress: scanProgress),
          ),
          // Logo merkezi
          Transform.scale(
            scale: pulseScale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF0B2A35), Color(0xFF04080F)],
                  stops: [0.3, 1.0],
                ),
                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF06B6D4).withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 4),
                  BoxShadow(color: const Color(0xFF22D3EE).withValues(alpha: 0.12), blurRadius: 60, spreadRadius: 8),
                ],
              ),
              child: const Center(
                child: Text(
                  'XR',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF22D3EE),
                    letterSpacing: 2,
                    shadows: [Shadow(color: Color(0xFF06B6D4), blurRadius: 20)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// CTA Butonları
class _XRexCtaButtons extends StatelessWidget {
  final double pulseScale;
  final VoidCallback onStart;

  const _XRexCtaButtons({required this.pulseScale, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          // Birincil CTA
          Transform.scale(
            scale: pulseScale,
            child: GestureDetector(
              onTap: onStart,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.55),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch_rounded, color: Colors.black, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'HEMEN BAŞLA',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // İkincil CTA
          GestureDetector(
            onTap: () => _showHowItWorks(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_outline_rounded, color: Color(0xFF94A3B8), size: 18),
                  SizedBox(width: 10),
                  Text(
                    'NASIL ÇALIŞIR?',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HowItWorksSheet(),
    );
  }
}

/// Özellik şeridi
class _XRexFeatureRow extends StatelessWidget {
  const _XRexFeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          _FeatureChip(icon: Icons.document_scanner_rounded, label: 'AI Tarama'),
          _FeatureChip(icon: Icons.auto_fix_high_rounded, label: 'Otomatik Fiyat'),
          _FeatureChip(icon: Icons.table_chart_rounded, label: 'JSON / Excel'),
          _FeatureChip(icon: Icons.offline_bolt_rounded, label: 'Offline Çalışır'),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1728).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF1F2A3D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF22D3EE), size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt istatistik barı
class _XRexStatBar extends StatelessWidget {
  final double progress; // 0.0 – 1.0

  const _XRexStatBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: const Border(top: BorderSide(color: Color(0xFF1F2A3D), width: 1)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF090D18).withValues(alpha: 0.0),
            const Color(0xFF090D18).withValues(alpha: 0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBubble(
            icon: Icons.inventory_2_rounded,
            value: (12000 * progress).toInt(),
            suffix: '+',
            label: 'Ürün İşlendi',
          ),
          _buildDivider(),
          _StatBubble(
            icon: Icons.grid_view_rounded,
            value: (980 * progress).toInt(),
            suffix: '',
            label: 'Katalog Üretildi',
          ),
          _buildDivider(),
          _StatBubble(
            icon: Icons.bolt_rounded,
            value: (progress * 100).toInt(),
            suffix: '%',
            label: 'AI Doğruluk',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Container(
    width: 1,
    height: 36,
    color: const Color(0xFF1F2A3D),
  );
}

class _StatBubble extends StatelessWidget {
  final IconData icon;
  final int value;
  final String suffix;
  final String label;

  const _StatBubble({
    required this.icon,
    required this.value,
    required this.suffix,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF06B6D4), size: 14),
            const SizedBox(width: 6),
            Text(
              '${_format(value)}$suffix',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  String _format(int v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }
}

/// Nasıl Çalışır alt panel
class _HowItWorksSheet extends StatelessWidget {
  const _HowItWorksSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E1728), Color(0xFF0A1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1F2A3D)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF06B6D4).withValues(alpha: 0.12), blurRadius: 40),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'NASIL ÇALIŞIR?',
            style: TextStyle(
              color: Color(0xFF22D3EE),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '3 adımda AI katalog',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 28),
          const _HowItWorksStep(
            step: 1,
            icon: Icons.add_a_photo_rounded,
            title: 'Fotoğraf Çek / Yükle',
            desc: 'Ürün fotoğrafını galerinden seç veya kamerandan çek.',
          ),
          const SizedBox(height: 20),
          const _HowItWorksStep(
            step: 2,
            icon: Icons.document_scanner_rounded,
            title: 'AI Tarama',
            desc: 'XREX sinir ağı metni, fiyatları ve ürün isimlerini saniyeler içinde tespit eder.',
            accentColor: Color(0xFFFF6A00),
          ),
          const SizedBox(height: 20),
          const _HowItWorksStep(
            step: 3,
            icon: Icons.table_chart_rounded,
            title: 'Kataloğu Düzenle & İndir',
            desc: 'Ürünleri gözden geçir, düzenle ve JSON veya tablo formatında dışa aktar.',
            accentColor: Color(0xFF22C55E),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('Anladım',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String desc;
  final Color accentColor;

  const _HowItWorksStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.desc,
    this.accentColor = const Color(0xFF06B6D4),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: accentColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('0$step  ', style: TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PAINTERS
// ══════════════════════════════════════════════════════════════════════════════

/// Uzay arka planı – çok katmanlı radial gradient + nebula lekeleri
class _SpaceBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ana koyu gradient
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.35),
        radius: 1.2,
        colors: [Color(0xFF071428), Color(0xFF04080F)],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Siyan nebula - sol üst
    final nebula1 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF06B6D4).withValues(alpha: 0.07), Colors.transparent],
        radius: 0.7,
      ).createShader(Rect.fromCenter(center: Offset(size.width * 0.18, size.height * 0.22), width: size.width * 0.8, height: size.width * 0.8));
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.22), size.width * 0.55, nebula1);

    // Mor nebula - sağ alt
    final nebula2 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF7C3AED).withValues(alpha: 0.06), Colors.transparent],
        radius: 0.7,
      ).createShader(Rect.fromCenter(center: Offset(size.width * 0.82, size.height * 0.78), width: size.width * 0.7, height: size.width * 0.7));
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.78), size.width * 0.45, nebula2);

    // Turuncu nebula - ortanın altı
    final nebula3 = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFF6A00).withValues(alpha: 0.04), Colors.transparent],
      ).createShader(Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.88), width: size.width, height: size.height * 0.4));
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.9), size.width * 0.5, nebula3);
  }

  @override
  bool shouldRepaint(_SpaceBackgroundPainter old) => false;
}

/// Parçacık alanı – uzay yıldızları
class _ParticleFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  const _ParticleFieldPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y + p.speed * progress) % 1.0;
      final x = p.x;

      // Yıldız parıltısı
      final glow = Paint()
        ..color = const Color(0xFF22D3EE).withValues(alpha: p.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x * size.width, y * size.height), p.radius * 1.8, glow);

      // Yıldız çekirdeği
      final star = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity);
      canvas.drawCircle(Offset(x * size.width, y * size.height), p.radius, star);
    }
  }

  @override
  bool shouldRepaint(_ParticleFieldPainter old) => old.progress != progress;
}

/// CRT / X-Ray scanline efekti – yavaş kayan yatay şerit
class _ScanlinePainter extends CustomPainter {
  final double progress;

  const _ScanlinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Sürekli yatay ince çizgiler (CRT grid)
    final linePaint = Paint()
      ..color = const Color(0xFF22D3EE).withValues(alpha: 0.022)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Kayan parlak tarama çizgisi
    final scanY = size.height * progress;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        const Color(0xFF22D3EE).withValues(alpha: 0.06),
        const Color(0xFF22D3EE).withValues(alpha: 0.15),
        const Color(0xFF22D3EE).withValues(alpha: 0.06),
        Colors.transparent,
      ],
      stops: const [0, 0.3, 0.5, 0.7, 1],
    );
    final scanPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, scanY - 30, size.width, 60));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 30, size.width, 60), scanPaint);
  }

  @override
  bool shouldRepaint(_ScanlinePainter old) => old.progress != progress;
}

/// Logo etrafındaki dönen X-Ray halkaları
class _ScanRingPainter extends CustomPainter {
  final double progress;

  const _ScanRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Dış hep-parlayan büyük halka
    _drawRing(canvas, center, 87, const Color(0xFF06B6D4), 0.12, 1.5);
    // İkinci halka
    _drawRing(canvas, center, 78, const Color(0xFF22D3EE), 0.1, 1.0);

    // Dönen kesikli ark – dış
    _drawArc(canvas, center, 87, progress * 2 * math.pi, const Color(0xFF06B6D4), 0.7, 2.0, gapFactor: 0.35);
    // Dönen kesikli ark – iç (ters yön)
    _drawArc(canvas, center, 75, -progress * 2 * math.pi * 0.7, const Color(0xFF7C3AED), 0.5, 1.5, gapFactor: 0.6);

    // Dönen belirteçler (küçük parlak noktalar)
    for (int i = 0; i < 4; i++) {
      final angle = progress * 2 * math.pi + (i * math.pi / 2);
      final pos = Offset(center.dx + 87 * math.cos(angle), center.dy + 87 * math.sin(angle));
      final dotPaint = Paint()
        ..color = const Color(0xFF22D3EE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pos, 3, dotPaint);
      canvas.drawCircle(pos, 1.5, Paint()..color = Colors.white);
    }
  }

  void _drawRing(Canvas canvas, Offset center, double r, Color color, double opacity, double width) {
    canvas.drawCircle(center, r,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width);
  }

  void _drawArc(Canvas canvas, Offset center, double r, double startAngle, Color color, double opacity, double width, {double gapFactor = 0.3}) {
    final rect = Rect.fromCenter(center: center, width: r * 2, height: r * 2);
    final sweepAngle = math.pi * 2 * (1 - gapFactor);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(_ScanRingPainter old) => old.progress != progress;
}

/// Logo içinden geçen X-Ray tarama çizgisi
class _ScanLinePainter extends CustomPainter {
  final double progress;

  const _ScanLinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const r = 50.0;
    final scanY = center.dy - r + (r * 2 * progress);

    // Yatay tarama ışığı
    if (scanY >= center.dy - r && scanY <= center.dy + r) {
      final gradient = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF22D3EE).withValues(alpha: 0.5),
          Colors.transparent,
        ],
      );
      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(center.dx - r, scanY - 1, r * 2, 2));
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
      canvas.drawRect(Rect.fromLTWH(center.dx - r, scanY - 2, r * 2, 4), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  DATA MODEL
// ══════════════════════════════════════════════════════════════════════════════

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
  });
}
