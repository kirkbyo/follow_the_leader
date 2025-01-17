import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' hide LeaderLayer;
import 'package:flutter/widgets.dart';
import 'package:follow_the_leader/src/logging.dart';
import 'package:vector_math/vector_math_64.dart';

import 'leader.dart';
import 'leader_link.dart';

/// A widget that follows a [Leader].
class Follower extends SingleChildRenderObjectWidget {
  const Follower.withOffset({
    Key? key,
    required this.link,
    this.offset = Offset.zero,
    this.leaderAnchor = Alignment.topCenter,
    this.followerAnchor = Alignment.bottomCenter,
    this.boundary,
    this.showWhenUnlinked = true,
    this.repaintWhenLeaderChanges = false,
    Widget? child,
  })  : aligner = null,
        super(key: key, child: child);

  const Follower.withAligner({
    Key? key,
    required this.link,
    required this.aligner,
    this.boundary,
    this.showWhenUnlinked = false,
    this.repaintWhenLeaderChanges = false,
    Widget? child,
  })  : leaderAnchor = null,
        followerAnchor = null,
        offset = null,
        super(key: key, child: child);

  /// The link object that connects this [CompositedTransformFollower] with a
  /// [CompositedTransformTarget].
  ///
  /// This property must not be null.
  final LeaderLink link;

  /// Boundary that constrains where the follower is allowed to appear, such as
  /// within the bounds of the screen.
  ///
  /// If [boundary] is `null` then the follower isn't constrained at all.
  final FollowerBoundary? boundary;

  final FollowerAligner? aligner;

  /// The anchor point on the linked [CompositedTransformTarget] that
  /// [followerAnchor] will line up with.
  ///
  /// {@template flutter.widgets.CompositedTransformFollower.targetAnchor}
  /// For example, when [leaderAnchor] and [followerAnchor] are both
  /// [Alignment.topLeft], this widget will be top left aligned with the linked
  /// [CompositedTransformTarget]. When [leaderAnchor] is
  /// [Alignment.bottomLeft] and [followerAnchor] is [Alignment.topLeft], this
  /// widget will be left aligned with the linked [CompositedTransformTarget],
  /// and its top edge will line up with the [CompositedTransformTarget]'s
  /// bottom edge.
  /// {@endtemplate}
  ///
  /// Defaults to [Alignment.topLeft].
  final Alignment? leaderAnchor;

  /// The anchor point on this widget that will line up with [followerAnchor] on
  /// the linked [CompositedTransformTarget].
  ///
  /// {@macro flutter.widgets.CompositedTransformFollower.targetAnchor}
  ///
  /// Defaults to [Alignment.topLeft].
  final Alignment? followerAnchor;

  /// The additional offset to apply to the [leaderAnchor] of the linked
  /// [CompositedTransformTarget] to obtain this widget's [followerAnchor]
  /// position.
  final Offset? offset;

  /// Whether to show the widget's contents when there is no corresponding
  /// [Leader] with the same [link].
  ///
  /// When the widget is not linked, then: if [showWhenUnlinked] is true, the
  /// child is visible and not repositioned; if it is false, then child is
  /// hidden.
  final bool showWhenUnlinked;

  /// Whether to repaint the [child] when the [Leader] changes offset
  /// or size.
  ///
  /// This should be `true` when the [child]'s appearance is based on the
  /// location or size of the [Leader], such as a menu with an arrow that
  /// points in the direction of the [Leader]. Otherwise, if the [child]'s
  /// appearance isn't impacted by [Leader], then passing `false` will be
  /// more efficient, because fewer repaints will be scheduled.
  final bool repaintWhenLeaderChanges;

  @override
  RenderFollower createRenderObject(BuildContext context) {
    return RenderFollower(
      link: link,
      offset: offset,
      leaderAnchor: leaderAnchor,
      followerAnchor: followerAnchor,
      aligner: aligner,
      boundary: boundary,
      showWhenUnlinked: showWhenUnlinked,
      repaintWhenLeaderChanges: repaintWhenLeaderChanges,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderFollower renderObject) {
    renderObject
      ..link = link
      ..offset = offset
      ..leaderAnchor = leaderAnchor
      ..followerAnchor = followerAnchor
      ..aligner = aligner
      ..boundary = boundary
      ..showWhenUnlinked = showWhenUnlinked
      ..repaintWhenLeaderChanges = repaintWhenLeaderChanges;
  }
}

abstract class FollowerAligner {
  FollowerAlignment align(Rect globalLeaderRect, Size followerSize);
}

class FollowerAlignment {
  const FollowerAlignment({
    required this.leaderAnchor,
    required this.followerAnchor,
    this.followerOffset = Offset.zero,
  });

