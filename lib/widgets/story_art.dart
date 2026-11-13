// lib/widgets/story_art.dart
//
// Story illustrations. Pictures live in assets/story_art/ as
// <story id>_<two-digit scene>.webp (scene 00 is the cover). A story shows a
// picture only when that file is in the app; until then a soft card with
// the scene's emoji stands in, so stories work with or without art.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';
import 'motion.dart';

class StoryArt {
  const StoryArt._();

  static Set<String>? _assets;
  static Future<Set<String>>? _loading;

  static String path(String storyId, int scene) =>
      'assets/story_art/${storyId}_${scene.toString().padLeft(2, '0')}.webp';

  /// Every asset path in the app, loaded once.
  static Future<Set<String>> assets() {
    final ready = _assets;
    if (ready != null) {
      return Future.value(ready);
    }
    return _loading ??= AssetManifest.loadFromAssetBundle(rootBundle).then((m) {
      final all = m.listAssets().toSet();
      _assets = all;
      return all;
    }).catchError((Object _) => <String>{});
  }

  static bool hasSync(String storyId, int scene) => _assets?.contains(path(storyId, scene)) ?? false;

  /// The asset list when already loaded, else null.
  static Set<String>? get loadedAssets => _assets;
}

/// One scene of a story, cross-fading when [scene] changes, with a slow
/// zoom ("Ken Burns") so a still picture feels alive.
class StoryScene extends StatefulWidget {
  const StoryScene({
    super.key,
    required this.storyId,
    required this.scene,
    required this.fallbackEmoji,
    this.animate = true,
    this.radius = 24,
  });

  final String storyId;
  final int scene;
  final String fallbackEmoji;
  final bool animate;
  final double radius;

  @override
  State<StoryScene> createState() => _StorySceneState();
}

class _StorySceneState extends State<StoryScene> with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 14));
  Set<String>? _assets = StoryArt._assets;

  @override
  void initState() {
    super.initState();
    if (_assets == null) {
      StoryArt.assets().then((a) {
        if (mounted) {
          setState(() => _assets = a);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate) {
      loopUnlessReducedMotion(_zoom, context, reverse: true);
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = StoryArt.path(widget.storyId, widget.scene);
    final has = _assets?.contains(path) ?? false;
    final Widget child;
    if (has) {
      child = AnimatedBuilder(
        key: ValueKey(path),
        animation: _zoom,
        builder: (context, image) {
          final t = Curves.easeInOut.transform(_zoom.value);
          return Transform.scale(
            scale: 1.0 + 0.08 * t,
            alignment: Alignment(-0.3 + 0.6 * t, 0.2 - 0.4 * t),
            child: image,
          );
        },
        child: Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    } else {
      child = Container(
        key: ValueKey('emoji-${widget.fallbackEmoji}'),
        decoration: const BoxDecoration(gradient: AppGradients.sunrise),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(widget.fallbackEmoji,
                style: const TextStyle(fontFamily: AppTheme.emojiFont, fontSize: 72, height: 1.1)),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: child,
      ),
    );
  }
}
