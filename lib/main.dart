import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:reorderables/reorderables.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MyApplication());
}

class MyApplication extends StatelessWidget {
  const MyApplication({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeActivity(),
    );
  }
}

class HomeActivity extends StatelessWidget {
  const HomeActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <_HomeAction>[
      _HomeAction(
        label: 'Merge PDFs',
        icon: Icons.merge_type,
        color: Colors.indigo,
        builder: (_) => const MergePage(),
      ),
      _HomeAction(
        label: 'Split by Pages',
        icon: Icons.content_cut,
        color: Colors.teal,
        builder: (_) => const SplitPage(),
      ),
      _HomeAction(
        label: 'Reduce Size',
        icon: Icons.compress,
        color: Colors.orange,
        builder: (_) => const CompressPage(),
      ),
      _HomeAction(
        label: 'Image to PDF',
        icon: Icons.picture_as_pdf,
        color: Colors.cyanAccent,
        builder: (_) => ImageToPdfPage(),
      ),
      _HomeAction(
        label: 'Preview (local path)',
        icon: Icons.picture_as_pdf,
        color: Colors.pink,
        builder: (_) => const ViewerHintPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Toolbox'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: actions
                .map(
                  (a) => _ActionCard(
                label: a.label,
                icon: a.icon,
                color: a.color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: a.builder),
                ),
              ),
            )
                .toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tips',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Each tool opens its own page.\n'
                '• Files are saved inside the app’s Documents directory.\n'
                '• Split supports ranges like 1,3-5,8 or “all”.\n'
                '• Compress does safe re-save & form/annotation flatten where possible.',
          ),
        ],
      ),
    );
  }
}

class _HomeAction {
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  _HomeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class _ActionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 170,
        height: 110,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- Utilities ----------------------------- */

Future<Directory> _appDocsDir() async => getApplicationDocumentsDirectory();

Future<String> _outputPath(String rawName) async {
  final dir = await _appDocsDir();
  final safe = rawName.trim().isEmpty ? 'output' : rawName.trim();
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '${dir.path}/$safe-$ts.pdf';
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/* ----------------------------- Merge Page ---------------------------- */

class MergePage extends StatefulWidget {
  const MergePage({super.key});

  @override
  State<MergePage> createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  final _nameCtrl = TextEditingController(text: 'merged');
  List<File> _files = [];

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _files = result.paths.whereType<String>().map((e) => File(e)).toList();
      });
    }
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      _toast(context, 'Pick at least two PDFs to merge.');
      return;
    }
    final PdfDocument out = PdfDocument();
    try {
      for (final f in _files) {
        final bytes = await f.readAsBytes();
        final PdfDocument src = PdfDocument(inputBytes: bytes);
        for (int i = 0; i < src.pages.count; i++) {
          final page = out.pages.add();
          final tpl = src.pages[i].createTemplate();
          page.graphics.drawPdfTemplate(
            tpl,
            const Offset(0, 0),
            Size(page.size.width, page.size.height),
          );
        }
        src.dispose();
      }
      out.fileStructure.incrementalUpdate = false;
      final Uint8List outBytes = Uint8List.fromList(await out.save());
      final path = await _outputPath(_nameCtrl.text);
      await File(path).writeAsBytes(outBytes, flush: true);
      _toast(context, 'Saved: ${path.split('/').last}');
      await OpenFilex.open(path);
    } catch (e) {
      _toast(context, 'Merge failed: $e');
    } finally {
      out.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationScaffold(
      title: 'Merge PDFs',
      onPick: _pick,
      files: _files,
      nameCtrl: _nameCtrl,
      actionLabel: 'Merge & Save',
      onRun: _merge,
    );
  }
}

