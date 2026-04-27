import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/inspection_record.dart';
import '../providers/vehicle_provider.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';
import '../utils/theme.dart';
import '../widgets/ocr_input_field.dart';
import '../widgets/photo_slot_widget.dart';

class InspectionFormScreen extends StatefulWidget {
  final String? inspectionId;
  const InspectionFormScreen({super.key, this.inspectionId});

  @override
  State<InspectionFormScreen> createState() => _InspectionFormScreenState();
}

class _InspectionFormScreenState extends State<InspectionFormScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService();
  late TabController _tab;

  // ── 컨트롤러 ──
  final _mgmtNoCtrl = TextEditingController();
  final _driverOrgCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverContactCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();
  final _grossWeightCtrl = TextEditingController();
  final _axleCtrl = TextEditingController();
  final _maxLoadCtrl = TextEditingController();
  final _modemCtrl = TextEditingController();
  final _sensorCtrl = TextEditingController();
  final _cameraCtrl = TextEditingController();

  // 중량센서(A)
  final _emptyGWCtrl = TextEditingController();
  final _emptyERCtrl = TextEditingController();
  final _fullGWCtrl = TextEditingController();
  final _fullERCtrl = TextEditingController();
  final List<TextEditingController> _chCtrls =
      List.generate(8, (_) => TextEditingController());

  // 계근대(B)
  final List<TextEditingController> _scaleEmptyCtrl =
      List.generate(5, (_) => TextEditingController());
  final List<TextEditingController> _scaleFullCtrl =
      List.generate(5, (_) => TextEditingController());
  String _scaleType = '';

  DateTime _inspDate = DateTime.now();
  Map<String, String> _slotPaths = {};
  bool _saving = false;
  bool _loading = true;
  String? _existingId;

  List<TextEditingController> get _allControllers => [
        _mgmtNoCtrl,
        _driverOrgCtrl,
        _driverNameCtrl,
        _driverContactCtrl,
        _plateCtrl,
        _vehicleTypeCtrl,
        _grossWeightCtrl,
        _axleCtrl,
        _maxLoadCtrl,
        _modemCtrl,
        _sensorCtrl,
        _cameraCtrl,
        _emptyGWCtrl,
        _emptyERCtrl,
        _fullGWCtrl,
        _fullERCtrl,
        ..._chCtrls,
        ..._scaleEmptyCtrl,
        ..._scaleFullCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadExisting();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _allControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (widget.inspectionId != null) {
      final rec = await _db.getInspection(widget.inspectionId!);
      if (rec != null && mounted) {
        _existingId = rec.id;
        _mgmtNoCtrl.text = rec.mgmtNo;
        _driverOrgCtrl.text = rec.driverOrg;
        _driverNameCtrl.text = rec.driverName;
        _driverContactCtrl.text = rec.driverContact;
        _plateCtrl.text = rec.plateNo;
        _vehicleTypeCtrl.text = rec.vehicleType;
        _grossWeightCtrl.text = rec.grossWeight;
        _axleCtrl.text = rec.axleCount;
        _maxLoadCtrl.text = rec.maxLoad;
        _modemCtrl.text = rec.modemNo;
        _sensorCtrl.text = rec.sensorId;
        _cameraCtrl.text = rec.cameraId;
        _emptyGWCtrl.text = rec.emptyGrossWeight;
        _emptyERCtrl.text = rec.emptyErrorRate;
        _fullGWCtrl.text = rec.fullGrossWeight;
        _fullERCtrl.text = rec.fullErrorRate;
        final chs = [
          rec.ch1,
          rec.ch2,
          rec.ch3,
          rec.ch4,
          rec.ch5,
          rec.ch6,
          rec.ch7,
          rec.ch8
        ];
        for (int i = 0; i < 8; i++) _chCtrls[i].text = chs[i];
        final se = [
          rec.scaleEmptyAx1,
          rec.scaleEmptyAx2,
          rec.scaleEmptyAx3,
          rec.scaleEmptyAx4,
          rec.scaleEmptyTotal
        ];
        final sf = [
          rec.scaleFullAx1,
          rec.scaleFullAx2,
          rec.scaleFullAx3,
          rec.scaleFullAx4,
          rec.scaleFullTotal
        ];
        for (int i = 0; i < 5; i++) {
          _scaleEmptyCtrl[i].text = se[i];
          _scaleFullCtrl[i].text = sf[i];
        }
        _scaleType = rec.scaleType;
        if (rec.inspectionDate.isNotEmpty) {
          try {
            _inspDate = DateFormat('yyyy-MM-dd').parse(rec.inspectionDate);
          } catch (_) {}
        }
        _slotPaths = {for (final p in rec.photos) p.slotKey: p.photoPath};
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onPlateChanged(String val) async {
    if (val.length < 6) return;
    final vehicle = await context.read<VehicleProvider>().findByPlate(val);
    if (vehicle != null && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('차량 정보 자동완성'),
          content: Text('차량번호 ${vehicle.plateNo}\n\n'
              '소속: ${vehicle.owner}\n'
              '차종명: ${vehicle.vehicleType}\n'
              '총중량: ${vehicle.grossWeight}톤  축수: ${vehicle.axleCount}축\n'
              '최대적재량: ${vehicle.maxLoad}톤\n'
              '모뎀번호: ${vehicle.modemNo}\n'
              '센서ID: ${vehicle.sensorId}  카메라ID: ${vehicle.cameraId}\n\n'
              '자동으로 입력할까요?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('아니오')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('입력')),
          ],
        ),
      );
      if (confirm == true && mounted) {
        setState(() {
          _driverOrgCtrl.text = vehicle.owner;
          _vehicleTypeCtrl.text = vehicle.vehicleType;
          _grossWeightCtrl.text = vehicle.grossWeight;
          _axleCtrl.text = vehicle.axleCount;
          _maxLoadCtrl.text = vehicle.maxLoad;
          _modemCtrl.text = vehicle.modemNo;
          _sensorCtrl.text = vehicle.sensorId;
          _cameraCtrl.text = vehicle.cameraId;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _inspDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030));
    if (picked != null) setState(() => _inspDate = picked);
  }

  Future<void> _save() async {
    if (_plateCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('차량번호를 입력해주세요')));
      return;
    }
    setState(() => _saving = true);

    final record = InspectionRecord(
      id: _existingId ?? const Uuid().v4(),
      createdAt: DateTime.now(),
      mgmtNo: _mgmtNoCtrl.text.trim(),
      inspectionDate: DateFormat('yyyy-MM-dd').format(_inspDate),
      driverOrg: _driverOrgCtrl.text.trim(),
      driverName: _driverNameCtrl.text.trim(),
      driverContact: _driverContactCtrl.text.trim(),
      plateNo: _plateCtrl.text.trim(),
      vehicleType: _vehicleTypeCtrl.text.trim(),
      grossWeight: _grossWeightCtrl.text.trim(),
      axleCount: _axleCtrl.text.trim(),
      maxLoad: _maxLoadCtrl.text.trim(),
      modemNo: _modemCtrl.text.trim(),
      sensorId: _sensorCtrl.text.trim(),
      cameraId: _cameraCtrl.text.trim(),
      emptyGrossWeight: _emptyGWCtrl.text.trim(),
      emptyErrorRate: _emptyERCtrl.text.trim(),
      fullGrossWeight: _fullGWCtrl.text.trim(),
      fullErrorRate: _fullERCtrl.text.trim(),
      ch1: _chCtrls[0].text,
      ch2: _chCtrls[1].text,
      ch3: _chCtrls[2].text,
      ch4: _chCtrls[3].text,
      ch5: _chCtrls[4].text,
      ch6: _chCtrls[5].text,
      ch7: _chCtrls[6].text,
      ch8: _chCtrls[7].text,
      scaleEmptyAx1: _scaleEmptyCtrl[0].text,
      scaleEmptyAx2: _scaleEmptyCtrl[1].text,
      scaleEmptyAx3: _scaleEmptyCtrl[2].text,
      scaleEmptyAx4: _scaleEmptyCtrl[3].text,
      scaleEmptyTotal: _scaleEmptyCtrl[4].text,
      scaleFullAx1: _scaleFullCtrl[0].text,
      scaleFullAx2: _scaleFullCtrl[1].text,
      scaleFullAx3: _scaleFullCtrl[2].text,
      scaleFullAx4: _scaleFullCtrl[3].text,
      scaleFullTotal: _scaleFullCtrl[4].text,
      scaleType: _scaleType,
    );

    await _db.saveInspection(
        record: record, slotPaths: _slotPaths, existingId: _existingId);

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('새 점검')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final df = DateFormat('yyyy년 MM월 dd일 (E)', 'ko');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inspectionId == null ? '새 점검' : '점검 수정'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '기본 정보'),
            Tab(text: '계측 데이터'),
            Tab(text: '장착 사진'),
          ],
        ),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)))
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, color: Colors.white, size: 18),
                  label:
                      const Text('저장', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: TabBarView(controller: _tab, children: [
        // ── Tab 1: 기본 정보 ──────────────────────────────────────
        ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: ListTile(
            leading:
                const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            title: Text(df.format(_inspDate),
                style: const TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: _pickDate,
          )),
          const SizedBox(height: 10),
          _section('점검 정보', [
            OcrInputField(
                label: '관리번호',
                controller: _mgmtNoCtrl,
                fieldType: OcrFieldType.general,
                hint: '관리번호 입력'),
          ]),
          const SizedBox(height: 10),
          _section('운전자 정보', [
            OcrInputField(
                label: '소속',
                controller: _driverOrgCtrl,
                fieldType: OcrFieldType.general),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OcrInputField(
                      label: '성명',
                      controller: _driverNameCtrl,
                      fieldType: OcrFieldType.general)),
              const SizedBox(width: 10),
              Expanded(
                  child: OcrInputField(
                      label: '연락처',
                      controller: _driverContactCtrl,
                      fieldType: OcrFieldType.modemNo,
                      hint: '010-0000-0000')),
            ]),
          ]),
          const SizedBox(height: 10),
          _section('차량 정보', [
            OcrInputField(
                label: '차량번호',
                controller: _plateCtrl,
                fieldType: OcrFieldType.plateNo,
                required: true,
                hint: '예) 86누0773',
                onChanged: _onPlateChanged),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OcrInputField(
                      label: '차종명',
                      controller: _vehicleTypeCtrl,
                      fieldType: OcrFieldType.general)),
              const SizedBox(width: 10),
              Expanded(
                  child: OcrInputField(
                      label: '축수',
                      controller: _axleCtrl,
                      fieldType: OcrFieldType.general,
                      hint: '예) 3')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OcrInputField(
                      label: '총중량(톤)',
                      controller: _grossWeightCtrl,
                      fieldType: OcrFieldType.general)),
              const SizedBox(width: 10),
              Expanded(
                  child: OcrInputField(
                      label: '최대적재량(톤)',
                      controller: _maxLoadCtrl,
                      fieldType: OcrFieldType.general)),
            ]),
          ]),
          const SizedBox(height: 10),
          _section('장비 정보', [
            OcrInputField(
                label: '통합단말기 모뎀번호',
                controller: _modemCtrl,
                fieldType: OcrFieldType.modemNo,
                hint: '예) 012-3328-8152'),
            const SizedBox(height: 10),
            OcrInputField(
                label: '중량센서 ID',
                controller: _sensorCtrl,
                fieldType: OcrFieldType.sensorId,
                hint: '예) RLS21-008'),
            const SizedBox(height: 10),
            OcrInputField(
                label: 'IP카메라 ID',
                controller: _cameraCtrl,
                fieldType: OcrFieldType.cameraId,
                hint: '예) CA21-008'),
          ]),
          const SizedBox(height: 80),
        ]),

        // ── Tab 2: 계측 데이터 ────────────────────────────────────
        ListView(padding: const EdgeInsets.all(16), children: [
          _section('중량센서(A) — 공차 정보', [
            Row(children: [
              Expanded(child: _numField('공차 총중량', _emptyGWCtrl, hint: 'kg')),
              const SizedBox(width: 10),
              Expanded(child: _numField('공차 오차율(%)', _emptyERCtrl, hint: '%')),
            ]),
          ]),
          const SizedBox(height: 10),
          _section('중량센서(A) — 만차 정보', [
            Row(children: [
              Expanded(child: _numField('만차 총중량', _fullGWCtrl, hint: 'kg')),
              const SizedBox(width: 10),
              Expanded(child: _numField('만차 오차율(%)', _fullERCtrl, hint: '%')),
            ]),
          ]),
          const SizedBox(height: 10),
          _section('공만차편차 신호 (CH1 ~ CH8)', [
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.8),
              itemCount: 8,
              itemBuilder: (ctx, i) => _numField('CH${i + 1}', _chCtrls[i]),
            ),
          ]),
          const SizedBox(height: 10),
          _section('계근대(B) — 공차 축중량', [
            Row(children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                    child:
                        _numField('${i + 1}축', _scaleEmptyCtrl[i], hint: 'kg')),
                if (i < 3) const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 8),
            _numField('공차 총중량(kg)', _scaleEmptyCtrl[4]),
          ]),
          const SizedBox(height: 10),
          _section('계근대(B) — 만차 축중량', [
            Row(children: [
              for (int i = 0; i < 4; i++) ...[
                Expanded(
                    child:
                        _numField('${i + 1}축', _scaleFullCtrl[i], hint: 'kg')),
                if (i < 3) const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 8),
            _numField('만차 총중량(kg)', _scaleFullCtrl[4]),
          ]),
          const SizedBox(height: 10),
          _section('계근대 타입', [
            Row(children: [
              _typeChip('계근대'),
              const SizedBox(width: 12),
              _typeChip('이동식축중기'),
            ]),
          ]),
          const SizedBox(height: 80),
        ]),

        // ── Tab 3: 장착 사진 ──────────────────────────────────────
        GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9),
          itemCount: kPhotoSlots.length,
          itemBuilder: (ctx, i) {
            final slot = kPhotoSlots[i];
            return PhotoSlotWidget(
              slotKey: slot.key,
              label: slot.label,
              photoPath: _slotPaths[slot.key],
              onPhotoSaved: (path) =>
                  setState(() => _slotPaths[slot.key] = path),
              onRemove: _slotPaths[slot.key] != null
                  ? () => setState(() => _slotPaths.remove(slot.key))
                  : null,
            );
          },
        ),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            const Divider(height: 14),
            ...children,
          ]),
        ),
      );

  Widget _numField(String label, TextEditingController ctrl, {String? hint}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFFDDE3DD))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide: const BorderSide(color: Color(0xFFDDE3DD))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(7),
                borderSide:
                    const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
          ),
        ),
      ]);

  Widget _typeChip(String label) {
    final selected = _scaleType == label;
    return GestureDetector(
      onTap: () => setState(() => _scaleType = selected ? '' : label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}
