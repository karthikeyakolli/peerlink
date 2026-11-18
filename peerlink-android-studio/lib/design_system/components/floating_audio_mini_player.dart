import 'package:flutter/material.dart';
import '../../core/audio_player_service.dart';

/// Minimalist Light-only sticky bottom mini-player bar for background music and lecture listening.
/// Adheres strictly to zero-glow, zero-gradient, and pure #FFFFFF surfaces.
class FloatingAudioMiniPlayer extends StatelessWidget {
  const FloatingAudioMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AudioTrack?>(
      valueListenable: AudioPlayerService.instance.currentTrackNotifier,
      builder: (context, track, _) {
        if (track == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thin progress bar
              ValueListenableBuilder<Duration>(
                valueListenable: AudioPlayerService.instance.positionNotifier,
                builder: (context, pos, _) {
                  final durMs = track.duration.inMilliseconds;
                  final double progress = durMs > 0 ? (pos.inMilliseconds / durMs).clamp(0.0, 1.0) : 0.0;
                  return ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  );
                },
              ),
              InkWell(
                key: const Key('mini_player_body'),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                onTap: () => _showFullPlayerSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      // Album cover art thumbnail or music icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDBEAFE)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: track.albumArtBytes != null
                            ? Image.memory(
                                track.albumArtBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.music_note_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 10),
                      // Title and Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              track.displayTitle,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              track.displayArtist,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Skip Previous
                      IconButton(
                        key: const Key('mini_player_prev'),
                        icon: const Icon(Icons.skip_previous_rounded, size: 20, color: Color(0xFF475569)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Previous Track',
                        onPressed: () => AudioPlayerService.instance.skipPrevious(),
                      ),
                      // Play / Pause
                      ValueListenableBuilder<bool>(
                        valueListenable: AudioPlayerService.instance.isPlayingNotifier,
                        builder: (context, isPlaying, _) {
                          return IconButton(
                            key: const Key('mini_player_play_pause'),
                            icon: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 24,
                              color: const Color(0xFF2563EB),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            tooltip: isPlaying ? 'Pause' : 'Play',
                            onPressed: () => AudioPlayerService.instance.togglePlayPause(),
                          );
                        },
                      ),
                      // Skip Next
                      IconButton(
                        key: const Key('mini_player_next'),
                        icon: const Icon(Icons.skip_next_rounded, size: 20, color: Color(0xFF475569)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Next Track',
                        onPressed: () => AudioPlayerService.instance.skipNext(),
                      ),
                      // Close button
                      IconButton(
                        key: const Key('mini_player_close'),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: 'Close Player',
                        onPressed: () => AudioPlayerService.instance.closeMiniPlayer(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showFullPlayerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AudioPlayerSheetContent(),
    );
  }
}

class _AudioPlayerSheetContent extends StatelessWidget {
  const _AudioPlayerSheetContent();

  @override
  Widget build(BuildContext context) {
    final service = AudioPlayerService.instance;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: ValueListenableBuilder<AudioTrack?>(
        valueListenable: service.currentTrackNotifier,
        builder: (context, track, _) {
          if (track == null) return const SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Album Art Large Display
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                clipBehavior: Clip.antiAlias,
                child: track.albumArtBytes != null
                    ? Image.memory(
                        track.albumArtBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF2563EB),
                          size: 56,
                        ),
                      )
                    : const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF2563EB),
                        size: 56,
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                track.displayTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${track.displayArtist} • ${track.album}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Scrubber and Timestamps
              ValueListenableBuilder<Duration>(
                valueListenable: service.positionNotifier,
                builder: (context, pos, _) {
                  final durSec = track.duration.inSeconds;
                  final curSec = pos.inSeconds.clamp(0, durSec);
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          activeTrackColor: const Color(0xFF2563EB),
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                          thumbColor: const Color(0xFF2563EB),
                        ),
                        child: Slider(
                          value: curSec.toDouble(),
                          min: 0.0,
                          max: durSec > 0 ? durSec.toDouble() : 1.0,
                          onChanged: (val) => service.seekTo(Duration(seconds: val.round())),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${pos.inMinutes}:${(pos.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            Text(
                              track.formattedDuration,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              // Main Control Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle Toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: service.isShuffleNotifier,
                    builder: (context, shuffle, _) {
                      return IconButton(
                        key: const Key('full_player_shuffle'),
                        icon: Icon(
                          Icons.shuffle_rounded,
                          color: shuffle ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                        tooltip: 'Shuffle',
                        onPressed: () => service.toggleShuffle(),
                      );
                    },
                  ),
                  // Previous
                  IconButton(
                    key: const Key('full_player_prev'),
                    icon: const Icon(Icons.skip_previous_rounded, size: 28, color: Color(0xFF334155)),
                    tooltip: 'Previous',
                    onPressed: () => service.skipPrevious(),
                  ),
                  // Play/Pause Large
                  ValueListenableBuilder<bool>(
                    valueListenable: service.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          key: const Key('full_player_play_pause'),
                          iconSize: 36,
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF2563EB),
                          ),
                          onPressed: () => service.togglePlayPause(),
                        ),
                      );
                    },
                  ),
                  // Next
                  IconButton(
                    key: const Key('full_player_next'),
                    icon: const Icon(Icons.skip_next_rounded, size: 28, color: Color(0xFF334155)),
                    tooltip: 'Next',
                    onPressed: () => service.skipNext(),
                  ),
                  // Loop Mode
                  ValueListenableBuilder<AudioLoopMode>(
                    valueListenable: service.loopModeNotifier,
                    builder: (context, mode, _) {
                      IconData icon = Icons.repeat_rounded;
                      Color color = const Color(0xFF94A3B8);
                      if (mode == AudioLoopMode.all) {
                        color = const Color(0xFF2563EB);
                      } else if (mode == AudioLoopMode.one) {
                        icon = Icons.repeat_one_rounded;
                        color = const Color(0xFF2563EB);
                      }
                      return IconButton(
                        key: const Key('full_player_loop'),
                        icon: Icon(icon, color: color),
                        tooltip: 'Repeat: ${mode.name}',
                        onPressed: () => service.cycleLoopMode(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Speed Pill Selector
              ValueListenableBuilder<double>(
                valueListenable: service.speedNotifier,
                builder: (context, speed, _) {
                  return Wrap(
                    spacing: 6,
                    children: [0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                      final selected = (speed - s).abs() < 0.01;
                      return ChoiceChip(
                        label: Text('${s}x', style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        selectedColor: const Color(0xFFEFF6FF),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        side: BorderSide(
                          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                        ),
                        onSelected: (_) => service.setPlaybackSpeed(s),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
