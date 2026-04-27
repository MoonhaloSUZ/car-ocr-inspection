import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../utils/theme.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('차량 목록 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '차량 추가',
            onPressed: () => _showVehicleDialog(context, null),
          ),
        ],
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator())
          : provider.vehicles.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.directions_car_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('등록된 차량이 없습니다',
                        style: TextStyle(color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showVehicleDialog(context, null),
                      icon: const Icon(Icons.add),
                      label: const Text('차량 추가'),
                    ),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.vehicles.length,
                  itemBuilder: (ctx, i) =>
                      _VehicleCard(vehicle: provider.vehicles[i]),
                ),
    );
  }

  static void _showVehicleDialog(BuildContext context, Vehicle? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _VehicleForm(vehicle: existing),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  const _VehicleCard({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
          child: Text('${vehicle.serialNo}',
              style: const TextStyle(
                  color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
        ),
        title: Text(vehicle.plateNo,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${vehicle.owner} · ${vehicle.vehicleType}',
            style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 8),
                _row('축수', '${vehicle.axleCount} 축'),
                _row('총중량', '${vehicle.grossWeight} 톤'),
                _row('최대적재량', '${vehicle.maxLoad} 톤'),
                _row('모뎀번호', vehicle.modemNo),
                _row('센서ID', vehicle.sensorId),
                _row('카메라ID', vehicle.cameraId),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => VehicleListScreen._showVehicleDialog(
                          context, vehicle),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red)),
                      onPressed: () => _confirmDelete(context),
                      icon:
                          const Icon(Icons.delete, size: 16, color: Colors.red),
                      label:
                          const Text('삭제', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ]),
      );

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('차량 삭제'),
        content: Text('${vehicle.plateNo} 차량을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              context.read<VehicleProvider>().deleteVehicle(vehicle.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VehicleForm extends StatefulWidget {
  final Vehicle? vehicle;
  const _VehicleForm({this.vehicle});

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _c = {
      'plateNo': TextEditingController(text: v?.plateNo ?? ''),
      'owner': TextEditingController(text: v?.owner ?? ''),
      'vehicleType': TextEditingController(text: v?.vehicleType ?? ''),
      'axleCount': TextEditingController(text: v?.axleCount ?? ''),
      'grossWeight': TextEditingController(text: v?.grossWeight ?? ''),
      'maxLoad': TextEditingController(text: v?.maxLoad ?? ''),
      'modemNo': TextEditingController(text: v?.modemNo ?? ''),
      'sensorId': TextEditingController(text: v?.sensorId ?? ''),
      'cameraId': TextEditingController(text: v?.cameraId ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) c.dispose();
    super.dispose();
  }

  void _save() {
    if (_c['plateNo']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('차량번호를 입력해주세요')));
      return;
    }
    final provider = context.read<VehicleProvider>();
    if (widget.vehicle != null) {
      widget.vehicle!
        ..plateNo = _c['plateNo']!.text.trim()
        ..owner = _c['owner']!.text.trim()
        ..vehicleType = _c['vehicleType']!.text.trim()
        ..axleCount = _c['axleCount']!.text.trim()
        ..grossWeight = _c['grossWeight']!.text.trim()
        ..maxLoad = _c['maxLoad']!.text.trim()
        ..modemNo = _c['modemNo']!.text.trim()
        ..sensorId = _c['sensorId']!.text.trim()
        ..cameraId = _c['cameraId']!.text.trim();
      provider.updateVehicle(widget.vehicle!);
    } else {
      final v = Vehicle(
        id: const Uuid().v4(),
        serialNo: 0,
        plateNo: _c['plateNo']!.text.trim(),
        owner: _c['owner']!.text.trim(),
        vehicleType: _c['vehicleType']!.text.trim(),
        axleCount: _c['axleCount']!.text.trim(),
        grossWeight: _c['grossWeight']!.text.trim(),
        maxLoad: _c['maxLoad']!.text.trim(),
        modemNo: _c['modemNo']!.text.trim(),
        sensorId: _c['sensorId']!.text.trim(),
        cameraId: _c['cameraId']!.text.trim(),
      );
      provider.addVehicle(v);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.vehicle == null ? '차량 추가' : '차량 수정',
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field('차량번호 *', _c['plateNo']!),
          _field('소속', _c['owner']!),
          _field('차종명', _c['vehicleType']!),
          Row(children: [
            Expanded(child: _field('축수', _c['axleCount']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('총중량(톤)', _c['grossWeight']!)),
            const SizedBox(width: 8),
            Expanded(child: _field('최대적재량(톤)', _c['maxLoad']!)),
          ]),
          _field('모뎀번호', _c['modemNo']!),
          _field('센서ID', _c['sensorId']!),
          _field('카메라ID', _c['cameraId']!),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                onPressed: _save,
                child: Text(widget.vehicle == null ? '추가' : '저장')),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 12),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      );
}
