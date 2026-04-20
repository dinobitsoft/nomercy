// modules/ui/lib/src/screens/map_designer_screen.dart
//
// Top-down 2D map designer — runs in the browser (Flutter web).
//
// Layout:
//   ┌────────────────────────────────────────────────────────┐
//   │  AppBar: title · world-size · export                   │
//   ├──────────┬─────────────────────────────┬───────────────┤
//   │ TOOLBAR  │  CANVAS  (top-down X/Z)     │ PROPERTIES    │
//   │ 200 px   │  pan · zoom  (InteractiveV) │ 260 px        │
//   └──────────┴─────────────────────────────┴───────────────┘
//
// Coordinates:
//   Canvas shows the world X-Z plane (Y = height, edited in properties).
//   World origin (0, 0) is the centre-bottom of the map.
//   X: –worldWidth/2 … +worldWidth/2  →  canvas left … right
//   Z: 0 … worldDepth                 →  canvas top  … bottom

import 'dart:convert';
import 'dart:math' as math;

import 'package:engine/engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── pixel density (world units per canvas pixel) ──────────────────────────────
const double _kPPU = 0.22; // 1 world unit = 0.22 px at zoom 1×
const double _kSnap = 80.0; // grid snap (world units)

// ─────────────────────────────────────────────────────────────────────────────
// Mutable designer object
// ─────────────────────────────────────────────────────────────────────────────

class _Obj {
  final String id;
  MapObjectShape shape;
  double x, y, z;
  double sizeX, sizeY, sizeZ;
  String material;
  Map<String, dynamic> props;

  _Obj({
    required this.id,
    required this.shape,
    this.x = 0,
    this.y = 0,
    this.z = 400,
    double? sizeX,
    double? sizeY,
    double? sizeZ,
    this.material = 'stone',
    Map<String, dynamic>? props,
  })  : sizeX = sizeX ?? _defSX(shape),
        sizeY = sizeY ?? _defSY(shape),
        sizeZ = sizeZ ?? _defSZ(shape),
        props = props ?? _defProps(shape);

  // ── default dimensions per shape ──────────────────────────────────────────

  static double _defSX(MapObjectShape s) => switch (s) {
        MapObjectShape.wall             => 300,
        MapObjectShape.platform         => 280,
        MapObjectShape.stairs           => 160,
        MapObjectShape.ramp             => 200,
        MapObjectShape.elevatedPlatform => 500,
        MapObjectShape.arch             => 440,
        MapObjectShape.zigzag           => 260,
        MapObjectShape.pyramid          => 480,
        MapObjectShape.triangle         => 200,
        MapObjectShape.cone             => 120,
        MapObjectShape.cylinder         => 140,
        MapObjectShape.spawnPlayer      => 80,
        MapObjectShape.spawnBot         => 80,
        _                               => 180,
      };

  static double _defSY(MapObjectShape s) => switch (s) {
        MapObjectShape.wall             => 180,
        MapObjectShape.platform         => 30,
        MapObjectShape.stairs           => 300,
        MapObjectShape.ramp             => 240,
        MapObjectShape.elevatedPlatform => 240,
        MapObjectShape.arch             => 280,
        MapObjectShape.zigzag           => 240,
        MapObjectShape.pyramid          => 240,
        MapObjectShape.triangle         => 120,
        MapObjectShape.cone             => 180,
        MapObjectShape.cylinder         => 200,
        MapObjectShape.spawnPlayer      => 10,
        MapObjectShape.spawnBot         => 10,
        _                               => 100,
      };

  static double _defSZ(MapObjectShape s) => switch (s) {
        MapObjectShape.wall             => 40,
        MapObjectShape.platform         => 140,
        MapObjectShape.stairs           => 450,
        MapObjectShape.ramp             => 480,
        MapObjectShape.elevatedPlatform => 200,
        MapObjectShape.arch             => 80,
        MapObjectShape.zigzag           => 560,
        MapObjectShape.pyramid          => 480,
        MapObjectShape.triangle         => 200,
        MapObjectShape.cone             => 120,
        MapObjectShape.cylinder         => 140,
        MapObjectShape.spawnPlayer      => 80,
        MapObjectShape.spawnBot         => 80,
        _                               => 180,
      };

