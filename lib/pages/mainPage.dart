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

  String errorMessage = "";

  bool showExtraButtons = false;

  bool degrees = true;
  bool eyeComfort = false;

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
    return double.parse(value.toStringAsFixed(12));
  }

  double? getResult ({ bool shouldreset = true }) {
    if (config.isEmpty) {
      errorMessage = "";
      return null;
    }

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
      if (!e.toString().contains(RegExp(r"(inclusive range|value range is empty)"))) {
        errorMessage = e.toString().split(":")[1];
      }
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
        // Insert '*' if next token is π, e, '(', '%' or '|'
        if (next.operation == "π" || next.operation == "e" || next.operation == "(" || next.operation == "%") {
          tokens.add('*');
        }
      }
    } else if (m.operation != null) {
      if (m.operation == "π") {
        tokens.add(pi);
      } else if (m.operation == "e") {
        tokens.add(e);
      } else if (m.operation == "%") {
        tokens.add(0.01);
      } else if (m.operation == "|") {
        tokens.add('|');
      } else {
        tokens.add(m.operation);
        // Insert '*' if operation is ')' and next token is a number, π, e, '(', '%' or '|'
        if (m.operation == ")" && i + 1 < models.length) {
          var next = models[i + 1];
          if (next.value != null || next.operation == "π" || next.operation == "e" || next.operation == "(" || next.operation == "%") {
            tokens.add('*');
          }
        }
      }
    } else {
      throw Exception("Invalid model");
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
      case 'mod':
        return left % right;
      default:
        throw Exception("Unsupported operation: $op");
    }
  }

  // Function to apply a unary operation
  double applyUnaryOperation(String op, double operand) {
    double result;
    switch (op) {
      case 'sin':
        result = sin(degrees ? (operand * pi / 180) : operand);
        break;
      case 'cos':
        result = cos(degrees ? (operand * pi / 180) : operand);
        break;
      case 'tan':
        result = tan(degrees ? (operand * pi / 180) : operand);
        break;
      case 'log':
        result = log(operand) / ln10;
        break;
      case 'ln':
        result = log(operand);
        break;
      case '√':
        result = sqrt(operand);
        break;
      default:
        throw Exception("Unsupported unary operation: $op");
    }
    return roundFloatError(result);
  }

  // Evaluate expression
  double evaluateExpression(List<dynamic> tokens) {
    debugPrint("tokens $tokens");

    // Handle absolute value
    int openIndex;
    while ((openIndex = tokens.indexOf('|')) != -1) {
      int closeIndex = tokens.indexOf('|', openIndex + 1);
      if (closeIndex == -1) throw const FormatException("Mismatched '|' for absolute value");
      double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex));
      tokens.replaceRange(openIndex, closeIndex + 1, [value.abs()]);
    }

    // Handle parentheses
    while ((openIndex = tokens.lastIndexOf('(')) != -1) {
      int closeIndex = tokens.indexOf(')', openIndex);
      double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex));
      tokens.replaceRange(openIndex, closeIndex + 1, [value]);
    }

    // Handle unary operations
    for (var op in ["log", 'ln', 'sin', 'cos', 'tan', '√']) {
      while (tokens.contains(op)) {
        int index = tokens.indexOf(op);
        double operand = tokens[index + 1];
        double result = applyUnaryOperation(op, operand);
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
      String stringLeft = tokens[0].toString();

      if (tokens.length == 2 && stringLeft == "-") {
        return tokens[1] * -1.0;
      }

      String stringRight = tokens[2].toString();

      int offset = 1;

      if (stringLeft == "-") {
        stringLeft = "-${tokens[0 + offset]}";
        stringRight = tokens[2 + offset].toString();
        offset++;
      }
      
      if (stringRight == "-") {
        stringRight = "-${tokens[2 + offset]}";
      }

      double result = applyOperation(tokens[offset], double.parse(stringLeft), double.parse(stringRight));

      tokens.replaceRange(0, 2 + offset, [result]);
    }

    return roundFloatError(tokens[0]);
  }

  return roundFloatError(evaluateExpression(tokens));
}

  void handleButtonPress(String buttonText, bool operator, Color color){
    if (operator) {
      switch (buttonText) {
        case "C": config.clear(); break;
        case "DEL": if (config.isNotEmpty) config.removeLast(); break;
        case ".": config.last.isDecimal = true; break;
        case "=": getResult(); setState(() {}); return;
        default:
          if(config.last.value != null) {
            final addition = Model(operation: buttonText);
            config.add(addition);
          } else {
            debugPrint("not adding opperand");
          }
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
      drawer: drawer(context),
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
              Positioned(
                top: 15,
                right: 10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      eyeComfort = !eyeComfort;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5a6372),
                      borderRadius: BorderRadius.all(Radius.circular(25))
                    ),
                    child: Icon(
                      Icons.remove_red_eye_outlined,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        config.map((e) => displayString(e)).join(),
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8)),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 5, 12, 10),
                    alignment: Alignment.bottomLeft,
                    child: Text((previewResult ?? errorMessage).toString().replaceAll(RegExp(r"(\.0*|(?<=\.\d*)0+)$"), ""), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
                  ),
                  showExtraButtons ? extraButtonsStrip() : const SizedBox.shrink(),
                  Container(
                    height: showExtraButtons ? 320 : 445,
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 5),
                    alignment: Alignment.bottomCenter,
                    child: GridView.count(
                      childAspectRatio: showExtraButtons ? 1.4 : 1,
                      crossAxisCount: 4,
                      children: [
                        iconButton(),
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(5)
        ),
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
                extraFunctionButton("mod"),
                extraFunctionButton("|x|"),
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
      ),
    );
  }

  Widget extraFunctionButton(String buttonText) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if(buttonText != "deg" && buttonText != "rad"){
            final addition = Model(operation: buttonText != "|x|" ? buttonText: "|");
            config.add(addition);
            if (buttonText != "e" && buttonText != "π" && buttonText != "(" && buttonText != ")" && buttonText != "|x|") {
              config.add(Model(operation: "("));
            }
          } else {
            degrees = !degrees;
          }
          setState(() {
            previewResult = getResult(shouldreset: false);
          });
        },
        child: SizedBox(
          height: 42.5,
            child: Center(
              child: Text(buttonText, style: TextStyle(fontSize: 25, color: Colors.white.withOpacity(0.8))),
            ),
        ),
      ),
    );
  }

  Widget drawer(BuildContext context){
    if(history.isEmpty){
      return const Center(
        child: Text("ingen historik att visa", style: TextStyle(fontSize: 30, color: Colors.white)),
      );
    }

    return SafeArea(
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.55,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
        decoration: const BoxDecoration(
          color: Color(0xff151515),
          borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28))
        ),
        child: ListView.builder(
          shrinkWrap: true,
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
            Text(item.models.map((e) => displayString(e)).join(""), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.75))),
            Text(item.result.toStringAsFixed(8).replaceAll(RegExp(r"(\.0*|(?<=\.\d*)0+)$"), ""), style: TextStyle(fontSize: 19, color: Colors.white.withOpacity(0.75))),
          ],
        )
      ),
    );
  }

  Widget iconButton({Color color = leftOperand}) {

    return GestureDetector(
      onTapDown: (details) => toggleExtraButtons(),
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
            child: Icon(showExtraButtons ? Icons.arrow_downward_rounded: Icons.arrow_upward_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}