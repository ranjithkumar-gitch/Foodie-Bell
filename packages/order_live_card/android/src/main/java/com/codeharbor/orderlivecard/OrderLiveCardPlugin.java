package com.codeharbor.orderlivecard;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.service.notification.StatusBarNotification;
import android.view.View;
import android.widget.RemoteViews;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * The live order card in the notification bar, drawn with a native layout
 * that copies the app's home order card: stage icon, title and subtitle,
 * the step progress bar, the shop with items and total, and the delivery
 * code strip. Called from Dart (`lib/order_live_card.dart`), including from
 * FCM's background isolate, so it works while the app is closed.
 */
public class OrderLiveCardPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.NewIntentListener {
    static final String CHANNEL_ID = "order_live_v1";
    static final String EXTRA_ROUTE = "order_live_route";
    static final String EXTRA_STAGE = "order_live_stage";
    static final String EXTRA_HASH = "order_live_hash";

    private static final int[] SEGMENTS = {R.id.olc_seg1, R.id.olc_seg2, R.id.olc_seg3, R.id.olc_seg4, R.id.olc_seg5};

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activityBinding;
    private String launchRoute;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "order_live_card");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "show":
                    show(call);
                    result.success(null);
                    break;
                case "cancel": {
                    Integer id = call.argument("id");
                    String tag = call.argument("tag");
                    NotificationManagerCompat.from(context).cancel(tag, id == null ? 0 : id);
                    result.success(null);
                    break;
                }
                case "active":
                    result.success(active(call));
                    break;
                case "takeLaunchRoute": {
                    String route = launchRoute;
                    launchRoute = null;
                    result.success(route);
                    break;
                }
                default:
                    result.notImplemented();
            }
        } catch (Exception e) {
            result.error("order_live_card", e.getMessage(), null);
        }
    }

    private void ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return;
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null || nm.getNotificationChannel(CHANNEL_ID) != null) return;
        NotificationChannel ch = new NotificationChannel(CHANNEL_ID, "Order in progress", NotificationManager.IMPORTANCE_HIGH);
        ch.setDescription("Your current order or delivery, updated at every step.");
        nm.createNotificationChannel(ch);
    }

    private int smallIcon() {
        int id = context.getResources().getIdentifier("ic_notification", "drawable", context.getPackageName());
        return id != 0 ? id : context.getApplicationInfo().icon;
    }

    private static String str(MethodCall call, String key) {
        Object v = call.argument(key);
        return v == null ? "" : v.toString();
    }

    private static int num(MethodCall call, String key) {
        Object v = call.argument(key);
        return v instanceof Number ? ((Number) v).intValue() : 0;
    }

    private static boolean flag(MethodCall call, String key) {
        Object v = call.argument(key);
        return v instanceof Boolean && (Boolean) v;
    }

    /** Colour [color] with [alpha] (0–255). */
    private static int withAlpha(int color, int alpha) {
        return (color & 0x00FFFFFF) | (alpha << 24);
    }

    private void fillCommon(RemoteViews v, String title, String subtitle, String emoji, int color) {
        v.setTextViewText(R.id.olc_title, title);
        v.setTextViewText(R.id.olc_subtitle, subtitle);
        v.setTextViewText(R.id.olc_emoji, emoji);
        v.setInt(R.id.olc_icon_bg, "setColorFilter", withAlpha(color, 0x2E));
    }

    private void show(MethodCall call) {
        ensureChannel();
        int id = num(call, "id");
        String tag = str(call, "tag");
        String title = str(call, "title");
        String subtitle = str(call, "subtitle");
        String emoji = str(call, "emoji");
        int step = num(call, "step");
        int steps = Math.min(num(call, "steps"), SEGMENTS.length);
        int color = num(call, "color");
        boolean ongoing = flag(call, "ongoing");
        String otp = call.argument("otp");
        String pkg = context.getPackageName();

        RemoteViews small = new RemoteViews(pkg, R.layout.olc_small);
        fillCommon(small, title, subtitle, emoji, color);

        RemoteViews big = new RemoteViews(pkg, R.layout.olc_big);
        fillCommon(big, title, subtitle, emoji, color);
        // The progress bar: done steps in the brand colour, the current one
        // lighter, the rest grey — the home card's bar, without the sweep.
        big.setViewVisibility(R.id.olc_progress, steps > 0 ? View.VISIBLE : View.GONE);
        for (int i = 0; i < SEGMENTS.length; i++) {
            int seg = SEGMENTS[i];
            if (i >= steps) {
                big.setViewVisibility(seg, View.GONE);
                continue;
            }
            big.setViewVisibility(seg, View.VISIBLE);
            int n = i + 1;
            int c = n < step ? color : n == step ? withAlpha(color, 0x99) : 0xFFE0E0E0;
            big.setInt(seg, "setColorFilter", c);
        }
        big.setTextViewText(R.id.olc_footer_title, str(call, "footerTitle"));
        big.setTextViewText(R.id.olc_footer_text, str(call, "footerText"));
        if (otp != null && !otp.isEmpty()) {
            big.setViewVisibility(R.id.olc_otp_row, View.VISIBLE);
            big.setTextViewText(R.id.olc_otp, otp);
            big.setTextViewText(R.id.olc_otp_label, str(call, "otpLabel"));
        } else {
            big.setViewVisibility(R.id.olc_otp_row, View.GONE);
        }

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(pkg);
        if (launch == null) launch = new Intent();
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        launch.putExtra(EXTRA_ROUTE, str(call, "route"));
        int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
        PendingIntent tap = PendingIntent.getActivity(context, id, launch, flags);

        Bundle extras = new Bundle();
        extras.putString(EXTRA_STAGE, str(call, "stage"));
        extras.putString(EXTRA_HASH, str(call, "hash"));

        NotificationCompat.Builder b = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(smallIcon())
                .setColor(color)
                .setContentTitle(title)
                .setContentText(subtitle)
                .setStyle(new NotificationCompat.DecoratedCustomViewStyle())
                .setCustomContentView(small)
                .setCustomBigContentView(big)
                .setOngoing(ongoing)
                .setAutoCancel(!ongoing)
                .setOnlyAlertOnce(!flag(call, "alert"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_STATUS)
                .setContentIntent(tap)
                .addExtras(extras);
        try {
            NotificationManagerCompat.from(context).notify(tag, id, b.build());
        } catch (SecurityException e) {
            // Notifications not allowed on this device: nothing to show.
        }
    }

    private Map<String, String> active(MethodCall call) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null;
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return null;
        Integer id = call.argument("id");
        String tag = call.argument("tag");
        for (StatusBarNotification n : nm.getActiveNotifications()) {
            if (id != null && n.getId() == id && tag != null && tag.equals(n.getTag())) {
                Map<String, String> out = new HashMap<>();
                out.put("stage", n.getNotification().extras.getString(EXTRA_STAGE));
                out.put("hash", n.getNotification().extras.getString(EXTRA_HASH));
                return out;
            }
        }
        return null;
    }

    private static String routeOf(Intent intent) {
        if (intent == null) return null;
        String route = intent.getStringExtra(EXTRA_ROUTE);
        if (route != null) intent.removeExtra(EXTRA_ROUTE);
        return route != null && route.startsWith("/") ? route : null;
    }

    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        String route = routeOf(intent);
        if (route == null) return false;
        channel.invokeMethod("tap", route);
        return true;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        binding.addOnNewIntentListener(this);
        String route = routeOf(binding.getActivity().getIntent());
        if (route != null) launchRoute = route;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activityBinding != null) activityBinding.removeOnNewIntentListener(this);
        activityBinding = null;
    }
}
