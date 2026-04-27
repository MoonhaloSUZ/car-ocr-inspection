import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/inspection_record.dart';
import '../providers/inspection_provider.dart';
import '../utils/theme.dart';
import 'inspection_form_screen.dart';
import 'inspection_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가축분뇨 검증장비 정기점검표')),
      body: const _HomeBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('새 점검'),
      ),
    );
  }

  static void _openForm(BuildContext context, String? id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InspectionFormScreen(inspectionId: id)),
    ).then((saved) {
      if (saved == true && context.mounted) {
        context.read<InspectionProvider>().reload();
      }
    });
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.records.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.assignment_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('점검 기록이 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('하단 버튼으로 새 점검을 시작하세요',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: provider.records.length,
        itemBuilder: (ctx, i) => _RecordCard(record: provider.records[i]),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final InspectionRecord record;
  const _RecordCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd');
    final displayDate = record.inspectionDate.isNotEmpty
        ? record.inspectionDate
        : df.format(record.createdAt);

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
            color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('점검 삭제'),
          content: Text('${record.plateNo} 점검 기록을 삭제할까요?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
      onDismissed: (_) {
        if (context.mounted) {
          context.read<InspectionProvider>().delete(record.id);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    InspectionDetailScreen(inspectionId: record.id)),
          ).then((_) => context.read<InspectionProvider>().reload()),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 차량번호 (크게)
              Row(children: [
                const Icon(Icons.directions_car,
                    color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 6),
                Text(record.plateNo.isNotEmpty ? record.plateNo : '(차량번호 없음)',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                _photoChip(record.filledPhotoCount),
              ]),
              const SizedBox(height: 6),
              const Divider(height: 8),
              // 점검일자
              _infoRow(Icons.calendar_today, '점검일자', displayDate),
              const SizedBox(height: 3),
              // 관리번호
              _infoRow(Icons.tag, '관리번호',
                  record.mgmtNo.isNotEmpty ? record.mgmtNo : '-'),
              const SizedBox(height: 3),
              // 소속
              if (record.driverOrg.isNotEmpty)
                _infoRow(Icons.business, '소속', record.driverOrg),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text('$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]);

  Widget _photoChip(int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: count > 0
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: count > 0
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.photo_camera,
              size: 11, color: count > 0 ? AppTheme.primaryColor : Colors.grey),
          const SizedBox(width: 3),
          Text('$count/${kPhotoSlots.length}',
              style: TextStyle(
                  fontSize: 11,
                  color: count > 0 ? AppTheme.primaryColor : Colors.grey,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}
