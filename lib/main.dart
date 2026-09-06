import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' hide Border;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MoneyfyMasterApp());
}

class MoneyfyMasterApp extends StatelessWidget {
  const MoneyfyMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Учет доходов',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
          error: Color(0xFFF43F5E),
        ),
        cardColor: const Color(0xFF1E293B),
        useMaterial3: true,
      ),
      home: const RootPinWrapper(),
    );
  }
}

// --------------------------- МОДЕЛЬ ДАННЫХ ---------------------------
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

class CategoryItem {
  final String title;
  final IconData icon;
  final Color color;
  final String type;

  const CategoryItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.type,
  });
}

const List<CategoryItem> kAllCategories = [
  // Доходы
  CategoryItem(title: 'Дисплеи / Экраны', icon: Icons.phone_android_rounded, color: Color(0xFF10B981), type: 'income'),
  CategoryItem(title: 'Разблокировка / FRP', icon: Icons.lock_open_rounded, color: Color(0xFF06B6D4), type: 'income'),
  CategoryItem(title: 'Пайка / BGA / Разъем', icon: Icons.electrical_services_rounded, color: Color(0xFF3B82F6), type: 'income'),
  CategoryItem(title: 'Аккумуляторы', icon: Icons.battery_charging_full_rounded, color: Color(0xFF8B5CF6), type: 'income'),
  CategoryItem(title: 'Прошивка / ПО', icon: Icons.memory_rounded, color: Color(0xFFEC4899), type: 'income'),
  CategoryItem(title: 'Продажа запчастей', icon: Icons.shopping_bag_rounded, color: Color(0xFFF59E0B), type: 'income'),
  CategoryItem(title: 'Прочий доход', icon: Icons.add_circle_outline_rounded, color: Color(0xFF14B8A6), type: 'income'),

  // Расходы
  CategoryItem(title: 'Закупка запчастей', icon: Icons.inventory_2_rounded, color: Color(0xFFF43F5E), type: 'expense'),
  CategoryItem(title: 'Расходники (флюс/клей)', icon: Icons.science_rounded, color: Color(0xFFFB923C), type: 'expense'),
  CategoryItem(title: 'Инструмент / F64', icon: Icons.handyman_rounded, color: Color(0xFFE11D48), type: 'expense'),
  CategoryItem(title: 'Аренда / Мастерская', icon: Icons.storefront_rounded, color: Color(0xFFD946EF), type: 'expense'),
  CategoryItem(title: 'Коммуналка / Связь', icon: Icons.wifi_rounded, color: Color(0xFFA855F7), type: 'expense'),
  CategoryItem(title: 'Личные расходы', icon: Icons.person_rounded, color: Color(0xFF64748B), type: 'expense'),
  CategoryItem(title: 'Прочий расход', icon: Icons.remove_circle_outline_rounded, color: Color(0xFF94A3B8), type: 'expense'),
];

