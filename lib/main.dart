// =============================================================================
//  MINIMAL LAUNCHER  •  v0.200.1
//  Flutter >= 3.27 (Dart >= 3.6) • Material 3 • tanpa paket pihak ketiga
// -----------------------------------------------------------------------------
//  CARA MENJALANKAN
//  1. flutter create launcher && ganti lib/main.dart dengan file ini.
//  2. pubspec.yaml  ->  version: 0.200.1+200
//  3. Agar bisa dipilih sebagai launcher Android, tambahkan di
//     android/app/src/main/AndroidManifest.xml (di dalam <activity>):
//
//       <intent-filter>
//         <action android:name="android.intent.action.MAIN"/>
//         <category android:name="android.intent.category.HOME"/>
//         <category android:name="android.intent.category.DEFAULT"/>
//       </intent-filter>
//
//  4. Jalankan dalam mode profile/release untuk mengukur FPS sebenarnya:
//       flutter run --profile
//
//  PETA ARSITEKTUR (satu file, dipisah per bagian)
//   1. Tema        : LauncherColors (ThemeExtension), AppTheme, ThemeController
//   2. Layanan     : ClockService (timer terpusat, hemat baterai)
//   3. Data        : AppEntry + daftar aplikasi
//   4. Navigasi    : openApp() -> transisi "expand dari ikon" (PageRouteBuilder)
//   5. Komponen    : Pressable, AppTile, LauncherStatusBar, ClockWidget, dll.
//   6. Layar       : HomeScreen, DrawerScreen, AppWindow, SettingsScreen
//
//  GESTUR
//   • Geser ke atas di home      -> buka laci aplikasi
//   • Ketuk dua kali pada jam    -> ganti tema Gelap/Terang
//   • Geser ke bawah di jendela aplikasi -> kembali
// =============================================================================

import 'dart:async';
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kAppVersion = '0.200.1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Mode imersif: status bar sistem disembunyikan, diganti LauncherStatusBar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const LauncherApp());
}

// =============================================================================
// 1. TEMA
// =============================================================================

/// Token warna kustom yang ikut berganti bersama ThemeData.
@immutable
class LauncherColors extends ThemeExtension<LauncherColors> {
  const LauncherColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;

  /// True Black (OLED) + satu aksen neon mint.
  static const dark = LauncherColors(
    background: Color(0xFF000000),
    surface: Color(0xFF0E0F11),
    surfaceHigh: Color(0xFF17191C),
    hairline: Color(0xFF23262B),
    textPrimary: Color(0xFFF2F4F5),
    textSecondary: Color(0xFF8B9096),
    accent: Color(0xFF3DF5C0),
    onAccent: Color(0xFF00110B),
  );

