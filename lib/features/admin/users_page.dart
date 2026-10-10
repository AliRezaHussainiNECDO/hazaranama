import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/donor_tiers.dart';
import '../../core/widgets.dart';
import '../../core/app_logo.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import 'user_detail_page.dart';

List<MapEntry<String, int>> _groupCount(List<UserProfile> users, String Function(UserProfile) key) {
  final map = <String, int>{};
  for (final u in users) {
    final k = key(u);
    map[k] = (map[k] ?? 0) + 1;
  }
  final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return list;
}

/// فهرست مدرن کاربران — آمار کلی، شکست جغرافیایی، جست‌وجو و فیلتر
/// وضعیت/نقش، و کارت‌های ردیف با حلقه‌ی مقام کمک‌کننده روی آواتار؛ لمس هر
/// ردیف پرونده‌ی کامل آن کاربر (با تاریخچه‌ی زنده‌ی فعالیت) را باز می‌کند.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final _query = TextEditingController();
  String _statusFilter = 'all'; // all | active | blocked
  String _roleFilter = 'all'; // all | admin | editor | user
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      await Future.wait([app.loadUsers(), app.loadDonorLeaderboard()]);
    } catch (_) {
      // شبکه در دسترس نیست؛ فهرست فعلی همچنان نمایش داده می‌شود
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.colors;
    final users = app.users;

    final active = users.where((u) => u.status == UserStatus.active).length;
    final blocked = users.where((u) => u.status == UserStatus.blocked).length;
    final donors = users.where((u) => app.donorTotalForUser(u.id) > 0).length;

    final byCountry = _groupCount(users, (u) => u.country);
    final byOrigin = _groupCount(users, (u) => u.originProvince);
    final byDistrict = _groupCount(users, (u) => u.district);

    final q = _query.text.trim().toLowerCase();
    var filtered = users.where((u) => q.isEmpty ||
        u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) ||
        u.country.toLowerCase().contains(q) || u.originProvince.toLowerCase().contains(q) || u.district.toLowerCase().contains(q)).toList();
    if (_statusFilter == 'active') filtered = filtered.where((u) => u.status == UserStatus.active).toList();
    if (_statusFilter == 'blocked') filtered = filtered.where((u) => u.status == UserStatus.blocked).toList();
    if (_roleFilter != 'all') filtered = filtered.where((u) => roleToDbValue(u.role) == _roleFilter).toList();
    // پرشورترین کمک‌کنندگان بالای فهرست بیایند — انگیزه‌ی بصری بیشتر برای مدیر
    filtered.sort((a, b) => app.donorTotalForUser(b.id).compareTo(app.donorTotalForUser(a.id)));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ثبت‌نام همیشه بلافاصله فعال می‌شود؛ نقش «مدیر» فقط از طریق ورود مستقیم با ایمیل مدیر در دسترس است. مسدودسازی صرفاً برای تخلف استفاده می‌شود.',
              style: TextStyle(color: theme.textFaint, fontSize: 12.5, height: 1.8)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1, padding: EdgeInsets.zero,
            children: [
              _statCard(theme, 'کل کاربران', users.length, Icons.groups, theme.blue),
              _statCard(theme, 'فعال', active, Icons.verified_user, theme.success),
              _statCard(theme, 'مسدود', blocked, Icons.block, theme.danger),
              _statCard(theme, 'کمک‌کننده', donors, Icons.volunteer_activism_rounded, theme.yellow),
            ],
          ),
          const SizedBox(height: 16),
          _breakdown(theme, 'کشور محل سکونت', Icons.public, byCountry, theme.blue),
          const SizedBox(height: 12),
          _breakdown(theme, 'ولایت/ریشه‌ی اصلی', Icons.map, byOrigin, theme.yellow),
          const SizedBox(height: 12),
          _breakdown(theme, 'ولسوالی', Icons.account_balance, byDistrict, theme.success),
          const SizedBox(height: 16),
          HzTextField(controller: _query, icon: Icons.search, hint: 'جست‌وجو بر اساس نام، ایمیل، کشور، ولایت یا ولسوالی…', theme: theme),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _FilterDropdown(theme: theme, value: _statusFilter, items: const {'all': 'همه‌ی وضعیت‌ها', 'active': 'فعال', 'blocked': 'مسدود'}, onChanged: (v) => setState(() => _statusFilter = v))),
            const SizedBox(width: 8),
            Expanded(child: _FilterDropdown(theme: theme, value: _roleFilter, items: const {'all': 'همه‌ی نقش‌ها', 'admin': 'مدیر', 'editor': 'ویراستار', 'user': 'کاربر'}, onChanged: (v) => setState(() => _roleFilter = v))),
          ]),
          const SizedBox(height: 14),
          if (_loading && users.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('کاربری با این مشخصات پیدا نشد.', style: TextStyle(color: theme.textFaint, fontSize: 12))))
          else
            for (final (i, u) in filtered.indexed) ...[
              _UserRow(theme: theme, user: u, donorTotalUsd: app.donorTotalForUser(u.id),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserDetailPage(userId: u.id)))).staggered(i, step: const Duration(milliseconds: 30)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _statCard(theme, String label, int value, IconData icon, Color color) =>
      HzStatTile(theme: theme, icon: icon, color: color, value: '$value', label: label);

  Widget _breakdown(theme, String title, IconData icon, List<MapEntry<String, int>> rows, Color color) {
    final maxV = rows.isEmpty ? 1 : rows.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          StatIconBox(icon: icon, color: color, size: 26),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        for (final e in rows.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(e.key, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                Text('${e.value}', style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: e.value / maxV, minHeight: 5, backgroundColor: theme.bgCardAlt, valueColor: AlwaysStoppedAnimation(color)),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final AppColors theme;
  final String value;
  final Map<String, String> items;
  final void Function(String) onChanged;
  const _FilterDropdown({required this.theme, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.glassBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: theme.bgElevated,
          icon: Icon(Icons.expand_more, size: 16, color: theme.textFaint),
          style: TextStyle(fontFamily: 'Vazirmatn', color: theme.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w700),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) => onChanged(v ?? 'all'),
        ),
      ),
    );
  }
}

