import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  final TextEditingController _cigarettesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _cigarettesController.addListener(_validateInput);
    _priceController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _cigarettesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final cigarettesText = _cigarettesController.text.trim();
    final priceText = _priceController.text.trim();
    setState(() {
      final cigarettesValid = cigarettesText.isNotEmpty &&
          int.tryParse(cigarettesText) != null &&
          int.parse(cigarettesText) > 0;
      final priceValid = priceText.isNotEmpty &&
          int.tryParse(priceText) != null &&
          int.parse(priceText) > 0;
      _isButtonEnabled = cigarettesValid && priceValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.assignment, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                '今週吸う本数を入力してください',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _cigarettesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '本数',
                  hintText: '例: 10',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.smoking_rooms),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '一箱の値段',
                  hintText: '例: 600',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isButtonEnabled
                    ? () async {
                        await _saveData();
                        Navigator.of(context).pop();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                ),
                child: const Text('次へ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final cigarettes = int.parse(_cigarettesController.text.trim());
    final price = int.parse(_priceController.text.trim());
    
    // 本数と金額を別々のキーで保存
    await prefs.setInt('weeklyCigarettes', cigarettes);
    await prefs.setInt('cigarettePrice', price);
    
    // 入力完了時のタイムスタンプを保存（1週間後の結果表示に使用）
    await prefs.setInt(
      'questCompletedTimestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
