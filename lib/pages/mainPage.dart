// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../components/ExpressionDisplay.dart';
import '../components/ExpressionParser.dart';
import '../components/HistoryCache.dart';
import '../components/graphViewer.dart';
import '../models/historyItem.dart';
import '../models/mathModel.dart';

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

  int cursorIndex = 0;

  double? previewResult;

  String errorMessage = "";

  bool showExtraButtons = false;

  bool isDegrees = true;
  bool inverse = false;

  bool vibrate = true;


  String displayString(Model model) {
    if (model.value != "null" && model.value != null) {
      return model.isDecimal ? model.value.toString(): model.value.toString().replaceAll(".0", "");
    } else {
      return model.operation ?? "";
    }
  }

    double? getResult({bool shouldreset = true}) {
    if (config.isEmpty) {
      errorMessage = "";
      return null;
    }

    try {
      double result = calculateResult(config, degrees: isDegrees);

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

  void handleButtonPress(String buttonText, bool operator, Color color) {
    if (operator) {
      switch (buttonText) {
        case "C":
          config.clear();
          if (vibrate) {
            Vibration.vibrate(
              pattern: [0, 150],
              intensities: [1, 1]
            );
          }
          cursorIndex = 0;
          break;
        case "DEL":
          if (config.isNotEmpty && cursorIndex > 0) {
            if (cursorIndex < config.length) {
              config.removeAt(cursorIndex - 1);
              cursorIndex--;
            } else {
              final lastValue = config.last.value;
              if (lastValue != null && lastValue.length > 1) {
                config.last.value = lastValue.substring(0, lastValue.length - 1);
              } else {
                config.removeLast();
                cursorIndex--;
              }
            }
          }
          break;
        case ".":
          if (cursorIndex <= config.length) {
            config[cursorIndex -1] = Model(value: "${config[cursorIndex -1].value}.", isDecimal: true);
          }
          break;
        case "=":
          setState(getResult);
          cursorIndex = 0;
          return;
        default:
          final addition = Model(operation: buttonText);
          config.insert(cursorIndex, addition);
          cursorIndex += buttonText.length;
      }
    } else {
      if (config.isNotEmpty && config[cursorIndex -1].value != null) {
        final currentValue = config[cursorIndex -1].value! + buttonText;
        config[cursorIndex -1].value = currentValue;
      } else {
        final addition = Model(value: buttonText);
        config.add(addition);
        cursorIndex++;
      }
    }

    setState(() {
      previewResult = getResult(shouldreset: false);
    });
  }

  void updateCursorPosition(int newPosition) {
    setState(() {
      cursorIndex = newPosition;
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

    print("selector index $cursorIndex config length ${config.length}  ${config.map((element) => element.value ?? element.operation)}");
    final bool includesX = config.any((element) => element.operation == "X");

    return Scaffold(
      key: _scaffoldKey,
      drawer: drawer(context),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.35,
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
            Positioned(
              top: 15,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    vibrate = !vibrate;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF5a6372),
                    borderRadius: BorderRadius.all(Radius.circular(25))
                  ),
                  child: Icon(Icons.vibration,
                    color: vibrate ? const Color.fromARGB(255, 48, 167, 52).withOpacity(0.95): const Color.fromARGB(255, 236, 36, 22).withOpacity(0.95),
                  ),
                ),
              ),
            ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0, right: 10.0),
                      child: includesX ? ZoomableLineChart(config: config, degrees: isDegrees): const SizedBox(),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.bottomLeft,
                    child: EditableTextWithCursor(config: config, onUpdateCursorPosition: updateCursorPosition),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                    alignment: Alignment.bottomLeft,
                    child: !includesX ? Text((previewResult ?? errorMessage).toString().replaceAll(RegExp(r"(\.0*|(?<=\.\d*)0+)$"), ""), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))): const SizedBox(),
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
                modeToggle(isDegrees ? "deg": "rad", () { 
                  isDegrees = !isDegrees;
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
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final Model addition = Model(operation: buttonText != "|x|" ? buttonText : "|");
              config.insert(cursorIndex, addition);
              if (!["e", "π", "(", ")", "|x|", "!", "«", "»"].contains(buttonText)) {
                config.insert(cursorIndex + 1, Model(operation: "("));
                cursorIndex++;
              }
              cursorIndex += buttonText.length;
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
        cursorIndex += item.result.length;
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
        onTap: () {
          if (vibrate) {
            Vibration.vibrate(
              pattern: [0, 150],
              intensities: [1, 1]
            );
          }
          setState(func);
        },
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