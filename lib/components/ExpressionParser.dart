// ignore_for_file: file_names

import 'dart:math';

import '../models/mathModel.dart';

double roundFloatError(double value) {
  return double.parse(value.toStringAsFixed(12));
}

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

double applyUnaryOperation(String op, double operand, bool degrees) {
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
      throw Exception("Unsupported unary operation: \"$op\"");
  }

  return roundFloatError(result);
}

// Evaluate expression
double evaluateExpression(List<dynamic> tokens, bool degrees) {

  int openIndex;
  while ((openIndex = tokens.lastIndexOf('(')) != -1) {
    int closeIndex = tokens.indexOf(')', openIndex);
    double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex), degrees);
    tokens.replaceRange(openIndex, closeIndex + 1, [value]);
  }

  while ((openIndex = tokens.indexOf('|')) != -1) {
    int closeIndex = tokens.indexOf('|', openIndex + 1);
    if (closeIndex == -1) throw Exception("missing end '|'");
    double value = evaluateExpression(tokens.sublist(openIndex + 1, closeIndex), degrees);
    tokens.replaceRange(openIndex, closeIndex + 1, [value.abs()]);
  }

  for (String op in ['!', '%']) {
    while (tokens.contains(op)) {
      int index = tokens.indexOf(op);
      double operand = tokens[index - 1];
      double result = applyUnaryOperation(op, operand, degrees);
      tokens.replaceRange(index - 1, index + 1, [result]);
    }
  }

  for (String op in ["»", "«", "^"]) {
    while (tokens.contains(op)) {
      int index = tokens.indexOf(op);
      double left = tokens[index - 1];
      double right = tokens[index + 1];
      double result = applyOperation(op, left, right);
      tokens.replaceRange(index - 1, index + 2, [result]);
    }
  }

  for (String op in ['sin', 'sin⁻¹', 'cos', 'cos⁻¹', 'tan', 'tan⁻¹', 'log', 'log2', 'ln', '√']) {
    while (tokens.contains(op)) {
      int index = tokens.indexOf(op);
      double operand = tokens[index + 1];
      double result = applyUnaryOperation(op, operand, degrees);
      tokens.replaceRange(index, index + 2, [result]);
    }
  }

  int multIndex;
  while ((multIndex = tokens.indexWhere((t) => t == '×' || t == '÷')) != -1) {
    double left = tokens[multIndex - 1];
    double right = tokens[multIndex + 1];
    double result = applyOperation(tokens[multIndex], left, right);
    tokens.replaceRange(multIndex - 1, multIndex + 2, [result]);
  }

  for (int j = 0; j < tokens.length; j++) {
    if (j != tokens.length - 1 && (j - 1 < 0 || tokens[j -1] == "-") && tokens[j] == "-" && tokens[j + 1].runtimeType == double) {
      tokens.replaceRange(j, j + 2, [double.parse(tokens[j].toString() + tokens[j + 1].toString())]);
    } else if (j != tokens.length - 1 && (j - 1 < 0 || tokens[j -1].runtimeType != double) && tokens[j] == "+") {
      tokens.removeAt(j);
    }
  }

  while (tokens.length > 1) {
    double left = tokens[0];
    double right = tokens[2];
    double result = applyOperation(tokens[1], left, right);
    tokens.replaceRange(0, 3, [result]);
  }

  return roundFloatError(tokens[0]); // after all stages tokens[0] is the result
}

double calculateResult(List<Model> models, {bool degrees = true, double xvalue = 0}) {
  List<dynamic> tokens = [];

  // Convert models to tokens
  for (int i = 0; i < models.length; i++) {
    Model m = models[i];

    if (m.value != null) {
      tokens.add(double.parse(m.value ?? "0.0"));
      if (i + 1 < models.length) {
        Model next = models[i + 1];
        // add implicit multiplication if next token is a number or function
        if (["X", "π", "e", "E", "(", "√", "ln", "log", "log2", "sin", "cos", "tan", "sin⁻¹", "cos⁻¹", "tan⁻¹"].contains(next.operation)) {
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

  return roundFloatError(evaluateExpression(tokens, degrees));
}