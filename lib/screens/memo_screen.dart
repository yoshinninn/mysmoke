import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoScreen extends StatefulWidget {
  const MemoScreen({super.key});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // load history
    final rawList = prefs.getStringList('memo_history') ?? [];
    final parsed = rawList.map((e) {
      try {
        return jsonDecode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{'text': e, 'time': 0};
      }
    }).toList();
    setState(() {
      _history = parsed;
      _isLoading = false;
    });
  }

  Future<void> _saveMemoFromDialog(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = text.trim();

    // save current memo
    await prefs.setString('memo_text', trimmed);

    // add to history with timestamp
    if (trimmed.isNotEmpty) {
      final entry = {
        'text': trimmed,
        'time': DateTime.now().millisecondsSinceEpoch,
      };
      // keep newest first
      final current = prefs.getStringList('memo_history') ?? [];
      final newList = [jsonEncode(entry), ...current];
      await prefs.setStringList('memo_history', newList);
    }

    // reload history
    await _loadHistory();

    // return to home screen
    if (mounted) Navigator.of(context).pop(trimmed);
  }

  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('memo_history') ?? [];
    if (index < 0 || index >= current.length) return;

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('履歴を削除しますか？'),
        content: const Text('この操作は取り消せません。よろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    current.removeAt(index);
    await prefs.setStringList('memo_history', current);
    await _loadHistory();
  }

  Future<void> _showEditMemoDialog(int index) async {
    if (index < 0 || index >= _history.length) return;
    final item = _history[index];
    final controller = TextEditingController(
      text: (item['text'] ?? '') as String,
    );

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('メモを編集'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'メモを編集してください',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return; // キャンセル

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('memo_history') ?? [];
    try {
      final decoded = jsonDecode(current[index]) as Map<String, dynamic>;
      decoded['text'] = result.trim();
      decoded['time'] = DateTime.now().millisecondsSinceEpoch;
      current[index] = jsonEncode(decoded);
      await prefs.setStringList('memo_history', current);
      await prefs.setString('memo_text', result.trim());
      await _loadHistory();
    } catch (_) {
      // fallback: replace simple string
      current[index] = jsonEncode({
        'text': result.trim(),
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setStringList('memo_history', current);
      await prefs.setString('memo_text', result.trim());
      await _loadHistory();
    }
  }

  Future<void> _setAsHomeMemo(int index) async {
    if (index < 0 || index >= _history.length) return;
    final item = _history[index];
    final text = (item['text'] ?? '') as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memo_text', text);
    if (mounted) Navigator.of(context).pop(text);
  }

  void _showNewMemoDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新しいメモ'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'メモを入力してください',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text;
              Navigator.of(context).pop();
              _saveMemoFromDialog(text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ'),
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
              child: Text(
                'メモはまだありません',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.separated(
              itemCount: _history.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = _history[index];
                final timeMs = (item['time'] ?? 0) as int;
                final date = DateTime.fromMillisecondsSinceEpoch(
                  timeMs,
                ).toLocal();
                final formatted =
                    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                final text = (item['text'] ?? '') as String;
                return ListTile(
                  title: Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(formatted),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'set') {
                        _setAsHomeMemo(index);
                      } else if (value == 'edit') {
                        _showEditMemoDialog(index);
                      } else if (value == 'delete') {
                        _deleteHistoryItem(index);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'set',
                        child: Row(
                          children: const [
                            Icon(Icons.home, size: 18),
                            SizedBox(width: 8),
                            Text('ホームに設定'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: const [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('編集'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: const [
                            Icon(Icons.delete_forever, size: 18),
                            SizedBox(width: 8),
                            Text('削除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMemoDialog,
        backgroundColor: Colors.grey[300],
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}
