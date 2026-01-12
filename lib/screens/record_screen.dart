import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  Future<Map<String, int>> _loadTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'dailyCount_${now.year}_${now.month}_${now.day}';

    final todayCount = prefs.getInt(todayKey) ?? 0;
    final pricePerPack = prefs.getInt('cigarettePrice') ?? 0;
    final weeklyCigarettes = prefs.getInt('weeklyCigarettes') ?? 0;
    // 1箱20本換算で今日の出費を計算（小数点は四捨五入）
    final todayCost = ((pricePerPack / 20) * todayCount).round();

    return {
      'todayCount': todayCount,
      'todayCost': todayCost,
      'weeklyCigarettes': weeklyCigarettes,
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
      body: FutureBuilder<Map<String, int>>(
        future: _loadTodayData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('データの読み込みに失敗しました'));
          }

          final todayCount = snapshot.data!['todayCount'] ?? 0;
          final todayCost = snapshot.data!['todayCost'] ?? 0;
          final weeklyCigarettes = snapshot.data!['weeklyCigarettes'] ?? 0;

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
                    const Icon(
                      Icons.article,
                      size: 80,
                      color: Colors.deepPurple,
                    ),
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
                    const SizedBox(height: 12),
                    _buildLungsImage(context, isOverGoal),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Display lungs image from assets with warning if over goal
  Widget _buildLungsImage(BuildContext context, bool isOverGoal) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Use up to 45% of screen height, but cap to a reasonable max
    final imageHeight = math.min(screenHeight * 0.60, 520.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0),
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
            Image.asset(
              'assets/lungs.png',
              height: imageHeight,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
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
