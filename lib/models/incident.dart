class Incident {
  final int incidentId;
  final int incidentTypeId;
  final String incidentTypeName;
  final DateTime date;
  final int statusId;
  final double? latitude;
  final double? longitude;

  Incident({
    required this.incidentId,
    required this.incidentTypeId,
    required this.incidentTypeName,
    required this.date,
    required this.statusId,
    this.latitude,
    this.longitude,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    final incidentType = json['incident_type'] as Map<String, dynamic>?;
    return Incident(
      incidentId: (json['incidentid'] as num).toInt(),
      incidentTypeId: (json['incidenttypeid'] as num).toInt(),
      incidentTypeName: incidentType != null
          ? (incidentType['name'] as String? ?? 'Unknown')
          : 'Unknown',
      date: DateTime.parse(json['date'] as String),
      statusId: (json['statusid'] as num?)?.toInt() ?? 1,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
