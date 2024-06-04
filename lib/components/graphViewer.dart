// ignore_for_file: file_names

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


  List<FlSpot> generateDataPoints() {
    List<FlSpot> points = [];
    // final start = DateTime.now();

    final double accuracy = (maxX - minX) / 400 /* number of points */;
    // print("accuracy $accuracy");

    try {
      for (double x = minX; x <= maxX; x += accuracy) {
        double y = calculateResult(widget.config, degrees: widget.degrees, xvalue: x);
        if (!y.isNaN) {
          points.add(FlSpot(x, y));
        }
      }
    } catch (e) {
      debugPrint("error $e");
    }

    // final int mcdiff = start.difference(DateTime.now()).inMicroseconds * -1;

    //debugPrint("results ${points.length} points ${mcdiff / 1E3}ms");
    return points;
  }

  @override
  Widget build(BuildContext context) {

    final List<FlSpot> datapoints = generateDataPoints();

    intervall = clampDouble((maxX - minX) / 8, 2, 1E300);

    // print("interval $intervall");

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
    );
  }
}
