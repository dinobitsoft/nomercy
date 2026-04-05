---
name: performance-optimizer
description: Audit Flutter/Dart code for performance anti-patterns and rewrite them. Use when asked to optimize, improve performance, or fix rebuilds in Flutter UI code.
allowed-tools: Read Grep Edit Write Glob Bash
argument-hint: [file or directory to audit]
---

# Flutter Performance Optimizer

Audit and fix Flutter performance anti-patterns in `$ARGUMENTS` (or the current file/selection if no argument given).

## Workflow

1. **Scan** target files with Grep for each anti-pattern listed below.
2. **For every hit** — read the surrounding context, confirm it is indeed an anti-pattern, then rewrite it using the matching solution.
3. **Report** a summary table: file | line | anti-pattern | fix applied.
4. Do NOT change logic, business rules, or layout — only the rebuild/performance concern.

---

## Anti-Pattern Catalogue

### 1. Excessive `setState` rebuilds

**Problem:** `setState` re-runs `build()` for the entire `StatefulWidget` subtree, even if only one leaf needs updating.

**Detect:** `setState` calls inside `StatefulWidget` that wrap a single field increment / toggle / assignment.

**Fix:** Convert to `StatelessWidget` with `ValueNotifier` + `ValueListenableBuilder`, scoping the rebuild to the smallest possible widget.

```dart
// BAD
class Counter extends StatelessWidget { ... }
class _CounterState extends State<Counter> {
  int count = 0;
  @override Widget build(BuildContext context) {
    return Column(children: [
      Text('$count'),
      ElevatedButton(onPressed: () => setState(() => count++), child: Text('+')),
    ]);
  }
}

// GOOD
class Counter extends StatelessWidget {
  final _count = ValueNotifier<int>(0);
  @override Widget build(BuildContext context) {
    return Column(children: [
      ValueListenableBuilder<int>(
        valueListenable: _count,
        builder: (_, v, __) => Text('$v'),
      ),
      ElevatedButton(onPressed: () => _count.value++, child: const Text('+')),
    ]);
  }
}
```

Other acceptable localisation tools: `StreamBuilder`, `Selector` (provider), `BlocBuilder` (bloc).

---

### 2. `const` missing on immutable widgets

**Problem:** Widgets with no runtime-variable children are reconstructed every frame even though they never change.

**Detect:** Widget constructors (`Text(`, `Icon(`, `Padding(`, `SizedBox(`, `EdgeInsets.`, etc.) that take only literal values and are NOT prefixed with `const`.

**Fix:** Add `const` keyword.

```dart
// BAD
Text('Hello')
SizedBox(height: 16)

// GOOD
const Text('Hello')
const SizedBox(height: 16)
```

---

### 3. Anonymous functions / lambdas in `build()`

**Problem:** Inline `() {}` closures create new function objects each build, breaking `==` equality checks and forcing child widgets to rebuild.

**Detect:** `onPressed: () {`, `onTap: () {`, `onChanged: (v) {` inside a `build` method.

**Fix:** Extract to a named method on the widget/state class.

```dart
// BAD
ElevatedButton(onPressed: () => _submit(), ...)

// GOOD — reference, not a new closure
ElevatedButton(onPressed: _submit, ...)
```

---

### 4. Missing `RepaintBoundary` around animated or frequently-repainting widgets

**Problem:** An animated widget (e.g. `AnimatedBuilder`, looping `Lottie`, custom painter) causes its siblings to repaint every frame.

**Detect:** `AnimatedBuilder(`, `AnimationController`, custom `CustomPainter` without a surrounding `RepaintBoundary`.

**Fix:** Wrap with `RepaintBoundary`.

```dart
// GOOD
RepaintBoundary(
  child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => MyParticles()),
)
```

---

### 5. Missing `Key` on list items

**Problem:** Without a `key`, Flutter cannot match old and new elements during list updates. This breaks reordering, removal animations, and causes incorrect widget reuse — especially with stateful children.

**Detect:** `ListView.builder`, `GridView.builder`, `SliverList`, or any `.map()` returning widgets where the returned widget has no `key:` parameter.

**Fix:** Add `ValueKey(item.id)` (or another stable unique identifier) to the top-level widget returned by `itemBuilder`.

```dart
// BAD
ListView.builder(
  itemCount: items.length,
  itemBuilder: (_, index) {
    final item = items[index];
    return ListTile(
      title: Text(item.title),
    );
  },
);

// GOOD
ListView.builder(
  itemCount: items.length,
  itemBuilder: (_, index) {
    final item = items[index];
    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.title),
    );
  },
);
```

Use `ValueKey` for data-driven ids, `ObjectKey` for object identity, `UniqueKey` only when items must never be reused (e.g. dismissible one-shots).

---

### 6. `Future` created inside `build()`

**Problem:** Calling an async function directly inside `build()` creates a new `Future` on every rebuild. `FutureBuilder` treats each new `Future` instance as a fresh request, so it resets to the loading state and fires the network/IO call again — on every rebuild.

