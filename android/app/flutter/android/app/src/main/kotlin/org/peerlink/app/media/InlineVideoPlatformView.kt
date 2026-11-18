package org.peerlink.app.media

import android.content.Context
import android.net.Uri
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.MediaController
import android.widget.VideoView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File

/**
 * Hardware-accelerated inline Android VideoView PlatformView registered as
 * "org.peerlink/inline_video_view" so users can watch received and local videos
 * directly inside PeerLink with play/pause, seek scrub bar, and full GPU decode.
 */
class InlineVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val path = params?.get("path")?.toString() ?: ""
        return InlineVideoPlatformView(context, path)
    }
}

class InlineVideoPlatformView(
    context: Context,
    filePath: String
) : PlatformView {

    private val container: FrameLayout = FrameLayout(context).apply {
        setBackgroundColor(android.graphics.Color.BLACK)
    }
    private val videoView: VideoView = VideoView(context)

    init {
        val lp = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT,
            Gravity.CENTER
        )
        container.addView(videoView, lp)

        val controller = MediaController(context)
        controller.setAnchorView(videoView)
        videoView.setMediaController(controller)

        if (filePath.isNotBlank()) {
            try {
                val uri = if (filePath.startsWith("content://")) {
                    Uri.parse(filePath)
                } else {
                    Uri.fromFile(File(filePath))
                }
                videoView.setVideoURI(uri)
                videoView.setOnPreparedListener { mp ->
                    mp.isLooping = false
                    videoView.start()
                }
                videoView.setOnErrorListener { _, _, _ -> true }
            } catch (_: Exception) {}
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        try {
            videoView.stopPlayback()
        } catch (_: Exception) {}
    }
}
