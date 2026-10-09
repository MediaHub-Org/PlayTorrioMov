import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../services/debrid/debrid_cache_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../widgets/settings/settings_scroll_view.dart';
import '../../services/theme/app_colors.dart';
import '../../services/tv_type.dart';
import '../../services/app_units.dart';

class DebridSettingsPage extends StatefulWidget {
  const DebridSettingsPage({super.key});

  @override
  State<DebridSettingsPage> createState() => _DebridSettingsPageState();
}

class _DebridSettingsPageState extends State<DebridSettingsPage> {
  final _debrid = DebridService();
  bool _useDebrid = false;
  String _selectedService = 'None';

  final _rdKeyCtrl = TextEditingController();
  final _torboxKeyCtrl = TextEditingController();
  final _alldebridKeyCtrl = TextEditingController();
  final _premiumizeKeyCtrl = TextEditingController();
  final _debridlinkKeyCtrl = TextEditingController();

  final Map<String, bool> _obscuredMap = {
    'Real-Debrid': true,
    'TorBox': true,
    'AllDebrid': true,
    'Premiumize': true,
    'Debrid-Link': true,
  };

  final Map<String, String?> _statusMap = {};
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  String _sanitizeKey(String raw) {
    var s = raw.trim();
    if (s.startsWith('Bearer ')) s = s.substring(7).trim();
    if ((s.startsWith('"') && s.endsWith('"')) || (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }

  Future<void> _loadSettings() async {
    final useDebrid = await _debrid.getUseDebridForStreams();
    final service = await _debrid.getSelectedService();
    final rd = await _debrid.realDebrid.getToken() ?? '';
    final tb = await _debrid.torBox.getKey() ?? '';
    final ad = await _debrid.allDebrid.getKey() ?? '';
    final pm = await _debrid.premiumize.getKey() ?? '';
    final dl = await _debrid.debridLink.getKey() ?? '';

    _rdKeyCtrl.text = rd;
    _torboxKeyCtrl.text = tb;
    _alldebridKeyCtrl.text = ad;
    _premiumizeKeyCtrl.text = pm;
    _debridlinkKeyCtrl.text = dl;

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _selectedService = service;
      });
    }