/* ------------------------------ Split Page --------------------------- */

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  final _nameCtrl = TextEditingController(text: 'split');
  final _rangeCtrl = TextEditingController(); // filled after picking
  File? _file;
  int _pageCount = 0;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final f = File(result.files.single.path!);
      final bytes = await f.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      setState(() {
        _file = f;
        _pageCount = doc.pages.count;
        _rangeCtrl.text = '1-$_pageCount';
      });
      doc.dispose();
    }
  }

  List<int> _parseRanges(String input, int maxPages) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed == 'all') {
      return List<int>.generate(maxPages, (i) => i + 1);
    }
    final pages = <int>{};
    for (final part in trimmed.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (p.contains('-')) {
        final bits = p.split('-');
        if (bits.length == 2) {
          final start = int.tryParse(bits[0].trim());
          final end = int.tryParse(bits[1].trim());
          if (start != null && end != null && start >= 1 && end <= maxPages && start <= end) {
            for (int i = start; i <= end; i++) pages.add(i);
          }
        }
      } else {
        final n = int.tryParse(p);
        if (n != null && n >= 1 && n <= maxPages) pages.add(n);
      }
    }
    final list = pages.toList()..sort();
    return list;
  }

  Future<void> _split() async {
    if (_file == null) {
      _toast(context, 'Pick a PDF first.');
      return;
    }
    final srcBytes = await _file!.readAsBytes();
    final PdfDocument src = PdfDocument(inputBytes: srcBytes);
    final total = src.pages.count;
    final ranges = _parseRanges(_rangeCtrl.text, total);
    if (ranges.isEmpty) {
      _toast(context, 'Invalid page ranges.');
      src.dispose();
      return;
    }
    final PdfDocument out = PdfDocument();
    try {
      for (final pageNo in ranges) {
        final tpl = src.pages[pageNo - 1].createTemplate();
        final newPage = out.pages.add();
        newPage.graphics.drawPdfTemplate(
          tpl,
          const Offset(0, 0),
          Size(newPage.size.width, newPage.size.height),
        );
      }
      out.fileStructure.incrementalUpdate = false;
      final bytes = await out.save();
      final path = await _outputPath(_nameCtrl.text);
      await File(path).writeAsBytes(bytes, flush: true);
      _toast(context, 'Saved: ${path.split('/').last}');
      await OpenFilex.open(path);
    } catch (e) {
      _toast(context, 'Split failed: $e');
    } finally {
      out.dispose();
      src.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationScaffold(
      title: 'Split by Pages',
      onPick: _pick,
      files: _file == null ? [] : [_file!],
      nameCtrl: _nameCtrl,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pageCount > 0) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Total pages: $_pageCount'),
          ),
          TextField(
            controller: _rangeCtrl,
            decoration: const InputDecoration(
              labelText: 'Page ranges (e.g., 1,3-5,8 or all)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actionLabel: 'Split & Save',
      onRun: _split,
    );
  }
}

/* ---------------------------- Compress Page -------------------------- */

class CompressPage extends StatefulWidget {
  const CompressPage({super.key});

  @override
  State<CompressPage> createState() => _CompressPageState();
}

class _CompressPageState extends State<CompressPage> {
  final _nameCtrl = TextEditingController(text: 'compressed');
  File? _file;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = File(result.files.single.path!));
    }
  }

  Future<void> _compress() async {
    if (_file == null) {
      _toast(context, 'Pick a PDF first.');
      return;
    }
    final bytes = await _file!.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);
    try {
      // Best-effort: flatten forms & annotations; re-save without incremental updates.
      try {
        if (doc.form != null) {
          doc.form!.setDefaultAppearance(false);
          doc.form!.flattenAllFields();
        }
      } catch (_) {}

      doc.fileStructure.incrementalUpdate = false;

      final outBytes = await doc.save();
      final path = await _outputPath(_nameCtrl.text);
      await File(path).writeAsBytes(outBytes, flush: true);
      _toast(context, 'Saved: ${path.split('/').last}');
      await OpenFilex.open(path);
    } catch (e) {
      _toast(context, 'Compression failed: $e');
    } finally {
      doc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OperationScaffold(
      title: 'Reduce Size',
      onPick: _pick,
      files: _file == null ? [] : [_file!],
      nameCtrl: _nameCtrl,
      actionLabel: 'Compress & Save',
      onRun: _compress,
    );
  }
}

