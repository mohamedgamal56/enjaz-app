class SeedReason {
  final String labelAr;
  final String labelEn;
  final String category; // 'postpone' | 'waiting' | 'stopped' | 'partial' | 'any'

  const SeedReason({
    required this.labelAr,
    required this.labelEn,
    required this.category,
  });
}

const List<SeedReason> initialSeedReasons = [
  SeedReason(
    labelAr: 'مفيش فلوس',
    labelEn: 'No money',
    category: 'any',
  ),
  SeedReason(
    labelAr: 'مستني حد',
    labelEn: 'Waiting for someone',
    category: 'waiting',
  ),
  SeedReason(
    labelAr: 'مفيش وقت',
    labelEn: 'No time',
    category: 'postpone',
  ),
  SeedReason(
    labelAr: 'مفيش طاقة أو مود',
    labelEn: 'No energy',
    category: 'partial',
  ),
  SeedReason(
    labelAr: 'ظرف طارئ',
    labelEn: 'Emergency',
    category: 'any',
  ),
  SeedReason(
    labelAr: 'محتاج معدات',
    labelEn: 'Need equipment',
    category: 'stopped',
  ),
  SeedReason(
    labelAr: 'مستني رد العميل',
    labelEn: 'Waiting for client',
    category: 'waiting',
  ),
  SeedReason(
    labelAr: 'الطقس',
    labelEn: 'Weather',
    category: 'postpone',
  ),
  SeedReason(
    labelAr: 'ظهرت أولوية أهم',
    labelEn: 'Higher priority came up',
    category: 'postpone',
  ),
  SeedReason(
    labelAr: 'محتاج معلومات',
    labelEn: 'Need information',
    category: 'waiting',
  ),
];
