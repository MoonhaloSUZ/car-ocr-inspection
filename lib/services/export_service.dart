import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/inspection_record.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  pw.Font? _regular;
  pw.Font? _bold;

  Future<void> _loadFonts() async {
    if (_regular != null) return;
    _regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'));
    _bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  }

  pw.TextStyle _s({double sz = 8.5, bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
          font: bold ? _bold : _regular,
          fontBold: _bold,
          fontSize: sz,
          color: color);

  // ── 공통 셀 ──────────────────────────────────────────────────────────
  pw.Widget _hCell(String text, {double minH = 16, bool gray = true}) =>
      pw.Container(
        constraints: pw.BoxConstraints(minHeight: minH),
        color: gray ? PdfColors.grey200 : null,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        alignment: pw.Alignment.center,
        child: pw.Text(text,
            style: _s(bold: true), textAlign: pw.TextAlign.center),
      );

  pw.Widget _vCell(String text, {double minH = 16, pw.Alignment? align}) =>
      pw.Container(
        constraints: pw.BoxConstraints(minHeight: minH),
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        alignment: align ?? pw.Alignment.centerLeft,
        child: pw.Text(text, style: _s()),
      );

  pw.Widget _blankCell({double minH = 16}) => pw.Container(
        constraints: pw.BoxConstraints(minHeight: minH),
      );

  // ── PDF 내보내기 ─────────────────────────────────────────────────────
  Future<void> exportPdf(InspectionRecord rec) async {
    await _loadFonts();

    final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!));

    // ── Page 1 ──────────────────────────────────────────────────────
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _buildTitle(),
          pw.SizedBox(height: 5),
          _buildHeaderTable(rec),
          pw.SizedBox(height: 5),
          _buildVehicleTable(rec),
          pw.SizedBox(height: 5),
          _buildEquipTable(rec),
          pw.SizedBox(height: 5),
          _buildResultBox(),
        ],
      ),
    ));

    // ── Page 2: 장착사진 ─────────────────────────────────────────────
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      build: (ctx) => _buildPhotoPage(rec),
    ));

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final df = DateFormat('yyyyMMdd');
    final file =
        File('${dir.path}/점검표_${rec.plateNo}_${df.format(rec.createdAt)}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: '가축분뇨 검증장비 정기점검표');
  }

  // ── 제목 ────────────────────────────────────────────────────────────
  pw.Widget _buildTitle() => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
        child: pw.Row(children: [
          pw.Container(
            width: 90,
            height: 32,
            color: PdfColors.white,
            alignment: pw.Alignment.center,
            child: pw.Text('한국환경공단', style: _s(sz: 10, bold: true)),
          ),
          pw.Container(width: 1, height: 32, color: PdfColors.black),
          pw.Expanded(
            child: pw.Center(
              child: pw.Text('가축분뇨 검증장비 정기점검표', style: _s(sz: 14, bold: true)),
            ),
          ),
        ]),
      );

  // ── 헤더 (관리번호/점검일자/운전자/점검자) ──────────────────────────
  pw.Widget _buildHeaderTable(InspectionRecord rec) {
    final df = DateFormat('yyyy년   MM월   dd일');
    final dateStr = rec.inspectionDate.isNotEmpty
        ? rec.inspectionDate
        : df.format(rec.createdAt);

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(42),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FixedColumnWidth(42),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(children: [
          _hCell('관리번호'),
          _vCell(rec.mgmtNo),
          _hCell('점검일자'),
          _vCell(dateStr),
        ]),
        pw.TableRow(children: [
          _hCell('운전자'),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text(
                '소속: ${rec.driverOrg}     성명: ${rec.driverName}     (서명)',
                style: _s()),
          ),
          _hCell('연락처'),
          _vCell(rec.driverContact),
        ]),
        pw.TableRow(children: [
          _hCell('점검자'),
          pw.Padding(
            padding: const pw.EdgeInsets.all(3),
            child: pw.Text('소속: 한국환경공단     성명:                  (서명)',
                style: _s()),
          ),
          _hCell('연락처'),
          _blankCell(),
        ]),
      ],
    );
  }

  // ── 차량정보 (차량번호 1행 2열로 합침) ──────────────────────────────
  pw.Widget _buildVehicleTable(InspectionRecord rec) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(42), // 차량정보
        1: const pw.FlexColumnWidth(3), // 차량번호값 / 축수값
        2: const pw.FixedColumnWidth(32), // 차종명 / 최대적재량
        3: const pw.FlexColumnWidth(2), // 차종명값 / 최대적재량값
        4: const pw.FixedColumnWidth(32), // 총중량
        5: const pw.FlexColumnWidth(1.5), // 총중량값
      },
      children: [
        // Row 1: 차량번호 (col 1 spans full), 차종명, 총중량
        pw.TableRow(children: [
          _hCell('차량\n정보', minH: 20),
          _vCell('차량번호:  ${rec.plateNo}', minH: 20),
          _hCell('차종명', minH: 20),
          _vCell(rec.vehicleType, minH: 20),
          _hCell('총중량', minH: 20),
          _vCell('${rec.grossWeight} 톤', minH: 20),
        ]),
        // Row 2: 축수, 최대적재량
        pw.TableRow(children: [
          _hCell(''),
          _blankCell(minH: 18),
          _hCell('축수', minH: 18),
          _vCell('${rec.axleCount} 축', minH: 18),
          _hCell('최대\n적재량', minH: 18),
          _vCell('${rec.maxLoad} 톤', minH: 18),
        ]),
      ],
    );
  }

  // ── 장비별 점검결과 (원본 양식 완전 일치) ───────────────────────────
  pw.Widget _buildEquipTable(InspectionRecord rec) {
    final border = pw.TableBorder.all(width: 0.5);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // 섹션 헤더
        pw.Container(
          color: PdfColors.grey200,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Center(
              child: pw.Text('장비별 점검결과', style: _s(sz: 9, bold: true))),
        ),

        // ── 중량센서(A) ────────────────────────────────────────────
        pw.Table(border: border, columnWidths: {
          0: const pw.FixedColumnWidth(50),
          1: const pw.FixedColumnWidth(38),
          2: const pw.FixedColumnWidth(30),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1.8),
          5: const pw.FlexColumnWidth(1),
        }, children: [
          pw.TableRow(children: [
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 52),
              color: PdfColors.grey200,
              alignment: pw.Alignment.center,
              child: pw.Text('중량센서\n(A)',
                  style: _s(bold: true), textAlign: pw.TextAlign.center),
            ),
            pw.Column(children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('공차\n정보',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('만차\n정보',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
            ]),
            pw.Column(children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('총중량', style: _s()),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('총중량', style: _s()),
              ),
            ]),
            pw.Column(children: [
              _vCell(rec.emptyGrossWeight, minH: 16),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              _vCell(rec.fullGrossWeight, minH: 16),
            ]),
            pw.Column(children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('오차율(%)\n(B-A)/B*100', style: _s(sz: 7.5)),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('오차율(%)\n(B-A)/B*100', style: _s(sz: 7.5)),
              ),
            ]),
            pw.Column(children: [
              _vCell(rec.emptyErrorRate, minH: 16),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              _vCell(rec.fullErrorRate, minH: 16),
            ]),
          ]),
        ]),

        // 공만차편차 CH1~CH8
        pw.Table(border: border, columnWidths: {
          0: const pw.FixedColumnWidth(50),
          1: const pw.FixedColumnWidth(38),
          2: const pw.FixedColumnWidth(25),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1),
          5: const pw.FlexColumnWidth(1),
          6: const pw.FlexColumnWidth(1),
          7: const pw.FlexColumnWidth(1),
          8: const pw.FlexColumnWidth(1),
          9: const pw.FlexColumnWidth(1),
          10: const pw.FlexColumnWidth(1),
        }, children: [
          pw.TableRow(children: [
            _blankCell(minH: 14),
            pw.Container(
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.all(2),
              alignment: pw.Alignment.center,
              child: pw.Text('공만차\n편차',
                  style: _s(), textAlign: pw.TextAlign.center),
            ),
            pw.Container(
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.all(2),
              alignment: pw.Alignment.center,
              child: pw.Text('신호', style: _s()),
            ),
            for (final ch in [
              'CH1',
              'CH2',
              'CH3',
              'CH4',
              'CH5',
              'CH6',
              'CH7',
              'CH8'
            ])
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(2),
                alignment: pw.Alignment.center,
                child: pw.Text(ch, style: _s(sz: 7)),
              ),
          ]),
          pw.TableRow(children: [
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _vCell(rec.ch1, minH: 14),
            _vCell(rec.ch2, minH: 14),
            _vCell(rec.ch3, minH: 14),
            _vCell(rec.ch4, minH: 14),
            _vCell(rec.ch5, minH: 14),
            _vCell(rec.ch6, minH: 14),
            _vCell(rec.ch7, minH: 14),
            _vCell(rec.ch8, minH: 14),
          ]),
        ]),

        // ── 계근대(B) ──────────────────────────────────────────────
        pw.Table(border: border, columnWidths: {
          0: const pw.FixedColumnWidth(50),
          1: const pw.FixedColumnWidth(38),
          2: const pw.FixedColumnWidth(25),
          3: const pw.FlexColumnWidth(1),
          4: const pw.FlexColumnWidth(1),
          5: const pw.FlexColumnWidth(1),
          6: const pw.FlexColumnWidth(1),
          7: const pw.FlexColumnWidth(1.8),
          8: const pw.FlexColumnWidth(1.5),
        }, children: [
          pw.TableRow(children: [
            pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 36),
              color: PdfColors.grey200,
              alignment: pw.Alignment.center,
              child: pw.Text('계근대(B)\n(이동식\n축중기)',
                  style: _s(bold: true), textAlign: pw.TextAlign.center),
            ),
            pw.Column(children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('공차\n정보',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('만차\n정보',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
            ]),
            pw.Column(children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text('중량', style: _s()),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Text('중량', style: _s()),
              ),
            ]),
            for (final label in ['1축', '2축', '3축', '4축'])
              pw.Column(children: [
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(label, style: _s()),
                ),
                pw.Divider(height: 0.5, color: PdfColors.grey400),
                pw.Container(
                  color: PdfColors.grey200,
                  padding: const pw.EdgeInsets.all(3),
                  alignment: pw.Alignment.center,
                  child: pw.Text(label, style: _s()),
                ),
              ]),
            pw.Column(children: [
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('총중량\n(kg)',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                color: PdfColors.grey200,
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text('총중량\n(kg)',
                    style: _s(), textAlign: pw.TextAlign.center),
              ),
            ]),
            pw.Column(children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  '${rec.scaleType == "계근대" ? "■" : "□"} 계근대',
                  style: _s(),
                ),
              ),
              pw.Divider(height: 0.5, color: PdfColors.grey400),
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  '${rec.scaleType == "이동식축중기" ? "■" : "□"} 이동식\n  축중기',
                  style: _s(),
                ),
              ),
            ]),
          ]),
          // 공차 수치 행
          pw.TableRow(children: [
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _vCell(rec.scaleEmptyAx1, minH: 14),
            _vCell(rec.scaleEmptyAx2, minH: 14),
            _vCell(rec.scaleEmptyAx3, minH: 14),
            _vCell(rec.scaleEmptyAx4, minH: 14),
            _vCell(rec.scaleEmptyTotal, minH: 14),
            _blankCell(minH: 14),
          ]),
          // 만차 수치 행
          pw.TableRow(children: [
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _blankCell(minH: 14),
            _vCell(rec.scaleFullAx1, minH: 14),
            _vCell(rec.scaleFullAx2, minH: 14),
            _vCell(rec.scaleFullAx3, minH: 14),
            _vCell(rec.scaleFullAx4, minH: 14),
            _vCell(rec.scaleFullTotal, minH: 14),
            _blankCell(minH: 14),
          ]),
        ]),

        // ── 장비 및 상태 (통합단말기 ~ 장착사진) ──────────────────
        pw.Table(border: border, columnWidths: {
          0: const pw.FixedColumnWidth(50),
          1: const pw.FixedColumnWidth(38),
          2: const pw.FlexColumnWidth(1),
        }, children: [
          // 통합단말기
          pw.TableRow(children: [
            _hCell('통합단말기', minH: 40),
            _blankCell(minH: 40),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        'RoadLoad-N    S/N:                          모뎀번호: ${rec.modemNo}',
                        style: _s()),
                    pw.SizedBox(height: 3),
                    pw.Text(
                        '□STATUS  □SENSOR  □BLUETOOTH                     상태: □정상  □고장  □분실',
                        style: _s()),
                    pw.Text('□MODEM  □SD CARD 유무', style: _s()),
                  ]),
            ),
          ]),
          // 중량센서
          pw.TableRow(children: [
            _hCell('중량센서', minH: 16),
            _hCell('장비\n및\n상태', minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  'RoadLoad-S    센서 ID: ${rec.sensorId}                    상태: □정상  □고장  □분실',
                  style: _s()),
            ),
          ]),
          // IP카메라
          pw.TableRow(children: [
            _hCell('IP카메라', minH: 16),
            _blankCell(minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  'XV-CA100      카메라 ID: ${rec.cameraId}                  상태: □정상  □고장  □분실',
                  style: _s()),
            ),
          ]),
          // 모바일 디바이스
          pw.TableRow(children: [
            _hCell('모바일\n디바이스', minH: 16),
            _blankCell(minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  '모델명:                   ID: -                          상태: □정상  □고장  □분실',
                  style: _s()),
            ),
          ]),
          // SD카드
          pw.TableRow(children: [
            _hCell('SD카드', minH: 16),
            _blankCell(minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                  'MicroSD 32GB   ID: -                              상태: □정상  □고장  □분실',
                  style: _s()),
            ),
          ]),
          // 봉인스티커
          pw.TableRow(children: [
            _hCell('봉인\n스티커', minH: 16),
            _blankCell(minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text('□정상  □훼손  □재봉인', style: _s()),
            ),
          ]),
          // 장착사진
          pw.TableRow(children: [
            _hCell('장착사진', minH: 16),
            _blankCell(minH: 16),
            pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text('□차량정면  □차량측면  □차량내부  □통합단말기  □IP카메라  □중량센서',
                  style: _s()),
            ),
          ]),
        ]),
      ],
    );
  }

  // ── 점검결과 ─────────────────────────────────────────────────────────
  pw.Widget _buildResultBox() => pw.Table(
        border: pw.TableBorder.all(width: 0.5),
        children: [
          pw.TableRow(children: [
            _hCell('점검결과', minH: 32),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                '□ 이상없음                □ 공차 보정               □ 만차 보정\n'
                '□ 유지보수 현장조치       □ 유지보수 신청            □ 기타(SD카드 교체 등)',
                style: _s(),
              ),
            ),
          ]),
        ],
      );

  // ── 장착사진 페이지 ──────────────────────────────────────────────────
  pw.Widget _buildPhotoPage(InspectionRecord rec) {
    final photoMap = {for (final p in rec.photos) p.slotKey: p.photoPath};

    pw.Widget photoBox(String key, String label) {
      final path = photoMap[key];
      pw.Widget imgContent;
      if (path != null && File(path).existsSync()) {
        try {
          imgContent = pw.Image(pw.MemoryImage(File(path).readAsBytesSync()),
              fit: pw.BoxFit.cover);
        } catch (_) {
          imgContent = pw.Center(child: pw.Text('사진 오류', style: _s()));
        }
      } else {
        imgContent = pw.SizedBox();
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 95,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2),
              color: PdfColors.lightBlue100,
            ),
            child: imgContent,
          ),
          pw.Center(child: pw.Text(label, style: _s(sz: 8))),
          pw.SizedBox(height: 4),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.all(5),
          child:
              pw.Center(child: pw.Text('장착사진', style: _s(sz: 11, bold: true))),
        ),
        pw.SizedBox(height: 6),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            for (int i = 0; i < kPhotoSlots.length; i += 2)
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 5),
                  child: photoBox(kPhotoSlots[i].key, kPhotoSlots[i].label),
                ),
                i + 1 < kPhotoSlots.length
                    ? photoBox(kPhotoSlots[i + 1].key, kPhotoSlots[i + 1].label)
                    : pw.SizedBox(),
              ]),
          ],
        ),
      ],
    );
  }
}