  static Map<String, dynamic> _defProps(MapObjectShape s) => switch (s) {
        MapObjectShape.stairs => {
          'steps': 5,
          'stepWidth': 160.0,
          'stepHeight': 60.0,
          'stepDepth': 90.0,
        },
        MapObjectShape.ramp => {'subdivisions': 6},
        MapObjectShape.elevatedPlatform => {
          'platformHeight': 240.0,
          'platformWidth': 500.0,
          'platformDepth': 200.0,
          'slabThickness': 60.0,
          'columnWidth': 100.0,
        },
        MapObjectShape.arch => {
          'openingWidth': 280.0,
          'pillarWidth': 80.0,
          'pillarHeight': 280.0,
          'pillarDepth': 80.0,
          'lintelThick': 60.0,
        },
        MapObjectShape.zigzag => {
          'levels': 4,
          'levelHeight': 60.0,
          'blockWidth': 260.0,
          'blockDepth': 140.0,
        },
        MapObjectShape.pyramid => {
          'layers': 4,
          'baseWidth': 480.0,
          'layerHeight': 60.0,
          'stepInset': 60.0,
        },
        _ => {},
      };

  MapObjectData toData() => MapObjectData(
        id: id,
        shape: shape,
        x: x,
        y: y,
        z: z,
        sizeX: sizeX,
        sizeY: sizeY,
        sizeZ: sizeZ,
        material: material,
        props: Map.from(props),
      );

  _Obj copyWith({
    MapObjectShape? shape,
    double? x,
    double? y,
    double? z,
    double? sizeX,
    double? sizeY,
    double? sizeZ,
    String? material,
    Map<String, dynamic>? props,
  }) =>
      _Obj(
        id: id,
        shape: shape ?? this.shape,
        x: x ?? this.x,
        y: y ?? this.y,
        z: z ?? this.z,
        sizeX: sizeX ?? this.sizeX,
        sizeY: sizeY ?? this.sizeY,
        sizeZ: sizeZ ?? this.sizeZ,
        material: material ?? this.material,
        props: props ?? Map.from(this.props),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MapDesignerScreen extends StatefulWidget {
  const MapDesignerScreen({super.key});

  @override
  State<MapDesignerScreen> createState() => _MapDesignerScreenState();
}

class _MapDesignerScreenState extends State<MapDesignerScreen> {
  // ── tool ──────────────────────────────────────────────────────────────────
  /// null = select/move mode.
  MapObjectShape? _tool = MapObjectShape.box;
  String _material = 'stone';

  // ── world ─────────────────────────────────────────────────────────────────
  double _worldWidth = 2400;
  double _worldDepth = 3200;

  // ── objects ───────────────────────────────────────────────────────────────
  final List<_Obj> _objects = [];
  _Obj? _selected;
  int _nextId = 1;

  // ── canvas ────────────────────────────────────────────────────────────────
  final _tc = TransformationController();

  // ── property text controllers ─────────────────────────────────────────────
  final _tcX    = TextEditingController();
  final _tcY    = TextEditingController();
  final _tcZ    = TextEditingController();
  final _tcSX   = TextEditingController();
  final _tcSY   = TextEditingController();
  final _tcSZ   = TextEditingController();
  final _tcProps = TextEditingController();
  bool _suppressPropSync = false;

  double get _cW => _worldWidth  * _kPPU;
  double get _cH => _worldDepth  * _kPPU;

  // ── coordinate helpers ────────────────────────────────────────────────────
  double _wx2cx(double wx) => (wx + _worldWidth / 2) * _kPPU;
  double _wz2cy(double wz) => wz * _kPPU;
  double _cx2wx(double cx) => cx / _kPPU - _worldWidth / 2;
  double _cy2wz(double cy) => cy / _kPPU;

  double _snap(double v) => (v / _kSnap).round() * _kSnap;

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _tc.dispose();
    _tcX.dispose();   _tcY.dispose();   _tcZ.dispose();
    _tcSX.dispose();  _tcSY.dispose();  _tcSZ.dispose();
    _tcProps.dispose();
    super.dispose();
  }

  // ── selection helpers ─────────────────────────────────────────────────────
  void _select(_Obj? obj) {
    setState(() => _selected = obj);
    if (obj == null) return;
    _suppressPropSync = true;
    _tcX.text    = obj.x.toStringAsFixed(0);
    _tcY.text    = obj.y.toStringAsFixed(0);
    _tcZ.text    = obj.z.toStringAsFixed(0);
    _tcSX.text   = obj.sizeX.toStringAsFixed(0);
    _tcSY.text   = obj.sizeY.toStringAsFixed(0);
    _tcSZ.text   = obj.sizeZ.toStringAsFixed(0);
    _tcProps.text = obj.props.isEmpty
        ? ''
        : const JsonEncoder.withIndent('  ').convert(obj.props);
    _suppressPropSync = false;
  }

  void _deleteSelected() {
    if (_selected == null) return;
    setState(() {
      _objects.remove(_selected);
      _selected = null;
    });
  }

  void _applyPropField(void Function(_Obj obj) mutate) {
    if (_suppressPropSync || _selected == null) return;
    setState(() => mutate(_selected!));
  }

  // ── canvas interaction ────────────────────────────────────────────────────
  void _onTapDown(TapDownDetails d) {
    final cp = d.localPosition;
    final wx = _snap(_cx2wx(cp.dx));
    final wz = _snap(_cy2wz(cp.dy));

    if (_tool == null) {
      // Select mode — find topmost object under tap
      _Obj? hit;
      for (final obj in _objects.reversed) {
        if (_hitTest(obj, cp)) {
          hit = obj;
          break;
        }
      }
      _select(hit);
      return;
    }

    // Place mode — create new object
    final obj = _Obj(
      id: 'obj_${_nextId++}',
      shape: _tool!,
      x: wx,
      y: 0,
      z: wz,
      material: _material,
    );
    setState(() {
      _objects.add(obj);
      _select(obj);
    });
  }

  bool _hitTest(_Obj obj, Offset cp) {
    if (obj.shape == MapObjectShape.spawnPlayer ||
        obj.shape == MapObjectShape.spawnBot) {
      final dx = cp.dx - _wx2cx(obj.x);
      final dy = cp.dy - _wz2cy(obj.z);
      return math.sqrt(dx * dx + dy * dy) < 16;
    }
    final rect = _objRect(obj);
    return rect.contains(cp);
  }

  Rect _objRect(_Obj obj) {
    final cx = _wx2cx(obj.x);
    final cy = _wz2cy(obj.z);
    final pw = obj.sizeX * _kPPU;
    final ph = obj.sizeZ * _kPPU;
    return Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph);
  }

