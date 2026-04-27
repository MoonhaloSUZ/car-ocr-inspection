import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/inspection.dart';
import '../providers/inspection_provider.dart';
import '../utils/theme.dart';
import 'inspection_form_screen.dart';
import 'inspection_detail_screen.dart';
import 'template_editor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('현장 점검표'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rtl),
            tooltip: '점검표 편집',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TemplateEditorScreen()),
            ),
          ),
        ],
      ),
      body: const _HomeBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InspectionFormScreen(),
          ),
        ).then((_) => context.read<InspectionProvider>().reload()),
        icon: const Icon(Icons.add),
        label: const Text('새 점검'),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();

    return Column(
      children: [
        _FilterBar(filter: provider.filter, locations: provider.locations),
        Expanded(
          child: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : provider.inspections.isEmpty
                  ? _EmptyState(hasFilter: provider.filter.hasFilter)
                  : RefreshIndicator(
                      onRefresh: provider.reload,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: provider.inspections.length,
                        itemBuilder: (ctx, i) => _InspectionCard(
                          inspection: provider.inspections[i],
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final InspectionFilter filter;
  final List<String> locations;

  const _FilterBar({required this.filter, required this.locations});

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(filter: filter, locations: locations),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM/dd');
    final chips = <Widget>[];

    if (filter.location != null && filter.location!.isNotEmpty) {
      chips.add(_FilterChip(
        label: '📍 ${filter.location}',
        onRemove: () => context
            .read<InspectionProvider>()
            .applyFilter(filter.copyWith(clearLocation: true)),
      ));
    }
    if (filter.dateFrom != null || filter.dateTo != null) {
      final from =
          filter.dateFrom != null ? df.format(filter.dateFrom!) : '∞';
      final to = filter.dateTo != null ? df.format(filter.dateTo!) : '∞';
      chips.add(_FilterChip(
        label: '📅 $from ~ $to',
        onRemove: () => context
            .read<InspectionProvider>()
            .applyFilter(filter.copyWith(
              clearDateFrom: true,
              clearDateTo: true,
            )),
      ));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _showFilterSheet(context),
            icon: Icon(
              Icons.filter_list,
              size: 18,
              color: filter.hasFilter
                  ? AppTheme.primaryColor
                  : Colors.grey.shade600,
            ),
            label: Text(
              '필터',
              style: TextStyle(
                color: filter.hasFilter
                    ? AppTheme.primaryColor
                    : Colors.grey.shade600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: filter.hasFilter
                    ? AppTheme.primaryColor
                    : Colors.grey.shade300,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: chips
                      .expand((c) => [c, const SizedBox(width: 6)])
                      .toList(),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (filter.hasFilter)
            TextButton(
              onPressed: () =>
                  context.read<InspectionProvider>().clearFilter(),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('초기화',
                  style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.primaryColor)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 14, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Inspection inspection;

  const _InspectionCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');
    final completion = (inspection.completionRate * 100).toInt();

    return Dismissible(
      key: Key(inspection.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('점검 삭제'),
            content: Text('${inspection.location}의 점검 기록을 삭제할까요?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) =>
          context.read<InspectionProvider>().deleteInspection(inspection.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  InspectionDetailScreen(inspectionId: inspection.id),
            ),
          ).then((_) => context.read<InspectionProvider>().reload()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 16,
                                  color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  inspection.location,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            df.format(inspection.createdAt),
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600),
                          ),
                          if (inspection.inspector.isNotEmpty)
                            Text(
                              '점검자: ${inspection.inspector}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                    _CompletionCircle(percent: completion),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatBadge('Y', inspection.yCount, AppTheme.yColor),
                    const SizedBox(width: 6),
                    _StatBadge('N', inspection.nCount, AppTheme.nColor),
                    const SizedBox(width: 6),
                    _StatBadge('NA', inspection.naCount, AppTheme.naColor),
                    if (inspection.unchecked > 0) ...[
                      const SizedBox(width: 6),
                      _StatBadge('미점검', inspection.unchecked,
                          Colors.orange.shade400),
                    ],
                    if (inspection.photos.isNotEmpty) ...[
                      const Spacer(),
                      Icon(Icons.photo, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text('${inspection.photos.length}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
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
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _CompletionCircle extends StatelessWidget {
  final int percent;
  const _CompletionCircle({required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent == 100
        ? AppTheme.yColor
        : percent > 0
            ? Colors.orange
            : Colors.grey;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            value: percent / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 4,
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.search_off : Icons.assignment_outlined,
            size: 72,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilter ? '검색 결과가 없습니다' : '점검 기록이 없습니다',
            style:
                TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter ? '필터를 변경해 보세요' : '하단 버튼으로 새 점검을 시작하세요',
            style:
                TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Bottom Sheet ────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final InspectionFilter filter;
  final List<String> locations;

  const _FilterSheet({required this.filter, required this.locations});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _location;
  late DateTime? _from;
  late DateTime? _to;
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _location = widget.filter.location;
    _from = widget.filter.dateFrom;
    _to = widget.filter.dateTo;
    _locationController.text = _location ?? '';
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom
        ? (_from ?? DateTime.now())
        : (_to ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case 'today':
          _from = DateTime(now.year, now.month, now.day);
          _to = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          _from = now.subtract(const Duration(days: 7));
          _to = now;
          break;
        case 'month':
          _from = DateTime(now.year, now.month, 1);
          _to = now;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd');
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('필터 설정',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('점검 장소',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              hintText: '장소 검색...',
              prefixIcon: Icon(Icons.location_on_outlined, size: 18),
            ),
            onChanged: (v) => _location = v.isEmpty ? null : v,
          ),
          if (widget.locations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: widget.locations
                  .take(8)
                  .map((loc) => ActionChip(
                        label: Text(loc, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _location = loc;
                            _locationController.text = loc;
                          });
                        },
                        backgroundColor: _location == loc
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : null,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Text('기간 설정',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _PresetChip('오늘', () => _setPreset('today')),
              const SizedBox(width: 6),
              _PresetChip('최근 1주', () => _setPreset('week')),
              const SizedBox(width: 6),
              _PresetChip('이번 달', () => _setPreset('month')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: '시작일',
                  date: _from != null ? df.format(_from!) : null,
                  onTap: () => _pickDate(true),
                  onClear: _from != null
                      ? () => setState(() => _from = null)
                      : null,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('~'),
              ),
              Expanded(
                child: _DatePickerButton(
                  label: '종료일',
                  date: _to != null ? df.format(_to!) : null,
                  onTap: () => _pickDate(false),
                  onClear:
                      _to != null ? () => setState(() => _to = null) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<InspectionProvider>().applyFilter(
                      InspectionFilter(
                        location: _locationController.text.isEmpty
                            ? null
                            : _locationController.text,
                        dateFrom: _from,
                        dateTo: _to,
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('적용'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final String? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date ?? label,
                style: TextStyle(
                  fontSize: 13,
                  color: date != null ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close,
                    size: 16, color: Colors.grey.shade400),
              )
            else
              Icon(Icons.calendar_today,
                  size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
