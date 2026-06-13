import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/xrex_catalog_session.dart';
import '../screens/xrex_import_screen.dart';
import '../widgets/photo_picker_zone.dart';

class XRexHomeScreen extends StatefulWidget {
  const XRexHomeScreen({super.key});

  @override
  State<XRexHomeScreen> createState() => _XRexHomeScreenState();
}

class _XRexHomeScreenState extends State<XRexHomeScreen> {
  static const List<String> businessTypes = [
    'Aktar',
    'Gözlükçü',
    'Butik',
    'Nalbur',
    'Kozmetikçi',
    'Oyuncakçı',
    'Manav',
    'Şarküteri',
    'Kuruyemişçi',
    'Kırtasiye',
    'Telefon aksesuarcısı',
    'Pet shop',
    'Hediyelik eşya',
    'Çiçekçi',
    'Ayakkabıcı',
    'Takı / bijuteri',
    'Ev tekstili',
    'Züccaciye',
    'Hırdavat',
    'Oto aksesuar',
    'Spor ürünleri',
    'Bebek / çocuk ürünleri',
    'Kitap / sahaf',
    'Pastane / unlu mamuller',
    'Yerel üretici',
    'Diğer',
  ];

  String selectedBusinessType = businessTypes.first;
  Uint8List? selectedImageBytes;
  bool isPicking = false;

  Future<void> _pickImage() async {
    if (isPicking) return;
    setState(() => isPicking = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      final bytes = result?.files.single.bytes;
      if (!mounted) return;
      if (bytes == null) {
        setState(() => isPicking = false);
        return;
      }

      setState(() {
        selectedImageBytes = bytes;
        isPicking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => isPicking = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçilemedi: $error')));
    }
  }

  void _startImport() {
    final imageBytes = selectedImageBytes;
    if (imageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce bir fotoğraf seçin.')));
      return;
    }

    final session = XRexCatalogSession(
      sessionId: DateTime.now().microsecondsSinceEpoch.toString(),
      businessType: selectedBusinessType,
      selectedImageBytes: imageBytes,
      products: const [],
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => XRexImportScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child:
                      isWide
                          ? Row(
                            children: [
                              Expanded(
                                child: _HeroPanel(onStart: _startImport),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: _setupPanel()),
                            ],
                          )
                          : ListView(
                            children: [
                              _HeroPanel(onStart: _startImport),
                              const SizedBox(height: 18),
                              _setupPanel(),
                            ],
                          ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _setupPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1728),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF1F2A3D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'İşletme türünü seçin',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                businessTypes.map((type) {
                  final selected = type == selectedBusinessType;
                  return ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => selectedBusinessType = type);
                    },
                    selectedColor: const Color(0xFF06B6D4),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF04111D) : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 18),
          PhotoPickerZone(
            onPick: _pickImage,
            hasImage: selectedImageBytes != null,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPicking ? null : _startImport,
              icon:
                  isPicking
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Taslak paneline geç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final VoidCallback onStart;

  const _HeroPanel({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101A2E), Color(0xFF0B1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF263349)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF04111D),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'X-rex',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Fotoğraftan katalog taslağı oluştur.',
            style: TextStyle(
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Raf, reyon, çoklu ürün fotoğrafı veya e-ticaret ekran görüntüsünü referans alın. Ürünleri manuel girin, son ekranda temiz JSON çıktısı alın.',
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _RuleChip(label: 'API yok'),
              _RuleChip(label: 'Backend yok'),
              _RuleChip(label: 'OCR yok'),
              _RuleChip(label: 'Tamamen yerel'),
            ],
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Başla'),
          ),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;

  const _RuleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: const Color(0xFF263349)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