// --------------------------- ХРАНИЛИЩЕ ---------------------------
class StorageService {
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_data_v3.json');
  }

  static Future<Map<String, dynamic>> loadData() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (_) {}
    return {'pin': null, 'transactions': []};
  }

  static Future<void> saveData({required String? pin, required List<Transaction> transactions}) async {
    try {
      final file = await _getFile();
      final data = {
        'pin': pin,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

// --------------------------- ЭКРАН PIN-КОДА ---------------------------
class RootPinWrapper extends StatefulWidget {
  const RootPinWrapper({super.key});

  @override
  State<RootPinWrapper> createState() => _RootPinWrapperState();
}

class _RootPinWrapperState extends State<RootPinWrapper> {
  bool _isLoading = true;
  String? _savedPin;
  bool _isUnlocked = false;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = await StorageService.loadData();
    final pin = data['pin'] as String?;
    final txList = (data['transactions'] as List<dynamic>?) ?? [];
    setState(() {
      _savedPin = (pin != null && pin.isNotEmpty) ? pin : null;
      _transactions = txList.map((e) => Transaction.fromJson(e)).toList();
      _isLoading = false;
      _isUnlocked = (_savedPin == null);
    });
  }

  void _onUnlocked() {
    setState(() => _isUnlocked = true);
  }

  void _onPinChanged(String? newPin) {
    setState(() => _savedPin = newPin);
    StorageService.saveData(pin: _savedPin, transactions: _transactions);
  }

  void _onTransactionsChanged(List<Transaction> updated) {
    setState(() => _transactions = updated);
    StorageService.saveData(pin: _savedPin, transactions: _transactions);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isUnlocked && _savedPin != null) {
      return PinScreen(
        expectedPin: _savedPin!,
        onSuccess: _onUnlocked,
      );
    }

    return MainDashboard(
      transactions: _transactions,
      currentPin: _savedPin,
      onPinChanged: _onPinChanged,
      onTransactionsChanged: _onTransactionsChanged,
    );
  }
}

class PinScreen extends StatefulWidget {
  final String expectedPin;
  final VoidCallback onSuccess;

  const PinScreen({super.key, required this.expectedPin, required this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _input = '';
  String? _error;

  void _pressDigit(String digit) {
    if (_input.length < 4) {
      setState(() {
        _input += digit;
        _error = null;
      });
      if (_input.length == 4) {
        _verify();
      }
    }
  }

  void _deleteDigit() {
    if (_input.isNotEmpty) {
      setState(() {
        _input = _input.substring(0, _input.length - 1);
        _error = null;
      });
    }
  }

  void _verify() {
    if (_input == widget.expectedPin) {
      widget.onSuccess();
    } else {
      setState(() {
        _input = '';
        _error = 'Неверный пароль';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, size: 64, color: Color(0xFF38BDF8)),
              const SizedBox(height: 16),
              const Text(
                'Вход в приложение',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Введите 4-значный ПИН-код',
                style: TextStyle(fontSize: 14, color: _error != null ? const Color(0xFFF43F5E) : Colors.grey),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _input.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? const Color(0xFF38BDF8) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 12,
                  itemBuilder: (ctx, idx) {
                    if (idx < 9) {
                      final digit = '${idx + 1}';
                      return _buildKey(digit, () => _pressDigit(digit));
                    } else if (idx == 9) {
                      return const SizedBox.shrink();
                    } else if (idx == 10) {
                      return _buildKey('0', () => _pressDigit('0'));
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
                        onPressed: _deleteDigit,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E293B),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

// --------------------------- ГЛАВНЫЙ ЭКРАН (MONEFY STYLE) ---------------------------
enum TimePeriod { day, week, month, year }

class MainDashboard extends StatefulWidget {
  final List<Transaction> transactions;
  final String? currentPin;
  final ValueChanged<String?> onPinChanged;
  final ValueChanged<List<Transaction>> onTransactionsChanged;

  const MainDashboard({
    super.key,
    required this.transactions,
    required this.currentPin,
    required this.onPinChanged,
    required this.onTransactionsChanged,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  TimePeriod _period = TimePeriod.month;
  DateTime _anchorDate = DateTime.now();

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<String> _monthNames = [
    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
  ];

  String _formatMoney(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m} ',
    );
  }

  void _shiftPeriod(int offset) {
    setState(() {
      if (_period == TimePeriod.day) {
        _anchorDate = _anchorDate.add(Duration(days: offset));
      } else if (_period == TimePeriod.week) {
        _anchorDate = _anchorDate.add(Duration(days: offset * 7));
      } else if (_period == TimePeriod.month) {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + offset, 1);
      } else if (_period == TimePeriod.year) {
        _anchorDate = DateTime(_anchorDate.year + offset, 1, 1);
      }
    });
  }

  String get _periodLabel {
    if (_period == TimePeriod.day) {
      final now = DateTime.now();
      if (_anchorDate.year == now.year && _anchorDate.month == now.month && _anchorDate.day == now.day) {
        return 'Сегодня, ${_anchorDate.day} ${_monthNames[_anchorDate.month - 1].toLowerCase()}';
      }
      return '${_anchorDate.day} ${_monthNames[_anchorDate.month - 1]} ${_anchorDate.year}';
    } else if (_period == TimePeriod.week) {
      final start = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${start.day}.${start.month} — ${end.day}.${end.month}.${end.year}';
    } else if (_period == TimePeriod.month) {
      return '${_monthNames[_anchorDate.month - 1]} ${_anchorDate.year}';
    } else {
      return '${_anchorDate.year} год';
    }
  }

  List<Transaction> get _filteredTransactions {
    final list = widget.transactions.where((t) {
      if (_isSearching && _searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchNote = t.note.toLowerCase().contains(q);
        final matchCat = t.category.toLowerCase().contains(q);
        final matchAmount = t.amount.toString().contains(q);
        return matchNote || matchCat || matchAmount;
      }

      if (_period == TimePeriod.day) {
        return t.date.year == _anchorDate.year && t.date.month == _anchorDate.month && t.date.day == _anchorDate.day;
      } else if (_period == TimePeriod.week) {
        final start = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
        final startDate = DateTime(start.year, start.month, start.day);
        final endDate = startDate.add(const Duration(days: 7));
        return t.date.isAfter(startDate.subtract(const Duration(seconds: 1))) && t.date.isBefore(endDate);
      } else if (_period == TimePeriod.month) {
        return t.date.year == _anchorDate.year && t.date.month == _anchorDate.month;
      } else {
        return t.date.year == _anchorDate.year;
      }
    }).toList();

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  double get _totalIncome => _filteredTransactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpense => _filteredTransactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _balance => _totalIncome - _totalExpense;

  Map<String, double> get _expenseByCategory {
    final map = <String, double>{};
    for (final t in _filteredTransactions.where((t) => t.type == 'expense')) {
      map[t.category] = (map[t.category] ?? 0.0) + t.amount;
    }
    return map;
  }

  void _addTransaction(Transaction tx) {
    final updated = List<Transaction>.from(widget.transactions)..add(tx);
    widget.onTransactionsChanged(updated);
  }

  void _deleteTransaction(String id) {
    final updated = List<Transaction>.from(widget.transactions)..removeWhere((t) => t.id == id);
    widget.onTransactionsChanged(updated);
  }

  void _openAddModal({String? preselectedType, String? preselectedCategory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FastEntryPadSheet(
        initialType: preselectedType ?? 'income',
        initialCategory: preselectedCategory,
        onSave: (type, amount, cat, note) {
          final tx = Transaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: type,
            amount: amount,
            category: cat,
            date: DateTime.now(),
            note: note,
          );
          _addTransaction(tx);
        },
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PinSettingsDialog(
        currentPin: widget.currentPin,
        onPinSaved: (newPin) {
          widget.onPinChanged(newPin);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(newPin == null ? 'Пароль удален' : 'Пароль сохранен')),
          );
        },
      ),
    );
  }

  Future<void> _exportExcel() async {
    final list = _filteredTransactions;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для выгрузки')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheetName = 'Отчет $_periodLabel'.replaceAll('—', '-');
    final Sheet sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    sheet.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Тип'),
      TextCellValue('Категория'),
      TextCellValue('Сумма (UZS)'),
      TextCellValue('Заметка / Клиент'),
    ]);

    final df = DateFormat('dd.MM.yyyy HH:mm');
    for (final t in list) {
      sheet.appendRow([
        TextCellValue(df.format(t.date)),
        TextCellValue(t.type == 'income' ? 'Доход' : 'Расход'),
        TextCellValue(t.category),
        DoubleCellValue(t.amount),
        TextCellValue(t.note),
      ]);
    }

    sheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    sheet.appendRow([TextCellValue('ИТОГО ДОХОДЫ:'), DoubleCellValue(_totalIncome)]);
    sheet.appendRow([TextCellValue('ИТОГО РАСХОДЫ:'), DoubleCellValue(_totalExpense)]);
    sheet.appendRow([TextCellValue('ЧИСТЫЙ БАЛАНС:'), DoubleCellValue(_balance)]);

    final bytes = excel.encode();
    if (bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path)], text: 'Финансовый отчет: $_periodLabel');
    }
  }

  @override
  Widget build(BuildContext context) {
    final incomeCategories = kAllCategories.where((c) => c.type == 'income').toList();
    final expenseCategories = kAllCategories.where((c) => c.type == 'expense').toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Поиск по клиенту, модели, сумме...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _isSearching = false;
                      });
                    },
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Text('Monefy Мастер', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => setState(() => _isSearching = true),
            ),
          IconButton(
            icon: Icon(
              widget.currentPin != null ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: widget.currentPin != null ? const Color(0xFF38BDF8) : Colors.grey,
            ),
            tooltip: 'Настройка пароля',
            onPressed: _openSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
            tooltip: 'Экспорт в Excel',
            onPressed: _exportExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          // Выбор периода (День, Неделя, Месяц, Год)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildPeriodTab('День', TimePeriod.day),
                _buildPeriodTab('Неделя', TimePeriod.week),
                _buildPeriodTab('Месяц', TimePeriod.month),
                _buildPeriodTab('Год', TimePeriod.year),
              ],
            ),
          ),

          // Навигация периода (< Октябрь 2026 >)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: () => _shiftPeriod(-1),
                ),
                Text(
                  _periodLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: () => _shiftPeriod(1),
                ),
              ],
            ),
          ),

          // Центральная круговая диаграмма Monefy и иконки
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    width: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(220, 220),
                          painter: MonefyDonutPainter(
                            categoryAmounts: _expenseByCategory,
                            totalExpense: _totalExpense,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Баланс', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '${_balance >= 0 ? "+" : ""}${_formatMoney(_balance)}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _balance >= 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'UZS',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Карточки доход / расход под кругом
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 16),
                                    SizedBox(width: 4),
                                    Text('Доходы', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '+${_formatMoney(_totalIncome)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.arrow_upward_rounded, color: Color(0xFFF43F5E), size: 16),
                                    SizedBox(width: 4),
                                    Text('Расходы', style: TextStyle(color: Color(0xFFF43F5E), fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '-${_formatMoney(_totalExpense)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Быстрый выбор категорий (Monefy иконки)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Быстрый ввод по категории (нажмите на иконку):',
                          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: incomeCategories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final cat = incomeCategories[i];
                              return _buildCategoryQuickBadge(cat);
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: expenseCategories.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) {
                              final cat = expenseCategories[i];
                              return _buildCategoryQuickBadge(cat);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Список транзакций
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Операции (${_filteredTransactions.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_isSearching)
                          Text('Найдено: ${_filteredTransactions.length}', style: const TextStyle(color: Color(0xFF38BDF8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_filteredTransactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: const Text('Нет записей за выбранный период', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (ctx, i) {
                        final t = _filteredTransactions[i];
                        final isIncome = t.type == 'income';
                        final matchedCat = kAllCategories.firstWhere(
                          (c) => c.title == t.category,
                          orElse: () => CategoryItem(
                            title: t.category,
                            icon: isIncome ? Icons.add_circle : Icons.remove_circle,
                            color: isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                            type: t.type,
                          ),
                        );

                        return Dismissible(
                          key: Key(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: const Color(0xFFF43F5E),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          onDismissed: (_) => _deleteTransaction(t.id),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: matchedCat.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(matchedCat.icon, color: matchedCat.color),
                            ),
                            title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            subtitle: Text(
                              '${DateFormat('dd.MM HH:mm').format(t.date)}${t.note.isNotEmpty ? " • ${t.note}" : ""}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            trailing: Text(
                              '${isIncome ? "+" : "-"}${_formatMoney(t.amount)} UZS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text('ДОХОД', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () => _openAddModal(preselectedType: 'income'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.remove_rounded, size: 22),
                  label: const Text('РАСХОД', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  onPressed: () => _openAddModal(preselectedType: 'expense'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String label, TimePeriod period) {
    final active = _period == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = period),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF38BDF8) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? Colors.black : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryQuickBadge(CategoryItem cat) {
    return GestureDetector(
      onTap: () => _openAddModal(preselectedType: cat.type, preselectedCategory: cat.title),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: cat.color.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(cat.icon, color: cat.color, size: 24),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            child: Text(
              cat.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------- ОТРИСОВКА КРУГА MONEFY (CUSTOM PAINTER) ---------------------------
class MonefyDonutPainter extends CustomPainter {
  final Map<String, double> categoryAmounts;
  final double totalExpense;

  MonefyDonutPainter({required this.categoryAmounts, required this.totalExpense});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 18.0;

    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    if (totalExpense <= 0 || categoryAmounts.isEmpty) {
      final placeholderPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, placeholderPaint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final entry in categoryAmounts.entries) {
      final sweepAngle = (entry.value / totalExpense) * (2 * math.pi);
      final cat = kAllCategories.firstWhere(
        (c) => c.title == entry.key,
        orElse: () => const CategoryItem(title: '', icon: Icons.circle, color: Color(0xFF38BDF8), type: 'expense'),
      );

      final slicePaint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        slicePaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant MonefyDonutPainter oldDelegate) {
    return oldDelegate.totalExpense != totalExpense || oldDelegate.categoryAmounts != categoryAmounts;
  }
}

// --------------------------- БЫСТРЫЙ ВВОД / КАЛЬКУЛЯТОР ---------------------------
class FastEntryPadSheet extends StatefulWidget {
  final String initialType;
  final String? initialCategory;
  final void Function(String type, double amount, String category, String note) onSave;

  const FastEntryPadSheet({
    super.key,
    required this.initialType,
    this.initialCategory,
    required this.onSave,
  });

  @override
  State<FastEntryPadSheet> createState() => _FastEntryPadSheetState();
}

class _FastEntryPadSheetState extends State<FastEntryPadSheet> {
  late String _type;
  late String _category;
  String _amountStr = '0';
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    final availableCats = kAllCategories.where((c) => c.type == _type).map((c) => c.title).toList();
    _category = widget.initialCategory ?? availableCats.first;
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'C') {
        _amountStr = '0';
      } else if (key == '⌫') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (key == '000') {
        if (_amountStr != '0' && _amountStr.length <= 8) {
          _amountStr += '000';
        }
      } else {
        if (_amountStr == '0') {
          _amountStr = key;
        } else if (_amountStr.length <= 9) {
          _amountStr += key;
        }
      }
    });
  }

  String _formatAmount(String raw) {
    final numVal = double.tryParse(raw) ?? 0;
    return numVal.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = kAllCategories.where((c) => c.type == _type).toList();
    final isIncome = _type == 'income';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Переключатель Доход / Расход
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _type = 'income';
                      _category = kAllCategories.firstWhere((c) => c.type == 'income').title;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isIncome ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Доход',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.white : Colors.grey),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _type = 'expense';
                      _category = kAllCategories.firstWhere((c) => c.type == 'expense').title;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isIncome ? const Color(0xFFF43F5E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Расход',
                      style: TextStyle(fontWeight: FontWeight.bold, color: !isIncome ? Colors.white : Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Экран ввода суммы
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatAmount(_amountStr),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                  ),
                ),
                const Text('UZS', style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Выбор категории (горизонтальные чипсы)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                final cat = categories[idx];
                final selected = cat.title == _category;
                return ChoiceChip(
                  label: Text(cat.title),
                  selected: selected,
                  selectedColor: cat.color.withOpacity(0.3),
                  side: BorderSide(color: selected ? cat.color : Colors.transparent),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (sel) {
                    if (sel) setState(() => _category = cat.title);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Поле заметки (клиент / модель)
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Заметка: модель, клиент или деталь...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
            ),
          ),

          const SizedBox(height: 12),

          // Встроенная цифровая клавиатура
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildPadButton('1'), _buildPadButton('2'), _buildPadButton('3'), _buildPadButton('C', color: Colors.orange),
              _buildPadButton('4'), _buildPadButton('5'), _buildPadButton('6'), _buildPadButton('000'),
              _buildPadButton('7'), _buildPadButton('8'), _buildPadButton('9'), _buildPadButton('⌫', color: const Color(0xFFF43F5E)),
              const SizedBox.shrink(), _buildPadButton('0'), const SizedBox.shrink(),
              InkWell(
                onTap: () {
                  final amt = double.tryParse(_amountStr) ?? 0;
                  if (amt <= 0) return;
                  widget.onSave(_type, amt, _category, _noteController.text.trim());
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, color: Colors.black, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPadButton(String text, {Color? color}) {
    return InkWell(
      onTap: () => _pressKey(text),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

// --------------------------- НАСТРОЙКА ПАРОЛЯ ---------------------------
class PinSettingsDialog extends StatefulWidget {
  final String? currentPin;
  final ValueChanged<String?> onPinSaved;

  const PinSettingsDialog({super.key, required this.currentPin, required this.onPinSaved});

  @override
  State<PinSettingsDialog> createState() => _PinSettingsDialogState();
}

class _PinSettingsDialogState extends State<PinSettingsDialog> {
  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.currentPin != null) {
      _pinController.text = widget.currentPin!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF38BDF8)),
          SizedBox(width: 8),
          Text('Защита паролем'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Задайте 4-значный ПИН-код для блокировки входа в приложение при запуске.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, color: Colors.white),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.currentPin != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
            onPressed: () {
              widget.onPinSaved(null);
              Navigator.pop(context);
            },
            child: const Text('Отключить пароль'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
          onPressed: () {
            final pin = _pinController.text.trim();
            if (pin.length == 4) {
              widget.onPinSaved(pin);
              Navigator.pop(context);
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