    // Verify existing keys in background
    if (rd.isNotEmpty) {
      _verifyKeySilent('Real-Debrid', rd);
    }
    if (tb.isNotEmpty) {
      _verifyKeySilent('TorBox', tb);
    }
    if (ad.isNotEmpty) {
      _verifyKeySilent('AllDebrid', ad);
    }
    if (pm.isNotEmpty) {
      _verifyKeySilent('Premiumize', pm);
    }
    if (dl.isNotEmpty) {
      _verifyKeySilent('Debrid-Link', dl);
    }
  }

  Future<void> _verifyKeySilent(String provider, String key) async {
    final cleaned = _sanitizeKey(key);
    if (cleaned.isEmpty) return;

    try {
      String? username;
      if (provider == 'Real-Debrid') {
        final res = await _debrid.realDebrid.verifyToken(cleaned);
        username = res?['username'] as String?;
      } else if (provider == 'TorBox') {
        final res = await _debrid.torBox.verifyKey(cleaned);
        username = (res?['email'] ?? res?['username']) as String?;
      } else if (provider == 'AllDebrid') {
        final res = await _debrid.allDebrid.verifyKey(cleaned);
        username = res?['username'] as String?;
      } else if (provider == 'Premiumize') {
        final res = await _debrid.premiumize.verifyKey(cleaned);
        username = res != null ? 'Connected' : null;
      } else if (provider == 'Debrid-Link') {
        final res = await _debrid.debridLink.verifyKey(cleaned);
        username = res?['username'] as String?;
      }

      if (mounted && username != null) {
        setState(() {
          _statusMap[provider] = username;
        });
      }
    } catch (_) {
      // The provider is connected either way -- this only decides whether the
      // account name is shown beside it.
    }
  }

  Future<void> _saveProviderKey(String provider, TextEditingController controller) async {
    final key = _sanitizeKey(controller.text);
    controller.text = key;

    setState(() {
      _loadingMap[provider] = true;
    });

    if (key.isNotEmpty) {
      // Save key
      if (provider == 'Real-Debrid') {
        await _debrid.realDebrid.saveToken(key);
      } else if (provider == 'TorBox') {
        await _debrid.torBox.saveKey(key);
      } else if (provider == 'AllDebrid') {
        await _debrid.allDebrid.saveKey(key);
      } else if (provider == 'Premiumize') {
        await _debrid.premiumize.saveKey(key);
      } else if (provider == 'Debrid-Link') {
        await _debrid.debridLink.saveKey(key);
      }

      // Auto-enable Debrid and set as active service
      await _debrid.saveUseDebridForStreams(true);
      await _debrid.saveSelectedService(provider);

      String? verifiedUser;
      if (provider == 'Real-Debrid') {
        final user = await _debrid.realDebrid.verifyToken(key);
        verifiedUser = user?['username'] as String?;
      } else if (provider == 'TorBox') {
        final user = await _debrid.torBox.verifyKey(key);
        verifiedUser = (user?['email'] ?? user?['username']) as String?;
      } else if (provider == 'AllDebrid') {
        final user = await _debrid.allDebrid.verifyKey(key);
        verifiedUser = user?['username'] as String?;
      } else if (provider == 'Premiumize') {
        final user = await _debrid.premiumize.verifyKey(key);
        verifiedUser = user != null ? 'Connected' : null;
      } else if (provider == 'Debrid-Link') {
        final user = await _debrid.debridLink.verifyKey(key);
        verifiedUser = user?['username'] as String?;
      }

      if (!mounted) return;
      setState(() {
        _useDebrid = true;
        _selectedService = provider;
        _statusMap[provider] = verifiedUser ?? 'Saved';
        _loadingMap[provider] = false;
      });

      if (verifiedUser != null) {
        _showSnack(
          context.l10n.debridKeyVerified(provider, verifiedUser),
        );
      } else {
        _showSnack(context.l10n.debridKeySaved(provider));
      }
    } else {
      // Clear key
      if (provider == 'Real-Debrid') {
        await _debrid.realDebrid.saveToken('');
      } else if (provider == 'TorBox') {
        await _debrid.torBox.saveKey('');
      } else if (provider == 'AllDebrid') {
        await _debrid.allDebrid.saveKey('');
      } else if (provider == 'Premiumize') {
        await _debrid.premiumize.saveKey('');
      } else if (provider == 'Debrid-Link') {
        await _debrid.debridLink.saveKey('');
      }

      if (_selectedService == provider) {
        await _debrid.saveSelectedService('None');
      }

      if (!mounted) return;
      setState(() {
        if (_selectedService == provider) _selectedService = 'None';
        _statusMap.remove(provider);
        _loadingMap[provider] = false;
      });

      _showSnack(context.l10n.debridKeyCleared(provider));
    }
  }

  Future<void> _pasteToController(TextEditingController controller) async {
    // Read before the await: the clipboard call is an async gap, and the
    // widget can be gone by the time it returns.
    final pastedMessage = context.l10n.debridPastedKey;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final sanitized = _sanitizeKey(data.text!);
      controller.text = sanitized;
      _showSnack(pastedMessage);
    }
  }

  @override
  void dispose() {
    _rdKeyCtrl.dispose();
    _torboxKeyCtrl.dispose();
    _alldebridKeyCtrl.dispose();
    _premiumizeKeyCtrl.dispose();
    _debridlinkKeyCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF00E5FF),
        action: SnackBarAction(
          label: context.l10n.debridDismiss,
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOn(context);
    final l10n = context.l10n;
    // The provider ids are storage keys and API identifiers, not labels:
    // `_selectedService` is persisted and compared with `==` throughout, so
    // only the display of 'None' is translated, never the value.
    const services = [
      'None',
      'Real-Debrid',
      'TorBox',
      'AllDebrid',
      'Premiumize',
      'Debrid-Link',
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.bar,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back_ios_rounded, size: context.rem(AppRem.icon)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.settingsCategoryDebrid,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: AppType.headline),
        ),
      ),
      body: SettingsScrollView(
        topPadding: 20,
        bottomPadding: 20,
        children: [
          // Header description
          Padding(
            padding: EdgeInsets.only(bottom: context.rem(1.25)),
            child: Text(
              l10n.debridIntro,
              style: TextStyle(
                fontSize: AppType.smallPlus,
                color: AppColors.inkAlpha(0.5),
                height: 1.4, // ratio: a line height, not a size
              ),
            ),
          ),

          // Master Debrid Toggle Card
          Container(
            padding: EdgeInsets.all(context.rem(1.125)),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
              border: Border.all(
                color: _useDebrid
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.35)
                    : AppColors.inkAlpha(0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: context.rem(2.75),
                      height: context.rem(2.75),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusMd)),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: const Color(0xFF00E5FF),
                        size: context.rem(AppRem.iconLg),
                      ),
                    ),
                    SizedBox(width: context.rem(0.875)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.debridMasterTitle,
                            style: const TextStyle(
                              fontSize: AppType.bodyLg,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: context.rem(AppRem.xs)),
                          Text(
                            l10n.debridMasterSubtitle,
                            style: TextStyle(
                              color: AppColors.inkSubtle,
                              fontSize: AppType.captionPlus,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.rem(AppRem.ms)),
                    Switch.adaptive(
                      value: _useDebrid,
                      activeColor: const Color(0xFF00E5FF),
                      onChanged: (val) async {
                        setState(() => _useDebrid = val);
                        await _debrid.saveUseDebridForStreams(val);
                        if (val) {
                          final service = _selectedService;
                          if (service == 'None') {
                            _showSnack(
                              l10n.debridSelectNone,
                              isError: true,
                            );
                          } else {
                            final hasKey = await _debrid.hasKeyForService(service);
                            if (!hasKey) {
                              _showSnack(
                                l10n.debridNoKeyFor(service),
                                isError: true,
                              );
                            } else {
                              _showSnack(l10n.debridActivatedVia(service));
                            }
                          }
                        } else {
                          _showSnack(l10n.debridDisabled);
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: context.rem(0.875)),
                Text(
                  l10n.debridMasterBody,
                  style: TextStyle(
                    color: AppColors.inkAlpha(0.45),
                    fontSize: AppType.caption,
                    height: 1.35, // ratio: a line height, not a size
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: context.rem(AppRem.lg)),

          // Active Provider Selector
          Text(
            l10n.debridActiveProviderHeader,
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(0.625)),

          Container(
            padding: EdgeInsets.all(context.rem(AppRem.md)),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
              border: Border.all(
                color: AppColors.inkAlpha(0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.debridSelectDefault,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: AppType.body,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: context.rem(AppRem.xs)),
                Text(
                  l10n.debridSelectDefaultBody,
                  style: TextStyle(
                    color: AppColors.inkAlpha(0.45),
                    fontSize: AppType.caption,
                  ),
                ),
                SizedBox(height: context.rem(AppRem.ms)),
                DropdownButtonFormField<String>(
                  value: services.contains(_selectedService) ? _selectedService : 'None',
                  dropdownColor: AppColors.raised,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bar,
                    contentPadding: EdgeInsets.symmetric(horizontal: context.rem(0.875), vertical: context.rem(AppRem.ms)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: BorderSide(color: AppColors.inkAlpha(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: BorderSide(color: AppColors.inkAlpha(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                  ),
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.body, fontWeight: FontWeight.w600),
                  items: services.map((s) {
                    return DropdownMenuItem<String>(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            s == 'None' ? Icons.block_rounded : Icons.flash_on_rounded,
                            size: context.rem(AppRem.iconXs),
                            color: s == 'None' ? AppColors.inkDisabled : const Color(0xFF00E5FF),
                          ),
                          SizedBox(width: context.rem(AppRem.sm)),
                          Text(s == 'None' ? l10n.debridNone : s),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _selectedService = val);
                      await _debrid.saveSelectedService(val);
                      // What one service has cached says nothing of another.
                      DebridCacheService.instance.clear();
                      if (val != 'None') {
                        final hasKey = await _debrid.hasKeyForService(val);
                        if (!hasKey) {
                          _showSnack(
                            l10n.debridSelectedNoKey(val),
                          );
                          return;
                        }
                      }
                      _showSnack(
                        l10n.debridActiveSetTo(
                          val == 'None' ? l10n.debridNone : val,
                        ),
                      );
                    }
                  },
                ),
                // Said where the choice is made, so nobody picks it expecting
                // the Cached badge and wonders why there is none.
                if (_selectedService == 'Real-Debrid') ...[
                  SizedBox(height: context.rem(AppRem.sm)),
                  Text(
                    l10n.debridNoCacheLookupNote,
                    style: TextStyle(
                      color: AppColors.inkSubtle,
                      fontSize: AppType.caption,
                      height: 1.35, // ratio: a line height, not a size
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: context.rem(AppRem.lg)),

          // Provider API Keys
          Text(
            l10n.debridCredentialsHeader,
            style: TextStyle(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w700,
              color: AppColors.inkAlpha(0.35),
              letterSpacing: 1.1,
            ),
          ),
          SizedBox(height: context.rem(0.625)),

          // Real-Debrid Card
          _buildProviderCard(
            name: 'Real-Debrid',
            subtitle: _statusMap['Real-Debrid'] != null
                ? l10n.debridLoggedInAs(_statusMap['Real-Debrid']!)
                : l10n.debridGetTokenRealDebrid,
            statusBadge: _statusMap['Real-Debrid'],
            badgeColor: const Color(0xFF10B981),
            controller: _rdKeyCtrl,
            isLoading: _loadingMap['Real-Debrid'] == true,
            isActive: _selectedService == 'Real-Debrid',
            onSave: () => _saveProviderKey('Real-Debrid', _rdKeyCtrl),
          ),
          SizedBox(height: context.rem(AppRem.ms)),

          // TorBox Card
          _buildProviderCard(
            name: 'TorBox',
            subtitle: _statusMap['TorBox'] != null
                ? l10n.debridAccount(_statusMap['TorBox']!)
                : l10n.debridGetKeyTorBox,
            statusBadge: _statusMap['TorBox'],
            badgeColor: const Color(0xFF10B981),
            controller: _torboxKeyCtrl,
            isLoading: _loadingMap['TorBox'] == true,
            isActive: _selectedService == 'TorBox',
            onSave: () => _saveProviderKey('TorBox', _torboxKeyCtrl),
          ),
          SizedBox(height: context.rem(AppRem.ms)),

          // AllDebrid Card
          _buildProviderCard(
            name: 'AllDebrid',
            subtitle: _statusMap['AllDebrid'] != null
                ? l10n.debridAccount(_statusMap['AllDebrid']!)
                : l10n.debridGetKeyAllDebrid,
            statusBadge: _statusMap['AllDebrid'],
            badgeColor: const Color(0xFF10B981),
            controller: _alldebridKeyCtrl,
            isLoading: _loadingMap['AllDebrid'] == true,
            isActive: _selectedService == 'AllDebrid',
            onSave: () => _saveProviderKey('AllDebrid', _alldebridKeyCtrl),
          ),
          SizedBox(height: context.rem(AppRem.ms)),

          // Premiumize Card
          _buildProviderCard(
            name: 'Premiumize',
            subtitle: _statusMap['Premiumize'] != null
                ? l10n.debridAccountConnected
                : l10n.debridGetKeyPremiumize,
            statusBadge: _statusMap['Premiumize'],
            badgeColor: const Color(0xFF10B981),
            controller: _premiumizeKeyCtrl,
            isLoading: _loadingMap['Premiumize'] == true,
            isActive: _selectedService == 'Premiumize',
            onSave: () => _saveProviderKey('Premiumize', _premiumizeKeyCtrl),
          ),
          SizedBox(height: context.rem(AppRem.ms)),

          // Debrid-Link Card
          _buildProviderCard(
            name: 'Debrid-Link',
            subtitle: _statusMap['Debrid-Link'] != null
                ? l10n.debridAccount(_statusMap['Debrid-Link']!)
                : l10n.debridGetKeyDebridLink,
            statusBadge: _statusMap['Debrid-Link'],
            badgeColor: const Color(0xFF10B981),
            controller: _debridlinkKeyCtrl,
            isLoading: _loadingMap['Debrid-Link'] == true,
            isActive: _selectedService == 'Debrid-Link',
            onSave: () => _saveProviderKey('Debrid-Link', _debridlinkKeyCtrl),
          ),
          SizedBox(height: context.rem(1.25)),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required String name,
    required String subtitle,
    required TextEditingController controller,
    required VoidCallback onSave,
    bool isActive = false,
    bool isLoading = false,
    String? statusBadge,
    Color? badgeColor,
  }) {
    final l10n = context.l10n;
    final isObscured = _obscuredMap[name] ?? true;

    return Container(
      padding: EdgeInsets.all(context.rem(AppRem.md)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(context.rem(AppRem.radiusLg)),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : AppColors.inkAlpha(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: AppType.bodyPlus,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isActive) ...[
                SizedBox(width: context.rem(AppRem.sm)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(AppRem.xxs)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                  ),
                  child: Text(
                    l10n.debridActiveBadge,
                    style: TextStyle(
                      fontSize: TvType.scale(AppType.micro),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                ),
              ],
              if (statusBadge != null) ...[
                SizedBox(width: context.rem(AppRem.sm)),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.sm), vertical: context.rem(AppRem.xxs)),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF10B981)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(context.rem(AppRem.snug)),
                  ),
                  child: Text(
                    statusBadge,
                    style: TextStyle(
                      fontSize: TvType.scale(AppType.micro),
                      fontWeight: FontWeight.w800,
                      color: badgeColor ?? const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: context.rem(0.1875)),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.inkAlpha(0.45),
              fontSize: AppType.tinyPlus,
            ),
          ),
          SizedBox(height: context.rem(0.625)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isObscured,
                  style: TextStyle(color: AppColors.ink, fontSize: AppType.small),
                  decoration: InputDecoration(
                    hintText: l10n.debridKeyHint,
                    hintStyle: TextStyle(
                      color: AppColors.inkAlpha(0.25),
                      fontSize: AppType.caption,
                    ),
                    filled: true,
                    fillColor: AppColors.bar,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.ms), vertical: context.rem(0.625)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: BorderSide(color: AppColors.inkAlpha(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: BorderSide(color: AppColors.inkAlpha(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill)),
                      borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (controller.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear_rounded, color: AppColors.inkDisabled, size: context.rem(AppRem.iconSm)),
                            tooltip: l10n.debridClear,
                            onPressed: () {
                              controller.clear();
                              setState(() {});
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppColors.inkDisabled,
                            size: context.rem(AppRem.iconSm),
                          ),
                          tooltip: isObscured ? l10n.debridShowKey : l10n.debridHideKey,
                          onPressed: () {
                            setState(() {
                              _obscuredMap[name] = !isObscured;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.content_paste_rounded, color: const Color(0xFF00E5FF), size: context.rem(AppRem.iconSm)),
                          tooltip: l10n.debridPasteClipboard,
                          onPressed: () => _pasteToController(controller),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.rem(0.625)),
              ElevatedButton(
                onPressed: isLoading ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: context.rem(AppRem.md), vertical: context.rem(0.625)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(context.rem(AppRem.radiusPill))),
                  elevation: 0,
                ),
                child: isLoading
                    ? SizedBox(
                        width: context.rem(AppRem.md),
                        height: context.rem(AppRem.md),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        l10n.debridSave,
                        style: const TextStyle(fontSize: AppType.captionPlus, fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