**Detect:** `FutureBuilder(future: someFunction(` where `someFunction` is called inline rather than referencing a stored field.

**Fix:** Create the `Future` once in `initState` (or `didChangeDependencies` if it depends on `context`), store it in a field, and pass that field to `FutureBuilder`.

```dart
// BAD — new request on every rebuild
Widget build(BuildContext context) {
  return FutureBuilder(
    future: fetchData(), // new Future every time
    builder: (_, snapshot) {
      if (!snapshot.hasData) return CircularProgressIndicator();
      return Text(snapshot.data.toString());
    },
  );
}

// GOOD — Future created once
late Future _dataFuture;

@override
void initState() {
  super.initState();
  _dataFuture = fetchData();
}

Widget build(BuildContext context) {
  return FutureBuilder(
    future: _dataFuture,
    builder: (_, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();
      return Text(snapshot.data.toString());
    },
  );
}
```

If the future must re-fire on parameter change, refresh it inside `didUpdateWidget` or via an explicit user action — never inside `build`.

---

### 7. Network images without caching

**Problem:** `Image.network()` re-downloads the image from the network on every widget rebuild or screen revisit. There is no disk or memory cache, causing redundant requests, increased data usage, and visible flicker.

**Detect:** `Image.network(` anywhere in widget trees.

**Fix:** Replace with `CachedNetworkImage` from the `cached_network_image` package. It caches images on disk and in memory, shows a placeholder while loading, and handles errors gracefully.

```dart
// BAD — re-downloads on every rebuild
Column(
  children: [
    Image.network(url1),
    Image.network(url2),
    Image.network(url3),
  ],
);

// GOOD — cached on disk and in memory
Column(
  children: [
    CachedNetworkImage(imageUrl: url1),
    CachedNetworkImage(imageUrl: url2),
    CachedNetworkImage(imageUrl: url3),
  ],
);
```

Ensure `cached_network_image` is in `pubspec.yaml`:
```yaml
dependencies:
  cached_network_image: ^3.x.x
```

For placeholder and error handling:
```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (_, __) => const CircularProgressIndicator(),
  errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
);
```

---

### 8. `Opacity` widget instead of color-level alpha

**Problem:** The `Opacity` widget creates a separate compositing layer and offscreen buffer. Flutter must render the child into that buffer first, then composite it onto the screen with the given alpha — an extra GPU pass every frame.

**Detect:** `Opacity(opacity:` wrapping a widget whose color or decoration can directly accept an alpha value.

**Fix:** Move the alpha into the color itself using `.withOpacity()`. No extra layer, no offscreen buffer.

```dart
// BAD — extra compositing layer
Opacity(
  opacity: 0.5,
  child: Container(
    color: Colors.red,
    width: 100,
    height: 100,
  ),
);

// GOOD — alpha baked into the color, zero overhead
Container(
  width: 100,
  height: 100,
  color: Colors.red.withOpacity(0.5),
);
```

**When `Opacity` is still required:**
- The child is a complex subtree with multiple colors that must all fade together.
- You are animating opacity via `AnimatedOpacity` or `FadeTransition` — these are optimized and acceptable.
- The child contains images or custom painters where you cannot control the color directly.

---

### 9. Deeply nested widget trees

**Problem:** Widget trees deeper than ~10 levels increase layout recalculation time, make the render tree harder to traverse, and often hide redundant wrappers. Common culprits: `Container` wrapping a single `Padding`, `Align` with a single-child `Column`, or `SizedBox` wrapping `Container`.

**Detect:** Chains of single-child layout widgets (`Container`, `Padding`, `Align`, `Center`, `SizedBox`, `ConstrainedBox`, `DecoratedBox`) nested 3+ levels deep where the same effect can be expressed in fewer widgets.

**Fix:** Collapse redundant wrappers. Prefer purpose-specific widgets over `Container` (which internally stacks multiple layout passes). Replace `Align(alignment: Alignment.center, child: ...)` with `Center(child: ...)`. A `Column` with a single child is just noise — remove it.

```dart
// BAD — 5 layout widgets to center padded text
Container(
  child: Padding(
    padding: EdgeInsets.all(8),
    child: Align(
      alignment: Alignment.center,
      child: Column(
        children: [
          Text('Hello'),
        ],
      ),
    ),
  ),
);

// GOOD — 2 layout widgets, same result
Padding(
  padding: const EdgeInsets.all(8),
  child: Center(
    child: Text('Hello'),
  ),
);
```

**Common collapses:**

| Verbose | Collapsed |
|---|---|
| `Align(alignment: Alignment.center, child: X)` | `Center(child: X)` |
| `Column(children: [X])` (single child) | `X` directly |
| `Container(child: X)` with no decoration/size | `X` directly |
| `Container(padding: p, child: X)` | `Padding(padding: p, child: X)` |
| `Container(color: c, child: X)` | `ColoredBox(color: c, child: X)` |
| `SizedBox(width: w, height: h, child: Container(...))` | Merge into one `SizedBox` or `ConstrainedBox` |

---

### 10. Massive `StatefulWidget` doing too much