  final Alignment leaderAnchor;
  final Alignment followerAnchor;
  final Offset followerOffset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowerAlignment &&
          runtimeType == other.runtimeType &&
          leaderAnchor == other.leaderAnchor &&
          followerAnchor == other.followerAnchor;

  @override
  int get hashCode => leaderAnchor.hashCode ^ followerAnchor.hashCode;
}

/// A boundary that determines where a [Follower] is allowed to appear.
abstract class FollowerBoundary {
  /// Returns `true` if the given [offset] sits within this boundary,
  /// or `false` if it sits outside.
  bool contains(Offset offset);

  /// Constrains the given [desiredOffset] to a legal [Offset] for this
  /// boundary.
  Offset constrain(LeaderLink link, RenderBox follower, Offset desiredOffset);
}

/// A [FollowerBoundary] that keeps the follower within the screen bounds.
class ScreenFollowerBoundary implements FollowerBoundary {
  const ScreenFollowerBoundary(this.screenSize);

  final Size screenSize;

  @override
  bool contains(Offset offset) => screenSize.contains(offset);

  @override
  Offset constrain(LeaderLink link, RenderBox follower, Offset desiredOffset) {
    final followerSize = follower.size;
    final followerOffset = link.leader!.offset + desiredOffset;
    final xAdjustment = followerOffset.dx < 0
        ? -followerOffset.dx
        : followerOffset.dx > (screenSize.width - followerSize.width)
            ? (screenSize.width - followerSize.width) - followerOffset.dx
            : 0.0;
    final yAdjustment = followerOffset.dy < 0
        ? -followerOffset.dy
        : followerOffset.dy > (screenSize.height - followerSize.height)
            ? (screenSize.height - followerSize.height) - followerOffset.dy
            : 0.0;
    final adjustment = Offset(xAdjustment, yAdjustment);

    return desiredOffset + adjustment;
  }
}

/// A [FollowerBoundary] that keeps the follower within the bounds of the widget
/// attached to the given [boundaryKey].
class WidgetFollowerBoundary implements FollowerBoundary {
  const WidgetFollowerBoundary(this.boundaryKey);

  final GlobalKey? boundaryKey;

  @override
  bool contains(Offset offset) {
    if (boundaryKey == null || boundaryKey!.currentContext == null) {
      return false;
    }

    final boundaryBox = boundaryKey!.currentContext!.findRenderObject() as RenderBox;
    final boundaryRect = Rect.fromPoints(
      boundaryBox.localToGlobal(Offset.zero),
      boundaryBox.localToGlobal(boundaryBox.size.bottomRight(Offset.zero)),
    );
    return boundaryRect.contains(offset);
  }

  @override
  Offset constrain(LeaderLink link, RenderBox follower, Offset desiredOffset) {
    if (boundaryKey == null) {
      return desiredOffset;
    }

    if (boundaryKey!.currentContext == null) {
      FtlLogs.follower.warning(
          "Tried to constrain a follower to bounds of another widget, but the GlobalKey wasn't attached to anything: $boundaryKey");
      return desiredOffset;
    }

    final boundaryBox = boundaryKey!.currentContext!.findRenderObject() as RenderBox;
    final followerSize = follower.size;
    final boundaryGlobalOrigin = boundaryBox.localToGlobal(Offset.zero);
    final followerOffset = link.leader!.offset + desiredOffset;
    final xAdjustment = followerOffset.dx < boundaryGlobalOrigin.dx
        ? boundaryGlobalOrigin.dx - followerOffset.dx
        : followerOffset.dx > (boundaryGlobalOrigin.dx + boundaryBox.size.width - followerSize.width)
            ? (boundaryBox.size.width - followerSize.width) - followerOffset.dx + boundaryGlobalOrigin.dx
            : 0.0;
    final yAdjustment = followerOffset.dy < boundaryGlobalOrigin.dy
        ? boundaryGlobalOrigin.dy - followerOffset.dy
        : followerOffset.dy > (boundaryGlobalOrigin.dy + boundaryBox.size.height - followerSize.height)
            ? (boundaryBox.size.height - followerSize.height) - followerOffset.dy + boundaryGlobalOrigin.dy
            : 0.0;
    final adjustment = Offset(xAdjustment, yAdjustment);

    return desiredOffset + adjustment;
  }
}

class RenderFollower extends RenderProxyBox {
  RenderFollower({
    required LeaderLink link,
    FollowerBoundary? boundary,
    FollowerAligner? aligner,
    Alignment? leaderAnchor = Alignment.topLeft,
    Alignment? followerAnchor = Alignment.topLeft,
    Offset? offset = Offset.zero,
    bool showWhenUnlinked = true,
    bool repaintWhenLeaderChanges = false,
    RenderBox? child,
  })  : _link = link,
        _offset = offset,
        _leaderAnchor = leaderAnchor,
        _followerAnchor = followerAnchor,
        _aligner = aligner,
        _boundary = boundary,
        _showWhenUnlinked = showWhenUnlinked,
        _repaintWhenLeaderChanges = repaintWhenLeaderChanges,
        super(child);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (repaintWhenLeaderChanges) {
      _link.addListener(_onLinkChange);
    }
  }

