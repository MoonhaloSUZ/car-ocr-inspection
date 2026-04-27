import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/template_provider.dart';
import '../models/checklist_template.dart';
import '../utils/theme.dart';

class TemplateEditorScreen extends StatelessWidget {
  const TemplateEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('점검표 편집'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: '분류 추가',
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
      ),
      body: const _TemplateEditorBody(),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '분류명'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<TemplateProvider>().addCategory(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _TemplateEditorBody extends StatelessWidget {
  const _TemplateEditorBody();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TemplateProvider>();
    final categories = provider.categories;

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('분류가 없습니다', style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddCategoryDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('분류 추가'),
            ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      onReorder: (oldIndex, newIndex) =>
          provider.reorderCategories(oldIndex, newIndex),
      itemBuilder: (ctx, index) {
        final cat = categories[index];
        return _CategoryCard(key: ValueKey(cat.id), category: cat);
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '분류명'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<TemplateProvider>().addCategory(ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ChecklistCategory category;

  const _CategoryCard({super.key, required this.category});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = true;

  void _editCategory() {
    final ctrl = TextEditingController(text: widget.category.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 이름 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '분류명'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<TemplateProvider>()
                    .updateCategory(widget.category.id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('분류 삭제'),
        content:
            Text('"${widget.category.title}" 분류와 포함된 모든 항목이 삭제됩니다. 계속할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              context
                  .read<TemplateProvider>()
                  .deleteCategory(widget.category.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${widget.category.title}" 항목 추가'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '항목명'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<TemplateProvider>()
                    .addItem(widget.category.id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          // Category header
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.07),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(12),
                bottom: _expanded ? Radius.zero : const Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: context
                      .read<TemplateProvider>()
                      .categories
                      .indexOf(category),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        category.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  '${category.items.length}개',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editCategory();
                    if (v == 'add') _addItem();
                    if (v == 'delete') _deleteCategory();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('이름 수정'),
                        ])),
                    const PopupMenuItem(
                        value: 'add',
                        child: Row(children: [
                          Icon(Icons.add, size: 16),
                          SizedBox(width: 8),
                          Text('항목 추가'),
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('분류 삭제', style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          // Items
          if (_expanded)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.items.length,
              onReorder: (old, newIdx) => context
                  .read<TemplateProvider>()
                  .reorderItems(category.id, old, newIdx),
              itemBuilder: (ctx, idx) {
                final item = category.items[idx];
                return _ItemTile(
                  key: ValueKey(item.id),
                  item: item,
                  isLast: idx == category.items.length - 1,
                );
              },
            ),

          // Add item button
          if (_expanded)
            InkWell(
              onTap: _addItem,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '항목 추가',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ChecklistItem item;
  final bool isLast;

  const _ItemTile({super.key, required this.item, required this.isLast});

  void _editItem(BuildContext context) {
    final ctrl = TextEditingController(text: item.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '항목명'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context
                    .read<TemplateProvider>()
                    .updateItem(item.id, ctrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('항목 삭제'),
        content: Text('"${item.title}" 항목을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              context.read<TemplateProvider>().deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: context
                .read<TemplateProvider>()
                .categories
                .expand((c) => c.items)
                .toList()
                .indexOf(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Icon(Icons.drag_handle,
                  color: Colors.grey.shade400, size: 18),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(item.title, style: const TextStyle(fontSize: 14)),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: Colors.grey.shade500),
            onPressed: () => _editItem(context),
            tooltip: '수정',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: Colors.red.shade300),
            onPressed: () => _deleteItem(context),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }
}