  /// Putih lembut, kontras tinggi, aksen hijau tua agar terbaca di atas putih.
  static const light = LauncherColors(
    background: Color(0xFFF3F4F6),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9EBEE),
    hairline: Color(0xFFDADDE1),
    textPrimary: Color(0xFF0B0C0E),
    textSecondary: Color(0xFF565B62),
    accent: Color(0xFF007A5A),
    onAccent: Color(0xFFFFFFFF),
  );

  @override
  LauncherColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
  }) {
    return LauncherColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  LauncherColors lerp(ThemeExtension<LauncherColors>? other, double t) {
    if (other is! LauncherColors) return this;
    return LauncherColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension LauncherThemeX on BuildContext {
  LauncherColors get colors => Theme.of(this).extension<LauncherColors>()!;
}

/// ThemeData Material 3 dibangun sekali (static final) -> tidak ada alokasi
/// ulang saat toggle tema.
class AppTheme {
  AppTheme._();

  static final ThemeData dark = _build(LauncherColors.dark, Brightness.dark);
  static final ThemeData light = _build(LauncherColors.light, Brightness.light);

  static ThemeData _build(LauncherColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: b,
    ).copyWith(
      primary: c.accent,
      onPrimary: c.onAccent,
      surface: c.background,
      onSurface: c.textPrimary,
      outline: c.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      splashFactory: NoSplash.splashFactory, // tanpa ripple = lebih ringan
      highlightColor: Colors.transparent,
      extensions: <ThemeExtension<dynamic>>[c],
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onAccent : c.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}

/// Pengelola tema. ValueNotifier -> hanya MaterialApp yang rebuild.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.dark);
  static final ThemeController instance = ThemeController._();

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    HapticFeedback.selectionClick();
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}

// =============================================================================
// 2. LAYANAN JAM
// =============================================================================

/// Satu sumber waktu untuk seluruh UI.
///  • `minute` berubah tepat di pergantian menit (bukan tiap detik).
///  • `colonOn` berkedip tiap detik; hanya titik dua yang repaint.
class ClockService {
  ClockService._();
  static final ClockService instance = ClockService._();

  final ValueNotifier<DateTime> minute = ValueNotifier(DateTime.now());
  final ValueNotifier<bool> colonOn = ValueNotifier(true);

  Timer? _minuteTimer;
  Timer? _blinkTimer;

  void start() {
    refresh();
    _scheduleNextMinute();
    _blinkTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => colonOn.value = !colonOn.value,
    );
  }

  void stop() {
    _minuteTimer?.cancel();
    _minuteTimer = null;
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void refresh() => minute.value = DateTime.now();

  void _scheduleNextMinute() {
    _minuteTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1);
    _minuteTimer = Timer(next.difference(now), () {
      refresh();
      _scheduleNextMinute();
    });
  }
}

// =============================================================================
// 3. DATA
// =============================================================================

@immutable
class AppEntry {
  const AppEntry(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const List<AppEntry> kDockApps = [
  AppEntry('phone', 'Telepon', Icons.call_rounded),
  AppEntry('messages', 'Pesan', Icons.chat_bubble_rounded),
  AppEntry('browser', 'Browser', Icons.language_rounded),
  AppEntry('settings', 'Pengaturan', Icons.settings_rounded),
];

const List<AppEntry> kHomeApps = [
  AppEntry('camera', 'Kamera', Icons.camera_alt_rounded),
  AppEntry('gallery', 'Galeri', Icons.photo_library_rounded),
  AppEntry('music', 'Musik', Icons.music_note_rounded),
  AppEntry('maps', 'Peta', Icons.map_rounded),
  AppEntry('notes', 'Catatan', Icons.edit_note_rounded),
  AppEntry('calendar', 'Kalender', Icons.calendar_month_rounded),
  AppEntry('weather', 'Cuaca', Icons.wb_sunny_rounded),
  AppEntry('calc', 'Kalkulator', Icons.calculate_rounded),
  AppEntry('clock', 'Jam', Icons.schedule_rounded),
  AppEntry('files', 'Berkas', Icons.folder_rounded),
  AppEntry('mail', 'Email', Icons.mail_rounded),
  AppEntry('health', 'Kesehatan', Icons.favorite_rounded),
  AppEntry('wallet', 'Dompet', Icons.account_balance_wallet_rounded),
  AppEntry('books', 'Buku', Icons.menu_book_rounded),
  AppEntry('recorder', 'Perekam', Icons.mic_rounded),
  AppEntry('video', 'Video', Icons.play_circle_rounded),
];

const int _kAppsPerPage = 8; // 4 kolom x 2 baris

/// Laci aplikasi: diurutkan alfabetis sekali saja.
final List<AppEntry> kSortedApps = [...kDockApps, ...kHomeApps]
  ..sort((a, b) => a.label.compareTo(b.label));

/// Halaman grid dihitung sekali.
final List<List<AppEntry>> _kHomePages = [
  for (var i = 0; i < kHomeApps.length; i += _kAppsPerPage)
    kHomeApps.sublist(
      i,
      i + _kAppsPerPage > kHomeApps.length ? kHomeApps.length : i + _kAppsPerPage,
    ),
];

// =============================================================================
// 4. NAVIGASI & TRANSISI
// =============================================================================

const _kOpenCurve = Curves.easeInOutCubic;

Rect rectOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Buka aplikasi dengan efek mengembang dari posisi ikon.
/// Konten dilayout SEKALI pada ukuran layar penuh; yang dianimasikan hanya
/// clip + skala (FittedBox) sehingga tidak ada relayout tiap frame.
void openApp(BuildContext context, AppEntry app, Rect origin) {
  HapticFeedback.selectionClick();
  final Widget page =
      app.id == 'settings' ? const SettingsScreen() : AppWindow(app: app);

  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (context, animation, _, child) {
        final size = MediaQuery.sizeOf(context);
        final full = Offset.zero & size;
        final t = animation.drive(CurveTween(curve: _kOpenCurve));
        final fade = animation.drive(
          CurveTween(curve: const Interval(0.25, 1.0, curve: Curves.easeOut)),
        );

        return AnimatedBuilder(
          animation: t,
          // `child` dibangun sekali, tidak ikut rebuild tiap frame.
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: FadeTransition(opacity: fade, child: child),
          ),
          builder: (context, content) {
            final v = t.value;
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: Rect.lerp(origin, full, v)!,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(lerpDouble(20, 0, v)!),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      child: content,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

/// Buka laci aplikasi: geser naik + fade.
void openDrawer(BuildContext context) {
  HapticFeedback.lightImpact();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const DrawerScreen(),
      transitionsBuilder: (_, animation, __, child) {
        final t = animation.drive(CurveTween(curve: _kOpenCurve));
        return FadeTransition(
          opacity: t,
          child: SlideTransition(
            position: t.drive(
              Tween(begin: const Offset(0, 0.06), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}

// =============================================================================
// 5. KOMPONEN
// =============================================================================

/// Umpan balik sentuh: skala kecil yang halus. Hanya subtree ini yang rebuild.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.92,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Ikon aplikasi di grid home.
class AppTile extends StatefulWidget {
  const AppTile({super.key, required this.app});
  final AppEntry app;

  @override
  State<AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<AppTile> {
  final GlobalKey _iconKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => openApp(context, widget.app, rectOf(_iconKey.currentContext!)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            key: _iconKey,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.hairline, width: 0.8),
            ),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(widget.app.icon, size: 26, color: c.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.app.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.1,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status bar kustom: sapaan di kiri, indikator di kanan.
/// (Nilai baterai/sinyal statis; sambungkan ke `battery_plus` /
/// `connectivity_plus` bila ingin data nyata.)
class LauncherStatusBar extends StatelessWidget {
  const LauncherStatusBar({super.key});

  static String _greeting(int h) {
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
        child: Row(
          children: [
            ValueListenableBuilder<DateTime>(
              valueListenable: ClockService.instance.minute,
              builder: (_, now, __) => Text(
                _greeting(now.hour),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, size: 16, color: c.textPrimary),
            const SizedBox(width: 8),
            Icon(Icons.wifi_rounded, size: 16, color: c.textPrimary),
            const SizedBox(width: 10),
            Text(
              '82%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.battery_5_bar_rounded, size: 18, color: c.accent),
          ],
        ),
      ),
    );
  }
}

/// Widget jam minimalis. Rebuild hanya sekali per menit.
class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  static const _days = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli',
    'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final digits = TextStyle(
      fontSize: 92,
      height: 1,
      fontWeight: FontWeight.w200,
      letterSpacing: -2,
      color: c.textPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: ThemeController.instance.toggle,
        child: ValueListenableBuilder<DateTime>(
          valueListenable: ClockService.instance.minute,
          builder: (_, now, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_two(now.hour), style: digits),
                    const _BlinkColon(),
                    Text(_two(now.minute), style: digits),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 0.3,
                    color: c.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Titik dua berkedip. RepaintBoundary sendiri -> hanya layer kecil ini
/// yang digambar ulang tiap detik, bukan seluruh jam.
class _BlinkColon extends StatelessWidget {
  const _BlinkColon();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: ClockService.instance.colonOn,
        builder: (_, on, child) => AnimatedOpacity(
          opacity: on ? 1 : 0.2,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 80,
              height: 1,
              fontWeight: FontWeight.w200,
              color: c.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu halaman grid 4x2.
class _AppPage extends StatelessWidget {
  const _AppPage({required this.apps});
  final List<AppEntry> apps;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        crossAxisCount: 4,
        mainAxisSpacing: 18,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
        children: [
          for (final a in apps)
            Center(child: AppTile(key: ValueKey(a.id), app: a)),
        ],
      ),
    );
  }
}

/// Indikator halaman; lebar titik aktif beranimasi halus.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});
  final int count;
  final ValueListenable<int> page;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: page,
        builder: (_, p, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: i == p ? 18 : 6,
                decoration: BoxDecoration(
                  color: i == p
                      ? c.accent
                      : c.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dock bawah: kapsul solid semi-transparan (TANPA BackdropFilter -> hemat GPU).
class LauncherDock extends StatelessWidget {
  const LauncherDock({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: c.hairline, width: 0.8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _DockIcon(app: kDockApps[0]),
            _DockIcon(app: kDockApps[1]),
            const _DrawerButton(),
            _DockIcon(app: kDockApps[2]),
            _DockIcon(app: kDockApps[3]),
          ],
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({required this.app});
  final AppEntry app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: () => openApp(context, app, rectOf(context)),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Icon(app.icon, size: 26, color: c.textPrimary),
      ),
    );
  }
}

class _DrawerButton extends StatelessWidget {
  const _DrawerButton();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      pressedScale: 0.88,
      onTap: () => openDrawer(context),
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.apps_rounded, size: 26, color: c.onAccent),
        ),
      ),
    );
  }
}

// =============================================================================
// 6. LAYAR
// =============================================================================

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (_, mode, __) => MaterialApp(
        title: 'Minimal Launcher',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        // Peralihan tema instan, tanpa animasi lerp.
        themeAnimationDuration: Duration.zero,
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PageController _controller = PageController();
  final ValueNotifier<int> _page = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ClockService.instance.start();
  }

  /// Timer dihentikan saat launcher tidak terlihat -> hemat baterai & CPU.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ClockService.instance.start();
    } else {
      ClockService.instance.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ClockService.instance.stop();
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // Geser ke atas -> laci aplikasi.
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -350) openDrawer(context);
          },
          child: SafeArea(
            child: Column(
              children: [
                const LauncherStatusBar(),
                const Spacer(flex: 2),
                const ClockWidget(),
                const Spacer(flex: 3),
                SizedBox(
                  height: 226,
                  child: PageView.builder(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _kHomePages.length,
                    onPageChanged: (i) => _page.value = i,
                    itemBuilder: (_, i) => _AppPage(apps: _kHomePages[i]),
                  ),
                ),
                const SizedBox(height: 6),
                _PageDots(count: _kHomePages.length, page: _page),
                const Spacer(flex: 1),
                const LauncherDock(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Laci aplikasi dengan pencarian.
class DrawerScreen extends StatefulWidget {
  const DrawerScreen({super.key});

  @override
  State<DrawerScreen> createState() => _DrawerScreenState();
}

class _DrawerScreenState extends State<DrawerScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final q = _query.trim().toLowerCase();
    final apps = q.isEmpty
        ? kSortedApps
        : kSortedApps.where((a) => a.label.toLowerCase().contains(q)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Semua aplikasi',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: c.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: c.textPrimary),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: 'Cari aplikasi',
                  hintStyle: TextStyle(color: c.textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
                  filled: true,
                  fillColor: c.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: c.hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: c.accent),
                  ),
                ),
              ),
            ),
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Tidak ada aplikasi bernama "${_query.trim()}". '
                          'Coba kata lain.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      itemExtent: 64, // tinggi tetap -> layout list sangat murah
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: apps.length,
                      itemBuilder: (_, i) => RepaintBoundary(
                        child: _DrawerRow(app: apps[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({required this.app});
  final AppEntry app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      pressedScale: 0.97,
      onTap: () => openApp(context, app, rectOf(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.hairline, width: 0.8),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(app.icon, size: 22, color: c.textPrimary),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              app.label,
              style: TextStyle(fontSize: 16, color: c.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jendela aplikasi (placeholder). Geser ke bawah untuk menutup.
class AppWindow extends StatelessWidget {
  const AppWindow({super.key, required this.app});
  final AppEntry app;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 700) Navigator.of(context).pop();
        },
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.textSecondary),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Icon(app.icon, size: 44, color: c.onAccent),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        app.label,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Geser ke bawah untuk kembali ke home',
                        style: TextStyle(fontSize: 14, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pengaturan: toggle tema instan + info versi.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 700) Navigator.of(context).pop();
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pengaturan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SettingsCard(
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance,
                    builder: (_, mode, __) {
                      final dark = mode == ThemeMode.dark;
                      return Row(
                        children: [
                          Icon(
                            dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: c.accent,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mode gelap',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dark ? 'True black, hemat baterai OLED' : 'Putih lembut',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: dark,
                            onChanged: (_) => ThemeController.instance.toggle(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: c.textSecondary),
                      const SizedBox(width: 16),
                      Text(
                        'Versi',
                        style: TextStyle(fontSize: 16, color: c.textPrimary),
                      ),
                      const Spacer(),
                      Text(
                        kAppVersion,
                        style: TextStyle(fontSize: 15, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.hairline, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: child,
      ),
    );
  }
}