  // ── export ────────────────────────────────────────────────────────────────
  void _exportJson() {
    final mapData = MapData3D(
      id:         'designer_map_${DateTime.now().millisecondsSinceEpoch}',
      name:       'Designer Map',
      worldWidth: _worldWidth,
      worldDepth: _worldDepth,
      objects:    _objects.map((o) => o.toData()).toList(),
    );
    final json = const JsonEncoder.withIndent('  ').convert(mapData.toJson());
    showDialog<void>(
      context: context,
      builder: (_) => _ExportDialog(json: json),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: _buildAppBar(),
      body: Row(children: [
        _buildToolbar(),
        Expanded(child: _buildCanvas()),
        _buildProperties(),
      ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: const Text('MAP DESIGNER',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          // World size chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Chip(
              backgroundColor: Colors.grey[800],
              label: Text(
                '${_worldWidth.toInt()} × ${_worldDepth.toInt()}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export JSON',
            onPressed: _objects.isEmpty ? null : _exportJson,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
            onPressed: _objects.isEmpty
                ? null
                : () => setState(() {
                      _objects.clear();
                      _selected = null;
                    }),
          ),
          const SizedBox(width: 8),
        ],
      );

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      width: 200,
      color: const Color(0xFF111111),
      child: ListView(padding: const EdgeInsets.all(8), children: [
        _toolBtn(null,                     Icons.mouse,            'SELECT'),
        const _SectionLabel('SPAWN'),
        _toolBtn(MapObjectShape.spawnPlayer, Icons.person_pin,     'Player Spawn'),
        _toolBtn(MapObjectShape.spawnBot,    Icons.smart_toy,      'Bot Spawn'),
        const _SectionLabel('OBSTACLES'),
        _toolBtn(MapObjectShape.box,         Icons.crop_square,    'Box'),
        _toolBtn(MapObjectShape.wall,        Icons.view_agenda,    'Wall'),
        _toolBtn(MapObjectShape.stairs,      Icons.stairs,         'Stairs'),
        _toolBtn(MapObjectShape.ramp,        Icons.trending_up,    'Ramp'),
        _toolBtn(MapObjectShape.elevatedPlatform, Icons.table_chart, 'Elevated Plat.'),
        _toolBtn(MapObjectShape.arch,        Icons.account_balance,'Arch'),
        _toolBtn(MapObjectShape.zigzag,      Icons.show_chart,     'Zigzag'),
        _toolBtn(MapObjectShape.pyramid,     Icons.change_history, 'Pyramid'),
        _toolBtn(MapObjectShape.triangle,    Icons.details,        'Triangle'),
        _toolBtn(MapObjectShape.cone,        Icons.signal_cellular_alt, 'Cone'),
        _toolBtn(MapObjectShape.cylinder,    Icons.circle_outlined,'Cylinder'),
        const _SectionLabel('PLATFORMS'),
        _toolBtn(MapObjectShape.platform,    Icons.horizontal_rule,'Platform'),
        const _SectionLabel('MATERIAL'),
        ..._kMaterials.map((m) => _matBtn(m)),
        const SizedBox(height: 16),
        // Object count
        Center(
          child: Text(
            '${_objects.length} object${_objects.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ]),
    );
  }

  Widget _toolBtn(MapObjectShape? shape, IconData icon, String label) {
    final active = _tool == shape;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? const Color(0xFF1565C0) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _tool = shape),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(children: [
              Icon(icon, size: 16,
                  color: active ? Colors.white : Colors.white60),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: active ? Colors.white : Colors.white70)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _matBtn(String mat) {
    final active = _material == mat;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => setState(() => _material = mat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: Colors.white70)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(children: [
            Container(
                width: 14, height: 14,
                decoration: BoxDecoration(
                  color: _matColor(mat),
                  borderRadius: BorderRadius.circular(3),
                )),
            const SizedBox(width: 8),
            Text(mat,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? Colors.white : Colors.white60)),
          ]),
        ),
      ),
    );
  }

  // ── Canvas ────────────────────────────────────────────────────────────────
  Widget _buildCanvas() {
    return Container(
      color: const Color(0xFF222222),
      child: Center(
        child: InteractiveViewer(
          transformationController: _tc,
          boundaryMargin: const EdgeInsets.all(400),
          minScale: 0.2,
          maxScale: 6.0,
          child: SizedBox(
            width: _cW,
            height: _cH,
            child: GestureDetector(
              onTapDown: _onTapDown,
              child: CustomPaint(
                size: Size(_cW, _cH),
                painter: _CanvasPainter(
                  objects:    _objects,
                  selected:   _selected,
                  worldWidth: _worldWidth,
                  worldDepth: _worldDepth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Properties panel ──────────────────────────────────────────────────────
  Widget _buildProperties() {
    return Container(
      width: 260,
      color: const Color(0xFF111111),
      child: _selected == null ? _emptyProps() : _objectProps(_selected!),
    );
  }

  Widget _emptyProps() => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 40, color: Colors.white12),
              const SizedBox(height: 12),
              Text(
                _tool == null
                    ? 'Tap an object to select it'
                    : 'Tap the canvas to place a ${_tool!.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white30, fontSize: 13),
              ),
            ],
          ),
        ),
      );

  Widget _objectProps(_Obj obj) {
    final isSpawn = obj.shape == MapObjectShape.spawnPlayer ||
        obj.shape == MapObjectShape.spawnBot;
    return ListView(padding: const EdgeInsets.all(12), children: [
      // Shape badge
      Row(children: [
        Icon(_shapeIcon(obj.shape), size: 18, color: Colors.blue[200]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            obj.shape.name.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ),
        Text(
          '#${obj.id.split('_').last}',
          style: const TextStyle(color: Colors.white30, fontSize: 11),
        ),
      ]),
      const SizedBox(height: 12),

      // Position
      const _PropLabel('POSITION'),
      _propRow('X', _tcX, (v) => obj.x = _parseD(v, obj.x)),
      _propRow('Y (floor)', _tcY, (v) => obj.y = _parseD(v, obj.y)),
      _propRow('Z', _tcZ, (v) => obj.z = _parseD(v, obj.z)),
      const SizedBox(height: 8),

      if (!isSpawn) ...[
        // Size
        const _PropLabel('SIZE'),
        _propRow('Width X',  _tcSX, (v) => obj.sizeX = _parseD(v, obj.sizeX)),
        _propRow('Height Y', _tcSY, (v) => obj.sizeY = _parseD(v, obj.sizeY)),
        _propRow('Depth Z',  _tcSZ, (v) => obj.sizeZ = _parseD(v, obj.sizeZ)),
        const SizedBox(height: 8),

        // Material dropdown
        const _PropLabel('MATERIAL'),
        DropdownButton<String>(
          value: obj.material,
          dropdownColor: const Color(0xFF1A1A1A),
          isExpanded: true,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          items: _kMaterials
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Row(children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: _matColor(m),
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text(m),
                    ]),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => obj.material = v);
          },
        ),
        const SizedBox(height: 8),

        // Props (JSON) — only for compound shapes
        if (obj.props.isNotEmpty) ...[
          const _PropLabel('SHAPE PROPS (JSON)'),
          TextField(
            controller: _tcProps,
            maxLines: 6,
            style: const TextStyle(
                color: Colors.greenAccent, fontSize: 11,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A2A1A),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.white12)),
              contentPadding: const EdgeInsets.all(8),
              helperText: 'Edit shape parameters as JSON',
              helperStyle:
                  const TextStyle(color: Colors.white30, fontSize: 10),
            ),
            onChanged: (v) {
              try {
                final parsed =
                    jsonDecode(v) as Map<String, dynamic>;
                setState(() => obj.props = parsed);
              } catch (_) {
                // keep old props if JSON is invalid
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ],

      // Delete
      const Divider(color: Colors.white12),
      TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
        label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        onPressed: _deleteSelected,
      ),
    ]);
  }

  Widget _propRow(String label, TextEditingController tc,
      void Function(String) onCommit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Expanded(
          child: TextField(
            controller: tc,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            keyboardType:
                const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white12)),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onSubmitted: (v) {
              onCommit(v);
              setState(() {});
            },
          ),
        ),
      ]),
    );
  }

  static double _parseD(String s, double fallback) =>
      double.tryParse(s) ?? fallback;
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas painter
// ─────────────────────────────────────────────────────────────────────────────

