// Attributes tab for the SVG editor: Blender / Maya-style physical properties
// (material type, mass, density, viscosity, friction, bounciness, ...) plus
// user-defined custom attributes (Maya "Add Attribute").
//
// Everything is stored on the node as `data-*` attributes, so it travels with
// doc.toSvg() into the timeline and is ignored by flutter_svg when rendering.
// Read it back anywhere with:  node.physicsJson()

import 'package:flutter/material.dart';
import 'package:flutter_video_editor/core/models/svg_model.dart';

const _accent = Color(0xFF2DE2D0);
const _field = Color(0xFF2A2A2A);
const _lbl = TextStyle(color: Color(0xFFB4B4B4), fontSize: 11, fontFamily: 'Ubuntu');
const _strong = TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Ubuntu');

String _fmt(double v) {
  var s = v.toStringAsFixed(3);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

// ───────────────────────── MODEL ─────────────────────────

class _Preset {
  const _Preset(this.name, this.density,
      {this.friction = 0.5, this.bounce = 0.3, this.viscosity = 1, this.tension = 0.072, this.stiffness = 0.5});
  final String name;
  final double density, friction, bounce, viscosity, tension, stiffness;
}

enum PhysMaterial {
  solid('solid', 'Solid', Icons.crop_square, [
    _Preset('Wood', 700, friction: .5, bounce: .3),
    _Preset('Steel', 7850, friction: .6, bounce: .2),
    _Preset('Stone', 2700, friction: .7, bounce: .1),
    _Preset('Glass', 2500, friction: .4, bounce: .1),
    _Preset('Rubber', 1100, friction: .9, bounce: .8),
    _Preset('Foam', 50, friction: .6, bounce: .2),
  ]),
  rigid('rigid', 'Rigid body', Icons.sports_basketball_outlined, [
    _Preset('Wood', 700, friction: .5, bounce: .3),
    _Preset('Steel', 7850, friction: .6, bounce: .2),
    _Preset('Rubber', 1100, friction: .9, bounce: .8),
    _Preset('Glass', 2500, friction: .4, bounce: .1),
    _Preset('Foam', 50, friction: .6, bounce: .2),
  ]),
  soft('soft', 'Soft body', Icons.bubble_chart_outlined, [
    _Preset('Jelly', 1050, bounce: .6, stiffness: .25),
    _Preset('Rubber', 1100, bounce: .8, stiffness: .6),
    _Preset('Sponge', 80, bounce: .3, stiffness: .35),
  ]),
  liquid('liquid', 'Liquid', Icons.water_drop_outlined, [
    _Preset('Water', 1000, viscosity: 1, tension: .072, bounce: 0),
    _Preset('Oil', 900, viscosity: 60, tension: .032, bounce: 0),
    _Preset('Honey', 1400, viscosity: 10000, tension: .07, bounce: 0),
    _Preset('Lava', 2600, viscosity: 100000, tension: .4, bounce: 0),
  ]),
  gas('gas', 'Gas / smoke', Icons.cloud_outlined, [
    _Preset('Air', 1.2, bounce: 0),
    _Preset('Smoke', 1.1, bounce: 0),
    _Preset('Steam', .6, bounce: 0),
    _Preset('Helium', .18, bounce: 0),
  ]),
  cloth('cloth', 'Cloth', Icons.checkroom_outlined, [
    _Preset('Cotton', 1500, stiffness: .5),
    _Preset('Silk', 1340, stiffness: .2),
    _Preset('Leather', 900, stiffness: .8),
  ]);

  const PhysMaterial(this.id, this.label, this.icon, this.presets);
  final String id, label;
  final IconData icon;
  final List<_Preset> presets;

  static PhysMaterial? byId(String? id) {
    for (final m in values) {
      if (m.id == id) return m;
    }
    return null;
  }
}

extension SvgPhysics on SvgNode {
  bool get hasPhysics => attrs.containsKey('data-material');
  PhysMaterial? get material => PhysMaterial.byId(attrs['data-material']);

  double phys(String k, double def) => double.tryParse(attrs['data-$k'] ?? '') ?? def;
  bool physFlag(String k, bool def) => (attrs['data-$k'] ?? '$def') == 'true';
  void setPhys(String k, Object v) => attrs['data-$k'] = v is double ? _fmt(v) : '$v';

  void clearPhysics() => attrs.removeWhere((k, _) => k.startsWith('data-') && !k.startsWith('data-attr-'));

  /// Everything the video engine needs: {material, mass, density, ..., custom: {...}}
  Map<String, Object?> physicsJson() {
    final out = <String, Object?>{};
    final custom = <String, Object?>{};
    attrs.forEach((k, v) {
      if (!k.startsWith('data-')) return;
      final key = k.substring(5);
      Object? val = v;
      if (v == 'true' || v == 'false') {
        val = v == 'true';
      } else if (double.tryParse(v) != null) {
        val = double.parse(v);
      }
      if (key.startsWith('attr-')) {
        custom[key.substring(5)] = val;
      } else {
        out[key] = val;
      }
    });
    if (custom.isNotEmpty) out['custom'] = custom;
    return out;
  }
}

// ───────────────────────── PANEL ─────────────────────────

class SvgAttributesPanel extends StatelessWidget {
  const SvgAttributesPanel({super.key, required this.node, required this.edit, required this.live, required this.snap});

  final SvgNode node;
  final void Function(VoidCallback) edit; // snapshot + mutate
  final void Function(VoidCallback) live; // mutate only (sliders)
  final VoidCallback snap;

  void _setMaterial(PhysMaterial? m) => edit(() {
        if (m == null) {
          node.clearPhysics();
          return;
        }
        node.setPhys('material', m.id);
        _applyPreset(m.presets.first);
        void d(String k, double v) => node.attrs.putIfAbsent('data-$k', () => _fmt(v));
        d('mass', 1);
        d('gravity', m == PhysMaterial.gas ? 0 : 1);
        d('drag', .1);
        d('damping', .1);
        d('buoyancy', .5);
        d('dissipation', .1);
        d('turbulence', .2);
        node.attrs.putIfAbsent('data-collision', () => m == PhysMaterial.solid || m == PhysMaterial.rigid ? 'true' : 'false');
        if (m == PhysMaterial.solid) node.setPhys('static', 'true');
      });

  void _applyPreset(_Preset p) {
    node.setPhys('density', p.density);
    node.setPhys('friction', p.friction);
    node.setPhys('bounce', p.bounce);
    node.setPhys('viscosity', p.viscosity);
    node.setPhys('tension', p.tension);
    node.setPhys('stiffness', p.stiffness);
  }

  @override
  Widget build(BuildContext context) {
    final m = node.material;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 16), children: [
      _section('Material type'),
      SizedBox(
        height: 34,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _chip('None', Icons.block, m == null, () => _setMaterial(null)),
          for (final k in PhysMaterial.values) _chip(k.label, k.icon, m == k, () => _setMaterial(k)),
        ]),
      ),
      if (m == null)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Pick a type so this graphic behaves like a real object — liquid, rigid body, cloth and more.',
              style: _lbl),
        )
      else ...[
        _section('Presets'),
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final p in m.presets)
              _chip(p.name, null, false, () => edit(() => _applyPreset(p))),
          ]),
        ),
        _summary(m),
        ..._fields(context, m),
      ],
      _section('Custom attributes'),
      ..._custom(context),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _accent, side: const BorderSide(color: _accent), visualDensity: VisualDensity.compact),
          onPressed: () => _addCustom(context),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add attribute', style: TextStyle(fontSize: 11)),
        ),
      ),
    ]);
  }

  // ── derived info: weight, volume, floats/sinks ──
  Widget _summary(PhysMaterial m) {
    final mass = node.phys('mass', 1);
    final density = node.phys('density', 1000);
    final g = 9.81 * node.phys('gravity', 1);
    final weight = mass * g;
    final volumeL = density > 0 ? mass / density * 1000 : 0.0;
    final String behaviour;
    if (m == PhysMaterial.gas) {
      behaviour = density < 1.2 ? 'Rises in air' : 'Sinks in air';
    } else {
      behaviour = density < 1000 ? 'Floats on water' : 'Sinks in water';
    }
    Widget cell(String l, String v) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: _lbl.copyWith(fontSize: 10)),
              const SizedBox(height: 2),
              Text(v, style: _strong.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        cell('Weight', '${_fmt(double.parse(weight.toStringAsFixed(2)))} N'),
        const SizedBox(width: 8),
        cell('Volume', '≈ ${_fmt(double.parse(volumeL.toStringAsFixed(2)))} L'),
        const SizedBox(width: 8),
        cell('Behaviour', behaviour),
      ]),
    );
  }

  // ── fields per material ──
  List<Widget> _fields(BuildContext c, PhysMaterial m) {
    final w = <Widget>[_section('Physical')];
    w.add(_num('Mass', 'mass', 'kg', 1));
    w.add(_num('Density', 'density', 'kg/m³', 1000));
    switch (m) {
      case PhysMaterial.solid:
        w.addAll([
          _sl(c, 'Friction', 'friction', .5, 0, 1),
          _sl(c, 'Bounciness', 'bounce', .3, 0, 1),
          _toggle('Collision', 'collision', true),
        ]);
        break;
      case PhysMaterial.rigid:
        w.addAll([
          _sl(c, 'Friction', 'friction', .5, 0, 1),
          _sl(c, 'Bounciness', 'bounce', .3, 0, 1),
          _sl(c, 'Gravity scale', 'gravity', 1, -1, 3),
          _sl(c, 'Air drag', 'drag', .1, 0, 1),
          _toggle('Collision', 'collision', true),
        ]);
        break;
      case PhysMaterial.soft:
        w.addAll([
          _sl(c, 'Stiffness', 'stiffness', .5, 0, 1),
          _sl(c, 'Damping', 'damping', .1, 0, 1),
          _sl(c, 'Bounciness', 'bounce', .5, 0, 1),
          _sl(c, 'Gravity scale', 'gravity', 1, -1, 3),
          _toggle('Collision', 'collision', true),
        ]);
        break;
      case PhysMaterial.cloth:
        w.addAll([
          _sl(c, 'Stiffness', 'stiffness', .5, 0, 1),
          _sl(c, 'Damping', 'damping', .1, 0, 1),
          _sl(c, 'Friction', 'friction', .5, 0, 1),
          _sl(c, 'Gravity scale', 'gravity', 1, -1, 3),
          _sl(c, 'Air drag', 'drag', .1, 0, 1),
          _toggle('Pin top edge', 'pinned', false),
        ]);
        break;
      case PhysMaterial.liquid:
        w.addAll([
          _num('Viscosity', 'viscosity', 'mPa·s', 1),
          _sl(c, 'Surface tension', 'tension', .072, 0, .5, digits: 3),
          _sl(c, 'Gravity scale', 'gravity', 1, -1, 3),
          _toggle('Collide with objects', 'collision', true),
        ]);
        break;
      case PhysMaterial.gas:
        w.addAll([
          _sl(c, 'Buoyancy', 'buoyancy', .5, -1, 1),
          _sl(c, 'Dissipation', 'dissipation', .1, 0, 1),
          _sl(c, 'Turbulence', 'turbulence', .2, 0, 1),
          _sl(c, 'Gravity scale', 'gravity', 0, -1, 3),
        ]);
        break;
    }
    return w;
  }

  // ── custom attributes (Maya "Add Attribute") ──
  List<Widget> _custom(BuildContext c) {
    final keys = node.attrs.keys.where((k) => k.startsWith('data-attr-')).toList()..sort();
    if (keys.isEmpty) {
      return const [Text('Add your own properties, e.g. temperature, tag, is_fragile.', style: _lbl)];
    }
    return [
      for (final k in keys)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 96,
                child: Text(k.substring(10).replaceAll('_', ' '), overflow: TextOverflow.ellipsis, style: _lbl)),
            Expanded(child: _customValue(k)),
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () => edit(() => node.attrs.remove(k)),
              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
            ),
          ]),
        ),
    ];
  }

  Widget _customValue(String k) {
    final v = node.attrs[k] ?? '';
    if (v == 'true' || v == 'false') {
      return Align(
        alignment: Alignment.centerLeft,
        child: Switch(
          value: v == 'true',
          activeColor: _accent,
          onChanged: (b) => edit(() => node.attrs[k] = '$b'),
        ),
      );
    }
    return _textBox(
      key: ValueKey('$k$v${identityHashCode(node)}'),
      initial: v,
      keyboard: double.tryParse(v) != null ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
      onSubmit: (t) => edit(() => node.attrs[k] = t.trim()),
    );
  }

  Future<void> _addCustom(BuildContext c) async {
    final existing = node.attrs.keys.where((k) => k.startsWith('data-attr-')).map((k) => k.substring(10)).toSet();
    final r = await showDialog<List<String>>(context: c, builder: (_) => _AddAttrDialog(existing: existing));
    if (r == null) return;
    edit(() => node.attrs['data-attr-${r[0]}'] = r[1]);
  }

  // ── small widgets ──
  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t.toUpperCase(), style: _lbl.copyWith(fontSize: 10, letterSpacing: 1, color: Colors.white38)),
      );

  Widget _chip(String label, IconData? icon, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? _accent : _field, borderRadius: BorderRadius.circular(17)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 15, color: on ? Colors.black : Colors.white70), const SizedBox(width: 6)],
              Text(label,
                  style: TextStyle(
                      color: on ? Colors.black : const Color(0xFFD0D0D0),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Ubuntu')),
            ]),
          ),
        ),
      );

  Widget _textBox({Key? key, required String initial, required ValueChanged<String> onSubmit, TextInputType? keyboard, String? suffix}) =>
      Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(8)),
        child: TextFormField(
          key: key,
          initialValue: initial,
          keyboardType: keyboard,
          cursorColor: _accent,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Ubuntu'),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.only(top: 8),
            suffixText: suffix,
            suffixStyle: _lbl,
          ),
          onFieldSubmitted: onSubmit,
        ),
      );

  Widget _num(String label, String key, String unit, double def) {
    final v = node.phys(key, def);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 96, child: Text(label, style: _lbl)),
        Expanded(
          child: _textBox(
            key: ValueKey('$key${_fmt(v)}${identityHashCode(node)}'),
            initial: _fmt(v),
            suffix: unit,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            onSubmit: (t) {
              final p = double.tryParse(t.trim());
              if (p != null && p >= 0) edit(() => node.setPhys(key, p));
            },
          ),
        ),
      ]),
    );
  }

  Widget _sl(BuildContext c, String label, String key, double def, double mn, double mx, {int digits = 2}) {
    final v = node.phys(key, def).clamp(mn, mx).toDouble();
    return SizedBox(
      height: 32,
      child: Row(children: [
        SizedBox(width: 96, child: Text(label, style: _lbl)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(c).copyWith(
              trackHeight: 2,
              activeTrackColor: _accent,
              thumbColor: _accent,
              inactiveTrackColor: Colors.white12,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: v,
              min: mn,
              max: mx,
              onChangeStart: (_) => snap(),
              onChanged: (x) => live(() => node.setPhys(key, double.parse(x.toStringAsFixed(digits)))),
            ),
          ),
        ),
        SizedBox(width: 44, child: Text(_fmt(v), textAlign: TextAlign.end, style: _lbl)),
      ]),
    );
  }

  Widget _toggle(String label, String key, bool def) => SizedBox(
        height: 34,
        child: Row(children: [
          Expanded(child: Text(label, style: _lbl)),
          Switch(
            value: node.physFlag(key, def),
            activeColor: _accent,
            onChanged: (b) => edit(() => node.setPhys(key, '$b')),
          ),
        ]),
      );
}

