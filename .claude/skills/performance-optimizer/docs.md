# Performance Optimizer Skill

Audits Flutter/Dart code for performance anti-patterns and rewrites them in-place.

## Usage

```
/performance-optimizer lib/screens/home.dart
/performance-optimizer lib/screens/
/performance-optimizer                   # audits current file/selection
```

## What it fixes

| # | Anti-pattern | Root cause | Fix |
|---|---|---|---|
| 1 | `setState` full-tree rebuild | Entire `StatefulWidget` subtree re-runs `build()` | `ValueNotifier` + `ValueListenableBuilder` (or `StreamBuilder` / `Selector` / `BlocBuilder`) |
| 2 | Missing `const` on immutable widgets | New object allocated each frame | Add `const` keyword |
| 3 | Inline lambdas in `build()` | New closure object breaks `==`, forces child rebuild | Extract to named method |
| 4 | No `RepaintBoundary` around animations | Animated widget repaints entire parent | Wrap with `RepaintBoundary` |
| 5 | Missing `key` on list items | Flutter can't match old/new elements → broken reorder, wrong reuse | Add `ValueKey(item.id)` to `itemBuilder` root widget |
| 6 | `Future` created in `build()` | Every rebuild creates a new `Future` → repeated network/IO calls | Store future in `initState`, pass field to `FutureBuilder` |
| 7 | `Image.network` without cache | Re-downloads image on every rebuild → flicker, wasted data | Replace with `CachedNetworkImage` |
| 8 | `Opacity` widget over plain color | Creates extra compositing layer + offscreen buffer each frame | Move alpha into `.withOpacity()` on the color directly |
| 9 | Deeply nested widget trees | 10+ levels slow layout recalculation, hide redundant wrappers | Collapse with `Center`, `Padding`, `ColoredBox`; remove single-child `Column`/bare `Container` |
| 10 | Massive `StatefulWidget` | One rebuild repaints entire screen; hard to test/reuse | Decompose into small `const`-constructible `StatelessWidget` classes |
| 11 | Business logic in `build()` | Heavy ops run 10×/sec on every frame → jank | Move sort/filter/parse to `initState` or controller; `build()` only reads state |
| 12 | `ListView(children:)` eager build | All items instantiated upfront, even off-screen → memory & CPU waste | Replace with `ListView.builder` / `GridView.builder` / `SliverChildBuilderDelegate` |

## Rule 1 in depth — localizing `setState` rebuilds

This is the most impactful fix. `setState` marks the entire `StatefulWidget` dirty — Flutter re-runs its full `build()` method and diffs every descendant. For a screen with 50 widgets, updating a single counter still walks all 50.

**The fix:** push mutable state into a `ValueNotifier` held by a `StatelessWidget` and wrap only the updating leaf with `ValueListenableBuilder`.

```dart
// BEFORE — full Column rebuilds on every tap
class _MyScreenState extends State<MyScreen> {
  int counter = 0;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Counter: $counter'),
        ElevatedButton(
          onPressed: () => setState(() => counter++),
          child: Text('Increment'),
        ),
      ],
    );
  }
}

// AFTER — only the Text rebuilds
class MyScreen extends StatelessWidget {
  final ValueNotifier<int> counter = ValueNotifier(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: counter,
          builder: (_, value, __) => Text('Counter: $value'),
        ),
        ElevatedButton(
          onPressed: () => counter.value++,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

**When `setState` is still appropriate:**
- Rebuilding the whole widget really is necessary (e.g. theme switch, full-screen mode change).
- The widget is a leaf with no children — cost is trivial.
- You are using `Bloc` / `Riverpod` / `Provider` already — use their scoped builders instead.

## When to run this skill

- Before a performance review or profiling session.
- After adding a feature — catch regressions early.
- When the Flutter DevTools "Rebuild" overlay shows unexpected rebuild counts.
- When scrolling or animations feel janky.