class _CanvasPainter extends CustomPainter {
  final List<_Obj> objects;
  final _Obj? selected;
  final double worldWidth;
  final double worldDepth;

  const _CanvasPainter({
    required this.objects,
    required this.selected,
    required this.worldWidth,
    required this.worldDepth,
  });

  double _wx2cx(double wx) => (wx + worldWidth / 2) * _kPPU;
  double _wz2cy(double wz) => wz * _kPPU;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawAxes(canvas, size);
    _drawObjects(canvas);
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1C1C1C),
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final minorPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 0.5;
    final majorPaint = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = 1.0;

    const minorStep = _kSnap * _kPPU;         // 80 wu = grid cell
    const majorStep = minorStep * 5;           // every 5 cells

    for (double x = 0; x <= size.width; x += minorStep) {
      final p = x % majorStep < 0.5 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += minorStep) {
      final p = y % majorStep < 0.5 ? majorPaint : minorPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _drawAxes(Canvas canvas, Size size) {
    // X = 0 axis (vertical centre line)
    final xAxis = Paint()
      ..color = const Color(0xFF4A4A7A)
      ..strokeWidth = 1.5;
    final cx = _wx2cx(0);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), xAxis);

    // Z = 0 boundary (top edge)
    final zAxis = Paint()
      ..color = const Color(0xFF4A7A4A)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), zAxis);

    // World boundary dashes
    final boundPaint = Paint()
      ..color = const Color(0xFF5A5A5A)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      boundPaint,
    );
  }

  void _drawObjects(Canvas canvas) {
    for (final obj in objects) {
      _drawObj(canvas, obj, obj == selected);
    }
  }

  void _drawObj(Canvas canvas, _Obj obj, bool sel) {
    final cx = _wx2cx(obj.x);
    final cy = _wz2cy(obj.z);

    if (obj.shape == MapObjectShape.spawnPlayer ||
        obj.shape == MapObjectShape.spawnBot) {
      _drawSpawn(canvas, cx, cy, obj.shape == MapObjectShape.spawnPlayer, sel);
      return;
    }

    final pw = obj.sizeX * _kPPU;
    final ph = obj.sizeZ * _kPPU;
    final rect =
        Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph);

    final base = _matColor(obj.material);
    final fill = Paint()..color = base.withOpacity(0.65);
    final border = Paint()
      ..color = sel ? Colors.white : base.withOpacity(0.9)
      ..strokeWidth = sel ? 2.0 : 1.0
      ..style = PaintingStyle.stroke;

    // Platform = dashed border
    if (obj.shape == MapObjectShape.platform) {
      canvas.drawRect(rect, fill);
      _drawDashedRect(canvas, rect, border);
    } else {
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);
    }

    // Selection highlight
    if (sel) {
      canvas.drawRect(
        rect.inflate(3),
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Label (only if box is large enough)
    if (pw > 22 && ph > 12) {
      _drawLabel(canvas, rect, obj.shape.name, obj.y);
    }
  }

  void _drawSpawn(Canvas canvas, double cx, double cy, bool isPlayer,
      bool sel) {
    const r = 14.0;
    final color = isPlayer ? Colors.green : const Color(0xFFEF5350);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = color.withOpacity(0.7),
    );
    if (sel) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // Letter
    final tp = TextPainter(
      text: TextSpan(
        text: isPlayer ? 'P' : 'B',
        style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawLabel(Canvas canvas, Rect rect, String text, double floorY) {
    final label = '${text}\ny=${floorY.toInt()}';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: Colors.white70, fontSize: 8.5, height: 1.2),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 4);
    tp.paint(
        canvas,
        Offset(
          rect.center.dx - tp.width / 2,
          rect.center.dy - tp.height / 2,
        ));
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dash = 4.0, gap = 3.0;
    void line(Offset a, Offset b) {
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      final ux = dx / len, uy = dy / len;
      double d = 0;
      while (d < len) {
        final end = math.min(d + dash, len);
        canvas.drawLine(
          Offset(a.dx + ux * d, a.dy + uy * d),
          Offset(a.dx + ux * end, a.dy + uy * end),
          paint,
        );
        d += dash + gap;
      }
    }

    line(rect.topLeft, rect.topRight);
    line(rect.topRight, rect.bottomRight);
    line(rect.bottomRight, rect.bottomLeft);
    line(rect.bottomLeft, rect.topLeft);
  }

  @override
  bool shouldRepaint(_CanvasPainter o) =>
      o.objects != objects || o.selected != selected;
}

