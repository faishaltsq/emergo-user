import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';
import 'package:emergo/models/emergency_event.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample emergency history data
    final List<EmergencyEvent> emergencies = [
      EmergencyEvent(
        id: 1,
        type: EmergencyType.medical,
        dateTime: DateTime(2024, 1, 15, 14, 30),
        status: EmergencyStatus.handled,
      ),
      EmergencyEvent(
        id: 2,
        type: EmergencyType.fire,
        dateTime: DateTime(2024, 1, 10, 9, 15),
        status: EmergencyStatus.handled,
      ),
      EmergencyEvent(
        id: 3,
        type: EmergencyType.crime,
        dateTime: DateTime(2024, 1, 5, 22, 45),
        status: EmergencyStatus.pending,
      ),
    ];
    
    return Scaffold(
      appBar: const AppBarWidget(title: 'Emergency History'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: emergencies.length,
          itemBuilder: (context, index) {
            final emergency = emergencies[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getEmergencyColor(emergency.type).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        emergency.icon,
                        color: _getEmergencyColor(emergency.type),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${emergency.typeName} Emergency',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatDate(emergency.dateTime)} at ${_formatTime(emergency.dateTime)}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(context, emergency.status),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Color _getEmergencyColor(EmergencyType type) {
    switch (type) {
      case EmergencyType.medical:
        return Colors.red;
      case EmergencyType.fire:
        return Colors.orange;
      case EmergencyType.crime:
        return Colors.blue;
      case EmergencyType.disaster:
        return Colors.amber;
    }
  }
  
  Widget _buildStatusBadge(BuildContext context, EmergencyStatus status) {
    final isHandled = status == EmergencyStatus.handled;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHandled ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHandled ? Icons.check_circle : Icons.error,
            size: 14,
            color: isHandled ? Colors.green.shade800 : Colors.amber.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            isHandled ? 'handled' : 'pending',
            style: TextStyle(
              fontSize: 12,
              color: isHandled ? Colors.green.shade800 : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
  
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}