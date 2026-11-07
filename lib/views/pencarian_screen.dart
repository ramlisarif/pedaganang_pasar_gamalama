import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/pedagang_model.dart';
import '../services/pedagang_service.dart';
import 'map_rute_screen.dart';

extension StringCasingExtension on String {
  String toTitleCase() {
    if (isEmpty) return '';
    return split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }
}

class PencarianScreen extends StatefulWidget {
  const PencarianScreen({super.key});

  @override
  State<PencarianScreen> createState() => _PencarianScreenState();
}

class _PencarianScreenState extends State<PencarianScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PedagangService _service = PedagangService();

  bool _isLoading = true;
  Position? _userPosition;
  List<PedagangModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  String? _getImageAssetPath(String namePedagang) {
    final name = namePedagang.toLowerCase();

    if (name.contains('rempah')) {
      return 'assets/pedagang rempah barito.jpeg';
    } else if (name.contains('electronic') || name.contains('giga')) {
      return 'assets/gigacom.jpeg';
    } else if (name.contains('pakaian')) {
      return 'assets/pedagangpakaian.jpeg';
    } else if (name.contains('pertokoan') && name.contains('garuda')) {
      return 'assets/garudaelok.jpeg';
    } else if (name.contains('ruko sinar jaya')) {
      return 'assets/rukosinarjaya.jpeg';
    } else if (name.contains('depo mart')) {
      return 'assets/depomart.jpeg';
    } else if (name.contains('pertokoan') && name.contains('makmur')) {
      return 'assets/makmur.jpeg';
    } else if (name.contains('buah')) {
      return 'assets/pedagangbuah.jpeg';
    } else if (name.contains('sembako')) {
      return 'assets/pedagangsembako.jpeg';
    } else if (name.contains('ikan')) {
      return 'assets/pedagangikan.jpeg';
    }

    return null;
  }

  Future<void> _initData() async {
    _initGps();
    await _loadAllPedagang();
  }

  Future<void> _initGps() async {
    Position? pos = await _service.getCurrentLocation();
    if (mounted) {
      setState(() {
        _userPosition = pos;
      });
    }
  }

  Future<void> _loadAllPedagang() async {
    setState(() => _isLoading = true);
    List<PedagangModel> hasil = await _service.searchPedagang('');

    if (mounted) {
      setState(() {
        _searchResults = hasil;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSearch() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String query = _searchController.text;
    List<PedagangModel> hasil = await _service.searchPedagang(query);

    if (mounted) {
      setState(() {
        _searchResults = hasil;
        _isLoading = false;
      });
    }
  }

  void _onPedagangSelected(PedagangModel pedagang) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MapRuteScreen(pedagang: pedagang, userPosition: _userPosition),
      ),
    );
  }

  String _calculateDistance(double targetLat, double targetLng) {
    if (_userPosition == null) return '';
    double distanceInMeters = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      targetLat,
      targetLng,
    );
    if (distanceInMeters >= 1000) {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceInMeters.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Pencarian Pedagang',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header Input Pencarian
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleSearch(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama pedagang...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.teal.shade700,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _loadAllPedagang();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade900,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : const Icon(Icons.search_rounded, size: 20),
                    label: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Cari Pedagang',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Area Daftar Pedagang
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.teal.shade700,
                    ),
                  )
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final pedagang = _searchResults[index];
                      return _buildPedagangCard(pedagang);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Pedagang Tidak Ditemukan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coba ketik nama pedagang lainnya',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildPedagangCard(PedagangModel pedagang) {
    // Memastikan jika nama dari firebase kosong/null, tampilkan nama default
    final String displayName = pedagang.nama.trim().isNotEmpty
        ? pedagang.nama.toTitleCase()
        : 'Pedagang Tanpa Nama';

    final String? imagePath = _getImageAssetPath(displayName);
    final String jarakStr = _calculateDistance(
      pedagang.latitude,
      pedagang.longitude,
    );

    // Ambil deskripsi atau kategori jika ada di model
    final String deskripsiStr =
        pedagang.deskripsi ?? pedagang.kategori ?? 'Tidak ada deskripsi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onPedagangSelected(pedagang),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gambar Pedagang atau Placeholder Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imagePath != null
                      ? Image.asset(
                          imagePath,
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildFallbackIcon();
                          },
                        )
                      : _buildFallbackIcon(),
                ),
                const SizedBox(width: 14),

                // Area Nama + Deskripsi / Kategori
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Nama Pedagang
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Deskripsi / Kategori Pedagang
                      Text(
                        deskripsiStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Tombol Rute dan Jarak
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4EA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_outlined,
                        size: 20,
                        color: Colors.teal.shade700,
                      ),
                    ),
                    if (jarakStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        jarakStr,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 55,
      height: 55,
      color: Colors.teal.shade50,
      child: Icon(
        Icons.storefront_rounded,
        color: Colors.teal.shade700,
        size: 28,
      ),
    );
  }
}