  @override
  void detach() {
    if (repaintWhenLeaderChanges) {
      _link.removeListener(_onLinkChange);
    }
    layer = null;
    super.detach();
  }

  /// The link object that connects this [RenderFollower] with a
  /// [RenderLeaderLayer] earlier in the paint order.
  LeaderLink get link => _link;
  LeaderLink _link;
  set link(LeaderLink value) {
    if (_link == value) {
      return;
    }

    FtlLogs.follower.fine("Setting new link - $value");

    if (repaintWhenLeaderChanges) {
      _link.removeListener(_onLinkChange);
    }

    _link = value;

    if (repaintWhenLeaderChanges) {
      _link.addListener(_onLinkChange);
    }

    _firstPaintOfCurrentLink = true;

    markNeedsPaint();
  }

  void _onLinkChange() {
    if (owner == null) {
      // We're not attached to the framework pipeline.
      return;
    }

    FtlLogs.follower.finest("Follower's LeaderLink reported a change: $_link. Requesting Follower child repaint.");
    child?.markNeedsPaint();
  }

  FollowerBoundary? get boundary => _boundary;
  FollowerBoundary? _boundary;
  set boundary(FollowerBoundary? newValue) {
    if (newValue == _boundary) {
      return;
    }

    _boundary = newValue;
    markNeedsPaint();
  }

  FollowerAligner? get aligner => _aligner;
  FollowerAligner? _aligner;
  set aligner(FollowerAligner? newAligner) {
    if (newAligner == _aligner) {
      return;
    }

    _aligner = newAligner;
    markNeedsPaint();
  }

  /// The offset to apply to the origin of the linked [RenderLeaderLayer] to
  /// obtain this render object's origin.
  Offset? get offset => _offset;
  Offset? _offset;
  set offset(Offset? value) {
    if (_offset == value) return;
    FtlLogs.follower.fine("Setting new follower offset");
    _offset = value;
    markNeedsPaint();
  }

  /// The anchor point on the linked [RenderLeaderLayer] that [followerAnchor]
  /// will line up with.
  ///
  /// {@template flutter.rendering.RenderFollowerLayer.leaderAnchor}
  /// For example, when [leaderAnchor] and [followerAnchor] are both
  /// [Alignment.topLeft], this [RenderFollower] will be top left aligned
  /// with the linked [RenderLeaderLayer]. When [leaderAnchor] is
  /// [Alignment.bottomLeft] and [followerAnchor] is [Alignment.topLeft], this
  /// [RenderFollower] will be left aligned with the linked
  /// [RenderLeaderLayer], and its top edge will line up with the
  /// [RenderLeaderLayer]'s bottom edge.
  /// {@endtemplate}
  ///
  /// Defaults to [Alignment.topLeft].
  Alignment? get leaderAnchor => _leaderAnchor;
  Alignment? _leaderAnchor;
  set leaderAnchor(Alignment? value) {
    if (_leaderAnchor == value) return;
    _leaderAnchor = value;
    markNeedsPaint();
  }

