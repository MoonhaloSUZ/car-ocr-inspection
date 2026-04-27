import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/checklist_template.dart';
import '../providers/template_provider.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';
import '../widgets/result_toggle.dart';
import '../widgets/photo_picker_widget.dart';

class InspectionFormScreen extends StatefulWidget {
  final String? inspectionId; // null = new inspection

  const InspectionFormScreen({super.key, this.inspectionId});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen> {
  final _db = DatabaseService();
  final _locationCtrl = TextEditingController();
  final _inspectorCtrl = TextEditingController();
  final _overallNoteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final Map<String, String?> _results = {};
  final Map<String, TextEditingController> _noteCtrl = {};
  final Map<String, List<String>> _photos = {};
  final Set<String> _expandedCategories = {};
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _inspectorCtrl.dispose();
    _overallNoteCtrl.dispose();
    for (final c in _noteCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    // Provider가 아직 로딩 중일 수 있으므로 DB에서 직접 가져옴
    final template = await _db.getTemplate();

    // Initialize result + note controllers for all items
    for (final cat in template) {
      for (final item in cat.items) {
        _results[item.id] = null;
        _noteCtrl[item.id] = TextEditingController();
        _photos[item.id] = [];
      }
      _expandedCategories.add(cat.id);
    }

    // Load existing inspection if editing
    if (widget.inspectionId != null) {
      final insp = await _db.getInspection(widget.inspectionId!);
      if (insp != null && mounted) {
        _locationCtrl.text = insp.location;
        _inspectorCtrl.text = insp.inspector;
        _overallNoteCtrl.text = insp.overallNote ?? '';
        _date = insp.createdAt;

        for (final r in insp.results) {
          _results[r.itemId] = r.result;
          _noteCtrl[r.itemId]?.text = r.note ?? '';
        }
        for (final p in insp.photos) {
          if (p.itemId != null) {
            final fullPath =
                await DatabaseService.resolvePhotoPath(p.photoPath);
            _photos[p.itemId!] = [...(_photos[p.itemId!] ?? []), fullPath];
          }
        }
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_locationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('점검 장소를 입력해주세요')),
      );
      return;
    }

    setState(() => _saving = true);

    final notes = <String, String>{};
    for (final entry in _noteCtrl.entries) {
      notes[entry.key] = entry.value.text;
    }

    await _db.saveInspection(
      location: _locationCtrl.text.trim(),
      inspector: _inspectorCtrl.text.trim(),
      overallNote: _overallNoteCtrl.text.isEmpty ? null : _overallNoteCtrl.text,
      date: _date,
      results: _results,
      notes: notes,
      photos: _photos,
      existingId: widget.inspectionId,
    );

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
    }
  }

  int _getCategoryProgress(ChecklistCategory cat) =>
      cat.items.where((i) => _results[i.id] != null).length;

  @override
  Widget build(BuildContext context) {
    final template = context.watch<TemplateProvider>().categories;
    final df = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');

    if (_loading) {
      return Scaffold(
        appBar:
            AppBar(title: Text(widget.inspectionId == null ? '새 점검' : '점검 수정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalItems = template.fold(0, (sum, cat) => sum + cat.items.length);
    final checkedItems = _results.values.where((v) => v != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inspectionId == null ? '새 점검' : '점검 수정'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white, size: 20),
              label: const Text('저장', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: totalItems > 0 ? checkedItems / totalItems : 0,
            backgroundColor: Colors.grey.shade200,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 4,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Date picker
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(df.format(_date),
                                      style: const TextStyle(fontSize: 14)),
                                ),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(
                            labelText: '점검 장소 *',
                            prefixIcon:
                                Icon(Icons.location_on_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _inspectorCtrl,
                          decoration: const InputDecoration(
                            labelText: '점검자',
                            prefixIcon: Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Checklist categories
                ...template.map((cat) {
                  final progress = _getCategoryProgress(cat);
                  final total = cat.items.length;
                  final isExpanded = _expandedCategories.contains(cat.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        // Category header
                        InkWell(
                          onTap: () => setState(() {
                            if (isExpanded) {
                              _expandedCategories.remove(cat.id);
                            } else {
                              _expandedCategories.add(cat.id);
                            }
                          }),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.07),
                              borderRadius: BorderRadius.vertical(
                                top: const Radius.circular(12),
                                bottom: isExpanded
                                    ? Radius.zero
                                    : const Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cat.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$progress / $total',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: progress == total
                                        ? AppTheme.yColor
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Items
                        if (isExpanded)
                          ...cat.items.asMap().entries.map((e) {
                            final idx = e.key;
                            final item = e.value;
                            final isLast = idx == cat.items.length - 1;

                            return _InspectionItemTile(
                              item: item,
                              result: _results[item.id],
                              noteController:
                                  _noteCtrl[item.id] ?? TextEditingController(),
                              photos: _photos[item.id] ?? [],
                              isLast: isLast,
                              onResultChanged: (v) =>
                                  setState(() => _results[item.id] = v),
                              onPhotosChanged: (paths) =>
                                  setState(() => _photos[item.id] = paths),
                            );
                          }),
                      ],
                    ),
                  );
                }),

                // Overall note
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
                        TextField(
                          controller: _overallNoteCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '종합적인 점검 의견을 입력하세요 (선택)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionItemTile extends StatefulWidget {
  final ChecklistItem item;
  final String? result;
  final TextEditingController noteController;
  final List<String> photos;
  final bool isLast;
  final ValueChanged<String?> onResultChanged;
  final ValueChanged<List<String>> onPhotosChanged;

  const _InspectionItemTile({
    required this.item,
    required this.result,
    required this.noteController,
    required this.photos,
    required this.isLast,
    required this.onResultChanged,
    required this.onPhotosChanged,
  });

  @override
  State<_InspectionItemTile> createState() => _InspectionItemTileState();
}

class _InspectionItemTileState extends State<_InspectionItemTile> {
  bool _showNote = false;
  bool _showPhotos = false;

  @override
  void initState() {
    super.initState();
    _showNote = widget.noteController.text.isNotEmpty;
    _showPhotos = widget.photos.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: widget.isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                ResultToggle(
                  value: widget.result,
                  onChanged: widget.onResultChanged,
                ),
                const SizedBox(width: 6),
                // Note & photo toggles
                _IconToggle(
                  icon: Icons.edit_note,
                  active: _showNote || widget.noteController.text.isNotEmpty,
                  tooltip: '특이사항',
                  onTap: () => setState(() => _showNote = !_showNote),
                ),
                _IconToggle(
                  icon: Icons.photo_camera_outlined,
                  active: _showPhotos || widget.photos.isNotEmpty,
                  tooltip: '사진',
                  badge: widget.photos.isNotEmpty ? widget.photos.length : null,
                  onTap: () => setState(() => _showPhotos = !_showPhotos),
                ),
              ],
            ),
          ),
          if (_showNote)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: widget.noteController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: '특이사항 입력...',
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (_showPhotos)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: PhotoPickerWidget(
                photoPaths: widget.photos,
                onChanged: widget.onPhotosChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final int? badge;
  final VoidCallback onTap;

  const _IconToggle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                icon,
                size: 20,
                color: active ? AppTheme.primaryColor : Colors.grey.shade400,
              ),
            ),
            if (badge != null)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
