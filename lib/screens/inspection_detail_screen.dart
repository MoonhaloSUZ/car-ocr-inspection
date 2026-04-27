import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../providers/template_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../utils/theme.dart';
import '../widgets/result_toggle.dart';
import 'inspection_form_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;
  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final _db = DatabaseService();
  Inspection? _inspection;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final insp = await _db.getInspection(widget.inspectionId);
    if (insp != null) {
      // 사진 경로를 현재 앱 Documents 절대경로로 변환
      for (final photo in insp.photos) {
        photo.photoPath =
            await DatabaseService.resolvePhotoPath(photo.photoPath);
      }
    }
    if (mounted)
      setState(() {
        _inspection = insp;
        _loading = false;
      });
  }

  void _showExportSheet() {
    final template = context.read<TemplateProvider>().categories;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('내보내기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('PDF로 내보내기'),
              subtitle: const Text('사진 포함, 공유 가능한 문서'),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _exporting = true);
                try {
                  await ExportService().exportPdf(_inspection!, template);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF 내보내기 실패: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _exporting = false);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Excel로 내보내기'),
              subtitle: const Text('데이터 분석용 스프레드시트'),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _exporting = true);
                try {
                  await ExportService().exportExcel(_inspection!, template);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Excel 내보내기 실패: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _exporting = false);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('점검 상세')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_inspection == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('점검 상세')),
        body: const Center(child: Text('점검 기록을 찾을 수 없습니다')),
      );
    }

    final insp = _inspection!;
    final template = context.watch<TemplateProvider>().categories;
    final df = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');
    final resultMap = {for (final r in insp.results) r.itemId: r};
    final photoMap = <String, List<InspectionPhoto>>{};
    for (final p in insp.photos) {
      if (p.itemId != null) {
        photoMap.putIfAbsent(p.itemId!, () => []).add(p);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(insp.location),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: '수정',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InspectionFormScreen(inspectionId: insp.id),
                ),
              ).then((_) => _load()),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: '내보내기',
              onPressed: _showExportSheet,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(Icons.location_on, '점검 장소', insp.location),
                  const SizedBox(height: 6),
                  _InfoRow(
                      Icons.calendar_today, '점검 일시', df.format(insp.createdAt)),
                  if (insp.inspector.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(Icons.person, '점검자', insp.inspector),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('점검 결과 요약',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem('전체', insp.totalItems, Colors.grey.shade600),
                      _SummaryItem('Y (양호)', insp.yCount, AppTheme.yColor),
                      _SummaryItem('N (불량)', insp.nCount, AppTheme.nColor),
                      _SummaryItem('NA', insp.naCount, AppTheme.naColor),
                      if (insp.unchecked > 0)
                        _SummaryItem('미점검', insp.unchecked, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: insp.completionRate,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        insp.completionRate == 1.0
                            ? AppTheme.yColor
                            : AppTheme.primaryColor,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '완료율 ${(insp.completionRate * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Checklist results by category
          ...template.map((cat) {
            final catItems = cat.items;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.07),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          cat.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        Text(
                          '${catItems.where((i) => resultMap[i.id]?.result != null).length} / ${catItems.length}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  ...catItems.asMap().entries.map((e) {
                    final idx = e.key;
                    final item = e.value;
                    final result = resultMap[item.id];
                    final itemPhotos = photoMap[item.id] ?? [];

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: idx < catItems.length - 1
                              ? BorderSide(color: Colors.grey.shade100)
                              : BorderSide.none,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(item.title,
                                      style: const TextStyle(fontSize: 14)),
                                ),
                                const SizedBox(width: 8),
                                ResultBadge(result: result?.result),
                              ],
                            ),
                            if (result?.note != null &&
                                result!.note!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes,
                                        size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        result.note!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (itemPhotos.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _PhotoRow(photos: itemPhotos),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Overall note
          if (insp.overallNote != null && insp.overallNote!.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('종합 의견',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(insp.overallNote!,
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryItem(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<InspectionPhoto> photos;
  const _PhotoRow({required this.photos});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: photos.map((p) {
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _PhotoViewer(imagePath: p.photoPath),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(p.photoPath),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final String imagePath;
  const _PhotoViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar:
          AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(imagePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
