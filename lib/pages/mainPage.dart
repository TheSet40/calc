// ignore_for_file: file_names

import 'dart:math';

import 'package:calc/components/HistoryCache.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

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
  bool inverse = false;
  bool eyeComfort = false;

  void toggleExtraButtons() {
    setState(() {
      showExtraButtons = !showExtraButtons;
    });
  }

  String displayString(Model model) {
    if (model.value != "null" && model.value != null) {
      return model.isDecimal ? model.value.toString(): model.value.toString().replaceAll(".0", "");
    } else {
      return model.operation ?? "";
    }
  }

  double roundFloatError(double value) {
    return double.parse(value.toStringAsFixed(12));
  }

  double? getResult({bool shouldreset = true}) {
    if (config.isEmpty) {
      errorMessage = "";
      return null;
    }

    try {
      double result = calculateResult(config);

      if (shouldreset) {
        final List<Model> configCopy = List<Model>.from(config);
        final newItem = HistoryItem(models: configCopy, result: result.toString());
        HistoryCache.addToHistory(historyItem: newItem);
        history.add(newItem);

        config.clear();
        previewResult = null;
        final decimal = !result.toString().endsWith(".0");
        config.add(Model(value: result.toString(), isDecimal: decimal));
      }

      return result;
    } catch (e) {
      if (config.length > 1 && e.toString().contains(":")) {
        errorMessage = e.toString().split(":")[1];
      }
      debugPrint(e.toString());
    }

    return null;
  }

  double calculateResult(List<Model> models, {double xvalue = 0}) {
    List<dynamic> tokens = [];

    // Convert models to tokens
    for (int i = 0; i < models.length; i++) {
      Model m = models[i];

      if (m.value != null) {
        tokens.add(double.parse(m.value ?? "0.0"));
        if (i + 1 < models.length) {
          Model next = models[i + 1];
          // add implicit multiplication if next token is a number or function
          if (["X","π", "e", "E", "(", "√", "ln", "log", "log2", "sin", "cos", "tan", "sin⁻¹", "cos⁻¹", "tan⁻¹"].contains(next.operation)) {
            tokens.add('×');
          }
        }
      } else if (m.operation != null) {
        if (m.operation == "X") {
          tokens.add(xvalue);
          if (i + 1 < models.length) {
            Model next = models[i + 1];
            if (next.value != null || next.operation == "π" || next.operation == "e" || next.operation == "E") {
              tokens.add('×');
            }
          }
        } else if (m.operation == "π") {
          tokens.add(pi);
          if (i + 1 < models.length) {
            Model next = models[i + 1];
            if (next.value != null || next.operation == "π" || next.operation == "e" || next.operation == "E") {
              tokens.add('×');
            }
          }
        } else if (m.operation == "e") {
          tokens.add(e);
          if (i + 1 < models.length) {
            Model next = models[i + 1];
            if (next.value != null || next.operation == "π" || next.operation == "e" || next.operation == "E") {
              tokens.add('×');
            }
          }
        } else if (m.operation == "E") {
          tokens.addAll([10.0, "^"]);
        } else {
          tokens.add(m.operation);
          // add implicit multiplication if next token is a number or function
          if (m.operation == ")" && i + 1 < models.length) {
            Model next = models[i + 1];
            if (next.value != null || ["(", "√", "ln", "log", "log2", "sin", "cos", "tan", "sin⁻¹", "cos⁻¹", "tan⁻¹"].contains(next.operation)) {
              tokens.add('×');
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
        case '×':
          return left * right;
        case '÷':
          if (right == 0.0) throw Exception('Division by zero');
          return left / right;
        case '^':
          return pow(left, right) as double;
        case 'mod':
          return left % right;
        case '«':
          return (left.toInt() << right.toInt()).toDouble();
        case '»':
          return (left.toInt() >> right.toInt()).toDouble();
        default:
          throw Exception("Unsupported operation: $op");
      }
    }

    double factorial(double iterations) {
      double result = 1.0;

      for (int i = 2; i <= iterations; i++) {
        result *= i;
      }

      return result;
    }

    // Function to apply a unary operation
    double applyUnaryOperation(String op, double operand) {
      double result;
      switch (op) {
        case 'sin':
          result = sin(degrees ? (operand * pi / 180) : operand);
          break;
        case 'sin⁻¹':
          result = asin(degrees ? (operand * pi / 180) : operand);
          break;
        case 'cos':
          result = cos(degrees ? (operand * pi / 180) : operand);
          break;
        case 'cos⁻¹':
          result = acos(degrees ? (operand * pi / 180) : operand);
          break;
        case 'tan':
          result = tan(degrees ? (operand * pi / 180) : operand);
          break;
        case 'tan⁻¹':
          result = atan(degrees ? (operand * pi / 180) : operand);
          break;
        case 'log':
          result = log(operand) / ln10;
          break;
        case 'log2':
          result = log(operand) / ln2;
          break;
        case 'ln':
          result = log(operand);
          break;
        case '√':
          result = sqrt(operand);
          break;
        case '!':
          return factorial(operand);
        case '%':
          return operand * 0.01;
        default:
          throw Exception("Unsupported unary operation: $op");
      }

      return roundFloatError(result);
    }

    // Evaluate expression
    double evaluateExpression(List<dynamic> tokens) {
      // debugPrint("tokens $tokens");

      // Handle parentheses
      int openIndex;
      while ((openIndex = tokens.lastIndexOf('(')) != -1) {
        int closeIndex = tokens.indexOf(')', openIndex);
        double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex));
        tokens.replaceRange(openIndex, closeIndex + 1, [value]);
      }

      // Handle absolute value
      while ((openIndex = tokens.indexOf('|')) != -1) {
        int closeIndex = tokens.indexOf('|', openIndex + 1);
        if (closeIndex == -1) throw Exception("missing end '|'");
        double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex));
        tokens.replaceRange(openIndex, closeIndex + 1, [value.abs()]);
      }

      // Handle ending unary operations
      for (String op in ['!', '%']) {
        while (tokens.contains(op)) {
          int index = tokens.indexOf(op);
          double operand = tokens[index - 1];
          double result = applyUnaryOperation(op, operand);
          tokens.replaceRange(index - 1, index + 1, [result]);
        }
      }

      // Handle exponentiation
      for (String op in ["»", "«", "^"]) {
        while (tokens.contains(op)) {
          int index = tokens.indexOf(op);
          double left = tokens[index - 1];
          double right = tokens[index + 1];
          double result = applyOperation(op, left, right);
          tokens.replaceRange(index - 1, index + 2, [result]);
        }
      }

      // Handle starting unary operations
      for (String op in ['sin','sin⁻¹','cos','cos⁻¹','tan','tan⁻¹','log','log2','ln','√']) {
        while (tokens.contains(op)) {
          int index = tokens.indexOf(op);
          double operand = tokens[index + 1];
          double result = applyUnaryOperation(op, operand);
          tokens.replaceRange(index, index + 2, [result]);
        }
      }

      // Handle multiplication and division
      int multIndex;
      while ((multIndex = tokens.indexWhere((t) => t == '×' || t == '÷')) != -1) {
        double left = tokens[multIndex - 1];
        double right = tokens[multIndex + 1];
        double result = applyOperation(tokens[multIndex], left, right);
        tokens.replaceRange(multIndex - 1, multIndex + 2, [result]);
      }

      for (int j = 0; j < tokens.length; j++) {
        if (j != tokens.length - 1 && (j - 1 < 0 || tokens[j -1] == "-") && tokens[j] == "-" &&  tokens[j + 1].runtimeType == double) {
          tokens.replaceRange(j, j + 2, [double.parse(tokens[j].toString() + tokens[j + 1].toString())]);
        }
      }

      // debugPrint("input tokens for a & s $tokens");

      // Handle addition and subtraction
      while (tokens.length > 1) {
        double left = tokens[0];
        double right = tokens[2];
        double result = applyOperation(tokens[1], left, right);
        tokens.replaceRange(0, 3, [result]);
      }

      return roundFloatError(tokens[0]);
    }

    return roundFloatError(evaluateExpression(tokens));
  }

  List<FlSpot> generateDataPoints() {
    List<FlSpot> points = [];
    final start = DateTime.now();
    try {
      for (double x = -10; x <= 10; x += 0.075) {
        double y = calculateResult(config, xvalue: x);
        if (!y.isNaN) {
          points.add(FlSpot(x, y));
        }
      }
    } catch (e) {
      debugPrint("error $e");
    }

    final int mcdiff = start.difference(DateTime.now()).inMicroseconds * -1;

    debugPrint("results ${points.length} points ${mcdiff / 1E3}ms");
    return points;
  }

  void handleButtonPress(String buttonText, bool operator, Color color) {
    if (operator) {
      switch (buttonText) {
        case "C": 
          config.clear();
          Vibration.vibrate(
            duration: 400,
            pattern: [0, 150], // Pattern: [wait, vibrate, ...]
          );
          break;
        case "DEL":
          if (config.isNotEmpty) {
            if ((config.last.value ?? config.last.operation)!.length > 1) {
              config.last.value = config.last.value?.replaceRange(config.last.value!.length - 1, config.last.value!.length, "");
            } else {
              config.removeLast();
            }
            break;
          }
        case ".":
          config.last.isDecimal = true;
          config.last.value = "${config.last.value!}.0";
          break;
        case "=":
          setState(getResult);
          return;
        default:
          debugPrint("adding opperand: \"$buttonText\"");
          final addition = Model(operation: buttonText);
          config.add(addition);
      }
    } else {
      if (config.isNotEmpty && config.last.value != null) {
        if (!config.last.isDecimal) {
          final currentValue = config.last.value! + buttonText;
          config.last.value = currentValue;
        } else {
          final String currentValue = config.last.value!;
          final String finalValue = (currentValue.endsWith(".0") && buttonText != "0" ? currentValue.replaceAll(".0", "."): currentValue) + buttonText;
          config.last.value = finalValue;
        }
      } else {
        final addition = Model(value: buttonText);
        config.add(addition);
      }
    }

    setState(() {
      previewResult = getResult(shouldreset: false);
    });
  }

  @override
  void initState() {
    super.initState();
    gethistory();
  }

  Future<void> gethistory() async {
    history = await HistoryCache.loadHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {

    final List<FlSpot> datapoints = config.any((element) => element.operation == "X") ? generateDataPoints(): [];

    return Scaffold(
      key: _scaffoldKey,
      drawer: drawer(context),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.25,
              center: Alignment.topLeft,
              colors: [
                const Color(0xFF232937).withOpacity(0.95),
                const Color(0xFF232937)
              ]
            )
          ),
          child: Stack(children: [
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
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                      bottomRight: Radius.circular(25)
                    )
                  ),
                  child: Icon(
                    Icons.history,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ),
            // Positioned(
            //   top: 15,
            //   right: 10,
            //   child: GestureDetector(
            //     onTap: () {
            //       setState(() {
            //         eyeComfort = !eyeComfort;
            //       });
            //     },
            //     child: Container(
            //       padding: const EdgeInsets.all(6),
            //       decoration: const BoxDecoration(
            //         color: Color(0xFF5a6372),
            //         borderRadius: BorderRadius.all(Radius.circular(25))
            //       ),
            //       child: Icon(
            //         Icons.remove_red_eye_outlined,
            //         color: Colors.white.withOpacity(0.85),
            //       ),
            //     ),
            //   ),
            // ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: datapoints.isNotEmpty ? Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 15.0, 12.0, 0.0),
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: true),
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  reservedSize: 26,
                                  showTitles: true,
                                  interval: 2,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(0),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                                axisNameSize: 14,
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                  reservedSize: 0,
                                  showTitles: false,
                                ),
                                axisNameSize: 14,
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                  reservedSize: 0,
                                  showTitles: false,
                                ),
                                axisNameSize: 14,
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  reservedSize: 26,
                                  showTitles: true,
                                  interval: 2,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(0),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                                axisNameSize: 14,
                              ),
                            ),
                            borderData: FlBorderData(show: true, border: Border.all(color: Colors.white60)),
                            clipData: const FlClipData.all(),
                            minX: datapoints.reduce((a, b) => (a.y.abs() <= 10 && a.x < b.x) ? a : b).x,
                            maxX: 10,
                            minY: clampDouble(datapoints.reduce((a, b) => a.y < b.y && a.y >= -10 ? a : b).y - 2, -10, 10),
                            maxY: 10,
                            lineBarsData: [
                              LineChartBarData(
                                spots: datapoints,
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 2,
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(show: false),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      config.map((e) => displayString(e)).join(),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.8)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    alignment: Alignment.bottomLeft,
                    child: datapoints.isEmpty ? Text((previewResult ?? errorMessage).toString().replaceAll(RegExp(r"(\.0*|(?<=\.\d*)0+)$"), ""), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))): const SizedBox(),
                  ),
                  extraButtonsStrip(),
                  Container(
                    height: 286,
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 3),
                    alignment: Alignment.bottomCenter,
                    child: GridView.count(
                      childAspectRatio: 1.55,
                      crossAxisCount: 4,
                      children: [
                        normalButton("E", operator: true, color: leftOperand),
                        normalButton("%", operator: true, color: leftOperand),
                        normalButton("DEL", overload: "C", operator: true, color: leftOperand),
                        normalButton("÷", operator: true, color: rightOperand),
                        normalButton("7"),
                        normalButton("8"),
                        normalButton("9"),
                        normalButton("×", operator: true, color: rightOperand),
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
                        normalButton("X", operator: true, color: leftOperand),
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

  Widget normalButton(String buttonText, {bool operator = false, Color color = number, String? overload}) {
    return GestureDetector(
      onTap: () => handleButtonPress(buttonText, operator, color),
      onLongPress: () => handleButtonPress(overload ?? buttonText, operator, color),
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
          borderRadius: BorderRadius.circular(8)
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                extraFunctionButton("sin${inverse ? "⁻¹": ""}"),
                extraFunctionButton("cos${inverse ? "⁻¹": ""}"),
                extraFunctionButton("tan${inverse ? "⁻¹": ""}"),
                extraFunctionButton("π"),
                extraFunctionButton("e"),
                modeToggle(degrees ? "deg": "rad", () { 
                  degrees = !degrees;
                  previewResult = getResult(shouldreset: false);
                }),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                extraFunctionButton("mod"),
                extraFunctionButton("|x|"),
                extraFunctionButton(inverse ? "»" : "«"),
                extraFunctionButton("!"),
                extraFunctionButton("log2"),
                modeToggle("inv", () => inverse = !inverse)
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
          final Model addition = Model(operation: buttonText != "|x|" ? buttonText : "|");
          config.add(addition);
          if (!["e", "π", "(", ")", "|x|", "!", "«", "»"].contains(buttonText)) {
            config.add(Model(operation: "("));
          }
          setState(() {
            previewResult = getResult(shouldreset: false);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if(buttonText != "deg" && buttonText != "rad"){
                  final addition = Model(operation: buttonText != "|x|" ? buttonText : "|");
                  config.add(addition);
                  if (buttonText != "e" && buttonText != "π" && buttonText != "(" && buttonText != ")" && buttonText != "|x|" && buttonText != "!" && buttonText != "«" && buttonText != "»") {
                    config.add(Model(operation: "("));
                  }
                } else {
                  degrees = !degrees;
                }
                setState(() {
                  previewResult = getResult(shouldreset: false);
                });
              },
              child: Center(
                child: Text(buttonText, style: TextStyle(fontSize: 22, color: Colors.white.withOpacity(0.8))),
              ),
            ),
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
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.models.map((e) => displayString(e)).join(""), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.75))),
            Text(double.parse(item.result).toStringAsFixed(8).replaceAll(RegExp(r"(\.0*|(?<=\.\d*)0+)$"), ""), style: TextStyle(fontSize: 19, color: Colors.white.withOpacity(0.75))),
          ],
        )
      ),
    );
  }

  Widget modeToggle(String displayText, void Function() func) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(func),
        child: SizedBox(
          height: 42.5,
          child: Center(
            child: Text(displayText, style: const TextStyle(fontSize: 25, color: Color(0xFF75b6c7))),
          ),
        ),
      ),
    );
  }
}