import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  // 指定された日付から最も近い過去の月曜日を取得
  DateTime _getLastMonday(DateTime date) {
    final weekday = date.weekday; // 1=月曜日, 7=日曜日
    final daysToSubtract = weekday == 1 ? 0 : weekday - 1;
    return _dateOnly(date.subtract(Duration(days: daysToSubtract)));
  }

  int _daysInMonth(int year, int month) {
    final beginningNextMonth =
        (month == 12) ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return beginningNextMonth.subtract(const Duration(days: 1)).day;
  }

  Future<Map<String, dynamic>> _loadTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'dailyCount_${now.year}_${now.month}_${now.day}';

    final todayCount = prefs.getInt(todayKey) ?? 0;
    final pricePerPack = prefs.getInt('cigarettePrice') ?? 0;
    final weeklyCigarettes = prefs.getInt('weeklyCigarettes') ?? 0;
    // 1箱20本換算で今日の出費を計算（小数点は四捨五入）
    final todayCost = ((pricePerPack / 20) * todayCount).round();

    // 月内を1週(最大7日)単位で集計
    final daysInMonth = _daysInMonth(now.year, now.month);
    final weekBucketCount = ((daysInMonth - 1) ~/ 7) + 1; // 4〜5週
    final monthlyWeeklyCounts = List<int>.filled(weekBucketCount, 0);
    final monthlyWeekLabels = <String>[];

    for (int weekIndex = 0; weekIndex < weekBucketCount; weekIndex++) {
      final startDay = weekIndex * 7 + 1;
      final endDay = (startDay + 6) > daysInMonth ? daysInMonth : startDay + 6;
      monthlyWeekLabels.add('$startDay-${endDay}日');

      for (int day = startDay; day <= endDay; day++) {
        final key = 'dailyCount_${now.year}_${now.month}_$day';
        monthlyWeeklyCounts[weekIndex] += prefs.getInt(key) ?? 0;
      }
    }

    return {
      'todayCount': todayCount,
      'todayCost': todayCost,
      'weeklyCigarettes': weeklyCigarettes,
      'monthlyWeeklyCounts': monthlyWeeklyCounts,
      'monthlyWeekLabels': monthlyWeekLabels,
    };
  }

  String _formatCurrency(int amount) {
    final amountStr = amount.toString();
    final reversed = amountStr.split('').reversed.join();
    final buffer = StringBuffer();
    for (int i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(reversed[i]);
    }
    return '¥${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadTodayData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('データの読み込みに失敗しました'));
          }

          final todayCount = snapshot.data!['todayCount'] as int? ?? 0;
          final todayCost = snapshot.data!['todayCost'] as int? ?? 0;
          final weeklyCigarettes = snapshot.data!['weeklyCigarettes'] as int? ?? 0;
          final monthlyWeeklyCounts =
              snapshot.data!['monthlyWeeklyCounts'] as List<int>? ?? [];
          final monthlyWeekLabels =
              snapshot.data!['monthlyWeekLabels'] as List<String>? ?? [];

          // Calculate daily goal (1/7 of weekly goal, rounded up)
          // Show bubble when today's count is greater than or equal to the daily goal.
          // If weeklyCigarettes is not set (<= 0) or is an unrealistic large value, do not show the bubble.
          final int maxReasonableWeekly =
              200; // safeguard: more than this is likely a bad input
          int effectiveWeekly = weeklyCigarettes;
          bool ignoredLargeWeekly = false;
          if (weeklyCigarettes > maxReasonableWeekly) {
            // treat as unset to avoid extremely large dailyGoal
            effectiveWeekly = 0;
            ignoredLargeWeekly = true;
          }

          int dailyGoal = 0;
          bool isOverGoal = false;
          if (effectiveWeekly > 0) {
            dailyGoal = (effectiveWeekly / 7).ceil();
            isOverGoal = dailyGoal > 0 ? (todayCount >= dailyGoal) : false;
          }

          return SingleChildScrollView(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 24),
                    const Text(
                      '今日の記録',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.smoking_rooms,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '今日吸った本数',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$todayCount 本',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '今日の出費',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatCurrency(todayCost),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '月間 週別グラフ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMonthlyBarChart(
                      monthlyWeeklyCounts,
                      monthlyWeekLabels,
                    ),
                    const SizedBox(height: 24),
                    _buildLungsImage(context, isOverGoal, todayCount, weeklyCigarettes),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyBarChart(
    List<int> monthlyWeeklyCounts,
    List<String> monthlyWeekLabels,
  ) {
    if (monthlyWeeklyCounts.isEmpty || monthlyWeekLabels.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('データがありません')),
      );
    }

    final maxCount = monthlyWeeklyCounts.fold<int>(
      0,
      (prev, element) => element > prev ? element : prev,
    );
    final maxY = math.max(maxCount, 5).toDouble();

    final barGroups = monthlyWeeklyCounts.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value.toDouble();
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Colors.deepPurple,
            width: 22,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: Colors.grey[200],
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 20 ? 5 : 2,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[300]!,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < monthlyWeekLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            monthlyWeekLabels[idx],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY > 20 ? 5 : 2,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[300]!),
              ),
              barTouchData: BarTouchData(enabled: true),
            ),
          ),
        ),
      ),
    );
  }

  // Display lungs image from assets with warning if over goal
  Widget _buildLungsImage(BuildContext context, bool isOverGoal, int todayCount, int weeklyCigarettes) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Use up to 45% of screen height, but cap to a reasonable max
    final imageHeight = math.min(screenHeight * 0.60, 520.0);

    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 40.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOverGoal) ...[
              _SpeechBubble(
                title: '今日はちょっと多いかも？',
                body: '今日はちょっと多めかもしれないね。無理しないで、ひと息ついて深呼吸してみよう！',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
            ],
              // choose asset by thirds of weekly goal: hai_1 -> hai_2 -> hai_3, over goal -> hai_4
              Builder(builder: (context) {
                String assetPath = 'assets/hai_1.png';
                try {
                  final weeklyGoal = weeklyCigarettes;
                  if (weeklyGoal > 0) {
                    final third = weeklyGoal / 3.0;
                    if (todayCount > weeklyGoal) {
                      assetPath = 'assets/hai_4.png';
                    } else if (todayCount >= 2 * third) {
                      assetPath = 'assets/hai_3.png';
                    } else if (todayCount >= third) {
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
                  size: imageHeight,
                  interval: const Duration(milliseconds: 140),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class SplitSequenceImage extends StatefulWidget {
  final String asset;
  final double size;
  final Duration interval;

  const SplitSequenceImage({
    Key? key,
    required this.asset,
    required this.size,
    this.interval = const Duration(milliseconds: 140),
  }) : super(key: key);

  @override
  State<SplitSequenceImage> createState() => _SplitSequenceImagePainterState();
}

class _SplitSequenceImagePainterState extends State<SplitSequenceImage> {
  ui.Image? _image;
  int _visibleIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadImage();
    // start timer after a short delay to avoid racing before image load
    // Timer will be started inside _loadImage on success; if load fails we still start it
  }

  @override
  void didUpdateWidget(covariant SplitSequenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _image?.dispose();
      _image = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    try {
      final data = await rootBundle.load(widget.asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      setState(() {
        _image = frame.image;
      });
    } catch (e, st) {
      // Log and fallback to widget-based Image if decoding fails
      debugPrint('SplitSequenceImage: failed to load ${widget.asset}: $e');
      debugPrint(st.toString());
      setState(() {
        _image = null;
      });
    } finally {
      // ensure timer runs even if image load failed
      _timer?.cancel();
      _timer = Timer.periodic(widget.interval, (_) {
        setState(() {
          _visibleIndex = (_visibleIndex + 1) % 8;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    if (_image == null) {
      // fallback: use Image.asset and crop via FittedBox alignment
      final cols = 8;
      final alignment = Alignment(-1.0 + (_visibleIndex * 2.0) / (cols - 1), 0.0);
      return SizedBox(
        height: size,
        width: size,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: alignment,
          child: Image.asset(widget.asset),
        ),
      );
    }

    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(
        painter: _QuadPainter(image: _image!, index: _visibleIndex),
        size: Size(size, size),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  final ui.Image image;
  final int index;

  _QuadPainter({required this.image, required this.index});

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // Assume 8 characters arranged horizontally (1 row, 8 columns)
    const cols = 8;
    final srcW = imgW / cols;
    final srcH = imgH;

    // shrink slightly to avoid neighboring bleed
    const shrinkFactor = 1.0;
    final innerW = srcW * shrinkFactor;
    final innerH = srcH * shrinkFactor;
    final offsetX = index * srcW + (srcW - innerW) / 2.0;
    final offsetY = (srcH - innerH) / 2.0;
    final src = Rect.fromLTWH(offsetX, offsetY, innerW, innerH);
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);

    final paint = Paint()..isAntiAlias = true;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _QuadPainter oldDelegate) {
    return oldDelegate.index != index || oldDelegate.image != image;
  }
}

// Simple speech-bubble widget with a small pointer (rotated square)
class _SpeechBubble extends StatelessWidget {
  final String title;
  final String body;
  final Color color;

  const _SpeechBubble({
    Key? key,
    required this.title,
    required this.body,
    this.color = Colors.orange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            border: Border.all(color: Colors.orange[200]!, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withAlpha(30),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_emotions,
                    color: Colors.orange[700],
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.orange[700]),
              ),
            ],
          ),
        ),
        // Pointer (rotated square)
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 16, height: 16, color: Colors.orange[50]),
        ),
      ],
    );
  }
}

