package com.medifamily.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.tencent.android.tpush.XGIOperateCallback
import com.tencent.android.tpush.XGPushConfig
import com.tencent.android.tpush.XGPushManager
import com.tencent.android.tpush.XGPushBaseReceiver
import com.tencent.android.tpush.XGPushClickedResult
import com.tencent.android.tpush.XGPushRegisterResult
import com.tencent.android.tpush.XGPushShowedResult
import com.tencent.android.tpush.XGPushTextMessage

class MainActivity : FlutterActivity() {
    // TPNS 应用信息（com.medifamily.app）
    // AccessId: 1500045920  ← 已确认
    // AccessKey: 从 local.properties 注入（tpns.accessKey）

    companion object {
        private const val TPNS_CHANNEL = "medifamily/tpns"
        // 从 BuildConfig 读取（在 build.gradle 中通过 local.properties 注入）
        private val TPNS_ACCESS_ID  get() = BuildConfig.TPNS_ACCESS_ID.toLongOrNull() ?: 0L
        private val TPNS_ACCESS_KEY get() = BuildConfig.TPNS_ACCESS_KEY
    }

    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 开发阶段开启 TPNS 调试日志
        XGPushConfig.enableDebug(this, BuildConfig.DEBUG)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TPNS_CHANNEL
        ).apply {
            setMethodCallHandler { call, result -> handleMethodCall(call, result) }
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            // Flutter 调用：绑定账号
            "bindAccount" -> {
                val accountId = call.argument<String>("accountId") ?: run {
                    result.error("INVALID_ARGS", "accountId is null", null)
                    return
                }
                // 先注册，再绑定账号（TPNS 要求先完成设备注册）
                XGPushManager.registerPush(
                    applicationContext,
                    TPNS_ACCESS_ID,
                    TPNS_ACCESS_KEY,
                    object : XGIOperateCallback {
                        override fun onSuccess(data: Any?, flag: Int) {
                            XGPushManager.bindAccount(applicationContext, accountId)
                            result.success(true)
                        }
                        override fun onFail(data: Any?, errCode: Int, msg: String?) {
                            result.error("TPNS_ERROR", "注册失败: $msg (code=$errCode)", null)
                        }
                    }
                )
            }

            // Flutter 调用：解绑账号（退出登录时）
            "unbindAccount" -> {
                val accountId = call.argument<String>("accountId") ?: ""
                XGPushManager.delAccount(applicationContext, accountId)
                result.success(true)
            }

            // Flutter 调用：创建通知渠道
            "createChannels" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channels = call.argument<List<Map<String, Any>>>("channels") ?: emptyList()
                    createNotificationChannels(channels)
                }
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    // ── 通知渠道创建（Android 8+）───────────────────────────────────
    private fun createNotificationChannels(channels: List<Map<String, Any>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        channels.forEach { ch ->
            val id         = ch["id"] as? String ?: return@forEach
            val name       = ch["name"] as? String ?: id
            val desc       = ch["description"] as? String ?: ""
            val importance = (ch["importance"] as? Int) ?: NotificationManager.IMPORTANCE_DEFAULT
            val vibration  = ch["enableVibration"] as? Boolean ?: false
            val lights     = ch["enableLights"] as? Boolean ?: false
            val lightColor = (ch["lightColor"] as? Int) ?: Color.WHITE

            val channel = NotificationChannel(id, name, importance).apply {
                description = desc
                enableVibration(vibration)
                if (lights) {
                    enableLights(true)
                    this.lightColor = lightColor
                }
            }
            manager.createNotificationChannel(channel)
        }
    }

    // ── 将 TPNS 推送消息转发给 Flutter ─────────────────────────────
    fun sendToFlutter(method: String, args: Map<String, Any?>) {
        runOnUiThread {
            methodChannel?.invokeMethod(method, args)
        }
    }
}

// ── TPNS 消息接收器（在 AndroidManifest 中注册）─────────────────────
class TPNSReceiver : XGPushBaseReceiver() {

    private fun getMainActivity(context: Context): MainActivity? =
        (context.applicationContext as? android.app.Application)
            ?.let { app ->
                // 遍历 Activity 栈取 MainActivity（简化实现）
                null // 实际通过 Application.ActivityLifecycleCallbacks 维护
            }

    override fun onRegisterResult(context: Context, code: Int, result: XGPushRegisterResult?) {
        if (code == 0) {
            android.util.Log.d("TPNS", "注册成功 token=${result?.token}")
        } else {
            android.util.Log.e("TPNS", "注册失败 code=$code")
        }
    }

    override fun onTextMessage(context: Context, message: XGPushTextMessage?) {
        message ?: return
        val data = mapOf(
            "type"    to (message.customContent ?: ""),
            "title"   to (message.title ?: ""),
            "content" to (message.content ?: ""),
        )
        // 通过 EventBus 或 BroadcastReceiver 转发给 Flutter
        // 实际生产建议用 LocalBroadcastManager
        android.util.Log.d("TPNS", "透传消息: $data")
    }

    override fun onNotifactionShowedResult(context: Context, result: XGPushShowedResult?) {
        // 通知展示回调
    }

    override fun onNotifactionClickedResult(context: Context, result: XGPushClickedResult?) {
        result ?: return
        android.util.Log.d("TPNS", "通知点击 customContent=${result.customContent}")
    }

    override fun onUnregisterResult(context: Context, code: Int) {}
    override fun onSetTagResult(context: Context, code: Int, tagName: String?) {}
    override fun onDeleteTagResult(context: Context, code: Int, tagName: String?) {}
    override fun onQueryTagsResult(context: Context, code: Int, msg: String?, tags: String?) {}
    override fun onSetAccountResult(context: Context, code: Int, accountName: String?) {}
    override fun onDeleteAccountResult(context: Context, code: Int, accountName: String?) {}
}
