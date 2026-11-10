import 'package:material_ui/material_ui.dart';
import 'package:segmented_list/section/abstract_segmented_section.dart';

class CustomSegmentedSection extends AbstractSegmentedSection {
  const CustomSegmentedSection({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
