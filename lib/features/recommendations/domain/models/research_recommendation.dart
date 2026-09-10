import 'package:flutter/foundation.dart';

/// Categories for research-oriented biomechanical recommendations.
enum RecommendationCategory {
  movement('Movement & Repetition'),
  jointMotion('Joint Kinematics'),
  force('Thumb Contact Force'),
  motionIntensity('Motion Intensity'),
  general('Session Loading Structure');

  const RecommendationCategory(this.displayName);

  final String displayName;
}

/// Priority classification for research-oriented recommendations.
enum RecommendationPriority {
  informational('Informational', 0),
  moderate('Moderate Attention', 1),
  elevated('Elevated Priority', 2);

  const RecommendationPriority(this.displayName, this.rank);

  final String displayName;
  final int rank;
}

/// Immutable domain model representing a research-oriented ergonomic recommendation
/// derived from measured biomechanical telemetry.
///
/// **Non-Diagnostic Notice**:
/// Recommendations are engineering observations and ergonomic suggestions based on
/// measured prototype telemetry. They do NOT provide clinical diagnoses, medical advice,
/// or injury risk assessments.
@immutable
class ResearchRecommendation {
  ResearchRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.evidence,
    this.metricValue,
    this.referenceValue,
    this.unit,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.utc(2026, 9, 10);

  final String id;
  final String title;
  final String description;
  final RecommendationCategory category;
  final RecommendationPriority priority;
  final String evidence;
  final double? metricValue;
  final double? referenceValue;
  final String? unit;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'priority': priority.name,
        'evidence': evidence,
        'metricValue': metricValue,
        'referenceValue': referenceValue,
        'unit': unit,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory ResearchRecommendation.fromJson(Map<String, dynamic> json) {
    return ResearchRecommendation(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: RecommendationCategory.values.byName(json['category'] as String),
      priority: RecommendationPriority.values.byName(json['priority'] as String),
      evidence: json['evidence'] as String,
      metricValue: (json['metricValue'] as num?)?.toDouble(),
      referenceValue: (json['referenceValue'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  ResearchRecommendation copyWith({
    String? id,
    String? title,
    String? description,
    RecommendationCategory? category,
    RecommendationPriority? priority,
    String? evidence,
    double? metricValue,
    double? referenceValue,
    String? unit,
    DateTime? generatedAt,
  }) {
    return ResearchRecommendation(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      evidence: evidence ?? this.evidence,
      metricValue: metricValue ?? this.metricValue,
      referenceValue: referenceValue ?? this.referenceValue,
      unit: unit ?? this.unit,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResearchRecommendation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          category == other.category &&
          priority == other.priority &&
          evidence == other.evidence &&
          metricValue == other.metricValue &&
          referenceValue == other.referenceValue &&
          unit == other.unit;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        category,
        priority,
        evidence,
        metricValue,
        referenceValue,
        unit,
      );

  @override
  String toString() =>
      'ResearchRecommendation(id: $id, title: $title, priority: ${priority.name}, category: ${category.name})';
}

/// Configuration reference baselines used to trigger research recommendations.
@immutable
class RecommendationConfig {
  RecommendationConfig({
    this.refMovementsPerMinute = 30.0,
    this.refPercentageTimeMoving = 40.0,
    this.refPeakForce = 8.0,
    this.refForceExceedancePercentage = 20.0,
    this.refPeakAngularVelocity = 120.0,
    this.refAngularVelocityExceedancePercentage = 20.0,
    this.refIpExcursion = 60.0,
    this.refMcpExcursion = 50.0,
  }) {
    if (refMovementsPerMinute <= 0) {
      throw ArgumentError('refMovementsPerMinute must be positive');
    }
    if (refPercentageTimeMoving <= 0 || refPercentageTimeMoving > 100) {
      throw ArgumentError('refPercentageTimeMoving must be in (0, 100]');
    }
    if (refPeakForce <= 0) {
      throw ArgumentError('refPeakForce must be positive');
    }
    if (refForceExceedancePercentage <= 0 || refForceExceedancePercentage > 100) {
      throw ArgumentError('refForceExceedancePercentage must be in (0, 100]');
    }
    if (refPeakAngularVelocity <= 0) {
      throw ArgumentError('refPeakAngularVelocity must be positive');
    }
    if (refAngularVelocityExceedancePercentage <= 0 || refAngularVelocityExceedancePercentage > 100) {
      throw ArgumentError('refAngularVelocityExceedancePercentage must be in (0, 100]');
    }
    if (refIpExcursion <= 0) {
      throw ArgumentError('refIpExcursion must be positive');
    }
    if (refMcpExcursion <= 0) {
      throw ArgumentError('refMcpExcursion must be positive');
    }
  }

  final double refMovementsPerMinute;
  final double refPercentageTimeMoving;
  final double refPeakForce;
  final double refForceExceedancePercentage;
  final double refPeakAngularVelocity;
  final double refAngularVelocityExceedancePercentage;
  final double refIpExcursion;
  final double refMcpExcursion;

  Map<String, dynamic> toJson() => {
        'refMovementsPerMinute': refMovementsPerMinute,
        'refPercentageTimeMoving': refPercentageTimeMoving,
        'refPeakForce': refPeakForce,
        'refForceExceedancePercentage': refForceExceedancePercentage,
        'refPeakAngularVelocity': refPeakAngularVelocity,
        'refAngularVelocityExceedancePercentage': refAngularVelocityExceedancePercentage,
        'refIpExcursion': refIpExcursion,
        'refMcpExcursion': refMcpExcursion,
      };

  factory RecommendationConfig.fromJson(Map<String, dynamic> json) {
    return RecommendationConfig(
      refMovementsPerMinute: (json['refMovementsPerMinute'] as num).toDouble(),
      refPercentageTimeMoving: (json['refPercentageTimeMoving'] as num).toDouble(),
      refPeakForce: (json['refPeakForce'] as num).toDouble(),
      refForceExceedancePercentage: (json['refForceExceedancePercentage'] as num).toDouble(),
      refPeakAngularVelocity: (json['refPeakAngularVelocity'] as num).toDouble(),
      refAngularVelocityExceedancePercentage: (json['refAngularVelocityExceedancePercentage'] as num).toDouble(),
      refIpExcursion: (json['refIpExcursion'] as num).toDouble(),
      refMcpExcursion: (json['refMcpExcursion'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationConfig &&
          runtimeType == other.runtimeType &&
          refMovementsPerMinute == other.refMovementsPerMinute &&
          refPercentageTimeMoving == other.refPercentageTimeMoving &&
          refPeakForce == other.refPeakForce &&
          refForceExceedancePercentage == other.refForceExceedancePercentage &&
          refPeakAngularVelocity == other.refPeakAngularVelocity &&
          refAngularVelocityExceedancePercentage == other.refAngularVelocityExceedancePercentage &&
          refIpExcursion == other.refIpExcursion &&
          refMcpExcursion == other.refMcpExcursion;

  @override
  int get hashCode => Object.hash(
        refMovementsPerMinute,
        refPercentageTimeMoving,
        refPeakForce,
        refForceExceedancePercentage,
        refPeakAngularVelocity,
        refAngularVelocityExceedancePercentage,
        refIpExcursion,
        refMcpExcursion,
      );
}