  /// The anchor point on this [RenderFollower] that will line up with
  /// [followerAnchor] on the linked [RenderLeaderLayer].
  ///
  /// {@macro flutter.rendering.RenderFollowerLayer.leaderAnchor}
  ///
  /// Defaults to [Alignment.topLeft].
  Alignment? get followerAnchor => _followerAnchor;
  Alignment? _followerAnchor;
  set followerAnchor(Alignment? value) {
    if (_followerAnchor == value) return;
    _followerAnchor = value;
    markNeedsPaint();
  }

  bool get showWhenUnlinked => _showWhenUnlinked;
  bool _showWhenUnlinked;
  set showWhenUnlinked(bool value) {
    if (_showWhenUnlinked == value) return;
    _showWhenUnlinked = value;
    markNeedsPaint();
  }

  bool get repaintWhenLeaderChanges => _repaintWhenLeaderChanges;
  bool _repaintWhenLeaderChanges;
  set repaintWhenLeaderChanges(bool newValue) {
    if (newValue == _repaintWhenLeaderChanges) {
      return;
    }

    _repaintWhenLeaderChanges = newValue;
    if (_repaintWhenLeaderChanges) {
      _link.addListener(_onLinkChange);
    } else {
      _link.removeListener(_onLinkChange);
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  /// The layer we created when we were last painted.
  @override
  FollowerLayer? get layer => super.layer as FollowerLayer?;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // Disables the hit testing if this render object is hidden.
    if (!link.leaderConnected && !showWhenUnlinked) return false;
    // RenderFollowerLayer objects don't check if they are
    // themselves hit, because it's confusing to think about
    // how the untransformed size and the child's transformed
    // position interact.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final followerOffset = _previousFollowerOffset ?? Offset.zero;
    final transform = layer?.getLastTransform()?..translate(followerOffset.dx, followerOffset.dy);

    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (BoxHitTestResult result, Offset position) {
        return super.hitTestChildren(result, position: position);
      },
    );
  }

  Offset? _previousFollowerOffset;
  Offset? get previousFollowerOffset => _previousFollowerOffset;

  /// Indicates whether or not we are in the first paint of the current [LeaderLink].
  bool _firstPaintOfCurrentLink = true;

  @override
  void paint(PaintingContext context, Offset offset) {
    FtlLogs.follower.fine("Painting composited follower: $offset");

    if (!link.leaderConnected && _previousFollowerOffset == null) {
      FtlLogs.follower.fine("The leader isn't connected and there's no cached offset. Not painting anything.");
      if (!_firstPaintOfCurrentLink) {
        // We already painted and we still don't have a leader connected.
        // Avoid subsequent paint requests.
        return;
      }
      _firstPaintOfCurrentLink = false;

      // In the first frame we are not connected to the leader.
      // Check again in the next frame only if it's the first paint of the current link.
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (link.leaderConnected) {
          markNeedsPaint();
        }
      });

