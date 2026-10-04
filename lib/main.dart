import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'audio.dart';
import 'visuals.dart';
import 'sounds/runtime.dart';
import 'sounds/library.dart';
import 'sounds/assist.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'chimey',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff090b10),
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyan,
        brightness: Brightness.dark,
        surface: surface,
        primary: cyan,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
      ),
      dividerColor: const Color(0xff242630),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
    ),
    home: const ChimeyHome(),
  );
}

class SoundProfile {
  SoundProfile(
    this.name,
    this.detail,
    this.icon, {
    this.enabled = true,
    this.action = 'Visual cue',
  });
  final String name, detail;
  final IconData icon;
  bool enabled;
  String action;
}

class DemoScene {
  const DemoScene(
    this.name,
    this.response,
    this.detail,
    this.event,
    this.icon,
    this.level,
    this.hz,
    this.direction,
  );
  final String name, response, detail, event;
  final IconData icon;
  final double level, hz;
  final int direction;
}

const scenes = [
  DemoScene(
    'Quiet room',
    'Your space sounds calm.',
    'I’m here for the sounds that need you.',
    'Room is quiet',
    Icons.nights_stay_outlined,
    .18,
    180,
    0,
  ),
  DemoScene(
    'Doorbell',
    'Someone’s at the door.',
    'A familiar chime, coming from the right.',
    'Doorbell rang',
    Icons.doorbell_outlined,
    .72,
    1800,
    1,
  ),
  DemoScene(
    'Laundry',
    'Your laundry is ready.',
    'The finishing tone you taught me just played.',
    'Laundry finished',
    Icons.local_laundry_service_outlined,
    .57,
    980,
    3,
  ),
  DemoScene(
    'Unknown',
    'There’s a new sound nearby.',
    'A repeating beep. You can give it a name.',
    'Unfamiliar beep',
    Icons.graphic_eq_rounded,
    .82,
    2600,
    2,
  ),
];

class ChimeyHome extends StatefulWidget {
  const ChimeyHome({super.key});
  @override
  State<ChimeyHome> createState() => _ChimeyHomeState();
}

