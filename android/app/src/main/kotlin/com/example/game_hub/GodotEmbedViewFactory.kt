package com.example.game_hub

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Factory registered under the `godot_embed_view` view type name, so the
 * Dart side can create it via `AndroidView(viewType: 'godot_embed_view')`.
 *
 * Uses [StandardMessageCodec] so `creationParams` sent from Dart (a plain
 * Map passed with `creationParamsCodec: const StandardMessageCodec()`)
 * decode straight into the `Map<String?, Any?>?` that [GodotEmbedView]
 * expects.
 */
class GodotEmbedViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String?, Any?>
        return GodotEmbedView(context, viewId, creationParams)
    }
}