// ───────────────────────── ADD-ATTRIBUTE DIALOG ─────────────────────────

class _AddAttrDialog extends StatefulWidget {
  const _AddAttrDialog({required this.existing});
  final Set<String> existing;
  @override
  State<_AddAttrDialog> createState() => _AddAttrDialogState();
}

class _AddAttrDialogState extends State<_AddAttrDialog> {
  final _name = TextEditingController();
  final _value = TextEditingController();
  int _type = 0; // 0 number, 1 text, 2 yes/no
  bool _flag = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  void _submit() {
    final key = _name.text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (key.isEmpty) return setState(() => _err = 'Enter a name');
    if (widget.existing.contains(key)) return setState(() => _err = 'That name\'s already used');
    String val;
    if (_type == 2) {
      val = '$_flag';
    } else if (_type == 0) {
      final p = double.tryParse(_value.text.trim());
      if (p == null) return setState(() => _err = 'Enter a number');
      val = _fmt(p);
    } else {
      val = _value.text.trim();
    }
    Navigator.pop(context, [key, val]);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: _field,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        );
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text('Add attribute', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _name, style: _strong, decoration: deco('Name, e.g. temperature')),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 0, label: Text('Number')),
            ButtonSegment(value: 1, label: Text('Text')),
            ButtonSegment(value: 2, label: Text('Yes / no')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() {
            _type = s.first;
            _err = null;
          }),
        ),
        const SizedBox(height: 10),
        if (_type == 2)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _accent,
            title: const Text('Value', style: _lbl),
            value: _flag,
            onChanged: (b) => setState(() => _flag = b),
          )
        else
          TextField(
            controller: _value,
            style: _strong,
            keyboardType: _type == 0 ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
            decoration: deco(_type == 0 ? '0' : 'Value'),
          ),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}