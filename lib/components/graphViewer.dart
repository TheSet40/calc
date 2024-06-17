// ignore_for_file: file_names

import 'dart:math';

import 'package:calc/models/mathModel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ExpressionParser.dart';

class ZoomableLineChart extends StatefulWidget {
  final List<Model> config;
  final bool degrees;

  const ZoomableLineChart({super.key, required this.config, required this.degrees});

  @override
  State<ZoomableLineChart> createState() => _ZoomableLineChartState();
}

class _ZoomableLineChartState extends State<ZoomableLineChart> {
  double minX = -10.0;
  double maxX = 10.0;

  double minY = -10.0;
  double maxY = 10.0;

  double intervall = 2.0;
  double previousScaleFactor = 1.0;

  Offset previousOffset = Offset.zero;

  List<List<FlSpot>> generateDataPoints(double accuracy) {
    List<List<FlSpot>> points = [[]];
    List<List<Model>> configs = [[]];

    int grapfIndex = 0;

    for (int i = 0; i < widget.config.length; i++) {
      if (widget.config[i].operation == ",") {
        points.add([]);
        configs.add([]);
        grapfIndex++;
      } else {
        configs[grapfIndex].add(widget.config[i]);
      }
    }

    try {
      for (int i = 0; i < configs.length; i ++) {
        points[i] = _calculatePoints(configs[i], accuracy);
      }
    } catch (e) {
      debugPrint("error $e");
    }

    return points;
  }

  List<FlSpot> _calculatePoints(List<Model> config, double accuracy) {
    List<FlSpot> subPoints = [];
    for (double x = minX; x <= maxX; x += accuracy) {
      double y = calculateResult(config, degrees: widget.degrees, xvalue: x);
      if (!y.isNaN) {
        subPoints.add(FlSpot(x, y));
      }
    }
    return subPoints;
  }

  Color colorFromNumber(double number) {
    double hue = number % 360;

    double saturation = 0.95;
    double lightness = 0.575;

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  List<FlSpot> findIntersections(List<List<FlSpot>> datapoints) {
    if (datapoints.length < 2 || datapoints[0].isEmpty || datapoints[1].isEmpty) return [];

    List<FlSpot> intersections = [];
    // final DateTime start = DateTime.now();

    for (int i = 0; i < datapoints.length; i++) {
      for (int j = i + 1; j < datapoints.length; j++) {
        List<FlSpot> line1 = datapoints[i];
        List<FlSpot> line2 = datapoints[j];
        for (int k = 0; k < line1.length - 1; k++) {
          for (int l = 0; l < line2.length - 1; l++) {
            FlSpot? intersection = getIntersection(line1[k], line1[k + 1], line2[l], line2[l + 1]);
            if (intersection != null) {
              intersections.add(intersection);
            }
          }
        }
      }
    }

    // print("intersection time = ${DateTime.now().difference(start).inMilliseconds} ms");

    return intersections;
  }

  FlSpot? getIntersection(FlSpot p1, FlSpot p2, FlSpot q1, FlSpot q2) {
    double a1 = p2.y - p1.y;
    double b1 = p1.x - p2.x;
    double c1 = a1 * p1.x + b1 * p1.y;

    double a2 = q2.y - q1.y;
    double b2 = q1.x - q2.x;
    double c2 = a2 * q1.x + b2 * q1.y;

    double determinant = a1 * b2 - a2 * b1;

    if (determinant == 0) {
      return null;
    } else {
      double x = (b2 * c1 - b1 * c2) / determinant;
      double y = (a1 * c2 - a2 * c1) / determinant;

      if (isBetween(p1, p2, x, y) && isBetween(q1, q2, x, y)) {
        return FlSpot(x, y);
      } else {
        return null;
      }
    }
  }

  bool isBetween(FlSpot p1, FlSpot p2, double x, double y) {
    return (x >= min(p1.x, p2.x) && x <= max(p1.x, p2.x) && y >= min(p1.y, p2.y) && y <= max(p1.y, p2.y));
  }

  @override
  Widget build(BuildContext context) {

    final double accuracy = (maxX - minX) / 400;
    final double intersectaccuracy = accuracy / 2;

    final List<List<FlSpot>> datapoints = generateDataPoints(accuracy);
    final List<FlSpot> intersections = findIntersections(datapoints);

    intervall = clampDouble((maxX - minX) / 8, 0.005, 1E300);

    // print("accuracy = $accuracy");

    return GestureDetector(
      onScaleStart: (ScaleStartDetails details) {
        previousScaleFactor = 1.0;
        previousOffset = details.focalPoint;
      },
      onScaleUpdate: (ScaleUpdateDetails details) {
        setState(() {
          // Handle zoom
          double scaleChange = details.scale / previousScaleFactor;
          double newMinX = (minX + maxX) / 2 - (maxX - minX) / 2 / scaleChange;
          double newMaxX = (minX + maxX) / 2 + (maxX - minX) / 2 / scaleChange;
          double newMinY = (minY + maxY) / 2 - (maxY - minY) / 2 / scaleChange;
          double newMaxY = (minY + maxY) / 2 + (maxY - minY) / 2 / scaleChange;

          if (newMaxX - newMinX > 0.01 && newMaxY - newMinY > 0.01) {
            minX = newMinX;
            maxX = newMaxX;
            minY = newMinY;
            maxY = newMaxY;
          }

          previousScaleFactor = details.scale;

          // Panning
          double dx = (details.focalPoint.dx - previousOffset.dx) / context.size!.width * (maxX - minX);
          double dy = (previousOffset.dy - details.focalPoint.dy) / context.size!.height * (maxY - minY);

          minX -= dx;
          maxX -= dx;

          minY -= dy;
          maxY -= dy;

          previousOffset = details.focalPoint;
        });
      },
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                reservedSize: 26,
                showTitles: true,
                interval: intervall,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(accuracy > 0.025 ? 0: accuracy > 0.0025 ? 1: 2),
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
                interval: intervall,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(accuracy > 0.025 ? 0: accuracy < 0.0025 ? 2: 1),
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
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineBarsData: List.generate(datapoints.length, (index) => 
            LineChartBarData(
              spots: datapoints[index],
              isCurved: true,
              color: colorFromNumber(pow(6.823 + index, index * 2).toDouble()),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true, checkToShowDot: (spot, _) => intersections.any((intersection) => (intersection.x - spot.x).abs() <= intersectaccuracy && (intersection.y - spot.y).abs() <= intersectaccuracy)),
              belowBarData: BarAreaData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}
