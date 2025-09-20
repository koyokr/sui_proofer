import 'package:flutter/material.dart';

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isActive;
  final bool isWide;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.isActive,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: isWide ? _buildWideLayout() : _buildCompactLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildIconContainer(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(16, FontWeight.bold),
              const SizedBox(height: 4),
              _buildDescription(13, 0.8),
            ],
          ),
        ),
        if (isActive) _buildActiveIndicator(8),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIconContainer(isCompact: true),
            const Spacer(),
            if (isActive) _buildActiveIndicator(6),
          ],
        ),
        const SizedBox(height: 12),
        _buildTitle(14, FontWeight.bold),
        const SizedBox(height: 4),
        _buildDescription(12, 0.7, maxLines: 2),
      ],
    );
  }

  Widget _buildIconContainer({bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(isCompact ? 8 : 10),
      ),
      child: Icon(
        icon,
        color: color,
        size: isCompact ? 20 : 24,
      ),
    );
  }

  Widget _buildTitle(double fontSize, FontWeight fontWeight) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    );
  }

  Widget _buildDescription(double fontSize, double alpha, {int? maxLines}) {
    return Text(
      description,
      style: TextStyle(
        color: Colors.white.withValues(alpha: alpha),
        fontSize: fontSize,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }

  Widget _buildActiveIndicator(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: size * 0.75,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}