// ─────────────────────────────────────────────────────────────────────────────
// Export dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ExportDialog extends StatelessWidget {
  final String json;
  const _ExportDialog({required this.json});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Export JSON',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy, color: Colors.white70),
          label: const Text('Copy', style: TextStyle(color: Colors.white70)),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: json));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('Close', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers / constants
// ─────────────────────────────────────────────────────────────────────────────

const _kMaterials = [
  'stone', 'brick', 'wood', 'metal', 'ice', 'dirt', 'ground', 'sand',
];

Color _matColor(String mat) => switch (mat) {
      'stone'  => const Color(0xFF9E9E9E),
      'brick'  => const Color(0xFFB84030),
      'wood'   => const Color(0xFFC08836),
      'ice'    => const Color(0xFF68B0CC),
      'dirt'   => const Color(0xFF8A6438),
      'ground' => const Color(0xFF5A8A3A),
      'metal'  => const Color(0xFF607080),
      'sand'   => const Color(0xFFCAB060),
      _        => const Color(0xFF9E9E9E),
    };

IconData _shapeIcon(MapObjectShape s) => switch (s) {
      MapObjectShape.box              => Icons.crop_square,
      MapObjectShape.wall             => Icons.view_agenda,
      MapObjectShape.platform         => Icons.horizontal_rule,
      MapObjectShape.stairs           => Icons.stairs,
      MapObjectShape.ramp             => Icons.trending_up,
      MapObjectShape.elevatedPlatform => Icons.table_chart,
      MapObjectShape.arch             => Icons.account_balance,
      MapObjectShape.zigzag           => Icons.show_chart,
      MapObjectShape.pyramid          => Icons.change_history,
      MapObjectShape.triangle         => Icons.details,
      MapObjectShape.cone             => Icons.signal_cellular_alt,
      MapObjectShape.cylinder         => Icons.circle_outlined,
      MapObjectShape.spawnPlayer      => Icons.person_pin,
      MapObjectShape.spawnBot         => Icons.smart_toy,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      );
}

class _PropLabel extends StatelessWidget {
  final String text;
  const _PropLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
      );
}
