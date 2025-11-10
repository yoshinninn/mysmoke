import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('結果'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadResultsData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('データの読み込みに失敗しました'),
            );
          }

          final data = snapshot.data!;
          final weeklyCigarettes = data['weeklyCigarettes'] ?? 0;
          final cigarettePrice = data['cigarettePrice'] ?? 0;
          final questCompletedTimestamp = data['questCompletedTimestamp'];
          final totalCost = weeklyCigarettes * cigarettePrice;
          
          // 入力日時のフォーマット
          String inputDateText = '不明';
          if (questCompletedTimestamp != null) {
            final inputDate = DateTime.fromMillisecondsSinceEpoch(
              questCompletedTimestamp,
            );
            inputDateText = '${inputDate.year}年${inputDate.month}月${inputDate.day}日';
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.assessment,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    '1週間の結果',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '入力日: $inputDateText',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildResultRow(
                            '予定本数',
                            '$weeklyCigarettes 本',
                            Icons.smoking_rooms,
                            description: '今週吸う予定の本数',
                          ),
                          const Divider(),
                          _buildResultRow(
                            '一箱の値段',
                            _formatCurrency(cigarettePrice),
                            Icons.attach_money,
                            description: 'タバコ1箱の価格',
                          ),
                          const Divider(),
                          _buildResultRow(
                            '予定総額',
                            _formatCurrency(totalCost),
                            Icons.account_balance_wallet,
                            isHighlight: true,
                            description: '1週間の予定支出額',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('閉じる'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isHighlight ? Colors.deepPurple : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: isHighlight
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlight ? 22 : 18,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                  color: isHighlight ? Colors.deepPurple : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    // 3桁区切りのカンマを追加（例: 1000 -> 1,000）
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

  Future<Map<String, dynamic>> _loadResultsData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'weeklyCigarettes': prefs.getInt('weeklyCigarettes') ?? 0,
      'cigarettePrice': prefs.getInt('cigarettePrice') ?? 0,
      'questCompletedTimestamp': prefs.getInt('questCompletedTimestamp'),
    };
  }
}
