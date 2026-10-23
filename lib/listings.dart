import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'common.dart';
import 'strings.dart';

const ptypes = ['flat', 'house', 'plot', 'shop', 'office', 'land', 'pg', 'other'];
const areaUnits = ['sqft', 'gaj', 'marla', 'bigha', 'acre'];

// ───────────────────────── Meri Listing tab ─────────────────────────

class MyListingsTab extends StatefulWidget {
  const MyListingsTab({super.key});

  @override
  State<MyListingsTab> createState() => _MyListingsTabState();
}

class _MyListingsTabState extends State<MyListingsTab> {
  late Future<List<Map<String, dynamic>>> _future = _load();
  String _filter = 'all';

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await db.from('pd_listings').select().eq('dealer_id', myId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _open(Map<String, dynamic> l) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ListingDetail(listing: l)));
    _refresh();
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ListingForm()));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: brandDeep,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(tr('addListing')),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return RefreshIndicator(onRefresh: _refresh, child: ErrorRetry(onRetry: _refresh));
          final all = snap.data!;
          final rows = _filter == 'all' ? all : all.where((l) => l['status'] == _filter).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 96),
              children: [
                ChoiceRow(
                  scroll: true,
                  values: const ['all', 'active', 'sold', 'hidden'],
                  selected: _filter,
                  labelOf: (v) {
                    final n = v == 'all' ? all.length : all.where((l) => l['status'] == v).length;
                    return '${tr(v)} ($n)';
                  },
                  onSelected: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  SizedBox(height: 400, child: EmptyState(tr('noListings')))
                else
                  for (final l in rows)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: ListingCard(l: l, onTap: () => _open(l)),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────── Detail ─────────────────────────

class ListingDetail extends StatefulWidget {
  const ListingDetail({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  State<ListingDetail> createState() => _ListingDetailState();
}

class _ListingDetailState extends State<ListingDetail> {
  late Map<String, dynamic> l = widget.listing;
  bool _busy = false;

  bool get _mine => l['dealer_id'] == myId;
  Map<String, dynamic>? get _dealer => _mine ? me.value : l['pd_dealers'] as Map<String, dynamic>?;

  Future<void> _setStatus(String s) async {
    setState(() => _busy = true);
    try {
      final row = await db.from('pd_listings').update({'status': s}).eq('id', l['id']).select().single();
      setState(() => l = row);
    } catch (_) {
      if (mounted) showMsg(context, tr('errNet'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => ListingForm(existing: l)));
    if (saved == true) {
      final row = await db.from('pd_listings').select().eq('id', l['id']).single();
      setState(() => l = row);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context)) return;
    setState(() => _busy = true);
    try {
      final photos = List<String>.from(l['photos'] ?? const []);
      if (photos.isNotEmpty) {
        try { await db.storage.from(photoBucket).remove(photos); } catch (_) {}
      }
      await db.from('pd_listings').delete().eq('id', l['id']);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, tr('errNet'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = List<String>.from(l['photos'] ?? const []);
    final place = [l['locality'], l['city']].where((e) => (e ?? '').toString().isNotEmpty).join(', ');
    final dealer = _dealer;
    final facts = <List<String>>[
      [tr('ptype'), tr(l['ptype'] ?? 'other')],
      [tr('purpose'), tr(l['purpose'] ?? 'sale')],
      if (l['area'] != null) [tr('area'), '${l['area']} ${tr(l['area_unit'] ?? 'sqft')}'],
      if (l['bedrooms'] != null) ['BHK', '${l['bedrooms']}'],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_mine) IconButton(tooltip: tr('edit'), icon: const Icon(Icons.edit_outlined), onPressed: _busy ? null : _edit),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SizedBox(
            height: 240,
            child: photos.isEmpty
                ? Container(color: softOrange, child: const Icon(Icons.home_work_outlined, size: 72, color: brandOrange))
                : PageView(
                    children: [
                      for (final p in photos)
                        Image.network(photoUrl(p), fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: softOrange,
                                child: const Icon(Icons.broken_image_outlined, color: brandOrange))),
                    ],
                  ),
          ),
          if (photos.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${photos.length} ${tr('photos')} →', textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(formatPrice(l['price'] as num?, l['purpose'] as String?),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: brandDeep)),
                    ),
                    if (_mine) statusPill(l['status'] ?? 'active'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 18, color: muted),
                    const SizedBox(width: 4),
                    Expanded(child: Text(place, style: const TextStyle(color: muted))),
                  ]),
                ],
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        for (final f in facts)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text(f[0], style: const TextStyle(color: muted))),
                              Text(f[1], style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                if ((l['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(tr('description'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(l['description'], style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
                const SizedBox(height: 18),
                if (!_mine && dealer != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('dealer'), style: const TextStyle(color: muted, fontWeight: FontWeight.w600)),
                          Text(dealer['firm'] ?? dealer['name'] ?? '',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          if (dealer['firm'] != null) Text(dealer['name'] ?? ''),
                          Text('${phoneLabel(dealer['phone'])} • ${dealer['city'] ?? ''}',
                              style: const TextStyle(color: muted)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: const Icon(Icons.call),
                                label: Text(tr('call')),
                                onPressed: () => callNumber(context, dealer['phone']),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.chat_outlined),
                                label: Text(tr('whatsapp')),
                                style: FilledButton.styleFrom(minimumSize: const Size(48, 50)),
                                onPressed: () => openWhatsApp(context, dealer['phone'],
                                    tr('waListing').replaceAll('{title}', l['title'] ?? '')),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E7A3C)),
                  icon: const Icon(Icons.share),
                  label: Text(tr('share')),
                  onPressed: () => shareOnWhatsApp(context, listingShareText(l, dealer)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(tr('shareAny')),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: listingShareText(l, dealer)));
                    if (context.mounted) showMsg(context, '✓');
                  },
                ),
                if (_mine) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (l['status'] != 'sold')
                        OutlinedButton(onPressed: _busy ? null : () => _setStatus('sold'), child: Text(tr('markSold'))),
                      if (l['status'] != 'active')
                        OutlinedButton(onPressed: _busy ? null : () => _setStatus('active'), child: Text(tr('markActive'))),
                      if (l['status'] != 'hidden')
                        OutlinedButton(onPressed: _busy ? null : () => _setStatus('hidden'), child: Text(tr('hide'))),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: badRed),
                        onPressed: _busy ? null : _delete,
                        child: Text(tr('delete')),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Add / Edit form ─────────────────────────

class ListingForm extends StatefulWidget {
  const ListingForm({super.key, this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<ListingForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, dynamic> e = widget.existing ?? {};
  late String _purpose = e['purpose'] ?? 'sale';
  late String _ptype = e['ptype'] ?? 'flat';
  late String _unit = e['area_unit'] ?? 'sqft';
  late int? _bhk = e['bedrooms'] as int?;
  late final _title = TextEditingController(text: e['title'] ?? '');
  late final _price = TextEditingController(text: e['price']?.toString() ?? '');
  late final _area = TextEditingController(text: e['area']?.toString() ?? '');
  late final _city = TextEditingController(text: e['city'] ?? me.value?['city'] ?? '');
  late final _locality = TextEditingController(text: e['locality'] ?? '');
  late final _desc = TextEditingController(text: e['description'] ?? '');
  late final List<String> _kept = List<String>.from(e['photos'] ?? const []);
  final List<XFile> _new = [];
  bool _busy = false;

  bool get _hasRooms => _ptype == 'flat' || _ptype == 'house';

  Future<void> _pick() async {
    final room = 8 - _kept.length - _new.length;
    if (room <= 0) return;
    try {
      final files = await ImagePicker().pickMultiImage(maxWidth: 1600, imageQuality: 75);
      setState(() => _new.addAll(files.take(room)));
    } catch (_) {
      if (mounted) showMsg(context, tr('errNet'));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final data = {
      'purpose': _purpose,
      'ptype': _ptype,
      'title': _title.text.trim(),
      'price': int.parse(_price.text.replaceAll(RegExp(r'\D'), '')),
      'area': _area.text.trim().isEmpty ? null : num.tryParse(_area.text.trim()),
      'area_unit': _area.text.trim().isEmpty ? null : _unit,
      'bedrooms': _hasRooms ? _bhk : null,
      'city': _city.text.trim(),
      'locality': _locality.text.trim().isEmpty ? null : _locality.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
    };
    try {
      String id;
      if (widget.existing == null) {
        final row = await db.from('pd_listings').insert({...data, 'dealer_id': myId}).select('id').single();
        id = row['id'] as String;
      } else {
        id = e['id'] as String;
        await db.from('pd_listings').update(data).eq('id', id);
      }

      // Photos: remove the ones taken out, upload new ones
      final removed = List<String>.from(e['photos'] ?? const []).where((p) => !_kept.contains(p)).toList();
      if (removed.isNotEmpty) {
        try { await db.storage.from(photoBucket).remove(removed); } catch (_) {}
      }
      final paths = [..._kept];
      var failed = false;
      for (var i = 0; i < _new.length; i++) {
        try {
          final bytes = await _new[i].readAsBytes();
          final path = '$myId/$id/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          await db.storage.from(photoBucket).uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );
          paths.add(path);
        } catch (_) {
          failed = true;
        }
      }
      await db.from('pd_listings').update({'photos': paths}).eq('id', id);
      if (!mounted) return;
      showMsg(context, failed ? tr('photoFail') : tr('saved'));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, tr('errNet'));
      }
    }
  }

  Widget _label(String k) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(tr(k), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? tr('addListing') : tr('editListing'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _label('purpose'),
            ChoiceRow(values: const ['sale', 'rent'], selected: _purpose,
                onSelected: (v) => setState(() => _purpose = v)),
            _label('ptype'),
            ChoiceRow(values: ptypes, selected: _ptype, onSelected: (v) => setState(() => _ptype = v)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('title')),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _purpose == 'rent' ? tr('priceRent') : tr('price'),
                helperText: _price.text.isEmpty ? null : formatPrice(int.tryParse(_price.text), _purpose),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => (v ?? '').isEmpty ? tr('errRequired') : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _area,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: tr('area')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ChoiceRow(values: areaUnits, selected: _unit, onSelected: (v) => setState(() => _unit = v)),
            if (_hasRooms) ...[
              _label('bhk'),
              ChoiceRow(
                values: const ['1', '2', '3', '4', '5'],
                selected: _bhk?.toString(),
                labelOf: (v) => v == '5' ? '5+ BHK' : '$v BHK',
                onSelected: (v) => setState(() => _bhk = int.parse(v)),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('city')),
              validator: (v) => (v ?? '').trim().isEmpty ? tr('errRequired') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locality,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: tr('locality')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('description'), alignLabelWithHint: true),
            ),
            _label('photos'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _kept)
                  _Thumb(image: Image.network(photoUrl(p), fit: BoxFit.cover),
                      onRemove: () => setState(() => _kept.remove(p))),
                for (final f in _new)
                  _Thumb(image: FutureBuilder<Uint8List>(
                    future: f.readAsBytes(),
                    builder: (_, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : const SizedBox(),
                  ), onRemove: () => setState(() => _new.remove(f))),
                if (_kept.length + _new.length < 8)
                  InkWell(
                    onTap: _pick,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: softOrange,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: brandOrange),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: brandDeep),
                          const SizedBox(height: 4),
                          Text(tr('addPhotos'), style: const TextStyle(fontSize: 12, color: brandDeep)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? tr('saving') : tr('save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.onRemove});
  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
          Positioned(
            right: 2,
            top: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
