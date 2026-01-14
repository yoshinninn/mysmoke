import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'results_screen.dart'; //結果画面への遷移
import 'memo_screen.dart';
import 'quest_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _lastDailyResetKey = 'lastDailyResetDate';
  static const String _lastQuestTimestampKey = 'lastQuestTimestampChecked';
  static const String _weeklyCountKey = 'weeklySmokedCount';
  static const String _lastMondayResetKey = 'lastMondayResetDate';
  int _count = 0; // 現在の本数
  int _weeklyCount = 0; // 現在の週本数
  List<int> _weeklyDailyCounts = List.filled(7, 0);
  List<DateTime> _weekDates = const [];

  double _goal = 0;
  bool _isLoading = true;
  String _memo = '';

  @override
  void initState() {
    super.initState();
    _loadCount();
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    final prefs = await SharedPreferences.getInstance();
    final memo = prefs.getString('memo_text') ?? '';
    setState(() {
      _memo = memo;
    });
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _markDailyReset(SharedPreferences prefs, DateTime today) async {
    await prefs.setInt(
      _lastDailyResetKey,
      _dateOnly(today).millisecondsSinceEpoch,
    );
  }

  Future<void> _resetDailyCount(
    SharedPreferences prefs,
    String todayKey,
    DateTime today,
  ) async {
    await prefs.setInt(todayKey, 0);
    await _markDailyReset(prefs, today);
  }

  Future<void> _maybeResetDailyCount(
    SharedPreferences prefs,
    DateTime today,
    String todayKey,
  ) async {
    final lastResetMillis = prefs.getInt(_lastDailyResetKey);
    if (lastResetMillis == null) {
      await _markDailyReset(prefs, today);
      return;
    }

    final lastResetDate = DateTime.fromMillisecondsSinceEpoch(
      lastResetMillis,
      isUtc: false,
    );
    if (!_isSameDay(lastResetDate, today)) {
      await _resetDailyCount(prefs, todayKey, today);
    }
  }

  Future<void> _resetWeeklyProgress(
    SharedPreferences prefs,
    String todayKey,
    DateTime today, {
    int? questTimestamp,
  }) async {
    await _resetDailyCount(prefs, todayKey, today);
    await prefs.setInt(_weeklyCountKey, 0);
    if (questTimestamp != null) {
      await prefs.setInt(_lastQuestTimestampKey, questTimestamp);
    }
  }

  // 指定された日付から最も近い過去の月曜日を取得
  DateTime _getLastMonday(DateTime date) {
    final weekday = date.weekday; // 1=月曜日, 7=日曜日
    final daysToSubtract = weekday == 1 ? 0 : weekday - 1;
    return _dateOnly(date.subtract(Duration(days: daysToSubtract)));
  }

  Future<void> _loadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'dailyCount_${today.year}_${today.month}_${today.day}';

    await _maybeResetDailyCount(prefs, today, todayKey);

    // 月曜日を基準に週をチェック
    final currentMonday = _getLastMonday(today);
    final lastMondayResetMillis = prefs.getInt(_lastMondayResetKey);
    int count = prefs.getInt(todayKey) ?? 0;
    int weeklyCount = prefs.getInt(_weeklyCountKey) ?? 0;

    // questCompletedTimestampの更新をチェック（QuestScreenで新しい目標が設定された場合）
    final questCompletedTimestamp = prefs.getInt('questCompletedTimestamp');
    final lastQuestTimestamp = prefs.getInt(_lastQuestTimestampKey);
    final hasQuestUpdate =
        questCompletedTimestamp != null &&
        questCompletedTimestamp != lastQuestTimestamp;

    if (hasQuestUpdate) {
      // QuestScreenで新しい目標が設定された場合、週をリセット
      await _resetWeeklyProgress(
        prefs,
        todayKey,
        today,
        questTimestamp: questCompletedTimestamp,
      );
      await prefs.setInt(
        _lastMondayResetKey,
        currentMonday.millisecondsSinceEpoch,
      );
      count = 0;
      weeklyCount = 0;
    } else if (lastMondayResetMillis != null) {
      // 前回の月曜日リセット日を取得
      final lastMondayReset = DateTime.fromMillisecondsSinceEpoch(
        lastMondayResetMillis,
        isUtc: false,
      );
      final lastMondayDate = _dateOnly(lastMondayReset);

      // 新しい週が始まったかチェック（現在の月曜日が前回の月曜日より後）
      if (currentMonday.isAfter(lastMondayDate)) {
        // 新しい週が始まった場合、週をリセット
        await _resetWeeklyProgress(prefs, todayKey, today);
        await prefs.setInt(
          _lastMondayResetKey,
          currentMonday.millisecondsSinceEpoch,
        );
        count = prefs.getInt(todayKey) ?? 0;
        weeklyCount = 0;
      } else {
        // 同じ週内であれば、保存された値を読み込む
        count = prefs.getInt(todayKey) ?? 0;
        weeklyCount = prefs.getInt(_weeklyCountKey) ?? 0;
      }
    } else {
      // 初回起動時、現在の月曜日を記録
      await prefs.setInt(
        _lastMondayResetKey,
        currentMonday.millisecondsSinceEpoch,
      );
      count = prefs.getInt(todayKey) ?? 0;
      weeklyCount = prefs.getInt(_weeklyCountKey) ?? 0;
    }

    final weekDates = _generateWeekDates(prefs);
    final weeklyDailyCounts = _readWeeklyCounts(prefs, weekDates);

    // quest_screen.dartで入力された今週吸う本数を読み込んで7で割る
    final weeklyCigarettes = prefs.getInt('weeklyCigarettes') ?? 35;
    final goal = weeklyCigarettes / 7;

    setState(() {
      _count = count;
      _weeklyCount = weeklyCount;
      _weekDates = weekDates;
      _weeklyDailyCounts = weeklyDailyCounts;
      _goal = goal;
      _isLoading = false;
    });
  }

  Future<void> _increment() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = 'dailyCount_${today.year}_${today.month}_${today.day}';

    await _maybeResetDailyCount(prefs, today, todayKey);
    final currentCount = prefs.getInt(todayKey) ?? 0;
    setState(() {
      _count = currentCount;
    });

    final newCount = _count + 1;
    final newWeeklyCount = _weeklyCount + 1;
    await prefs.setInt(todayKey, newCount);
    await prefs.setInt(_weeklyCountKey, newWeeklyCount);

    final weekDates = _generateWeekDates(prefs);
    final weeklyDailyCounts = _readWeeklyCounts(prefs, weekDates);

    setState(() {
      _count = newCount;
      _weeklyCount = newWeeklyCount;
      _weekDates = weekDates;
      _weeklyDailyCounts = weeklyDailyCounts;
    });
  }

  List<DateTime> _generateWeekDates(SharedPreferences prefs) {
    // 月曜日を基準に週を生成
    final today = DateTime.now();
    final weekStart = _getLastMonday(today);

    // 月曜日から7日間を返す（月曜日から日曜日まで）
    return List.generate(
      7,
      (index) => _dateOnly(weekStart.add(Duration(days: index))),
    );
  }

  List<int> _readWeeklyCounts(
    SharedPreferences prefs,
    List<DateTime> weekDates,
  ) {
    return weekDates.map((date) {
      final key = 'dailyCount_${date.year}_${date.month}_${date.day}';
      return prefs.getInt(key) ?? 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final remaining = (_goal - _count) > 0 ? (_goal - _count) : 0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        centerTitle: true,
        title: const Text('ホーム', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          //結果画面への遷移
          icon: const Icon(Icons.assessment),
          onPressed: () {
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (context) => const ResultsScreen(),
                  ),
                )
                .then((_) {
                  _loadCount();
                });
          },
          tooltip: '結果画面',
        ), //結果画面への遷移
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // １日の本数表示
                // 目標表示
                Text(
                  '今日の目標：${_goal.toInt()} 本（残り ${remaining.toInt()} 本）',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  '一日の喫煙本数： $_count 本',
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  '一週間の喫煙本数： $_weeklyCount 本',
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 18),
                // same animated character display as in RecordScreen
                Center(
                  child: Builder(builder: (context) {
                    String assetPath = 'assets/hai_1.png';
                    try {
                      final weeklyCigarettes = (_goal * 7).round();
                      if (weeklyCigarettes > 0) {
                        final third = weeklyCigarettes / 3.0;
                        if (_count > weeklyCigarettes) {
                          assetPath = 'assets/hai_4.png';
                        } else if (_count >= 2 * third) {
                          assetPath = 'assets/hai_3.png';
                        } else if (_count >= third) {
                          assetPath = 'assets/hai_2.png';
                        } else {
                          assetPath = 'assets/hai_1.png';
                        }
                      }
                    } catch (_) {
                      assetPath = 'assets/hai_1.png';
                    }

                    return SplitSequenceImage(
                      asset: assetPath,
                      size: 160,
                      interval: const Duration(milliseconds: 140),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                Center(
                  child: ElevatedButton(
                    onPressed: _increment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      minimumSize: const Size(200, 64),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: const Text(
                      '+1本',
                      style: TextStyle(fontSize: 28, color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // 週間棒グラフ
                _buildWeeklyBarChart(),
                const SizedBox(height: 6),
                const Divider(thickness: 2),
                const SizedBox(height: 12),

                // メモラベル風
                InkWell(
                  onTap: () async {
                    // MemoScreen で保存されたテキストを受け取り更新
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const MemoScreen(),
                      ),
                    );
                    if (result != null && result is String) {
                      setState(() {
                        _memo = result;
                      });
                    } else {
                      // 何も返ってこなかった場合は再読み込み
                      _loadMemo();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[200],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('メモ', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          _memo.isNotEmpty ? _memo : 'メモを追加するにはタップしてください',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // 下部ナビゲーションはスクリーンショットに合わせ不要のため非表示
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }

  Widget _buildWeeklyBarChart() {
    // 月曜日から日曜日の順序で固定
    const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
    const horizontalLevels = [5, 10, 15];
    const barMaxHeight = 120.0;

    final maxCount = _weeklyDailyCounts.fold<int>(
      0,
      (previousValue, element) =>
          element > previousValue ? element : previousValue,
    );
    final safeMax = maxCount == 0 ? 1 : maxCount;
    final effectiveMax = safeMax < horizontalLevels.last
        ? horizontalLevels.last.toDouble()
        : safeMax.toDouble();

    Widget buildBarRow() {
      return Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (index) {
            final count = _weeklyDailyCounts.length > index
                ? _weeklyDailyCounts[index]
                : 0;
            final barHeight = (count / effectiveMax) * barMaxHeight;
            final displayHeight = barHeight < 6 ? 6.0 : barHeight;
            return Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 18,
                  height: displayHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    Widget buildLabelRow() {
      return Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          children: List.generate(7, (index) {
            final date = _weekDates.length > index
                ? _weekDates[index]
                : DateTime.now();
            final dateLabel = '${date.month}/${date.day}';
            // インデックス0が月曜日、インデックス6が日曜日になるように固定
            // _weekDatesは既に月曜日から始まっているので、インデックスをそのまま使用
            final weekdayIndex = index; // 0=月曜日, 1=火曜日, ..., 6=日曜日
            return Expanded(
              child: Column(
                children: [
                  Text(
                    weekdayLabels[weekdayIndex],
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    }

    List<Widget> buildHorizontalLines() {
      return horizontalLevels.map((level) {
        final ratio = (level / effectiveMax).clamp(0.0, 1.0);
        return Positioned(
          bottom: ratio * barMaxHeight,
          left: 0,
          right: 0,
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  level.toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
              Expanded(child: Container(height: 1, color: Colors.grey[350])),
            ],
          ),
        );
      }).toList();
    }

    return Column(
      children: [
        SizedBox(
          height: barMaxHeight,
          child: Stack(
            children: [
              ...buildHorizontalLines(),
              Positioned.fill(child: buildBarRow()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        buildLabelRow(),
      ],
    );
  }
}
