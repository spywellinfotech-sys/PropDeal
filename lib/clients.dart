import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'common.dart';
import 'listings.dart';
import 'strings.dart';

const kinds = ['buyer', 'seller', 'tenant'];

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

// ───────────────────────── Clients tab ─────────────────────────

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await db.from('pd_clients').select().eq('dealer_id', myId).order('created_at', ascending: false);
    final list = List<Map<String, dynamic>>.from(rows);
    // Open clients with the nearest follow-up first
    list.sort((a, b) {
      final ao = a['status'] == 'open' ? 0 : 1;
      final bo = b['status'] == 'open' ? 0 : 1;
      if (ao != bo) return ao - bo;
      final ad = _date(a['follow_up']);
      final bd = _date(b['follow_up']);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _openForm([Map<String, dynamic>? c]) async {
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ClientForm(existing: c)));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: brandDeep,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr('addClient')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return RefreshIndicator(onRefresh: _refresh, child: ErrorRetry(onRetry: _refresh));
          final all = snap.data!;
          final rows = _filter == 'all' ? all : all.where((c) => c['kind'] == _filter).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 96),
              children: [
                ChoiceRow(
                  scroll: true,
                  values: const ['all', ...kinds],
                  selected: _filter,
                  labelOf: (v) {
                    final n = v == 'all' ? all.length : all.where((c) => c['kind'] == v).length;
                    return '${tr(v)} ($n)';
                  },
                  onSelected: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  SizedBox(height: 360, child: EmptyState(tr('noClients'), icon: Icons.people_outline))
                else
                  for (final c in rows)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ClientCard(c: c, onTap: () => _openForm(c)),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.c, required this.onTap});
  final Map<String, dynamic> c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fu = _date(c['follow_up']);
    final today = _today();
    final open = c['status'] == 'open';
    Widget? fuPill;
    if (open && fu != null) {
      if (fu.isBefore(today)) {
        fuPill = Pill('${tr('overdue')} ${fmtDate(fu)}', bg: const Color(0xFFFBE5E1), fg: badRed);
      } else if (fu == today) {
        fuPill = Pill(tr('due'), bg: const Color(0xFFFFF3C4), fg: const Color(0xFF7A5600));
      } else {
        fuPill = Pill('${tr('followUp')} ${fmtDate(fu)}', bg: const Color(0xFFEDE7E3), fg: muted);
      }
    }
    final hasPhone = digits10(c['phone']).length == 10;
    final canMatch = c['kind'] != 'seller';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c['name'] ?? '',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  Pill(tr(c['kind'] ?? 'buyer')),
                ],
              ),
              if ((c['requirement'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(c['requirement'], maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted)),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (c['budget_max'] != null)
                    Pill(formatPrice(c['budget_max'] as num, c['kind'] == 'tenant' ? 'rent' : 'sale'),
                        bg: const Color(0xFFFFF3C4), fg: const Color(0xFF7A5600)),
                  if ((c['city'] ?? '').toString().isNotEmpty)
                    Pill(c['city'], bg: const Color(0xFFEDE7E3), fg: muted),
                  if (!open) Pill(tr(c['status']), bg: const Color(0xFFE1F2E6), fg: goodGreen),
                  if (fuPill != null) fuPill,
                ],
              ),
              if (hasPhone || canMatch) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (hasPhone) ...[
                      IconButton.filled(
                        tooltip: tr('call'),
                        style: IconButton.styleFrom(backgroundColor: brandDeep),
                        onPressed: () => callNumber(context, c['phone']),
                        icon: const Icon(Icons.call, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: tr('whatsapp'),
                        onPressed: () => openWhatsApp(context, c['phone'], ''),
                        icon: const Icon(Icons.chat_outlined),
                      ),
                    ],
                    const Spacer(),
                    if (canMatch)
                      TextButton.icon(
                        icon: const Icon(Icons.manage_search),
                        label: Text(tr('matches')),
                        onPressed: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => MatchesScreen(client: c))),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Add / Edit client ─────────────────────────

