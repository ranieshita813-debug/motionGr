import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_video_editor/core/models/project_model.dart';
import 'package:flutter_video_editor/features/editor/controllers/editor_controller.dart';
import 'package:flutter_video_editor/features/editor/utils/editor_helpers.dart';

class TrackingDataSheet extends StatelessWidget {
  const TrackingDataSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    final clip = editor.selectedClip;
    if (clip == null) {
      return const Center(
        child: Text(
          'Select a clip to view tracking data',
          style: TextStyle(color: Colors.white70, fontFamily: 'Fredoka'),
        ),
      );
    }

    final tracking = clip.trackingData;
    final bool hasData = tracking.points.isNotEmpty;

    return ColoredBox(
      color: bgToken,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF161A20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(
                  tracking.isEnabled ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                  color: tracking.isEnabled ? accentToken : Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracking.isEnabled ? 'Tracking Active' : 'Tracking Disabled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Fredoka',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasData
                            ? '${tracking.points.length} track points recorded'
                            : 'No tracking data available',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Fredoka'),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: tracking.isEnabled,
                  activeThumbColor: accentToken,
                  onChanged: (val) {
                    tapFeedback();
                    editor.updateTrackingData(tracking.copyWith(isEnabled: val));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (hasData) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white12),
              ),
              tileColor: const Color(0xFF161A20),
              leading: const Icon(PhosphorIconsRegular.arrowClockwise, color: accentToken),
              title: const Text(
                'Re-track Subject',
                style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Fredoka'),
              ),
              subtitle: const Text(
                'Select new point and re-run object tracking',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Fredoka'),
              ),
              onTap: () {
                tapFeedback();
                editor.startTrackingPointerMode();
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Colors.white12),
              ),
              tileColor: const Color(0xFF161A20),
              leading: const Icon(PhosphorIconsRegular.trash, color: Colors.redAccent),
              title: const Text(
                'Clear Tracking Data',
                style: TextStyle(color: Colors.redAccent, fontSize: 14, fontFamily: 'Fredoka'),
              ),
              subtitle: const Text(
                'Remove all tracked key points for this clip',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'Fredoka'),
              ),
              onTap: () {
                tapFeedback();
                editor.updateTrackingData(const TrackingData());
              },
            ),
          ] else ...[
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentToken,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(PhosphorIconsRegular.crosshair, size: 18),
                label: const Text(
                  'Start Object Tracking',
                  style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  tapFeedback();
                  editor.startTrackingPointerMode();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
