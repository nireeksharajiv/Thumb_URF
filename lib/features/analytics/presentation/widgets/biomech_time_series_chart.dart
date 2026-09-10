import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/sensor_reading.dart';

enum BiomechChannel {
  ipAngle('IP Angle', '°', Color(0xFF0B5D5E)),
  mcpAngle('MCP Angle', '°', Color(0xFF1E88E5)),
  force('Contact Force', 'N', Color(0xFFE65100)),
  angularVelocity('Angular Velocity', '°/s', Color(0xFF6A1B9A)),
  motionMagnitude('Motion Magnitude', 'g', Color(0xFF2E7D32));

  const BiomechChannel(this.label, this.unit, this.color);
  final String label;
  final String unit;
  final Color color;
}

/// High-performance, zero-dependency time-series chart widget for biomechanical channels.
///
/// Implemented with a custom [CustomPainter] that smoothly handles:
/// - Empty readings datasets
/// - Single-point datasets
/// - Short & long sessions (downsampled for 60fps rendering)
/// - Responsive scaling with clear axis labels, gridlines, and units
class BiomechTimeSeriesChart extends StatefulWidget {
  const BiomechTimeSeriesChart({
    required this.readings,
    this.initialChannel = BiomechChannel.ipAngle,
    super.key,
  });

  final List<SensorReading> readings;
  final BiomechChannel initialChannel;

  @override
  State<BiomechTimeSeriesChart> createState() => _BiomechTimeSeriesChartState();
}

class _BiomechTimeSeriesChartState extends State<BiomechTimeSeriesChart> {
  late BiomechChannel _selectedChannel;

  @override
  void initState() {
    super.initState();
    _selectedChannel = widget.initialChannel;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.show_chart,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'TELEMETRY TIME-SERIES',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Channel Selector Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: BiomechChannel.values.map((channel) {
                  final isSelected = channel == _selectedChannel;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${channel.label} (${channel.unit})'),
                      selected: isSelected,
                      selectedColor: channel.color.withAlpha(40),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? channel.color : null,
                      ),
                      side: BorderSide(
                        color: isSelected ? channel.color : Colors.grey.shade300,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedChannel = channel);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Chart Canvas area
            SizedBox(
              height: 220,
              width: double.infinity,
              child: widget.readings.isEmpty
                  ? Center(
                      child: Text(
                        'No sensor samples recorded for this session',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : CustomPaint(
                      painter: _TimeSeriesPainter(
                        readings: widget.readings,
                        channel: _selectedChannel,
                        gridColor: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
                        textColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSeriesPainter extends CustomPainter {
  _TimeSeriesPainter({
    required this.readings,
    required this.channel,
    required this.gridColor,
    required this.textColor,
  });

  final List<SensorReading> readings;
  final BiomechChannel channel;
  final Color gridColor;
  final Color textColor;

  double _extractValue(SensorReading r) => switch (channel) {
        BiomechChannel.ipAngle => r.ipAngle,
        BiomechChannel.mcpAngle => r.mcpAngle,
        BiomechChannel.force => r.force,
        BiomechChannel.angularVelocity => r.angularVelocity.abs(),
        BiomechChannel.motionMagnitude => r.motionMagnitude,
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;

    const leftPadding = 48.0;
    const bottomPadding = 24.0;
    const topPadding = 12.0;
    const rightPadding = 16.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Extract values and time offsets in seconds
    final startTime = readings.first.timestamp;
    final points = <_DataPoint>[];

    // Decimate for performance if dataset is massive (> 400 points)
    final step = math.max(1, (readings.length / 400).ceil());
    for (var i = 0; i < readings.length; i += step) {
      final r = readings[i];
      final seconds = r.timestamp.difference(startTime).inMilliseconds / 1000.0;
      points.add(_DataPoint(seconds, _extractValue(r)));
    }
    // Always include the last reading for end-of-session fidelity
    if (step > 1 && readings.isNotEmpty) {
      final last = readings.last;
      final seconds = last.timestamp.difference(startTime).inMilliseconds / 1000.0;
      points.add(_DataPoint(seconds, _extractValue(last)));
    }

    // 2. Find extrema for scaling
    var minY = points.first.y;
    var maxY = points.first.y;
    var maxTime = points.last.x;

    for (final p in points) {
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (maxTime <= 0) maxTime = 1.0; // Avoid 0-duration division

    // Add 10% head/foot room on Y-axis for aesthetic padding
    var yRange = maxY - minY;
    if (yRange == 0) {
      // Single value or flat line
      yRange = math.max(1.0, maxY.abs() * 0.2);
      minY = math.max(0.0, minY - yRange / 2);
      maxY = maxY + yRange / 2;
    } else {
      final pad = yRange * 0.12;
      minY = math.max(0.0, minY - pad);
      maxY = maxY + pad;
      yRange = maxY - minY;
    }

    // 3. Draw gridlines and Y-axis labels
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: textColor,
      fontSize: 10,
      fontFamily: 'monospace',
    );

    // 4 horizontal gridlines (0%, 33%, 66%, 100%)
    for (var i = 0; i <= 3; i++) {
      final fraction = i / 3.0;
      final yPos = topPadding + chartHeight * (1.0 - fraction);
      canvas.drawLine(
        Offset(leftPadding, yPos),
        Offset(size.width - rightPadding, yPos),
        gridPaint,
      );

      final val = minY + fraction * yRange;
      final textSpan = TextSpan(
        text: '${val.toStringAsFixed(val >= 100 ? 0 : 1)}${channel.unit}',
        style: textStyle,
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, yPos - tp.height / 2));
    }

    // 4. Draw X-axis time labels (start, midpoint, end)
    final timeLabels = [0.0, maxTime / 2, maxTime];
    for (final t in timeLabels) {
      final xFraction = t / maxTime;
      final xPos = leftPadding + chartWidth * xFraction;

      final textSpan = TextSpan(
        text: '${t.toStringAsFixed(t >= 10 ? 0 : 1)}s',
        style: textStyle,
      );
      final tp = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xPos - tp.width / 2, size.height - bottomPadding + 6));
    }

    // 5. Draw data line and gradient fill
    final linePaint = Paint()
      ..color = channel.color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    double mapX(double x) => leftPadding + (x / maxTime) * chartWidth;
    double mapY(double y) => topPadding + chartHeight * (1.0 - (y - minY) / yRange);

    if (points.length == 1) {
      // Single-point data representation
      final center = Offset(mapX(points.first.x), mapY(points.first.y));
      final dotPaint = Paint()
        ..color = channel.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 5.0, dotPaint);

      // Draw horizontal reference line
      final refPaint = Paint()
        ..color = channel.color.withAlpha(120)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(leftPadding, center.dy),
        Offset(size.width - rightPadding, center.dy),
        refPaint,
      );
      return;
    }

    for (var i = 0; i < points.length; i++) {
      final pt = points[i];
      final px = mapX(pt.x);
      final py = mapY(pt.y);

      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, topPadding + chartHeight);
        fillPath.lineTo(px, py);
      } else {
        path.lineTo(px, py);
        fillPath.lineTo(px, py);
      }
    }

    fillPath.lineTo(mapX(points.last.x), topPadding + chartHeight);
    fillPath.close();

    // Subtle area gradient below curve
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        channel.color.withAlpha(60),
        channel.color.withAlpha(5),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TimeSeriesPainter oldDelegate) =>
      oldDelegate.channel != channel || oldDelegate.readings != readings;
}

class _DataPoint {
  const _DataPoint(this.x, this.y);
  final double x;
  final double y;
}