      // Wait until the next frame to check if we have a leader connected.
      return;
    }

    if (link.leaderConnected) {
      _calculateFollowerOffset();
    }

    if (layer == null) {
      layer = FollowerLayer(
        link: link,
        showWhenUnlinked: showWhenUnlinked,
        linkedOffset: _previousFollowerOffset,
        unlinkedOffset: _previousFollowerOffset,
      );
    } else {
      layer
        ?..link = link
        ..showWhenUnlinked = showWhenUnlinked
        ..linkedOffset = _previousFollowerOffset
        ..unlinkedOffset = _previousFollowerOffset;
    }

    context.pushLayer(
      layer!,
      (context, offset) {
        FtlLogs.follower.fine("Painting follower content.");
        super.paint(context, offset);
      },
      Offset.zero,
      // We don't know where we'll end up, so we have no idea what our cull rect should be.
      childPaintBounds: Rect.largest,
    );
  }

  void _calculateFollowerOffset() {
    if (aligner != null) {
      _calculateFollowerOffsetWithAligner();
    } else {
      _calculateFollowerOffsetWithStaticValue();
    }
  }

  void _calculateFollowerOffsetWithAligner() {
    final globalLeaderRect = link.leader!.offset & link.leaderSize!;
    final followerAlignment = aligner!.align(globalLeaderRect, size);
    final leaderAnchor = followerAlignment.leaderAnchor;
    final followerAnchor = followerAlignment.followerAnchor;

    final Size? leaderSize = link.leaderSize;
    assert(
      link.leaderSize != null || (!link.leaderConnected || leaderAnchor == Alignment.topLeft),
      '$link: layer is linked to ${link.leader} but a valid leaderSize is not set. '
      'leaderSize is required when leaderAnchor is not Alignment.topLeft '
      '(current value is $leaderAnchor).',
    );

    final Offset effectiveLinkedOffset =
        (leaderSize == null ? Offset.zero : leaderAnchor.alongSize(leaderSize) - followerAnchor.alongSize(size)) +
            followerAlignment.followerOffset;
    FtlLogs.follower.fine("Leader layer offset: ${link.leader!.offset}");

    _previousFollowerOffset =
        boundary != null ? boundary!.constrain(link, this, effectiveLinkedOffset) : effectiveLinkedOffset;
  }

  void _calculateFollowerOffsetWithStaticValue() {
    final Size? leaderSize = link.leaderSize;
    assert(
      link.leaderSize != null || (!link.leaderConnected || leaderAnchor == Alignment.topLeft),
      '$link: layer is linked to ${link.leader} but a valid leaderSize is not set. '
      'leaderSize is required when leaderAnchor is not Alignment.topLeft '
      '(current value is $leaderAnchor).',
    );

    final Offset effectiveLinkedOffset = (leaderSize == null
        ? offset!
        : leaderAnchor!.alongSize(leaderSize) - followerAnchor!.alongSize(size) + offset!);
    FtlLogs.follower.fine("Leader layer offset: ${link.leader!.offset}");

    _previousFollowerOffset =
        boundary != null ? boundary!.constrain(link, this, effectiveLinkedOffset) : effectiveLinkedOffset;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(getCurrentTransform());
  }

  /// Return the transform that was used in the last composition phase, if any.
  ///
  /// If the [FollowerLayer] has not yet been created, was never composited, or
  /// was unable to determine the transform (see
  /// [FollowerLayer.getLastTransform]), this returns the identity matrix (see
  /// [Matrix4.identity].
  Matrix4 getCurrentTransform() {
    // return layer?.getLastTransform() ?? Matrix4.identity();

    final transform = layer?.getLastTransform() ?? Matrix4.identity();
    if (_previousFollowerOffset != null) {
      transform.translate(_previousFollowerOffset!.dx, _previousFollowerOffset!.dy);
    }
    return transform;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LeaderLink>('link', link));
    properties.add(DiagnosticsProperty<bool>('showWhenUnlinked', showWhenUnlinked));
    properties.add(DiagnosticsProperty<Offset>('offset', offset));
    properties.add(TransformProperty('current transform matrix', getCurrentTransform()));
  }
}

/// A composited layer that applies a transformation matrix to its children such
/// that they are positioned to match a [LeaderLayer].
///
/// If any of the ancestors of this layer have a degenerate matrix (e.g. scaling
/// by zero), then the [FollowerLayer] will not be able to transform its child
/// to the coordinate space of the [LeaderLayer].
///
/// A [linkedOffset] property can be provided to further offset the child layer
/// from the leader layer, for example if the child is to follow the linked
/// layer at a distance rather than directly overlapping it.
class FollowerLayer extends ContainerLayer {
  /// Creates a follower layer.
  ///
  /// The [link] property must not be null.
  ///
  /// The [unlinkedOffset], [linkedOffset], and [showWhenUnlinked] properties
  /// must be non-null before the compositing phase of the pipeline.
  FollowerLayer({
    required LeaderLink link,
    this.showWhenUnlinked = true,
    this.unlinkedOffset = Offset.zero,
    this.linkedOffset = Offset.zero,
  }) : _link = link;

  /// The link to the [LeaderLayer].
  ///
  /// The same object should be provided to a [LeaderLayer] that is earlier in
  /// the layer tree. When this layer is composited, it will apply a transform
  /// that moves its children to match the position of the [LeaderLayer].
  LeaderLink get link => _link;
  set link(LeaderLink value) {
    if (value != _link && _leaderHandle != null) {
      _leaderHandle!.dispose();
      _leaderHandle = value.registerFollower();
    }
    _link = value;
  }

  LeaderLink _link;

  /// Whether to show the layer's contents when the [link] does not point to a
  /// [LeaderLayer].
  ///
  /// When the layer is linked, children layers are positioned such that they
  /// have the same global position as the linked [LeaderLayer].
  ///
  /// When the layer is not linked, then: if [showWhenUnlinked] is true,
  /// children are positioned as if the [FollowerLayer] was a [ContainerLayer];
  /// if it is false, then children are hidden.
  ///
  /// The [showWhenUnlinked] property must be non-null before the compositing
  /// phase of the pipeline.
  bool? showWhenUnlinked;