**Problem:** Flutter is optimized for composition — many small widgets rebuilt cheaply beats one giant widget rebuilt expensively. A large `build()` method that renders headers, lists, footers, buttons, and images in a single widget means any state change rebuilds the entire screen. It also makes the code harder to test and reuse.

**Detect:** `build()` methods longer than ~40 lines, or `Column`/`Stack` with 5+ inline children that are not extracted into named widgets.

**Fix:** Decompose into small, focused `StatelessWidget` subclasses. Each piece becomes independently rebuildable, `const`-constructible, and reusable.

```dart
// BAD — one widget rebuilds everything
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Header'),
      ListView(...),
      Text('Footer'),
      ElevatedButton(...),
      Image.network(url),
    ],
  );
}

// GOOD — each piece is an independent, const-constructible widget
Widget build(BuildContext context) {
  return const Column(
    children: [
      Header(),
      Expanded(child: ItemsList()),
      Footer(),
    ],
  );
}

class Header extends StatelessWidget {
  const Header();
  @override
  Widget build(BuildContext context) => const Text('Header');
}

class ItemsList extends StatelessWidget {
  const ItemsList();
  @override
  Widget build(BuildContext context) => ListView(...);
}

class Footer extends StatelessWidget {
  const Footer();
  @override
  Widget build(BuildContext context) => const Text('Footer');
}
```

**Rules of thumb:**
- If a section of `build()` has a clear visual responsibility, it deserves its own widget class.
- Extracted widgets should be `const`-constructible wherever possible (enables compile-time caching).
- Stateful logic stays in the parent or moves into a dedicated controller — extracted children are `StatelessWidget`.

---

### 11. Business logic inside `build()`

**Problem:** `build()` can be called 10+ times per second. Any heavy operation placed directly inside it — sorting, filtering, mapping, parsing, formatting — runs on every frame, burning CPU and causing jank.

**Detect:** `.sort(`, `.where(`, `.map(`, `.reduce(`, `json`, `RegExp(`, `DateFormat(`, or multi-step data transformations called directly in the body of `build()` (not inside a `FutureBuilder`/`StreamBuilder` data source).

**Fix:** Move all data preparation to `initState`, `didUpdateWidget`, or a dedicated controller/notifier. Store the result in a field. `build()` should only read pre-computed state and assemble widgets.

```dart
// BAD — sort + filter runs every frame
Widget build(BuildContext context) {
  final sortedList = items..sort((a, b) => a.compareTo(b));
  final filtered = sortedList.where((e) => e > 10).toList();
  return ListView(
    children: filtered.map((e) => Text('$e')).toList(),
  );
}

// GOOD — computed once, build() only reads the result
late List<int> _filtered;

@override
void initState() {
  super.initState();
  final sorted = [...items]..sort((a, b) => a.compareTo(b));
  _filtered = sorted.where((e) => e > 10).toList();
}

@override
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: _filtered.length,
    itemBuilder: (_, i) => Text('${_filtered[i]}'),
  );
}
```

**If the data changes at runtime:** recompute inside a method triggered by the event (button press, stream update, `didUpdateWidget`), update the field, then call `setState` — never recompute inside `build` itself.

---

### 12. `ListView` with `children:` instead of `.builder`

**Problem:** `ListView(children: items.map(...).toList())` eagerly instantiates every widget and its subtree — even items the user will never scroll to. For 100 items this means 100 `ListTile` objects, 100 `Text` widgets, 200 layout passes, all created before the first frame is painted. `.builder` creates only the widgets currently visible on screen (typically 5–15), recycling them as the user scrolls.

**Detect:** `ListView(children:` or `GridView(children:` followed by `.map(` or a list literal with more than a handful of static items.

**Fix:** Replace with `ListView.builder` and an `itemBuilder` closure. Add `key: ValueKey(item.id)` if items can be reordered or removed (see rule 5).

```dart
// BAD — all items built immediately, regardless of visibility
Widget build(BuildContext context) {
  return ListView(
    children: items.map((item) {
      return ListTile(
        title: Text(item.title),
        subtitle: Text(item.subtitle),
      );
    }).toList(),
  );
}

// GOOD — only visible items are built, recycled on scroll
Widget build(BuildContext context) {
  return ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      return ListTile(
        key: ValueKey(item.id),
        title: Text(item.title),
        subtitle: Text(item.subtitle),
      );
    },
  );
}
```

**Variants:**
- `GridView(children:` → `GridView.builder`
- `CustomScrollView` with `SliverList(delegate: SliverChildListDelegate([...]))` → `SliverChildBuilderDelegate`
- Fewer than 5 static, truly immutable items — `children:` is acceptable.

---

## Output format

After applying fixes, print:

```
## Performance Audit Results

| File | Line | Anti-pattern | Fix |
|------|------|-------------|-----|
| lib/screens/home.dart | 42 | setState full rebuild | ValueListenableBuilder |
| lib/widgets/list.dart | 17 | ListView eager | ListView.builder |
```

If no anti-patterns are found, say so clearly.
