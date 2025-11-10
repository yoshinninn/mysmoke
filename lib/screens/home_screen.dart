import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _count = 4; // 現在の本数
  final int _goal = 6;

  void _increment() {
    setState(() {
      _count += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_goal - _count) > 0 ? (_goal - _count) : 0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        elevation: 0,
        centerTitle: true,
        title: const Text('ホーム', style: TextStyle(color: Colors.black)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // １日の本数表示
                Text(
                  '一日の喫煙本数： $_count 本',
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 18),

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

                // 簡易的な棒グラフ
                SizedBox(
                  height: 80,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(8, (i) {
                      final heights = [12, 28, 48, 36, 56, 44, 24, 40];
                      return Container(
                        width: 18,
                        height: heights[i].toDouble(),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(thickness: 2),
                const SizedBox(height: 12),

                // メモラベル風
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[200],
                  child: const Text('メモ', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),

                // 目標表示
                Text(
                  '今日の目標：$_goal 本（残り $remaining 本）',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      // 下部ナビゲーションはスクリーンショットに合わせ不要のため非表示
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }
}
