import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const ExpenseApp());

// ---------- DATA MODEL: oru expense = oru bill line ----------
class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
  });

  // Expense -> JSON (save panna pack panradhu)
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
      };

  // JSON -> Expense (load panna pack ah open panradhu)
  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        category: json['category'],
        date: DateTime.parse(json['date']),
      );
}

const List<String> categories = ['Food', 'Travel', 'Bills', 'Other'];

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// ---------- SCREEN 1: Home ----------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Expense> expenses = [];
  String selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    loadExpenses(); // app open aana udane saved data load pannu
  }

  // Phone storage la irundhu padi
  Future<void> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('expenses');
    if (data != null) {
      final List list = jsonDecode(data);
      setState(() {
        expenses = list.map((e) => Expense.fromJson(e)).toList();
      });
    }
  }

  // Phone storage la ezhudhu
  Future<void> saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await prefs.setString('expenses', data);
  }

  // Filter: select panna category mattum
  List<Expense> get filteredExpenses {
    if (selectedFilter == 'All') return expenses;
    return expenses.where((e) => e.category == selectedFilter).toList();
  }

  // Total: kaattura expenses oda mothama
  double get total =>
      filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

  Future<void> openAddScreen() async {
    final Expense? newExpense = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
    );
    if (newExpense != null) {
      setState(() => expenses.add(newExpense));
      saveExpenses();
    }
  }

  void deleteExpense(String id) {
    setState(() => expenses.removeWhere((e) => e.id == id));
    saveExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final shown = filteredExpenses;
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      body: Column(
        children: [
          // Total card
          Card(
            margin: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total ($selectedFilter)',
                      style: const TextStyle(fontSize: 16)),
                  Text('₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: ['All', ...categories].map((c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selectedFilter == c,
                    onSelected: (_) => setState(() => selectedFilter = c),
                  ),
                );
              }).toList(),
            ),
          ),
          // Expense list
          Expanded(
            child: shown.isEmpty
                ? const Center(child: Text('No expenses yet. Tap + to add!'))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final e = shown[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(e.title),
                          subtitle: Text(
                              '${e.category} • ${e.date.day}/${e.date.month}/${e.date.year}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${e.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () => deleteExpense(e.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddScreen,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------- SCREEN 2: Add Expense ----------
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  String category = 'Food';
  String? titleError;
  String? amountError;

  void saveExpense() {
    final title = titleController.text.trim();
    final amount = double.tryParse(amountController.text.trim());

    // Validation
    setState(() {
      titleError = title.isEmpty ? 'Title cannot be empty' : null;
      amountError = (amount == null || amount <= 0)
          ? 'Enter a valid amount greater than 0'
          : null;
    });
    if (titleError != null || amountError != null) return;

    Navigator.pop(
      context,
      Expense(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount!,
        category: category,
        date: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title (e.g. Tea)',
                border: const OutlineInputBorder(),
                errorText: titleError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: const OutlineInputBorder(),
                errorText: amountError,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category'),
            DropdownButton<String>(
              value: category,
              isExpanded: true,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveExpense,
                child: const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}