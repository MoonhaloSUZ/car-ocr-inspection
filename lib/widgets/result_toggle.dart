import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ResultToggle extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const ResultToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleButton(
          label: 'Y',
          selected: value == 'Y',
          selectedColor: AppTheme.yColor,
          onTap: enabled
              ? () => onChanged(value == 'Y' ? null : 'Y')
              : null,
        ),
        const SizedBox(width: 4),
        _ToggleButton(
          label: 'N',
          selected: value == 'N',
          selectedColor: AppTheme.nColor,
          onTap: enabled
              ? () => onChanged(value == 'N' ? null : 'N')
              : null,
        ),
        const SizedBox(width: 4),
        _ToggleButton(
          label: 'NA',
          selected: value == 'NA',
          selectedColor: AppTheme.naColor,
          onTap: enabled
              ? () => onChanged(value == 'NA' ? null : 'NA')
              : null,
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: label == 'NA' ? 40 : 34,
        height: 30,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

// Read-only badge for detail view
class ResultBadge extends StatelessWidget {
  final String? result;
  final double fontSize;

  const ResultBadge({super.key, required this.result, this.fontSize = 12});

  Color get _color {
    switch (result) {
      case 'Y':
        return AppTheme.yColor;
      case 'N':
        return AppTheme.nColor;
      case 'NA':
        return AppTheme.naColor;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = result ?? '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        border: Border.all(color: _color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}