/* ------------------------- Shared Operation UI ----------------------- */

class _OperationScaffold extends StatelessWidget {
  final String title;
  final VoidCallback onPick;
  final List<File> files;
  final TextEditingController nameCtrl;
  final String actionLabel;
  final VoidCallback onRun;
  final Widget? extra;

  const _OperationScaffold({
    super.key,
    required this.title,
    required this.onPick,
    required this.files,
    required this.nameCtrl,
    required this.actionLabel,
    required this.onRun,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.indigo, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(Icons.add, size: 56, color: Colors.indigo),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (files.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text(files[i].path.split(Platform.pathSeparator).last),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No files selected yet. Tap + to add.'),
                ),
              ),

            if (extra != null) ...[
              const SizedBox(height: 12),
              extra!,
            ],

            const SizedBox(height: 12),

            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Output PDF name (without .pdf)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onRun,
                icon: const Icon(Icons.download),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Image to PDF ------------------------*/
class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  _ImageToPdfPageState createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];
  TextEditingController _pdfNameController = TextEditingController();

  // Pick multiple images
  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null) {
      setState(() {
        _images.addAll(pickedFiles.map((e) => File(e.path)).toList());
      });
    }
  }

  // Create PDF
  Future<void> _createPdf() async {
    if (_images.isEmpty) return;

    final pdf = pw.Document();

    for (var img in _images) {
      final image = pw.MemoryImage(img.readAsBytesSync());
      pdf.addPage(pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        },
      ));
    }

    // Ask user if they want to pick a folder or file name
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Save PDF"),
        content: Text("Do you want to choose a folder or directly name the file?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "folder"),
            child: Text("Choose Folder"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "file"),
            child: Text("Save As File"),
          ),
        ],
      ),
    );

    if (choice == "folder") {
      // Folder picker
      String? outputDir = await FilePicker.platform.getDirectoryPath();
      if (outputDir != null) {
        final fileName = _pdfNameController.text.isEmpty
            ? "MyPDF"
            : _pdfNameController.text;
        final filePath = "$outputDir/$fileName.pdf";
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved at $filePath")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No folder selected")),
        );
      }
    } else if (choice == "file") {
      // Save as file (like before)
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF As...',
        fileName: "${_pdfNameController.text.isEmpty ? "MyPDF" : _pdfNameController.text}.pdf",
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsBytes(await pdf.save());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved at $outputPath")),
        );
      }
    }
  }


  // Reorder logic
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Image to PDF"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _pdfNameController,
              decoration: InputDecoration(
                labelText: "Enter PDF Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _images.isEmpty
                  ? Center(
                child: Text(
                  "No images selected",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ReorderableWrap(
                spacing: 10,
                runSpacing: 10,
                onReorder: _onReorder,
                children: _images
                    .asMap()
                    .map((index, file) => MapEntry(
                  index,
                  Container(
                    key: ValueKey(index),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.file(
                            file,
                            width: 120,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _images.removeAt(index);
                                });
                              },
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ))
                    .values
                    .toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Button Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: Icon(Icons.add_photo_alternate),
                  label: Text("Add Images"),
                ),
                ElevatedButton.icon(
                  onPressed: _createPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text("Create PDF"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------- Viewer Page --------------------------- */

class ViewerHintPage extends StatefulWidget {
  const ViewerHintPage({super.key});

  @override
  State<ViewerHintPage> createState() => _ViewerHintPageState();
}

class _ViewerHintPageState extends State<ViewerHintPage> {
  final ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview a Local PDF')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Enter full path of a local PDF to preview',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ctrl.text.trim().isEmpty
                  ? const Center(child: Text('Enter a local path above to preview.'))
                  : SfPdfViewer.file(File(ctrl.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}