class ClientForm extends StatefulWidget {
  const ClientForm({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<ClientForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> e = widget.existing ?? {};
  late String _kind = e['kind'] ?? 'buyer';
  late String? _ptype = e['ptype'] as String?;
  late String _status = e['status'] ?? 'open';
  late DateTime? _follow = _date(e['follow_up']);
  late final _name = TextEditingController(text: e['name'] ?? '');
  late final _phone = TextEditingController(text: digits10(e['phone']));
  late final _city = TextEditingController(text: e['city'] ?? me.value?['city'] ?? '');
  late final _budget = TextEditingController(text: e['budget_max']?.toString() ?? '');
  late final _req = TextEditingController(text: e['requirement'] ?? '');
  bool _busy = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _follow ?? _today(),
      firstDate: _today().subtract(const Duration(days: 365)),
      lastDate: _today().add(const Duration(days: 730)),
    );
    if (d != null) setState(() => _follow = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final budget = _budget.text.replaceAll(RegExp(r'\D'), '');
    final data = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : digits10(_phone.text),
      'kind': _kind,
      'purpose': _kind == 'tenant' ? 'rent' : 'sale',
      'ptype': _ptype,
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'budget_max': budget.isEmpty ? null : int.parse(budget),
      'requirement': _req.text.trim().isEmpty ? null : _req.text.trim(),
      'follow_up': _follow == null
          ? null
          : '${_follow!.year}-${_follow!.month.toString().padLeft(2, '0')}-${_follow!.day.toString().padLeft(2, '0')}',
      'status': _status,
    };
    try {
      if (widget.existing == null) {
        await db.from('pd_clients').insert({...data, 'dealer_id': myId});
      } else {
        await db.from('pd_clients').update(data).eq('id', e['id']);
      }
      if (!mounted) return;
      showMsg(context, tr('saved'));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, tr('errNet'));
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context)) return;
    try {
      await db.from('pd_clients').delete().eq('id', e['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) showMsg(context, tr('errNet'));
    }
  }

  Widget _label(String k) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(tr(k), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? tr('addClient') : tr('editClient')),
        actions: [
          if (widget.existing != null)
            IconButton(tooltip: tr('delete'), icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _label('kind'),
            ChoiceRow(values: kinds, selected: _kind, onSelected: (v) => setState(() => _kind = v)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('clientName')),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('clientPhone'), prefixText: '+91 '),
              validator: (v) => (v ?? '').trim().isEmpty || isMobile(v) ? null : tr('errPhone'),
            ),
            _label('ptype'),
            ChoiceRow(
              values: ptypes,
              selected: _ptype,
              onSelected: (v) => setState(() => _ptype = _ptype == v ? null : v),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('city')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budget,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: tr('budget'),
                helperText: _budget.text.isEmpty
                    ? null
                    : formatPrice(int.tryParse(_budget.text), _kind == 'tenant' ? 'rent' : 'sale'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _req,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('requirement'), alignLabelWithHint: true),
            ),
            _label('followUp'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_follow == null ? tr('pickDate') : fmtDate(_follow!)),
                    onPressed: _pickDate,
                  ),
                ),
                if (_follow != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setState(() => _follow = null), child: Text(tr('clearDate'))),
                ],
              ],
            ),
            if (widget.existing != null) ...[
              _label('status'),
              ChoiceRow(values: const ['open', 'done', 'lost'], selected: _status,
                  onSelected: (v) => setState(() => _status = v)),
            ],
            const SizedBox(height: 28),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? tr('saving') : tr('save'))),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Matching listings ─────────────────────────

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key, required this.client});
  final Map<String, dynamic> client;

  Future<List<Map<String, dynamic>>> _load() async {
    var q = db
        .from('pd_listings')
        .select('*, pd_dealers(name, firm, phone, city)')
        .eq('status', 'active')
        .eq('purpose', client['kind'] == 'tenant' ? 'rent' : 'sale');
    if (client['ptype'] != null) q = q.eq('ptype', client['ptype']);
    final city = (client['city'] ?? '').toString().trim();
    if (city.isNotEmpty) q = q.ilike('city', '%$city%');
    if (client['budget_max'] != null) q = q.lte('price', client['budget_max']);
    final rows = await q.order('price', ascending: true).limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${tr('matches')}: ${client['name']}')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorRetry(onRetry: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => MatchesScreen(client: client))));
          }
          final rows = snap.data!;
          if (rows.isEmpty) return EmptyState(tr('noMatches'), icon: Icons.manage_search);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (final l in rows)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ListingCard(
                    l: l,
                    showDealer: l['dealer_id'] != myId,
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ListingDetail(listing: l))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
