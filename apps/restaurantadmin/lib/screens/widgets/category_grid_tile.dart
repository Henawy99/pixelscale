import 'package:flutter/material.dart';
import 'package:restaurantadmin/models/menu_category.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';

class CategoryGridTile extends StatelessWidget {
  final MenuCategory category;
  final List<MenuItem> items;
  final VoidCallback onOpenCategory;
  final void Function(MenuItem item) onEditItem;
  final int previewCount;

  const CategoryGridTile({
    super.key,
    required this.category,
    required this.items,
    required this.onOpenCategory,
    required this.onEditItem,
    this.previewCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpenCategory,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                    child: Text('${items.length} items', style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.loose,
                child: items.isEmpty
                    ? Center(child: Text('No items', style: TextStyle(color: Colors.grey[500])))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length > previewCount ? previewCount : items.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (ctx, i) {
                          final it = items[i];
                          return Row(
                            children: [
                              Expanded(child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('€${it.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit, size: 16),
                                onPressed: () => onEditItem(it),
                              )
                            ],
                          );
                        },
                      ),
              ),
              if (items.length > previewCount) Align(
                alignment: Alignment.centerRight,
                child: Text('+${items.length - previewCount} more', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

