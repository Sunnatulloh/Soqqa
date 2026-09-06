import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Учет доходов и расходов',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class Transaction {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String category;
  final DateTime date;
  final String note;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    type: json['type'],
    amount: (json['amount'] as num).toDouble(),
    category: json['category'],
    date: DateTime.parse(json['date']),
    note: json['note'] ?? '',
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _currentMonth = DateTime.now();
  List<Transaction> _allTransactions = [];
  bool _isLoading = true;

  final List<String> _incomeCategories = [
    'Замена дисплея',
    'Прошивка / FRP / Разблокировка',
    'Пайка / BGA / Разъем',
    'Замена аккумулятора',
    'Продажа запчастей',
    'Прочее',
  ];

  final List<String> _expenseCategories = [
    'Закупка запчастей',
    'Расходники (флюс, клей, скотч)',
    'Оборудование и инструмент',
    'Аренда и коммуналка',
    'Личные расходы',
    'Прочее',
  ];

  static const List<String> _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/transactions.json');
  }

  Future<void> _loadTransactions() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        setState(() {
          _allTransactions = list.map((e) => Transaction.fromJson(e)).toList();
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveTransactions() async {
    try {
      final file = await _getFile();
      final data = jsonEncode(_allTransactions.map((e) => e.toJson()).toList());
      await file.writeAsString(data);
    } catch (_) {}
  }

  List<Transaction> get _monthlyTransactions {
    return _allTransactions.where((t) {
      return t.date.year == _currentMonth.year && t.date.month == _currentMonth.month;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  double get _totalIncome {
    return _monthlyTransactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _totalExpense {
    return _monthlyTransactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _netProfit => _totalIncome - _totalExpense;

  String _formatNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
  }

  void _showAddTransactionDialog(String type) {
    final categories = type == 'income' ? _incomeCategories : _expenseCategories;
    String selectedCategory = categories.first;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == 'income' ? 'Добавить доход' : 'Добавить расход',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: type == 'income' ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Модель / Клиент / Заметка',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == 'income' ? Colors.green[700] : Colors.red[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final amount = double.tryParse(amountController.text.replaceAll(' ', ''));
                        if (amount == null || amount <= 0) return;

                        final newTx = Transaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: type,
                          amount: amount,
                          category: selectedCategory,
                          date: DateTime.now(),
                          note: noteController.text.trim(),
                        );

                        setState(() {
                          _allTransactions.add(newTx);
                        });
                        _saveTransactions();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Сохранить', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    final list = _monthlyTransactions;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В этом месяце нет операций для экспорта')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final String sheetName = '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    sheet.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Тип'),
      TextCellValue('Категория'),
      TextCellValue('Сумма'),
      TextCellValue('Заметка / Клиент'),
    ]);

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    for (final tx in list) {
      sheet.appendRow([
        TextCellValue(dateFormat.format(tx.date)),
        TextCellValue(tx.type == 'income' ? 'Доход' : 'Расход'),
        TextCellValue(tx.category),
        DoubleCellValue(tx.amount),
        TextCellValue(tx.note),
      ]);
    }

    sheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    sheet.appendRow([TextCellValue('Итого доход:'), DoubleCellValue(_totalIncome)]);
    sheet.appendRow([TextCellValue('Итого расход:'), DoubleCellValue(_totalExpense)]);
    sheet.appendRow([TextCellValue('Чистая прибыль:'), DoubleCellValue(_netProfit)]);

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Report_${_currentMonth.year}_${_currentMonth.month}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes, flush: true);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Финансовый отчет за ${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final monthTitle = '${_monthNames[_currentMonth.month - 1]} ${_currentMonth.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Учет доходов и расходов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Экспорт в Excel',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 18),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: _buildSummaryCard('Доходы', _totalIncome, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Расходы', _totalExpense, Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('Прибыль', _netProfit, _netProfit >= 0 ? Colors.blue : Colors.orange)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _monthlyTransactions.isEmpty
                ? const Center(child: Text('Нет записей за этот месяц', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _monthlyTransactions.length,
                    itemBuilder: (ctx, i) {
                      final tx = _monthlyTransactions[i];
                      final isIncome = tx.type == 'income';
                      return Dismissible(
                        key: Key(tx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() {
                            _allTransactions.removeWhere((item) => item.id == tx.id);
                          });
                          _saveTransactions();
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${DateFormat('dd.MM.yyyy HH:mm').format(tx.date)}${tx.note.isNotEmpty ? " • ${tx.note}" : ""}',
                          ),
                          trailing: Text(
                            '${isIncome ? "+" : "-"}${_formatNumber(tx.amount)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isIncome ? Colors.green[800] : Colors.red[800],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Доход'),
                  onPressed: () => _showAddTransactionDialog('income'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.remove),
                  label: const Text('Расход'),
                  onPressed: () => _showAddTransactionDialog('expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, MaterialColor color) {
    return Card(
      elevation: 0,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: color.shade800, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatNumber(amount),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color.shade900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
