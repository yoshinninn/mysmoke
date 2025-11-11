import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  Future<Map<String, int>> _loadTodayData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = 'dailyCount_${now.year}_${now.month}_${now.day}';

    final todayCount = prefs.getInt(todayKey) ?? 0;
    final pricePerPack = prefs.getInt('cigarettePrice') ?? 0;
    // 1箱20本換算で今日の出費を計算（小数点は四捨五入）
    final todayCost = ((pricePerPack / 20) * todayCount).round();

    return {'todayCount': todayCount, 'todayCost': todayCost};
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

          return Center(
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
                                  Icon(Icons.smoking_rooms, color: Colors.grey),
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
                                  Icon(Icons.account_balance_wallet,
                                      color: Colors.grey),
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
