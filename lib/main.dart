import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/quest_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MySmoke',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _shouldShowQuest = false;

  @override
  void initState() {
    super.initState();
    _checkQuestScreen();
  }

  Future<void> _checkQuestScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyCigarettes = prefs.getInt('weeklyCigarettes');
    final cigarettePrice = prefs.getInt('cigarettePrice');
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    final lastQuestShownTimestamp = prefs.getInt('lastQuestScreenShown');

    bool shouldShow = false;

    // 本数と金額が入力されていない場合は、必ず表示
    if (weeklyCigarettes == null || cigarettePrice == null) {
      shouldShow = true;
      // 初回起動フラグを更新（本数・金額が入力されていない場合も初回として扱う）
      if (isFirstLaunch) {
        await prefs.setBool('isFirstLaunch', false);
      }
      await prefs.setInt(
        'lastQuestScreenShown',
        DateTime.now().millisecondsSinceEpoch,
      );
    } else if (isFirstLaunch) {
      // 初回起動の場合
      shouldShow = true;
      await prefs.setBool('isFirstLaunch', false);
      await prefs.setInt(
        'lastQuestScreenShown',
        DateTime.now().millisecondsSinceEpoch,
      );
    } else if (lastQuestShownTimestamp != null) {
      // 最後に表示されてからの経過時間をチェック
      final lastShown = DateTime.fromMillisecondsSinceEpoch(
        lastQuestShownTimestamp,
      );
      final now = DateTime.now();
      final difference = now.difference(lastShown);

      // 1週間（7日）経過している場合
      if (difference.inDays >= 7) {
        shouldShow = true;
        await prefs.setInt('lastQuestScreenShown', now.millisecondsSinceEpoch);
      }
    }

    setState(() {
      _shouldShowQuest = shouldShow;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // QuestScreen を表示する必要がある場合
    if (_shouldShowQuest) {
      // QuestScreen を表示し、閉じられたら MainScreen に遷移
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const QuestScreen()))
            .then((_) {
              // QuestScreen が閉じられたら MainScreen に遷移
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              }
            });
      });
      // 一時的にローディング画面を表示
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [const HomeScreen(), const RecordScreen()];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.article), label: '記録'),
        ],
      ),
    );
  }
}
