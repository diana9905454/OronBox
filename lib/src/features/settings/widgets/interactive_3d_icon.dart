import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// 具有轻量实体厚度与自然物理惯性的方形圆角 3D 小卡片
/// 支持双击振动弹性激活浮起，全自由度拖拽与惯性滑行旋转，再次双击或长按平滑丝滑复位
class Interactive3dIcon extends StatefulWidget {
  final Widget child;
  final double size;
  final double thickness;

  const Interactive3dIcon({
    super.key,
    required this.child,
    this.size = 72,
    this.thickness = 8.0,
  });

  @override
  State<Interactive3dIcon> createState() => Interactive3dIconState();
}

class Interactive3dIconState extends State<Interactive3dIcon>
    with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _resetController;
  late final Ticker _inertiaTicker;

  final Stopwatch _tapClock = Stopwatch()..start();
  Duration? _lastTapAt;
  Offset _lastTapPosition = Offset.zero;

  bool _is3dActive = false;
  bool _isResetting = false;
  double _rotateX = 0.0;
  double _rotateY = 0.0;
  double _startRotateX = 0.0;
  double _startRotateY = 0.0;

  // 物理惯性角速度 (rad/s) 与计时
  double _inertiaVelocityX = 0.0;
  double _inertiaVelocityY = 0.0;
  Duration _lastInertiaElapsed = Duration.zero;

  bool get is3dActive => _is3dActive;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _shakeAnimation = CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticOut,
    );

    // 丝滑复位动画控制器：从当前旋转角度与浮起状态平滑缓动归零
    _resetController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 360),
          )
          ..addListener(() {
            final t = Curves.easeOutCubic.transform(_resetController.value);
            setState(() {
              _rotateX = _startRotateX * (1.0 - t);
              _rotateY = _startRotateY * (1.0 - t);
            });
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              setState(() {
                _is3dActive = false;
                _isResetting = false;
                _rotateX = 0.0;
                _rotateY = 0.0;
              });
            }
          });

    // 自然惯性 Ticker：处理松手后的阻尼滑行旋转
    _inertiaTicker = createTicker(_onInertiaTick);
  }

  @override
  void dispose() {
    _inertiaTicker.dispose();
    _shakeController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onInertiaTick(Duration elapsed) {
    if (_lastInertiaElapsed == Duration.zero) {
      _lastInertiaElapsed = elapsed;
      return;
    }
    final dtMicroseconds = (elapsed - _lastInertiaElapsed).inMicroseconds;
    _lastInertiaElapsed = elapsed;

    if (dtMicroseconds <= 0) return;
    final dt = dtMicroseconds / 1000000.0;

    setState(() {
      _rotateX += _inertiaVelocityX * dt;
      _rotateY += _inertiaVelocityY * dt;
    });

    // 采用每秒指数阻尼衰减 (摩擦力衰减，手感自然绵密)
    final damping = math.pow(0.935, dt * 60.0).toDouble();
    _inertiaVelocityX *= damping;
    _inertiaVelocityY *= damping;

    // 速度衰减至阈值以下时平稳停下
    if (_inertiaVelocityX.abs() < 0.08 && _inertiaVelocityY.abs() < 0.08) {
      _stopInertia();
    }
  }

  void _startInertia(Offset velocityPixelsPerSecond) {
    if (!_is3dActive || _isResetting) return;

    final vx = -velocityPixelsPerSecond.dy * 0.024;
    final vy = velocityPixelsPerSecond.dx * 0.024;

    if (vx.abs() < 0.5 && vy.abs() < 0.5) {
      _stopInertia();
      return;
    }

    _inertiaVelocityX = vx.clamp(-32.0, 32.0);
    _inertiaVelocityY = vy.clamp(-32.0, 32.0);
    _lastInertiaElapsed = Duration.zero;

    if (!_inertiaTicker.isActive) {
      _inertiaTicker.start();
    }
  }

  void _stopInertia() {
    _inertiaVelocityX = 0.0;
    _inertiaVelocityY = 0.0;
    _lastInertiaElapsed = Duration.zero;
    if (_inertiaTicker.isActive) {
      _inertiaTicker.stop();
    }
  }

  void _smoothReset() {
    if (!_is3dActive || _isResetting) return;
    _lastTapAt = null;
    _stopInertia();
    HapticFeedback.lightImpact().catchError((_) {});
    _isResetting = true;
    _startRotateX = _rotateX;
    _startRotateY = _rotateY;
    _resetController.forward(from: 0.0);
  }

  void _onTap(Offset position) {
    if (_isResetting) return;

    final now = _tapClock.elapsed;
    final previousTap = _lastTapAt;
    if (previousTap == null ||
        now - previousTap > const Duration(milliseconds: 350) ||
        (position - _lastTapPosition).distance > kDoubleTapSlop) {
      _lastTapAt = now;
      _lastTapPosition = position;
      return;
    }

    _lastTapAt = null;
    if (!_is3dActive) {
      HapticFeedback.mediumImpact().catchError((_) {});
      setState(() {
        _is3dActive = true;
        _rotateX = -0.18;
        _rotateY = 0.24;
      });
      _shakeController.forward(from: 0.0);
    } else {
      _smoothReset();
    }
  }

  void _onPanDelta(Offset delta) {
    if (!_is3dActive || _isResetting) return;
    _lastTapAt = null;
    _stopInertia();
    setState(() {
      _rotateY += delta.dx * 0.024;
      _rotateX -= delta.dy * 0.024;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 匹配 SVG 图标本身的圆角曲率
    final radius = BorderRadius.circular(widget.size * (60.0 / 256.0));

    // 侧边切片颜色：精确对齐图标底色微暗部
    final edgeColor = isDark
        ? const Color(0xFF16191B)
        : const Color(0xFFE2E4E8);

    // 构建手势监听：激活状态下挂载内聚型手势识别器
    final gestures = <Type, GestureRecognizerFactory>{};

    if (!_is3dActive) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            (instance) {
              instance.onTapUp = (details) => _onTap(details.globalPosition);
            },
          );
    } else {
      gestures[_InteractiveCardGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<
            _InteractiveCardGestureRecognizer
          >(
            () => _InteractiveCardGestureRecognizer(
              onTap: _onTap,
              onDragStart: _stopInertia,
              onDragUpdate: _onPanDelta,
              onDragFling: _startInertia,
              onLongPress: _smoothReset,
            ),
            (instance) {
              instance.onTap = _onTap;
              instance.onDragStart = _stopInertia;
              instance.onDragUpdate = _onPanDelta;
              instance.onDragFling = _startInertia;
              instance.onLongPress = _smoothReset;
            },
          );
    }

    return RawGestureDetector(
      gestures: gestures,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeAnimation, _resetController]),
        builder: (context, child) {
          final progress = _shakeAnimation.value;
          final resetProgress = _isResetting
              ? Curves.easeOutCubic.transform(_resetController.value)
              : 0.0;
          final floatScale = _is3dActive
              ? 1.0 + (0.10 * progress) * (1.0 - resetProgress)
              : 1.0;
          final shakeAngle = _isResetting
              ? 0.0
              : math.sin(progress * math.pi * 4) * 0.14 * (1.0 - progress);

          // 正反空间朝向判定
          final isFrontFacing = math.cos(_rotateX) * math.cos(_rotateY) >= 0;

          // 复原轻量实体厚度（约 8 层微步进）
          final sliceCount = widget.thickness.round().clamp(6, 12);
          final sliceStep = widget.thickness / sliceCount;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                ...List.generate(sliceCount + 1, (index) {
                  final layerIndex = isFrontFacing
                      ? index
                      : (sliceCount - index);
                  final zOffset = layerIndex * sliceStep;

                  final matrix = Matrix4.identity()..setEntry(3, 2, 0.0015);
                  matrix.multiply(
                    Matrix4.diagonal3Values(floatScale, floatScale, 1.0),
                  );
                  matrix.rotateZ(shakeAngle);
                  matrix.rotateX(_rotateX);
                  matrix.rotateY(_rotateY);
                  matrix.multiply(Matrix4.translationValues(0.0, 0.0, zOffset));

                  // 正面外表层
                  if (layerIndex == sliceCount) {
                    return Transform(
                      transform: matrix,
                      alignment: FractionalOffset.center,
                      child: isFrontFacing
                          ? SizedBox(
                              width: widget.size,
                              height: widget.size,
                              child: widget.child,
                            )
                          : Container(
                              width: widget.size,
                              height: widget.size,
                              decoration: BoxDecoration(
                                color: edgeColor,
                                borderRadius: radius,
                              ),
                            ),
                    );
                  }

                  // 背面外表层
                  if (layerIndex == 0) {
                    return Transform(
                      transform: matrix,
                      alignment: FractionalOffset.center,
                      child: !isFrontFacing
                          ? SizedBox(
                              width: widget.size,
                              height: widget.size,
                              child: widget.child,
                            )
                          : Container(
                              width: widget.size,
                              height: widget.size,
                              decoration: BoxDecoration(
                                color: edgeColor,
                                borderRadius: radius,
                              ),
                            ),
                    );
                  }

                  // 侧边厚度层
                  return Transform(
                    transform: matrix,
                    alignment: FractionalOffset.center,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        color: edgeColor,
                        borderRadius: radius,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 激活态内聚手势识别器：
/// 在手指按下瞬间接管手势（阻止父级垂直滚动），追踪即时滑动速度并在松手时派发惯性
class _InteractiveCardGestureRecognizer extends OneSequenceGestureRecognizer {
  ValueChanged<Offset> onTap;
  VoidCallback onDragStart;
  ValueChanged<Offset> onDragUpdate;
  ValueChanged<Offset> onDragFling;
  VoidCallback onLongPress;

  int _downPointer = -1;
  Offset _downPosition = Offset.zero;
  Offset _lastPosition = Offset.zero;
  bool _hasMoved = false;
  bool _didLongPress = false;
  Timer? _longPressTimer;
  VelocityTracker? _velocityTracker;

  _InteractiveCardGestureRecognizer({
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragFling,
    required this.onLongPress,
  });

  @override
  String get debugDescription => 'InteractiveCardGestureRecognizer';

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_downPointer != -1) return;

    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);

    _downPointer = event.pointer;
    _downPosition = event.position;
    _lastPosition = event.position;
    _hasMoved = false;
    _didLongPress = false;

    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    onDragStart();

    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 550), () {
      _didLongPress = true;
      onLongPress();
    });
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _downPointer) return;
    if (_didLongPress) {
      if (event is PointerUpEvent || event is PointerCancelEvent) {
        _finishPointer(event.pointer);
      }
      return;
    }

    if (event is PointerMoveEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      final delta = event.position - _lastPosition;
      final totalDist = (event.position - _downPosition).distance;
      if (_hasMoved || totalDist > 4.0) {
        _hasMoved = true;
        _longPressTimer?.cancel();
        onDragUpdate(delta);
      }
      _lastPosition = event.position;
    } else if (event is PointerUpEvent) {
      _velocityTracker?.addPosition(event.timeStamp, event.position);
      _longPressTimer?.cancel();
      final totalDist = (event.position - _downPosition).distance;
      if (!_hasMoved && totalDist < 14.0) {
        onTap(event.position);
      } else if (_hasMoved) {
        // 松手时派发速度，启动自然惯性阻尼滑行
        final velocity =
            _velocityTracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
        onDragFling(velocity);
      }

      _finishPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      _finishPointer(event.pointer);
    }
  }

  void _finishPointer(int pointer) {
    _longPressTimer?.cancel();
    _velocityTracker = null;
    _downPointer = -1;
    stopTrackingPointer(pointer);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
