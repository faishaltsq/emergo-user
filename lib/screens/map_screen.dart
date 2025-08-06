import 'package:flutter/material.dart';
import 'package:emergo/widgets/app_bar_widget.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Nearby Facilities'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _filterChip(context, label: 'All', selected: true),
                  _filterChip(context, label: 'Hospital'),
                  _filterChip(context, label: 'Police'),
                  _filterChip(context, label: 'Fire Station'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Map placeholder
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.map,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Interactive Map',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      'Showing nearby emergency facilities',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Direction button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('Get Directions to Nearest Hospital'),
                onPressed: () {},
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Facility list
            Expanded(
              flex: 3,
              child: ListView(
                children: const [
                  FacilityCard(
                    name: 'City General Hospital',
                    type: 'Hospital',
                    distance: '0.8 km',
                  ),
                  SizedBox(height: 8),
                  FacilityCard(
                    name: 'Downtown Police Station',
                    type: 'Police',
                    distance: '1.2 km',
                  ),
                  SizedBox(height: 8),
                  FacilityCard(
                    name: 'Fire Station #3',
                    type: 'Fire',
                    distance: '1.5 km',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _filterChip(BuildContext context, {required String label, bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          children: [
            const Icon(Icons.filter_list, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {},
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).primaryColor : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class FacilityCard extends StatelessWidget {
  final String name;
  final String type;
  final String distance;
  
  const FacilityCard({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    type,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  distance,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: const Text('Route'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}