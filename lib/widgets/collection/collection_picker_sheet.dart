// lib/widgets/collection/collection_picker_sheet.dart
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

import '../../models/collection/media_collection.dart';
import '../../models/my_list/my_list_item.dart';
import '../../services/collections/media_collections_service.dart';
import '../../services/theme/app_colors.dart';
import '../../utils/navigation/adaptive_sheet.dart';
import '../../services/app_units.dart';

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
    return showAdaptiveSheet<void>(
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
          margin: EdgeInsets.fromLTRB(context.rem(AppRem.ms), context.rem(AppRem.sm), context.rem(AppRem.ms), context.rem(AppRem.ms)),
          decoration: BoxDecoration(
            color: AppColors.raised,
            borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
            border: Border.all(color: AppColors.inkAlpha(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.rem(AppRem.md), context.rem(AppRem.md), context.rem(AppRem.md), context.rem(AppRem.sm)),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      color: AppColors.accent,
                      size: context.rem(AppRem.icon),
                    ),
                    SizedBox(width: context.rem(0.625)),
                    Expanded(
                      child: Text(
                        context.l10n.libraryAddToCollection,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: AppType.bodyMd,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: context.rem(AppRem.iconSm)),
                      color: AppColors.inkMuted,
                      tooltip: context.l10n.playerClose,
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
                        padding: EdgeInsets.fromLTRB(context.rem(AppRem.md), context.rem(AppRem.sm), context.rem(AppRem.md), context.rem(AppRem.lg)),
                        child: Text(
                          context.l10n.libraryNoCollectionsYet,
                          style: TextStyle(
                            color: AppColors.inkSubtle,
                            fontSize: AppType.small,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: context.rem(AppRem.sm)),
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
            padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.ms)),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: AppColors.accent, size: context.rem(AppRem.icon)),
                SizedBox(width: context.rem(AppRem.ms)),
                Text(
                  context.l10n.libraryNewCollection,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: AppType.body,
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
      padding: EdgeInsets.fromLTRB(context.rem(AppRem.md), context.rem(AppRem.xs), context.rem(AppRem.md), context.rem(AppRem.ms)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitNew(),
              style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
              decoration: InputDecoration(
                hintText: context.l10n.libraryCollectionNameHint,
                hintStyle: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.body),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: context.rem(AppRem.ms),
                  vertical: context.rem(0.625),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                  borderSide: BorderSide(color: AppColors.inkAlpha(0.18)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.rem(AppRem.radiusSm)),
                  borderSide: BorderSide(color: AppColors.inkAlpha(0.18)),
                ),
              ),
            ),
          ),
          SizedBox(width: context.rem(AppRem.sm)),
          TextButton(onPressed: _submitNew, child: Text(context.l10n.libraryCreate)),
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
          padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(AppRem.ms)),
          child: Row(
            children: [
              Icon(
                inIt
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: inIt ? AppColors.accent : AppColors.inkMuted,
                size: context.rem(AppRem.iconMd),
              ),
              SizedBox(width: context.rem(AppRem.ms)),
              Expanded(
                child: Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.body),
                ),
              ),
              SizedBox(width: context.rem(AppRem.sm)),
              Text(
                collection.count == 1 ? '1 title' : '${collection.count} titles',
                style: TextStyle(color: AppColors.inkSubtle, fontSize: AppType.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
