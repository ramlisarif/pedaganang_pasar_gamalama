import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/pedagang_model.dart';
import '../services/pedagang_service.dart';
import 'pencarian_screen.dart'; // Untuk extension toTitleCase()

class MapRuteScreen extends StatefulWidget {
  final PedagangModel pedagang;
  final Position? userPosition;

  const MapRuteScreen({super.key, required this.pedagang, this.userPosition});

  @override
  State<MapRuteScreen> createState() => _MapRuteScreenState();
}

class _MapRuteScreenState extends State<MapRuteScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final PedagangService _service = PedagangService();

  List<PedagangModel> _allPedagang = [];
  List<PedagangModel> _filteredPedagang = [];
  PedagangModel? _selectedPedagang;

  // Lokasi & Navigasi Real-time
  LatLng? _currentLiveLocation;
  double _currentHeading = 0.0; // Arah hadap kompas / pergerakan
  double _remainingDistance = 0.0; // Jarak tersisa (meter)
  StreamSubscription<Position>? _positionStreamSubscription;

  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  bool _isLoadingData = true;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _selectedPedagang = widget.pedagang;
    _searchController.text = widget.pedagang.nama;

    if (widget.userPosition != null) {
      _currentLiveLocation = LatLng(
        widget.userPosition!.latitude,
        widget.userPosition!.longitude,
      );
    }

    _loadDataAndRoute();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataAndRoute() async {
    setState(() => _isLoadingData = true);

    List<PedagangModel> list = await _service.searchPedagang('');

    if (mounted) {
      setState(() {
        _allPedagang = list;
        _filteredPedagang = list;
        _isLoadingData = false;
      });
    }

    _fetchRouteForSelected();
  }

  // Memulai Navigasi Real-Time Mengikuti Pergerakan Pengguna
  void _startLiveNavigation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() {
      _isNavigating = true;
    });

    // Pengaturan pelacakan GPS akurasi tinggi
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Memperbarui posisi setiap bergerak 2 meter
    );

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final newLatLng = LatLng(position.latitude, position.longitude);

          // Hitung jarak sisa dari lokasi terkini ke lokasi tujuan pedagang
          double distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _selectedPedagang!.latitude,
            _selectedPedagang!.longitude,
          );

          if (mounted) {
            setState(() {
              _currentLiveLocation = newLatLng;
              _currentHeading = position.heading;
              _remainingDistance = distance;
            });

            // 1. Geser kamera peta secara otomatis mengikuti lokasi pengguna terbaru
            _mapController.move(newLatLng, 17.5);

            // 2. Perbarui rute dari posisi berjalan pengguna ke pedagang
            _fetchRouteForSelected();

            // 3. Deteksi otomatis jika pengguna telah SAMPAI DI TUJUAN (jarak <= 10 meter)
            if (distance <= 10.0) {
              _onArrivedAtDestination();
            }
          }
        });

    if (_currentLiveLocation != null) {
      _mapController.move(_currentLiveLocation!, 17.5);
    }
  }

  // Aksi ketika pengguna sudah sampai di tujuan
  void _onArrivedAtDestination() {
    _stopLiveNavigation();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Sampai di Tujuan!'),
          ],
        ),
        content: Text(
          'Anda telah berada di lokasi ${_selectedPedagang?.nama ?? "pedagang"}.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _stopLiveNavigation() {
    _positionStreamSubscription?.cancel();
    setState(() {
      _isNavigating = false;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPedagang = _allPedagang;
      } else {
        _filteredPedagang = _allPedagang
            .where((p) => p.nama.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectPedagang(PedagangModel pedagang) {
    setState(() {
      _selectedPedagang = pedagang;
      _searchController.text = pedagang.nama;
    });

    if (!_isNavigating) {
      _mapController.move(LatLng(pedagang.latitude, pedagang.longitude), 15.5);
    }

    _fetchRouteForSelected();
  }

  Future<void> _fetchRouteForSelected() async {
    if (_currentLiveLocation == null || _selectedPedagang == null) return;

    final startLat = _currentLiveLocation!.latitude;
    final startLng = _currentLiveLocation!.longitude;
    final endLat = _selectedPedagang!.latitude;
    final endLng = _selectedPedagang!.longitude;

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates =
              data['routes'][0]['geometry']['coordinates'] as List;

          List<LatLng> points = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _isLoadingRoute = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error mengambil rute: $e');
    }

    if (mounted) {
      setState(() {
        _routePoints = [LatLng(startLat, startLng), LatLng(endLat, endLng)];
        _isLoadingRoute = false;
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    final centerLatLng =
        _currentLiveLocation ??
        (_selectedPedagang != null
            ? LatLng(_selectedPedagang!.latitude, _selectedPedagang!.longitude)
            : const LatLng(0.7887, 127.3873));

    return Scaffold(
      body: Stack(
        children: [
          // -------------------------------------------------------------
          // 1. BASE MAP
          // -------------------------------------------------------------
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: centerLatLng, initialZoom: 15.5),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.rosma_info2',
              ),

              // Rute Jalan Raya
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: _isNavigating ? 6.5 : 5.0,
                      color: _isNavigating
                          ? Colors.blue.shade600
                          : Colors.blueAccent.shade700,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Markers Pedagang
                  ..._filteredPedagang.map((pedagang) {
                    final isSelected = pedagang.id == _selectedPedagang?.id;
                    return Marker(
                      point: LatLng(pedagang.latitude, pedagang.longitude),
                      width: isSelected ? 46 : 36,
                      height: isSelected ? 46 : 36,
                      child: GestureDetector(
                        onTap: () => _selectPedagang(pedagang),
                        child: Icon(
                          Icons.location_on,
                          color: isSelected
                              ? Colors.redAccent
                              : Colors.red.shade300,
                          size: isSelected ? 46 : 36,
                        ),
                      ),
                    );
                  }),

                  // Marker Lokasi Pengguna Real-Time (Memutar Sesuai Arah)
                  if (_currentLiveLocation != null)
                    Marker(
                      point: _currentLiveLocation!,
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: (_currentHeading * (3.141592653589793 / 180)),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blueAccent.shade700,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // -------------------------------------------------------------
          // 2. FLOATING SEARCH BAR
          // -------------------------------------------------------------
          if (!_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Cari Toko / Pasar...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      ),
                  ],
                ),
              ),
            ),

          // -------------------------------------------------------------
          // 3. FLOATING HASIL PENCARIAN CARD
          // -------------------------------------------------------------
          if (!_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.38,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil pencarian (${_filteredPedagang.length})',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: _isLoadingData
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _filteredPedagang.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Pedagang tidak ditemukan'),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _filteredPedagang.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                              itemBuilder: (context, index) {
                                final item = _filteredPedagang[index];
                                final isSelected =
                                    item.id == _selectedPedagang?.id;

                                return InkWell(
                                  onTap: () => _selectPedagang(item),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEFF6FF)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: Colors.red.shade600,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.nama.toTitleCase(),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E293B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                item.deskripsi ??
                                                    'Pasar Gamalama, Ternate',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

          // -------------------------------------------------------------
          // 4. FLOATING CARD NAVIGASI AKTIF (Info Jarak Sisa)
          // -------------------------------------------------------------
          if (_isNavigating)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,    
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade800,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Menuju ${_selectedPedagang?.nama ?? "Tujuan"}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sisa Jarak: ${_formatDistance(_remainingDistance)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // -------------------------------------------------------------
          // 5. TOMBOL MULAI / SELESAI NAVIGASI
          // -------------------------------------------------------------
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isNavigating
                    ? _stopLiveNavigation
                    : _startLiveNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNavigating
                      ? Colors.redAccent.shade700
                      : Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _isNavigating ? Icons.stop_rounded : Icons.navigation_rounded,
                  size: 24,
                ),
                label: Text(
                  _isNavigating
                      ? 'Selesai Navigasi'
                      : 'Mulai Navigasi ke ${_selectedPedagang?.nama ?? "Tujuan"}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
