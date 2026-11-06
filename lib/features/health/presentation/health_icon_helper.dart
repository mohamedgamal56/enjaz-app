import 'package:flutter/material.dart';

class HealthIconHelper {
  static IconData getKindIcon(String kind) {
    switch (kind) {
      case 'checkup':
        return Icons.health_and_safety_rounded;
      case 'test':
        return Icons.biotech_rounded;
      case 'specialist':
        return Icons.medical_services_rounded;
      case 'dental':
        return Icons.clean_hands_rounded;
      case 'vaccination':
        return Icons.vaccines_rounded;
      case 'other':
      default:
        return Icons.healing_rounded;
    }
  }

  static String getKindLabel(String kind, bool isArabic) {
    switch (kind) {
      case 'checkup':
        return isArabic ? 'فحص شامل' : 'Checkup';
      case 'test':
        return isArabic ? 'تحليل معملي' : 'Lab Test';
      case 'specialist':
        return isArabic ? 'كشف طبيب' : 'Specialist';
      case 'dental':
        return isArabic ? 'أسنان' : 'Dental';
      case 'vaccination':
        return isArabic ? 'تطعيم' : 'Vaccine';
      case 'other':
      default:
        return isArabic ? 'أخرى' : 'Other';
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'needed':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'postponed':
        return Colors.amber.shade700;
      case 'done':
        return Colors.green;
      case 'skipped':
      default:
        return Colors.grey;
    }
  }

  static String getStatusLabel(String status, bool isArabic) {
    switch (status) {
      case 'needed':
        return isArabic ? 'مطلوب' : 'Needed';
      case 'scheduled':
        return isArabic ? 'مجدول' : 'Scheduled';
      case 'postponed':
        return isArabic ? 'مؤجل' : 'Postponed';
      case 'done':
        return isArabic ? 'تم الإنجاز' : 'Done';
      case 'skipped':
        return isArabic ? 'تم التخطي' : 'Skipped';
      default:
        return status;
    }
  }

  static String getAdherenceLabel(String adherence, bool isArabic) {
    switch (adherence) {
      case 'not_started':
        return isArabic ? 'لم أبدأ' : 'Not Started';
      case 'following':
        return isArabic ? 'ملتزم' : 'Following';
      case 'stopped':
        return isArabic ? 'متوقف' : 'Stopped';
      case 'completed':
        return isArabic ? 'اكتمل' : 'Completed';
      default:
        return adherence;
    }
  }

  static Color getAdherenceColor(String adherence) {
    switch (adherence) {
      case 'not_started':
        return Colors.grey;
      case 'following':
        return Colors.green;
      case 'stopped':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