  /// Offset from parent in the parent's coordinate system, used when the layer
  /// is not linked to a [LeaderLayer].
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [unlinkedOffset] property must be non-null before the compositing
  /// phase of the pipeline.
  ///
  /// See also:
  ///
  ///  * [linkedOffset], for when the layers are linked.
  Offset? unlinkedOffset;

  /// Offset from the origin of the leader layer to the origin of the child
  /// layers, used when the layer is linked to a [LeaderLayer].
  ///
  /// The scene must be explicitly recomposited after this property is changed
  /// (as described at [Layer]).
  ///
  /// The [linkedOffset] property must be non-null before the compositing phase
  /// of the pipeline.
  ///
  /// See also:
  ///
  ///  * [unlinkedOffset], for when the layer is not linked.
  Offset? linkedOffset;

  CustomLayerLinkHandle? _leaderHandle;

  @override
  void attach(Object owner) {
    super.attach(owner);
    _leaderHandle = _link.registerFollower();
  }

  @override
  void detach() {
    super.detach();
    _leaderHandle?.dispose();
    _leaderHandle = null;
  }

  Offset? _lastOffset;
  Matrix4? _lastTransform;
  Matrix4? _invertedTransform;
  bool _inverseDirty = true;

  Offset? _transformOffset(Offset localPosition) {
    if (_inverseDirty) {
      _invertedTransform = Matrix4.tryInvert(getLastTransform()!);
      _inverseDirty = false;
    }
    if (_invertedTransform == null) {
      return null;
    }
    final Vector4 vector = Vector4(localPosition.dx, localPosition.dy, 0.0, 1.0);
    final Vector4 result = _invertedTransform!.transform(vector);
    return Offset(result[0] - linkedOffset!.dx, result[1] - linkedOffset!.dy);
  }

  @override
  bool findAnnotations<S extends Object>(AnnotationResult<S> result, Offset localPosition, {required bool onlyFirst}) {
    if (_leaderHandle!.leader == null) {
      if (showWhenUnlinked!) {
        return super.findAnnotations(result, localPosition - unlinkedOffset!, onlyFirst: onlyFirst);
      }
      return false;
    }
    final Offset? transformedOffset = _transformOffset(localPosition);
    if (transformedOffset == null) {
      return false;
    }
    return super.findAnnotations<S>(result, transformedOffset, onlyFirst: onlyFirst);
  }

  /// The transform that was used during the last composition phase.
  ///
  /// If the [link] was not linked to a [LeaderLayer], or if this layer has
  /// a degenerate matrix applied, then this will be null.
  ///
  /// This method returns a new [Matrix4] instance each time it is invoked.
  Matrix4? getLastTransform() {
    if (_lastTransform == null) {
      return null;
    }
    final Matrix4 result = Matrix4.translationValues(-_lastOffset!.dx, -_lastOffset!.dy, 0.0);
    result.multiply(_lastTransform!);
    return result;
  }

  /// Call [applyTransform] for each layer in the provided list.
  ///
  /// The list is in reverse order (deepest first). The first layer will be
  /// treated as the child of the second, and so forth. The first layer in the
  /// list won't have [applyTransform] called on it. The first layer may be
  /// null.
  static Matrix4 _collectTransformForLayerChain(List<ContainerLayer?> layers) {
    // Initialize our result matrix.
    final Matrix4 result = Matrix4.identity();
    // Apply each layer to the matrix in turn, starting from the last layer,
    // and providing the previous layer as the child.
    for (int index = layers.length - 1; index > 0; index -= 1) {
      layers[index]?.applyTransform(layers[index - 1], result);
    }
    return result;
  }

