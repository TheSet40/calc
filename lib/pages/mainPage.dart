// ignore_for_file: file_names

import 'dart:math';

import 'package:calc/components/HistoryCache.dart';
import 'package:flutter/material.dart';

import '../models/historyItem.dart';
import '../models/operation.dart';


class MainPage extends StatefulWidget {
  const MainPage({super.key});


  @override
  State<MainPage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MainPage> {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<HistoryItem> history = [];

  static const Color rightOperand = Color(0xFFd57f23);
  static const Color leftOperand = Color(0xFF4c5668);
  static const Color number = Color(0xFF2a303f);

  final List<Model> config = List.empty(growable: true);

  double? previewResult;

  bool showExtraButtons = false;

  bool degrees = true;

  void toggleExtraButtons() {
    setState(() {
      showExtraButtons = !showExtraButtons;
    });
  }
  
  String displayString(Model model) {
    if(model.value != null){
      return model.isDecimal ? model.value.toString(): model.value.toString().replaceAll(".0", "");
    } else {
      return model.operation ?? "";
    }
  }

  double roundFloatError(double value) {
    return double.parse(value.toStringAsFixed(15));
  }

  double? getResult ({ bool shouldreset = true }) {
    try {
      double result = calculateResult(config);

      if (shouldreset) {
        final List<Model> configCopy = List<Model>.from(config);
        final newItem = HistoryItem(models: configCopy, result: result);
        HistoryCache.addToHistory(historyItem: newItem);
        history.add(newItem);

        config.clear();
        previewResult = null;
        final decimal = !result.toString().endsWith(".0");
        config.add(Model(value: result, isDecimal: decimal));
      }

      return result;
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  double calculateResult(List<Model> models) {
    List<dynamic> tokens = [];

    // Convert models to tokens
    for (var i = 0; i < models.length; i++) {
      var m = models[i];
      if (m.value != null) {
        tokens.add(m.value);
        if (i + 1 < models.length) {
          var next = models[i + 1];
          // Insert '*' if next token is π, e, '(' or "%"
          if (next.operation == "π" || next.operation == "e" || next.operation == "(" || next.operation == "%") {
            tokens.add('*');
          }
        }
      } else if (m.operation != null) {
        if (m.operation == "π") {
          tokens.add(pi);
        } else if (m.operation == "e") {
          tokens.add(e);
        } else if (m.operation == "%"){
          tokens.add(0.01);
        } else {
          tokens.add(m.operation);
          // Insert '*' if operation is ')' and next token is a number, π, e, '(' or "%"
          if (m.operation == ")" && i + 1 < models.length) {
            var next = models[i + 1];
            if (next.value != null || next.operation == "π" || next.operation == "e" || next.operation == "(" || next.operation == "%") {
              tokens.add('*');
            }
          }
        }
      } else {
        throw const FormatException("Invalid model");
      }
    }

    // Function to apply an operation
    double applyOperation(String op, double left, double right) {
      switch (op) {
        case '+':
          return left + right;
        case '-':
          return left - right;
        case '*':
          return left * right;
        case '/':
          if (right == 0) throw Exception('Division by zero');
          return left / right;
        case '^':
          return pow(left, right) as double;
        default:
          throw FormatException("Unsupported operation: $op");
      }
    }

    // Function to apply a unary operation
    double applyUnaryOperation(String op, double operand) {
      double result;
      switch (op) {
        case 'log':
          result = log(operand) / ln10;
          break;
        case 'ln':
          result = log(operand);
          break;
        case 'sin':
          result = sin(degrees ? (operand * pi / 180) : operand);
          break;
        case 'cos':
          result = cos(degrees ? (operand * pi / 180) : operand);
          break;
        case 'tan':
          result = tan(degrees ? (operand * pi / 180) : operand);
          break;
        case '√':
          result = sqrt(operand);
          break;
        default:
          throw FormatException("Unsupported unary operation: $op");
      }
      return roundFloatError(result);
    }

    // Evaluate expression
  double evaluateExpression(List<dynamic> tokens) {
    // Handle parentheses and unary operations
    int index;
    while ((index = tokens.indexWhere((t) => t == '(' || _isUnaryOperation(t))) != -1) {
      if (tokens[index] == '(') {
        int closeIndex = _findClosingParenthesisIndex(tokens, index);
        double value = evaluateExpression(tokens.sublist(index + 1, closeIndex));
        tokens.replaceRange(index, closeIndex + 1, [value]);
      } else {
        // Handling unary operations like sin, cos, tan, √, etc.
        double operand = tokens[index + 1];
        double result = applyUnaryOperation(tokens[index], operand);
        tokens.replaceRange(index, index + 2, [result]);
      }
    }

      // Handle exponentiation
      while (tokens.contains('^')) {
        int index = tokens.indexOf('^');
        double left = tokens[index - 1];
        double right = tokens[index + 1];
        double result = applyOperation('^', left, right);
        tokens.replaceRange(index - 1, index + 2, [result]);
      }

      // Handle multiplication and division
      int multIndex;
      while ((multIndex = tokens.indexWhere((t) => t == '*' || t == '/')) != -1) {
        double left = tokens[multIndex - 1];
        double right = tokens[multIndex + 1];
        double result = applyOperation(tokens[multIndex], left, right);
        tokens.replaceRange(multIndex - 1, multIndex + 2, [result]);
      }

      // Handle addition and subtraction
      while (tokens.length > 1) {
        double left = tokens[0];
        double right = tokens[2];
        double result = applyOperation(tokens[1], left, right);
        tokens.replaceRange(0, 3, [result]);
      }

      return roundFloatError(tokens[0]);
    }

    return evaluateExpression(tokens);
  }

  // Helper function to find closing parenthesis
  int _findClosingParenthesisIndex(List<dynamic> tokens, int openIndex) {
    int level = 1;
    for (int i = openIndex + 1; i < tokens.length; i++) {
      if (tokens[i] == '(') {
        level++;
      } else if (tokens[i] == ')') {
        level--;
        if (level == 0) {
          return i;
        }
      }
    }
    throw const FormatException("Mismatched parentheses");
  }

  // Helper function to identify unary operations
  bool _isUnaryOperation(dynamic token) {
    return ['sin', 'cos', 'tan', '√', 'log', 'ln'].contains(token);
  }

  void handleButtonPress(String buttonText, bool operator, Color color){
    if (operator) {
      switch (buttonText) {
        case "C": config.clear(); break;
        case "^": toggleExtraButtons(); return;
        case "DEL": config.removeLast(); break;
        case ".": config.last.isDecimal = true; break;
        case "=": getResult(); setState(() {}); return;
        default:
          final addition = Model(operation: buttonText);
          config.add(addition);
      }
    } else {
      if (config.isNotEmpty && config.last.value != null) {
        if(!config.last.isDecimal){
          final currentValue = config.last.value! * 10 + (double.tryParse(buttonText) ?? 0.0);
          config.last.value = currentValue;
        } else {
          final currentValue = config.last.value.toString();
          final finalValue = currentValue.endsWith(".0") ? currentValue.replaceAll(".0", ".") + buttonText: currentValue + buttonText;
          config.last.value = double.parse(finalValue);
        }
      } else {
        final addition = Model(value: double.tryParse(buttonText));
        config.add(addition);
      }
    }
    setState(() {
      previewResult = getResult(shouldreset: false);
    });
  }

  @override
  void initState(){
    super.initState();
    gethistory();
  }

  Future<void> gethistory() async {
    history = await HistoryCache.loadHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: drawer(),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.25,
              center: Alignment.topLeft,
              colors: [const Color(0xFF232937).withOpacity(0.95), const Color(0xFF232937)])
          ),
          child: Stack(
            children: [
              Positioned(
                top: 15,
                left: 10,
                child: GestureDetector(
                  onTap: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5a6372),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25), bottomRight: Radius.circular(25))
                    ),
                    child: Icon(
                      Icons.history,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(right: 12),
                      alignment: Alignment.bottomRight,
                      child: Text(
                        config.map((e) => displayString(e)).join(" "),
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8)),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.only(top: 10, bottom: 10, right: 12),
                    alignment: Alignment.bottomRight,
                    child: Text((previewResult.toString().endsWith(".0") ? (previewResult ?? "").toString().replaceAll(".0", ""): (previewResult ?? "")).toString(), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                  ),
                  showExtraButtons ? extraButtonsStrip() : const SizedBox.shrink(),
                  Container(
                    height: showExtraButtons ? 320 : 445,
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 5),
                    alignment: Alignment.bottomCenter,
                    child: GridView.count(
                      childAspectRatio: showExtraButtons ? 1.4 : 1,
                      crossAxisCount: 4,
                      children: <Widget>[
                        normalButton("^", operator: true, color: leftOperand),
                        normalButton("%", operator: true, color: leftOperand),
                        normalButton("DEL", operator: true, color: leftOperand),
                        normalButton("/", operator: true, color: rightOperand),
                        normalButton("7"),
                        normalButton("8"),
                        normalButton("9"),
                        normalButton("*", operator: true, color: rightOperand),
                        normalButton("4"),
                        normalButton("5"),
                        normalButton("6"),
                        normalButton("-", operator: true, color: rightOperand),
                        normalButton("1"),
                        normalButton("2"),
                        normalButton("3"),
                        normalButton("+", operator: true, color: rightOperand),
                        normalButton(".", operator: true, color: leftOperand),
                        normalButton("0"),
                        normalButton("C", operator: true, color: leftOperand),
                        normalButton("=", operator: true, color: rightOperand),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          ),
        ),
      ),
    );
  }

  Widget normalButton(String buttonText, {bool operator = false, Color color = number}) {
    return GestureDetector(
      onTap: () => handleButtonPress(buttonText, operator, color),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            gradient: RadialGradient(
              radius: 0.5,
              center: Alignment.topLeft,
              colors: [color.withOpacity(0.9), color]
            )
          ),
          child: Center(
            child: Text(
              buttonText,
              style: TextStyle(fontSize: 28, color: Colors.white.withOpacity(0.8)),
            ),
          ),
        ),
      ),
    );
  }

  Widget extraButtonsStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              extraFunctionButton("sin"),
              extraFunctionButton("cos"),
              extraFunctionButton("tan"),
              extraFunctionButton("π"),
              extraFunctionButton("e"),
              extraFunctionButton(degrees ? "deg": "rad"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              extraFunctionButton("("),
              extraFunctionButton(")"),
              extraFunctionButton("√"),
              extraFunctionButton("^"),
              extraFunctionButton("log"),
              extraFunctionButton("ln"),
            ],
          ),
        ],
      ),
    );
  }

  Widget extraFunctionButton(String buttonText){
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if(buttonText != "deg" && buttonText != "rad"){
            final addition = Model(operation: buttonText);
            config.add(addition);
          } else {
            degrees = !degrees;
          }
          setState(() {
            previewResult = getResult(shouldreset: false);
          });
        },
        child: Container(
          color: Colors.black26,
          height: 50,
            child: Center(
              child: Text(buttonText, style: TextStyle(fontSize: 28, color: Colors.white.withOpacity(0.8))),
            ),
        ),
      ),
    );
  }

  Widget drawer(){
    if(history.isEmpty){
      return const Center(
        child: Text("ingen historik att visa", style: TextStyle(fontSize: 30, color: Colors.white)),
      );
    }

    return SafeArea(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
        child: ListView.builder(
          shrinkWrap: true,
          reverse: true,
          itemCount: history.length,
          itemBuilder: (BuildContext context, int index) { 
            return drawerCard(history[index]);
          },
        )
      ),
    );
  }

  Widget drawerCard(HistoryItem item){
    return GestureDetector(
      onTap: () {
        _scaffoldKey.currentState?.closeDrawer();
        final historyReslut = Model(value: item.result, isDecimal: true);
        config.add(historyReslut);
        setState(() {
          previewResult = getResult(shouldreset: false);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.models.map((e) => displayString(e)).join(" "), style: const TextStyle(fontSize: 16, color: Colors.white)),
            Text(item.result.toString(), style: const TextStyle(fontSize: 19, color: Colors.white)),
          ],
        )
      ),
    );
  }
}