import 'dart:ui';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'reader_status_bar_info.dart';

class ReaderHeader extends StatelessWidget {
  final String mangaTitle;
  final String chapterTitle;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onChapterListTap;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onShowShortcuts;
  final bool isFullscreen;

  const ReaderHeader({
    super.key,
    required this.mangaTitle,
    required this.chapterTitle,
    required this.onBack,
    required this.onSettings,
    this.onChapterListTap,
    this.onToggleFullscreen,
    this.onShowShortcuts,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobilePlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final isMobileDevice = isMobilePlatform || screenWidth < 600;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
                Colors.black.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobileDevice ? 10 : 16,
                vertical: 8,
              ),
              child: Row(
                children: [
                  _buildGlassIconButton(
                    Icons.arrow_back,
                    onBack,
                    tooltip: 'Back (Esc)',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: 'Select Chapter (Danh sách chương)',
                      child: InkWell(
                        onTap: onChapterListTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: onChapterListTap != null
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : Colors.white10,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      mangaTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.menu_book_rounded,
                                          size: 13,
                                          color: AppColors.primary.withValues(alpha: 0.9),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            chapterTitle,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (onChapterListTap != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.45),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.format_list_bulleted_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white.withValues(alpha: 0.85),
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isMobileDevice) ...[
                    const SizedBox(width: 8),
                    const ReaderStatusBarInfo(),
                  ],
                  if (onToggleFullscreen != null) ...[
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      isFullscreen
                          ? Icons.fullscreen_rounded
                          : Icons.fullscreen_exit_rounded,
                      onToggleFullscreen!,
                      tooltip: isFullscreen
                          ? 'Exit Fullscreen (F)'
                          : 'Fullscreen (F)',
                    ),
                  ],
                  if (onShowShortcuts != null && !isMobileDevice) ...[
                    const SizedBox(width: 8),
                    _buildGlassIconButton(
                      Icons.keyboard_alt_outlined,
                      onShowShortcuts!,
                      tooltip: 'Keyboard Shortcuts (?)',
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildGlassIconButton(
                    Icons.settings_outlined,
                    onSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
  }) {
    final button = Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onTap,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
