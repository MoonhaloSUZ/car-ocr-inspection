import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/inspection.dart';
import '../models/checklist_template.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _df = DateFormat('yyyy-MM-dd');
  final _dtf = DateFormat('yyyy년 MM월 dd일 HH시 mm분');

  // ─── PDF Export ────────────────────────────────────────────────────

  Future<void> exportPdf(
    Inspection inspection,
    List<ChecklistCategory> template,
  ) async {
    final pdf = pw.Document();
    final dateStr = _dtf.format(inspection.createdAt);

    // Build result lookup
    final resultMap = {
      for (final r in inspection.results) r.itemId: r,
    };
    final photoMap = <String, List<String>>{};
    for (final p in inspection.photos) {
      final key = p.itemId ?? '__overall__';
      photoMap.putIfAbsent(key, () => []).add(p.photoPath);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(dateStr, inspection),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('현장 점검표', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildSummaryBox(inspection),
          pw.SizedBox(height: 16),
          ...template.map((cat) => _buildCategoryTable(
                cat,
                resultMap,
                photoMap,
              )),
          if (inspection.overallNote != null &&
              inspection.overallNote!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildOverallNote(inspection.overallNote!),
          ],
        ],
      ),
    );

    // Photo pages
    final allPhotos = inspection.photos.where((p) => _fileExists(p.photoPath));
    if (allPhotos.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text('첨부 사진',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allPhotos.map((p) {
                try {
                  final img =
                      pw.MemoryImage(File(p.photoPath).readAsBytesSync());
                  return pw.Container(
                    width: 160,
                    height: 130,
                    child: pw.Image(img, fit: pw.BoxFit.cover),
                  );
                } catch (_) {
                  return pw.SizedBox();
                }
              }).toList(),
            ),
          ],
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/점검표_${inspection.location}_${_df.format(inspection.createdAt)}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: '현장 점검표');
  }

  pw.Widget _buildPdfHeader(String dateStr, Inspection inspection) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('현장 점검표',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            pw.Text('점검 장소: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(inspection.location),
            pw.SizedBox(width: 20),
            pw.Text('점검자: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(inspection.inspector),
          ]),
          pw.Divider(thickness: 1.5),
        ],
      );

  pw.Widget _buildSummaryBox(Inspection inspection) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            _summaryCell('전체', '${inspection.totalItems}'),
            _summaryCell('Y (양호)', '${inspection.yCount}',
                color: PdfColors.green700),
            _summaryCell('N (불량)', '${inspection.nCount}',
                color: PdfColors.red700),
            _summaryCell('N/A (해당없음)', '${inspection.naCount}',
                color: PdfColors.grey700),
            _summaryCell('미점검', '${inspection.unchecked}',
                color: PdfColors.orange700),
          ],
        ),
      );

  pw.Widget _summaryCell(String label, String value, {PdfColor? color}) =>
      pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  pw.Widget _buildCategoryTable(
    ChecklistCategory cat,
    Map<String, InspectionResult> resultMap,
    Map<String, List<String>> photoMap,
  ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 10),
          pw.Container(
            color: PdfColors.grey800,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: pw.Text(
              cat.title,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(50),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FixedColumnWidth(40),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableHeader('점검 항목'),
                  _tableHeader('결과'),
                  _tableHeader('특이사항'),
                  _tableHeader('사진'),
                ],
              ),
              ...cat.items.map((item) {
                final result = resultMap[item.id];
                final photoCount = photoMap[item.id]?.length ?? 0;
                return pw.TableRow(children: [
                  _tableCell(item.title),
                  _resultCell(result?.result),
                  _tableCell(result?.note ?? ''),
                  _tableCell(photoCount > 0 ? '$photoCount장' : ''),
                ]);
              }),
            ],
          ),
        ],
      );

  pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      );

  pw.Widget _tableCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
      );

  pw.Widget _resultCell(String? result) {
    PdfColor color = PdfColors.grey;
    if (result == 'Y') color = PdfColors.green700;
    if (result == 'N') color = PdfColors.red700;
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        result ?? '-',
        style: pw.TextStyle(
            fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildOverallNote(String note) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('종합 의견',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(note, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      );

  bool _fileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  // ─── Excel Export ─────────────────────────────────────────────────

  Future<void> exportExcel(
    Inspection inspection,
    List<ChecklistCategory> template,
  ) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final sheet = excel['점검표'];

    _excelWrite(sheet, 0, 0, '현장 점검표', isBold: true, fontSize: 16);
    _excelWrite(sheet, 1, 0, '점검 장소');
    _excelWrite(sheet, 1, 1, inspection.location);
    _excelWrite(sheet, 2, 0, '점검자');
    _excelWrite(sheet, 2, 1, inspection.inspector);
    _excelWrite(sheet, 3, 0, '점검 일시');
    _excelWrite(sheet, 3, 1, _dtf.format(inspection.createdAt));

    _excelWrite(sheet, 4, 0, '요약', isBold: true);
    _excelWrite(sheet, 4, 1, '전체: ${inspection.totalItems}');
    _excelWrite(sheet, 4, 2, 'Y(양호): ${inspection.yCount}');
    _excelWrite(sheet, 4, 3, 'N(불량): ${inspection.nCount}');
    _excelWrite(sheet, 4, 4, 'NA(해당없음): ${inspection.naCount}');
    _excelWrite(sheet, 4, 5, '미점검: ${inspection.unchecked}');

    int row = 6;
    _excelWrite(sheet, row, 0, '분류', isBold: true, bgColor: '#E8F5E9');
    _excelWrite(sheet, row, 1, '점검 항목', isBold: true, bgColor: '#E8F5E9');
    _excelWrite(sheet, row, 2, '결과', isBold: true, bgColor: '#E8F5E9');
    _excelWrite(sheet, row, 3, '특이사항', isBold: true, bgColor: '#E8F5E9');
    _excelWrite(sheet, row, 4, '사진 수', isBold: true, bgColor: '#E8F5E9');
    row++;

    final resultMap = {
      for (final r in inspection.results) r.itemId: r,
    };
    final photoMap = <String, int>{};
    for (final p in inspection.photos) {
      if (p.itemId != null) {
        photoMap[p.itemId!] = (photoMap[p.itemId!] ?? 0) + 1;
      }
    }

    for (final cat in template) {
      for (final item in cat.items) {
        final result = resultMap[item.id];
        _excelWrite(sheet, row, 0, cat.title);
        _excelWrite(sheet, row, 1, item.title);
        _excelWrite(sheet, row, 2, result?.result ?? '');
        _excelWrite(sheet, row, 3, result?.note ?? '');
        _excelWrite(sheet, row, 4, '${photoMap[item.id] ?? 0}');
        row++;
      }
    }

    if (inspection.overallNote != null && inspection.overallNote!.isNotEmpty) {
      row++;
      _excelWrite(sheet, row, 0, '종합 의견', isBold: true);
      _excelWrite(sheet, row, 1, inspection.overallNote!);
    }

    // Column widths
    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 30);
    sheet.setColumnWidth(4, 8);

    final bytes = excel.save();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/점검표_${inspection.location}_${_df.format(inspection.createdAt)}.xlsx');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], subject: '현장 점검표');
  }

  void _excelWrite(
    Sheet sheet,
    int row,
    int col,
    String value, {
    bool isBold = false,
    double? fontSize,
    String? bgColor,
  }) {
    final cell =
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    cell.value = TextCellValue(value);
    final style = bgColor != null
        ? CellStyle(
            bold: isBold,
            fontSize: fontSize?.toInt(),
            backgroundColorHex: ExcelColor.fromHexString(bgColor),
          )
        : CellStyle(
            bold: isBold,
            fontSize: fontSize?.toInt(),
          );
    cell.cellStyle = style;
  }
}