/// یک ردیف کاربر در فهرست — آواتار با حلقه‌ی مقام کمک‌کننده، نام، نشان
/// نقش، وضعیت، و خلاصه‌ی زادگاه.
class _UserRow extends StatelessWidget {
  final AppColors theme;
  final UserProfile user;
  final double donorTotalUsd;
  final VoidCallback onTap;
  const _UserRow({required this.theme, required this.user, required this.donorTotalUsd, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tier = donorTierForUser(user, donorTotalUsd);
    final statusColor = user.status == UserStatus.active ? theme.success : theme.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: theme.bgCard.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.glassBorder)),
        child: Row(children: [
          DonorRing(
            theme: theme, tier: tier, size: 52, childSize: 40,
            child: HzBadge(theme: theme, size: 40, filled: true, avatarPath: user.avatarPath,
                child: Text(user.name.isNotEmpty ? user.name[0] : '؟', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(user.name, style: TextStyle(color: theme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (user.role != UserRole.user) ...[
                  const SizedBox(width: 6),
                  _tinyPill(user.role == UserRole.admin ? theme.yellow : theme.blue, roleLabel(user.role)),
                ],
              ]),
              const SizedBox(height: 3),
              Text('${user.country} · ${user.originProvince}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textFaint, fontSize: 11.5)),
              if (tier != null) ...[
                const SizedBox(height: 4),
                DonorTierChip(tier: tier),
              ],
            ]),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(user.status == UserStatus.active ? 'فعال' : 'مسدود', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          Icon(Icons.keyboard_arrow_left_rounded, size: 18, color: theme.textFaint),
        ]),
      ),
    );
  }

  Widget _tinyPill(Color color, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}
