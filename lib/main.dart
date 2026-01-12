import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/record_screen.dart';
import 'screens/quest_screen.dart';
import 'screens/results_screen.dart';

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
  bool _shouldShowResults = false;

  @override
  void initState() {
    super.initState();
    _checkScreens();
  }

  Future<void> _checkScreens() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyCigarettes = prefs.getInt('weeklyCigarettes');
    final cigarettePrice = prefs.getInt('cigarettePrice');
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    final lastQuestShownTimestamp = prefs.getInt('lastQuestScreenShown');
    final lastMondayQuestShownTimestamp = prefs.getInt('lastMondayQuestShown');
    final questCompletedTimestamp = prefs.getInt('questCompletedTimestamp');

    bool shouldShowQuest = false;
    bool shouldShowResults = false;
    final now = DateTime.now();

    // 本数と金額が入力されていない場合は、必ずQuestScreenを表示
    if (weeklyCigarettes == null || cigarettePrice == null) {
      shouldShowQuest = true;
      // 初回起動フラグを更新（本数・金額が入力されていない場合も初回として扱う）
      if (isFirstLaunch) {
        await prefs.setBool('isFirstLaunch', false);
      }
      await prefs.setInt(
        'lastQuestScreenShown',
        now.millisecondsSinceEpoch,
      );
      // 月曜日の場合、月曜日の表示日も記録
      if (now.weekday == 1) {
        await prefs.setInt(
          'lastMondayQuestShown',
          now.millisecondsSinceEpoch,
        );
      }
    } else if (isFirstLaunch) {
      // 初回起動の場合
      shouldShowQuest = true;
      await prefs.setBool('isFirstLaunch', false);
      await prefs.setInt(
        'lastQuestScreenShown',
        now.millisecondsSinceEpoch,
      );
      // 月曜日の場合、月曜日の表示日も記録
      if (now.weekday == 1) {
        await prefs.setInt(
          'lastMondayQuestShown',
          now.millisecondsSinceEpoch,
        );
      }
    } else {
      // 月曜日の判定
      final isMonday = now.weekday == 1;
      if (isMonday) {
        if (lastMondayQuestShownTimestamp == null) {
          // まだ一度も月曜日に表示していない場合
          shouldShowQuest = true;
          await prefs.setInt(
            'lastMondayQuestShown',
            now.millisecondsSinceEpoch,
          );
          await prefs.setInt(
            'lastQuestScreenShown',
            now.millisecondsSinceEpoch,
          );
        } else {
          // 前回の月曜日表示日を取得
          final lastMondayShown = DateTime.fromMillisecondsSinceEpoch(
            lastMondayQuestShownTimestamp,
          );
          // 前回の月曜日表示日と今日が異なる月曜日かチェック
          final lastMondayDate = DateTime(
            lastMondayShown.year,
            lastMondayShown.month,
            lastMondayShown.day,
          );
          final todayDate = DateTime(now.year, now.month, now.day);
          
          if (todayDate.isAfter(lastMondayDate)) {
            // 新しい月曜日の場合
            shouldShowQuest = true;
            await prefs.setInt(
              'lastMondayQuestShown',
              now.millisecondsSinceEpoch,
            );
            await prefs.setInt(
              'lastQuestScreenShown',
              now.millisecondsSinceEpoch,
            );
          }
        }
      }
    }

    // ResultsScreenの表示チェック（QuestScreenよりも優先度が低い）
    // QuestScreenを表示する必要がない場合のみチェック
    if (!shouldShowQuest && questCompletedTimestamp != null) {
      final completedDate = DateTime.fromMillisecondsSinceEpoch(
        questCompletedTimestamp,
      );
      final now = DateTime.now();
      final difference = now.difference(completedDate);

      // QuestScreen入力から1週間（7日）経過している場合
      if (difference.inDays >= 7) {
        // まだResultsScreenを表示していない、または最後の表示から時間が経っている場合
        final lastResultsShownTimestamp = prefs.getInt(
          'lastResultsScreenShown',
        );
        if (lastResultsShownTimestamp == null) {
          // まだ一度も表示していない場合
          shouldShowResults = true;
          await prefs.setInt(
            'lastResultsScreenShown',
            now.millisecondsSinceEpoch,
          );
        } else {
          // 最後に表示してから1週間以上経過している場合、再度表示
          final lastShown = DateTime.fromMillisecondsSinceEpoch(
            lastResultsShownTimestamp,
          );
          final resultsDifference = now.difference(lastShown);
          if (resultsDifference.inDays >= 7) {
            shouldShowResults = true;
            await prefs.setInt(
              'lastResultsScreenShown',
              now.millisecondsSinceEpoch,
            );
          }
        }
      }
    }

    setState(() {
      _shouldShowQuest = shouldShowQuest;
      _shouldShowResults = shouldShowResults;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // QuestScreen を表示する必要がある場合（最優先）
    if (_shouldShowQuest) {
      // QuestScreen を表示し、閉じられたら MainScreen に遷移
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const QuestScreen()))
            .then((_) {
              // QuestScreen が閉じられたら、ResultsScreenをチェックしてからMainScreenに遷移
              if (mounted) {
                _checkAndShowResultsScreen();
              }
            });
      });
      // 一時的にローディング画面を表示
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ResultsScreen を表示する必要がある場合
    if (_shouldShowResults) {
      // ResultsScreen を表示し、閉じられたら MainScreen に遷移
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (context) => const ResultsScreen()),
            )
            .then((_) {
              // ResultsScreen が閉じられたら MainScreen に遷移
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

  Future<void> _checkAndShowResultsScreen() async {
    // QuestScreenが閉じられた後、ResultsScreenを表示する必要があるかチェック
    final prefs = await SharedPreferences.getInstance();
    final questCompletedTimestamp = prefs.getInt('questCompletedTimestamp');

    if (questCompletedTimestamp != null) {
      final completedDate = DateTime.fromMillisecondsSinceEpoch(
        questCompletedTimestamp,
      );
      final now = DateTime.now();
      final difference = now.difference(completedDate);

      // QuestScreen入力から1週間（7日）経過している場合
      if (difference.inDays >= 7 && mounted) {
        // ResultsScreenを表示
        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (context) => const ResultsScreen()),
            )
            .then((_) {
              // ResultsScreen が閉じられたら MainScreen に遷移
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              }
            });
        return;
      }
    }

    // ResultsScreenを表示しない場合、MainScreenに遷移
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
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