class _ChimeyHomeState extends State<ChimeyHome>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..repeat();
  int tab = 0, sceneIndex = 0, direction = 0;
  bool listening = true;
  bool liveMode = false;
  final audio = AudioSession(
    deviceFactory: () => nativeRecognition ? NativeCapture() : RecordCapture(),
  );
  final runtime = SoundRuntime();
  double level = .18, hz = 180;
  final profiles = [
    SoundProfile('Doorbell', 'A visitor at your door', Icons.doorbell_outlined),
    SoundProfile(
      'Laundry finished',
      'The end-of-cycle melody',
      Icons.local_laundry_service_outlined,
      action: 'Gentle vibration',
    ),
    SoundProfile(
      'Kitchen timer',
      'A little nudge when time is up',
      Icons.timer_outlined,
    ),
  ];
  final List<({String title, String detail, DateTime time})> activity = [];
  DemoScene get scene => scenes[sceneIndex];
  List<double> get edges => List.generate(
    4,
    (i) => listening ? level * (liveMode || i == direction ? 1 : .14) : .02,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    audio.addListener(audioChanged);
    runtime.addListener(runtimeChanged);
    unawaited(runtime.initialize());
  }

  void runtimeChanged() {
    if (mounted) setState(() {});
  }

  void audioChanged() {
    if (!mounted) return;
    setState(() {
      if (audio.active) {
        liveMode = true;
        listening = true;
        level = level * .65 + audio.frame.level * .35;
        hz = audio.frame.frequency;
      } else if (liveMode && !audio.starting) {
        listening = false;
        level = 0;
        hz = 0;
      }
    });
  }

  Future<void> useMicrophone() async {
    await audio.start();
  }

  void selectTab(int index) {
    if (!nativeRecognition && index != 0 && (liveMode || audio.starting)) {
      unawaited(audio.stop());
      liveMode = false;
      listening = false;
    }
    setState(() => tab = index);
  }

  void toggleListening() {
    if (liveMode || audio.starting) {
      if (listening || audio.starting) {
        unawaited(audio.stop());
      } else {
        unawaited(useMicrophone());
      }
    } else {
      setState(() => listening = !listening);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!nativeRecognition &&
        state != AppLifecycleState.resumed &&
        (audio.active || audio.starting)) {
      unawaited(audio.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    audio.removeListener(audioChanged);
    audio.dispose();
    runtime.removeListener(runtimeChanged);
    runtime.dispose();
    clock.dispose();
    super.dispose();
  }

  void chooseScene(int index) {
    unawaited(audio.stop());
    setState(() {
      liveMode = false;
      sceneIndex = index;
      level = scene.level;
      hz = scene.hz;
      direction = scene.direction;
      listening = true;
      activity.insert(0, (
        title: scene.event,
        detail: 'Demo response · no notification sent',
        time: DateTime.now(),
      ));
    });
  }

  void showInfo() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: surface,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A little more aware.', style: TextStyle(fontSize: 26)),
          const SizedBox(height: 16),
          const Text(
            'Chimey helps you notice useful sounds. Demo scenes simulate responses. Android microphone mode uses local acoustic recognition and can deliver configured personal-sound actions. Manage real profiles in your sound library.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'The light follows sound level and frequency. Directions in demo mode are simulated; one phone microphone cannot locate a sound.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1050;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced && clock.isAnimating) {
      clock.stop();
    }
    if (!reduced && !clock.isAnimating) {
      clock.repeat();
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: EdgeLight(
              clock: clock,
              level: listening ? level : 0,
              frequency: hz / 4000,
              edges: edges,
              active: listening,
              reducedMotion: reduced,
            ),
          ),
          RepaintBoundary(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 48 : 26,
                      wide ? 32 : 22,
                      wide ? 48 : 26,
                      20,
                    ),
                    child: header(wide),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: reduced ? 0 : 300),
                      child: tab == 0
                          ? listenView(wide, reduced)
                          : tab == 1
                          ? soundsView(wide)
                          : activityView(wide),
                    ),
                  ),
                  if (!wide) mobileNavigation(),
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(48, 16, 48, 28),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 14,
                            color: muted,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Your sounds stay yours.',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            '${profiles.length} sounds in your space',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(width: 24),
                          const Text(
                            'UI PROTOTYPE',
                            style: TextStyle(
                              color: muted,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
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

  Widget header(bool wide) => Row(
    children: [
      const Icon(Icons.graphic_eq_rounded, color: cyan, size: 27),
      const SizedBox(width: 10),
      if (wide)
        const Text(
          'chimey',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
          ),
        ),
      if (!wide)
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: const Text(
              'chimey',
              style: TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ),
      if (wide) ...[
        const SizedBox(width: 65),
        navigationItem(0, 'Listen', Icons.blur_on_rounded),
        navigationItem(1, 'Sounds', Icons.layers_outlined),
        navigationItem(2, 'Activity', Icons.history_rounded),
      ],
      const Spacer(),
      if (wide)
        StatusPill(
          label: liveMode ? 'Live microphone' : 'Demo mode',
          dot: true,
        ),
      if (!wide) Text(liveMode ? 'LIVE' : 'DEMO', style: eyebrow),
      const SizedBox(width: 8),
      IconButton(
        onPressed: showInfo,
        tooltip: 'About this prototype',
        icon: const Icon(Icons.info_outline_rounded, size: 19, color: muted),
      ),
    ],
  );
  Widget navigationItem(int index, String label, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: TextButton(
      onPressed: () => selectTab(index),
      style: TextButton.styleFrom(
        foregroundColor: tab == index ? Colors.white : muted,
        backgroundColor: tab == index
            ? const Color(0xff1b1e27)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 17), const SizedBox(width: 8), Text(label)],
      ),
    ),
  );
  Widget mobileNavigation() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        mobileTab(0, 'Listen', Icons.blur_on_rounded),
        mobileTab(1, 'Sounds', Icons.layers_outlined),
        mobileTab(2, 'Activity', Icons.history_rounded),
      ],
    ),
  );
  Widget mobileTab(int index, String label, IconData icon) => Expanded(
    child: TextButton(
      onPressed: () => selectTab(index),
      style: TextButton.styleFrom(foregroundColor: tab == index ? cyan : muted),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
  Widget listenView(bool wide, bool reduced) => LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        key: const ValueKey('listen'),
        padding: EdgeInsets.fromLTRB(
          wide ? 64 : 28,
          wide ? 30 : 14,
          wide ? 64 : 28,
          24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 54),
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: listeningStage(wide, reduced)),
                    const SizedBox(width: 64),
                    SizedBox(width: 280, child: demoPanel()),
                  ],
                )
              : Column(
                  children: [
                    listeningStage(wide, reduced),
                    const SizedBox(height: 36),
                    demoPanel(),
                  ],
                ),
        ),
      );
    },
  );
  Widget listeningStage(bool wide, bool reduced) => Column(
    children: [
      Row(
        children: [
          Text('YOUR SPACE', style: eyebrow),
          const Spacer(),
          Icon(Icons.circle, size: 6, color: listening ? cyan : muted),
          const SizedBox(width: 7),
          Text(
            listening ? 'Listening' : 'Paused',
            style: TextStyle(color: listening ? cyan : muted, fontSize: 12),
          ),
        ],
      ),
      SizedBox(height: wide ? 20 : 12),
      SizedBox(
        height: wide
            ? (MediaQuery.sizeOf(context).height < 800 ? 150 : 205)
            : 175,
        width: wide ? 400 : 300,
        child: SoundField(
          clock: clock,
          level: level,
          frequency: hz / 4000,
          active: listening,
          reducedMotion: reduced,
        ),
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: Duration(milliseconds: reduced ? 0 : 350),
        child: Text(
          listening
              ? (liveMode
                    ? (nativeRecognition
                          ? runtime.response
                          : level > .65
                          ? 'It’s getting louder around you.'
                          : 'Your space sounds calm.')
                    : scene.response)
              : 'Listening paused.',
          key: ValueKey(
            '$listening-$sceneIndex-$liveMode-${liveMode && level > .65}',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: wide ? 38 : 28,
            height: 1.18,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        listening
            ? (liveMode
                  ? (nativeRecognition
                        ? 'Personal matches can deliver your configured response.'
                        : 'The light follows your microphone in real time.')
                  : scene.detail)
            : 'Take a moment. I’ll be here when you’re ready.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 14),
      ),
      const SizedBox(height: 12),
      Text(
        liveMode
            ? 'Live audio · analyzed on this device'
            : sceneIndex == 0
            ? 'Simulated environment'
            : 'Demo response · no notification sent',
        style: const TextStyle(fontSize: 10, color: muted, letterSpacing: .3),
      ),
      const SizedBox(height: 28),
      Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: audio.starting || audio.stopping
                ? null
                : toggleListening,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffe0f6f6),
              foregroundColor: const Color(0xff10191c),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
            ),
            icon: Icon(
              listening ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
            ),
            label: Tooltip(
              message: listening ? 'Pause listening' : 'Resume listening',
              child: Text(listening ? 'Pause listening' : 'Resume listening'),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.outlined(
            onPressed: () => chooseScene(0),
            tooltip: 'Reset demo',
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(16),
              side: const BorderSide(color: Color(0xff30333f)),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 19, color: muted),
          ),
        ],
      ),
      SizedBox(height: wide ? 28 : 28),
      const Divider(),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: metric(
              'SOUND LEVEL',
              liveMode
                  ? audio.frame.dbfs.toStringAsFixed(0)
                  : '${(level * 70 + 20).round()}',
              liveMode ? 'dBFS · relative' : 'demo dB',
            ),
          ),
          Expanded(
            child: metric(
              'FREQUENCY',
              hz < 1000
                  ? hz.round().toString()
                  : (hz / 1000).toStringAsFixed(1),
              hz < 1000 ? 'Hz' : 'kHz',
            ),
          ),
          Expanded(
            child: metric(
              'DIRECTION',
              liveMode ? '—' : ['Front', 'Right', 'Behind', 'Left'][direction],
              liveMode ? 'not measured' : 'simulated',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Spectrum(
        level: listening ? level : .05,
        frequency: hz / 4000,
        bands: liveMode ? audio.frame.bands : null,
      ),
    ],
  );
  Widget metric(String label, String value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: eyebrow.copyWith(fontSize: 9, letterSpacing: 1.4)),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w300,
          letterSpacing: -.6,
        ),
      ),
      Text(unit, style: const TextStyle(color: muted, fontSize: 11)),
    ],
  );
  Widget demoPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text('SOUND PLAYGROUND', style: eyebrow),
          const Spacer(),
          const Icon(Icons.tune_rounded, color: muted, size: 16),
        ],
      ),
      const SizedBox(height: 12),
      const Text(
        'Try a moment.',
        style: TextStyle(fontSize: 23, letterSpacing: -.6),
      ),
      const SizedBox(height: 7),
      const Text(
        'See how Chimey responds to your space.',
        style: TextStyle(color: muted, fontSize: 12),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: audio.starting || audio.stopping
            ? null
            : () {
                if (liveMode) {
                  chooseScene(0);
                } else {
                  unawaited(useMicrophone());
                }
              },
        icon: Icon(
          liveMode ? Icons.science_outlined : Icons.mic_none_rounded,
          size: 17,
        ),
        label: Text(
          audio.starting
              ? 'Connecting…'
              : liveMode
              ? 'Use demo'
              : 'Use microphone',
        ),
      ),
      if (audio.starting)
        TextButton(
          onPressed: () => unawaited(audio.stop()),
          child: const Text('Cancel connection'),
        ),
      if (audio.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            audio.error!,
            style: const TextStyle(color: Color(0xffffc08c), fontSize: 11),
          ),
        ),
      const SizedBox(height: 20),
      ...List.generate(
        scenes.length,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: sceneIndex == i
                ? const Color(0xff192329)
                : const Color(0xff11141a),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: () => chooseScene(i),
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Icon(
                      scenes[i].icon,
                      color: sceneIndex == i ? cyan : muted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      scenes[i].name,
                      style: TextStyle(
                        color: sceneIndex == i ? cyan : Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      sceneIndex == i
                          ? Icons.equalizer_rounded
                          : Icons.arrow_outward_rounded,
                      size: 16,
                      color: sceneIndex == i ? cyan : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Divider(),
      const SizedBox(height: 18),
      if (liveMode) ...[
        Text('LIVE SOUND', style: eyebrow),
        const SizedBox(height: 14),
        const Text(
          'Audio stays on this device.',
          style: TextStyle(fontSize: 17),
        ),
        const SizedBox(height: 10),
        const Text(
          'Level and frequency shape the light. A single microphone does not measure direction, so every edge responds equally.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Text(
          nativeRecognition
              ? 'Relative dBFS · local recognition\nPersonal sound rules run on this device.'
              : 'Relative dBFS · no recording saved\nForeground visualization on this platform.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ] else ...[
        Text('SHAPE THE SOUND', style: eyebrow),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Level', style: TextStyle(color: muted, fontSize: 12)),
            const Spacer(),
            Text(
              '${(level * 70 + 20).round()} demo dB',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: level,
          min: .03,
          max: 1,
          semanticFormatterCallback: (v) =>
              '${(v * 70 + 20).round()} simulated decibels',
          onChanged: (v) => setState(() => level = v),
        ),
        Row(
          children: [
            const Text(
              'Frequency',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const Spacer(),
            Text('${hz.round()} Hz', style: const TextStyle(fontSize: 12)),
          ],
        ),
        Slider(
          value: hz,
          min: 80,
          max: 4000,
          onChanged: (v) => setState(() => hz = v),
        ),
        const Text(
          'Demo direction',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(
            4,
            (i) => ChoiceChip(
              label: Text(['Front', 'Right', 'Behind', 'Left'][i]),
              selected: direction == i,
              onSelected: (_) => setState(() => direction = i),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 11,
                color: direction == i ? cyan : muted,
              ),
              selectedColor: const Color(0xff203037),
              backgroundColor: surface,
              side: BorderSide(
                color: direction == i
                    ? const Color(0xff416068)
                    : const Color(0xff262a35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Louder on one side. More light on that edge.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    ],
  );
  Widget soundsView(bool wide) => SingleChildScrollView(
    key: const ValueKey('sounds'),
    padding: EdgeInsets.fromLTRB(
      wide ? 80 : 28,
      wide ? 48 : 20,
      wide ? 80 : 28,
      30,
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR SOUND LIBRARY', style: eyebrow),
            const SizedBox(height: 16),
            const Text(
              'Familiar sounds.\nThoughtful responses.',
              style: TextStyle(fontSize: 34, letterSpacing: -1, height: 1.15),
            ),
            const SizedBox(height: 16),
            const Text(
              'Teach Chimey what matters in your space.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 26),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SoundLibrary(runtime: runtime),
                ),
              ),
              icon: const Icon(Icons.library_music_outlined),
              label: const Text('Manage personal sounds & real actions'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SoundAssist(runtime: runtime),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Understand an unfamiliar sound'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: teachSound,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Teach a sound'),
            ),
            const SizedBox(height: 30),
            const Divider(),
            ...profiles.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(p.icon, color: cyan, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            p.detail,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          TextButton(
                            onPressed: () => configure(p),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(
                              '${p.action}  ↗',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: p.enabled,
                      onChanged: (v) => setState(() => p.enabled = v),
                      activeThumbColor: cyan,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Demo profiles · saved for this session only. Enrollment and actions are simulated.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> teachSound() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xff161922),
        title: const Text('Teach a sound'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give a familiar sound a name. This demo creates a profile without recording or training.',
                style: TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Sound name',
                  hintText: 'e.g. Coffee machine',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Save demo sound'),
          ),
        ],
      ),
    );
    // Wait until the dialog's reverse transition releases its TextField.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (name != null && mounted) {
      setState(
        () => profiles.add(
          SoundProfile(
            name,
            'Your personal demo sound',
            Icons.graphic_eq_rounded,
          ),
        ),
      );
    }
  }

  Future<void> configure(SoundProfile p) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: surface,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            const Text(
              'Choose a simulated response.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 18),
            ...['Visual cue', 'Gentle vibration', 'Connected light'].map(
              (a) => ListTile(
                title: Text(a),
                trailing: p.action == a
                    ? const Icon(Icons.check_rounded, color: cyan)
                    : null,
                onTap: () => Navigator.pop(context, a),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Preview only · no device action is executed.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
    if (action != null && mounted) {
      setState(() => p.action = action);
    }
  }

  Widget activityView(bool wide) => SingleChildScrollView(
    key: const ValueKey('activity'),
    padding: EdgeInsets.fromLTRB(
      wide ? 80 : 28,
      wide ? 48 : 20,
      wide ? 80 : 28,
      30,
    ),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('THE LITTLE MOMENTS', style: eyebrow),
            const SizedBox(height: 16),
            const Text(
              'Heard in your space.',
              style: TextStyle(fontSize: 34, letterSpacing: -1),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your demo listening history, all in one place.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 32),
            const Divider(),
            if (activity.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.history_rounded, size: 32, color: muted),
                    SizedBox(height: 20),
                    Text('A quiet start.', style: TextStyle(fontSize: 22)),
                    SizedBox(height: 8),
                    Text(
                      'Try a sound in Listen to see it here.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            ...activity.map(
              (a) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                leading: const Icon(Icons.blur_on_rounded, color: cyan),
                title: Text(a.title),
                subtitle: Text(
                  a.detail,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                trailing: Text(
                  '${a.time.hour.toString().padLeft(2, '0')}:${a.time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            ),
            if (activity.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => activity.clear()),
                child: const Text('Clear activity'),
              ),
          ],
        ),
      ),
    ),
  );
}

const eyebrow = TextStyle(
  color: muted,
  fontSize: 10,
  letterSpacing: 2,
  fontWeight: FontWeight.w500,
);

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.dot = false});
  final String label;
  final bool dot;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xff2b2e38)),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          const Icon(Icons.circle, size: 5, color: cyan),
          const SizedBox(width: 7),
        ],
        Text(label, style: const TextStyle(fontSize: 11, color: muted)),
      ],
    ),
  );
}
