// lib/widgets/collection/collection_picker_sheet.dart
import 'package:flutter/material.dart';

import '../../models/collection/media_collection.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/collections/media_collections_service.dart';
import '../../services/theme/app_colors.dart';

/// Picks which collections a title belongs to.
///
/// A checklist, not a single choice: a title can be in as many collections as
/// the user likes, which is the difference between this and Watchlist/Watched.
/// Tapping applies immediately — there is no Save button, because every row is
/// one reversible toggle and a confirm step would only add a way to lose the
/// change.
///
/// Creating happens here as well as in the Library, and deliberately: the
/// moment you most want a new collection is while holding a title that fits
/// none of the existing ones. Making someone leave, create, come back and find
/// the title again is the worst path through this feature. Renaming and
/// deleting are *not* here — they belong in the Library, where the collection
/// is the subject of the screen rather than an incidental row, and where you
/// can see what you are about to destroy.
class CollectionPickerSheet extends StatefulWidget {
  final MyListItem item;

  const CollectionPickerSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, MyListItem item) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CollectionPickerSheet(item: item),
    );
  }

  @override
  State<CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<CollectionPickerSheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _submitNew() {
    final created = MediaCollectionsService.create(_nameController.text);
    if (created == null) return; // Blank name; the field stays open.
    MediaCollectionsService.addItem(created.id, widget.item);
    _nameController.clear();
    setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    // Keeps the sheet clear of the keyboard while the new-collection field is
    // open, rather than the field hiding behind it.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.raised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.inkAlpha(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add to collection',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: AppColors.inkMuted,
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              _buildCreateRow(),
              Flexible(
                child: ValueListenableBuilder<List<MediaCollection>>(
                  valueListenable: MediaCollectionsService.collections,
                  builder: (context, collections, _) {
                    if (collections.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Text(
                          'No collections yet. Create one above and this title '
                          'goes straight into it.',
                          style: TextStyle(
                            color: AppColors.inkSubtle,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: collections.length,
                      itemBuilder: (context, i) =>
                          _buildRow(collections[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRow() {
    if (!_creating) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _creating = true);
            _nameFocus.requestFocus();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 12),
                Text(
                  'New collection',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitNew(),
              style: TextStyle(color: AppColors.ink, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Collection name',
                hintStyle: TextStyle(color: AppColors.inkSubtle, fontSize: 14),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.inkAlpha(0.18)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.inkAlpha(0.18)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: _submitNew, child: const Text('Create')),
        ],
      ),
    );
  }

  Widget _buildRow(MediaCollection collection) {
    final inIt = collection.contains(widget.item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (inIt) {
            MediaCollectionsService.removeItem(collection.id, widget.item);
          } else {
            MediaCollectionsService.addItem(collection.id, widget.item);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                inIt
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: inIt ? AppColors.accent : AppColors.inkMuted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.ink, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                collection.count == 1 ? '1 title' : '${collection.count} titles',
                style: TextStyle(color: AppColors.inkSubtle, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
