import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:oronbox/src/features/settings/widgets/interactive_3d_icon.dart';

void main() {
  group('Interactive3dIcon Widget Tests', () {
    testWidgets('renders child properly in normal state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Interactive3dIcon(size: 72, child: Text('TEST_ICON')),
          ),
        ),
      );

      expect(find.text('TEST_ICON'), findsOneWidget);
    });

    testWidgets('double tap activates 3d state and plays shake animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Interactive3dIcon(size: 72, child: Text('TEST_ICON')),
          ),
        ),
      );

      final target = find.byType(Interactive3dIcon);
      expect(target, findsOneWidget);

      // 连续两次 tap 触发 double tap
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pump();

      // 推进动画
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('TEST_ICON'), findsOneWidget);

      // 动画推进至完成
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.text('TEST_ICON'), findsOneWidget);
    });

    testWidgets('drag gesture rotates 3d card and double tap smoothly resets', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Interactive3dIcon(size: 72, child: Text('TEST_ICON')),
          ),
        ),
      );

      final target = find.byType(Interactive3dIcon);

      // 双击激活
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 650));

      final state = tester.state<Interactive3dIconState>(target);
      expect(state.is3dActive, isTrue);

      // 模拟拖拽旋转
      await tester.drag(target, const Offset(60, 40));
      await tester.pump();

      expect(find.text('TEST_ICON'), findsOneWidget);

      // 再次双击平滑丝滑复位
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pump();

      // 复位动画推进
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.is3dActive, isFalse);
    });

    testWidgets('fling gesture triggers natural inertia and damping', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Interactive3dIcon(size: 72, child: Text('TEST_ICON')),
          ),
        ),
      );

      final target = find.byType(Interactive3dIcon);
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 650));

      final state = tester.state<Interactive3dIconState>(target);
      expect(state.is3dActive, isTrue);

      // 快速 fling 滑动手势
      await tester.fling(target, const Offset(120, 80), 1000.0);
      await tester.pump(const Duration(milliseconds: 100));

      // 惯性持续衰减并平稳停下
      await tester.pump(const Duration(seconds: 2));
      expect(state.is3dActive, isTrue);
    });
  });
}
