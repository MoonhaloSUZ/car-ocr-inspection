import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';
import '../providers/inspection_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../utils/theme.dart';
import 'inspection_form_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;
  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _State();
}

class _State extends State<InspectionDetailScreen> {
  final _db = DatabaseService();
  InspectionRecord? _record;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rec = await _db.getInspection(widget.inspectionId);
    if (mounted)
      setState(() {
        _record = rec;
        _loading = false;
      });
  }

  Future<void> _export() async {
    if (_record == null) return;
    setState(() => _exporting = true);
    try {
      await ExportService().exportPdf(_record!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('PDF 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('점검 상세')),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_record == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('점검 상세')),
          body: const Center(child: Text('기록을 찾을 수 없습니다')));
    }

    final rec = _record!;
    final df = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');

    return Scaffold(
      appBar: AppBar(
        title: Text(rec.plateNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            InspectionFormScreen(inspectionId: rec.id)))
                .then((_) => _load()),
          ),
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF 내보내기',
                  onPressed: _export,
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 기본 정보
          _infoCard('기본 정보', [
            _row(
                '점검일자',
                rec.inspectionDate.isNotEmpty
                    ? rec.inspectionDate
                    : df.format(rec.createdAt)),
            _row('운전자 소속', rec.driverOrg),
            _row('성명', rec.driverName),
            _row('연락처', rec.driverContact),
          ]),
          const SizedBox(height: 10),

          // 차량 정보
          _infoCard('차량 정보', [
            _row('차량번호', rec.plateNo),
            _row('차종명', rec.vehicleType),
            _row('총중량', '${rec.grossWeight} 톤'),
            _row('축수', '${rec.axleCount} 축'),
            _row('최대적재량', '${rec.maxLoad} 톤'),
          ]),
          const SizedBox(height: 10),

          // 장비 정보
          _infoCard('장비 정보', [
            _row('모뎀번호', rec.modemNo),
            _row('센서ID', rec.sensorId),
            _row('카메라ID', rec.cameraId),
          ]),
          const SizedBox(height: 10),

          // 장착사진
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('장착사진',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor)),
                    const Spacer(),
                    Text('${rec.filledPhotoCount} / ${kPhotoSlots.length}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                  const Divider(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: kPhotoSlots.length,
                    itemBuilder: (ctx, i) {
                      final slot = kPhotoSlots[i];
                      final photoPath = rec.photos
                          .where((p) => p.slotKey == slot.key)
                          .map((p) => p.photoPath)
                          .firstOrNull;
                      return _PhotoTile(label: slot.label, path: photoPath);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor)),
              const Divider(height: 14),
              ...rows,
            ],
          ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(
              child: Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(fontSize: 13))),
        ]),
      );
}

class _PhotoTile extends StatelessWidget {
  final String label;
  final String? path;
  const _PhotoTile({required this.label, this.path});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = path != null && File(path!).existsSync();
    return GestureDetector(
      onTap: hasPhoto
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => _FullPhoto(path: path!, label: label)))
          : null,
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(
                  color: hasPhoto
                      ? AppTheme.primaryColor.withOpacity(0.4)
                      : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasPhoto
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(File(path!),
                        fit: BoxFit.cover, width: double.infinity))
                : Center(
                    child: Icon(Icons.photo_camera_outlined,
                        color: Colors.grey.shade300, size: 28)),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                color:
                    hasPhoto ? AppTheme.primaryColor : Colors.grey.shade500)),
      ]),
    );
  }
}

class _FullPhoto extends StatelessWidget {
  final String path;
  final String label;
  const _FullPhoto({required this.path, required this.label});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(label)),
        body: InteractiveViewer(
          child: Center(child: Image.file(File(path), fit: BoxFit.contain)),
        ),
      );
}
