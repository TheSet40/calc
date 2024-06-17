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
  double minX = -10;
  double maxX = 10;

  double minY = -10;
  double maxY = 10;

  double intervall = 2;
  double previousScaleFactor = 1.0;

  Offset previousOffset = Offset.zero;


  List<List<FlSpot>> generateDataPoints() {
    List<List<FlSpot>> points = [[]];

    List<List<Model>> configs = [[]];

    final double accuracy = (maxX - minX) / 400; // number of points

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

    //print("config1: ${configs[0].map((item) => "\"${item.value ?? item.operation}\"")} config2: ${configs[1].map((item) => "\"${item.value ?? item.operation}\"")}");

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

  @override
  Widget build(BuildContext context) {

    final List<List<FlSpot>> datapoints = generateDataPoints();

    intervall = clampDouble((maxX - minX) / 8, 2, 1E300);

    // print("${pow(10, 1 * 5.823 + 1).toInt()}");

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

          if (newMaxX - newMinX > 0.5 && newMaxY - newMinY > 0.5) {
            minX = newMinX;
            maxX = newMaxX;
            minY = newMinY;
            maxY = newMaxY;
          }

          previousScaleFactor = details.scale;

          // paning
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
                interval: intervall,
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
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ),
        ),
      ),
    );
  }
}
