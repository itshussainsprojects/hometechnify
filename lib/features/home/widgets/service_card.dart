import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/neu_theme.dart';
import '../../../core/utils/service_visuals.dart';
import 'job_posting_modal.dart';
import '../data/models/service_model.dart';

/// Premium service tile - a soft squircle icon chip on white, with a real
/// trade-specific icon and curated color resolved from the service name
/// (never a broken network image or a generic "category" glyph).
class ServiceCard extends StatefulWidget {
  final ServiceModel data;
  final int index;

  const ServiceCard({super.key, required this.data, required this.index});

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final iconContainerSize = isSmall ? 54.0 : 60.0;
    final iconSize = isSmall ? 26.0 : 30.0;
    final visual = ServiceVisuals.of(widget.data.name);
    final serviceColor = visual.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => JobPostingModal(
            serviceName: widget.data.name,
            serviceId: widget.data.id,
            serviceIcon: visual.icon,
            serviceIconUrl: widget.data.iconUrl,
            serviceColor: serviceColor,
          ),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: _isPressed
              ? NeuTheme.inset(radius: 20)
              : NeuTheme.raised(radius: 20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: isSmall ? 12 : 15,
                horizontal: 10,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Trade icon in a soft gradient squircle
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          serviceColor.withValues(alpha: 0.16),
                          serviceColor.withValues(alpha: 0.07),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(iconContainerSize * 0.32),
                    ),
                    child: Icon(visual.icon, size: iconSize, color: serviceColor),
                  ),
                  SizedBox(height: isSmall ? 8 : 10),
                  // Service name
                  Text(
                    widget.data.name,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate(delay: Duration(milliseconds: widget.index * 50)).fadeIn(duration: 350.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
  }
}
