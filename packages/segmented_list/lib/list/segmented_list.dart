import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/section/abstract_segmented_section.dart';

class SegmentedList extends StatelessWidget {
  const SegmentedList({
    required this.sections,
    this.shrinkWrap = false,
    this.maxWidth,
    this.physics,
    this.contentPadding,
    super.key,
  });

  final bool shrinkWrap;
  final double? maxWidth;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? contentPadding;
  final List<AbstractSegmentedSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: sections.length,
      padding: contentPadding ?? const EdgeInsets.symmetric(vertical: 20),
      itemBuilder: (BuildContext context, int index) {
        return Align(
          alignment: Alignment.center,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: sections[index],
          ),
        );
      },
    );
  }
}