  /// Find the common ancestor of two layers [a] and [b] by searching towards
  /// the root of the tree, and append each ancestor of [a] or [b] visited along
  /// the path to [ancestorsA] and [ancestorsB] respectively.
  ///
  /// Returns null if [a] [b] do not share a common ancestor, in which case the
  /// results in [ancestorsA] and [ancestorsB] are undefined.
  static Layer? _pathsToCommonAncestor(
    Layer? a,
    Layer? b,
    List<ContainerLayer?> ancestorsA,
    List<ContainerLayer?> ancestorsB,
  ) {
    // No common ancestor found.
    if (a == null || b == null) {
      return null;
    }

    if (identical(a, b)) {
      return a;
    }

    if (a.depth < b.depth) {
      ancestorsB.add(b.parent);
      return _pathsToCommonAncestor(a, b.parent, ancestorsA, ancestorsB);
    } else if (a.depth > b.depth) {
      ancestorsA.add(a.parent);
      return _pathsToCommonAncestor(a.parent, b, ancestorsA, ancestorsB);
    }

    ancestorsA.add(a.parent);
    ancestorsB.add(b.parent);
    return _pathsToCommonAncestor(a.parent, b.parent, ancestorsA, ancestorsB);
  }

  /// Populate [_lastTransform] given the current state of the tree.
  void _establishTransform() {
    _lastTransform = null;
    final LeaderLayer? leader = _leaderHandle!.leader;
    // Check to see if we are linked.
    if (leader == null) {
      return;
    }
    // If we're linked, check the link is valid.
    assert(
      leader.owner == owner,
      'Linked LeaderLayer anchor is not in the same layer tree as the FollowerLayer.',
    );
    assert(
      leader.lastOffset != null,
      'LeaderLayer anchor must come before FollowerLayer in paint order, but the reverse was true.',
    );

    // Stores [leader, ..., commonAncestor] after calling _pathsToCommonAncestor.
    final List<ContainerLayer?> forwardLayers = <ContainerLayer>[leader];
    // Stores [this (follower), ..., commonAncestor] after calling
    // _pathsToCommonAncestor.
    final List<ContainerLayer?> inverseLayers = <ContainerLayer>[this];

    final Layer? ancestor = _pathsToCommonAncestor(
      leader,
      this,
      forwardLayers,
      inverseLayers,
    );
    assert(ancestor != null);

    final Matrix4 forwardTransform = _collectTransformForLayerChain(forwardLayers);
    // Further transforms the coordinate system to a hypothetical child (null)
    // of the leader layer, to account for the leader's additional paint offset
    // and layer offset (LeaderLayer._lastOffset).
    leader.applyTransform(null, forwardTransform);
    forwardTransform.translate(linkedOffset!.dx, linkedOffset!.dy);

    final Matrix4 inverseTransform = _collectTransformForLayerChain(inverseLayers);

    if (inverseTransform.invert() == 0.0) {
      // We are in a degenerate transform, so there's not much we can do.
      return;
    }
    // Combine the matrices and store the result.
    inverseTransform.multiply(forwardTransform);
    _lastTransform = inverseTransform;
    _inverseDirty = true;
  }

  /// {@template flutter.rendering.FollowerLayer.alwaysNeedsAddToScene}
  /// This disables retained rendering.
  ///
  /// A [FollowerLayer] copies changes from a [LeaderLayer] that could be anywhere
  /// in the Layer tree, and that leader layer could change without notifying the
  /// follower layer. Therefore we have to always call a follower layer's
  /// [addToScene]. In order to call follower layer's [addToScene], leader layer's
  /// [addToScene] must be called first so leader layer must also be considered
  /// as [alwaysNeedsAddToScene].
  /// {@endtemplate}
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    assert(showWhenUnlinked != null);
    if (_leaderHandle!.leader == null && !showWhenUnlinked!) {
      _lastTransform = null;
      _lastOffset = null;
      _inverseDirty = true;
      engineLayer = null;
      return;
    }
    _establishTransform();
    if (_lastTransform != null) {
      engineLayer = builder.pushTransform(
        _lastTransform!.storage,
        oldLayer: engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
      _lastOffset = unlinkedOffset;
    } else {
      _lastOffset = null;
      final Matrix4 matrix = Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, .0);
      engineLayer = builder.pushTransform(
        matrix.storage,
        oldLayer: engineLayer as ui.TransformEngineLayer?,
      );
      addChildrenToScene(builder);
      builder.pop();
    }
    _inverseDirty = true;
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    assert(child != null);
    if (_lastTransform != null) {
      transform.multiply(_lastTransform!);
    } else {
      transform.multiply(Matrix4.translationValues(unlinkedOffset!.dx, unlinkedOffset!.dy, 0));
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LeaderLink>('link', link));
    properties.add(TransformProperty('transform', getLastTransform(), defaultValue: null));
  }
}
