<?php
/**
 * REFINED NOTIFICATION SYSTEM FOR HARRAJ SAHM
 * 
 * Instructions: Add this to your WordPress theme's functions.php file.
 * Ensure the OneSignal App ID and API Key are correct.
 */
/* ---------------------------------------------------------------------------
 * 1. REGISTER API ENDPOINTS
 * --------------------------------------------------------------------------- */
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/save-fcm-token', [
        'methods' => 'POST',
        'callback' => 'handle_save_fcm_token',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/notifications/inbox', [
        'methods' => 'GET',
        'callback' => 'hiraaj_get_notification_inbox',
        'permission_callback' => 'is_user_logged_in',
    ]);
    register_rest_route('custom/v1', '/notifications/read', [
        'methods' => 'POST',
        'callback' => 'hiraaj_mark_notification_inbox_read',
        'permission_callback' => 'is_user_logged_in',
    ]);
});
function handle_save_fcm_token($request)
{
    $user_id = get_current_user_id();
    $params = $request->get_json_params();

    // Support multiple key names for robustness (matches Flutter's NotificationService)
    $token = $params['token'] ?? $params['fcm_token'] ?? $params['onesignal_id'] ?? '';
    if (!empty($token)) {
        update_user_meta($user_id, 'onesignal_player_id', sanitize_text_field($token));
        return new WP_REST_Response(['success' => true, 'message' => 'Token saved'], 200);
    }
    return new WP_REST_Response(['success' => false, 'message' => 'No token provided'], 400);
}

function hiraaj_notification_inbox_key()
{
    return '_hiraaj_notification_inbox_v1';
}

function hiraaj_store_notification_for_user($user_id, $title, $body, $data = [], $image = '')
{
    $user_id = absint($user_id);
    if (!$user_id) {
        return;
    }
    $inbox = get_user_meta($user_id, hiraaj_notification_inbox_key(), true);
    $inbox = is_array($inbox) ? $inbox : [];
    $inbox[] = [
        'id' => wp_generate_uuid4(),
        'title' => sanitize_text_field($title),
        'body' => sanitize_textarea_field($body),
        'type' => sanitize_key($data['type'] ?? 'general'),
        'timestamp' => gmdate('c'),
        'is_read' => false,
        'data' => is_array($data) ? $data : [],
        'image' => esc_url_raw($image),
    ];
    if (count($inbox) > 100) {
        $inbox = array_slice($inbox, -100);
    }
    update_user_meta($user_id, hiraaj_notification_inbox_key(), $inbox);
}

function hiraaj_get_notification_inbox()
{
    $inbox = get_user_meta(
        get_current_user_id(),
        hiraaj_notification_inbox_key(),
        true
    );
    $inbox = is_array($inbox) ? array_reverse($inbox) : [];
    return new WP_REST_Response($inbox, 200);
}

function hiraaj_mark_notification_inbox_read(WP_REST_Request $request)
{
    $user_id = get_current_user_id();
    $params = $request->get_json_params();
    $notification_id = sanitize_text_field($params['id'] ?? '');
    $mark_all = rest_sanitize_boolean($params['all'] ?? false);
    if (rest_sanitize_boolean($params['clear'] ?? false)) {
        delete_user_meta($user_id, hiraaj_notification_inbox_key());
        return new WP_REST_Response(['success' => true], 200);
    }
    $inbox = get_user_meta($user_id, hiraaj_notification_inbox_key(), true);
    $inbox = is_array($inbox) ? $inbox : [];
    foreach ($inbox as &$notification) {
        if ($mark_all || ($notification_id !== '' && ($notification['id'] ?? '') === $notification_id)) {
            $notification['is_read'] = true;
        }
    }
    unset($notification);
    update_user_meta($user_id, hiraaj_notification_inbox_key(), $inbox);
    return new WP_REST_Response(['success' => true], 200);
}
/* ---------------------------------------------------------------------------
 * 2. ONESIGNAL CONFIGURATION
 * --------------------------------------------------------------------------- */
$hiraaj_onesignal_settings = get_option('OneSignalWPSetting', []);
$hiraaj_onesignal_settings = is_array($hiraaj_onesignal_settings)
    ? $hiraaj_onesignal_settings
    : [];
if (!defined('ONESIGNAL_APP_ID')) {
    define(
        'ONESIGNAL_APP_ID',
        get_option(
            'onesignal_app_id',
            $hiraaj_onesignal_settings['app_id'] ?? '9f9ed559-2c77-43e5-9c47-473043f2e6d4'
        )
    );
}
if (!defined('ONESIGNAL_API_KEY')) {
    define(
        'ONESIGNAL_API_KEY',
        defined('ONESIGNAL_REST_API_KEY')
            ? ONESIGNAL_REST_API_KEY
            : get_option(
                'onesignal_api_key',
                get_option(
                    'onesignal_rest_api_key',
                    $hiraaj_onesignal_settings['rest_api_key'] ?? ''
                )
            )
    );
}
/* ---------------------------------------------------------------------------
 * 3. HELPER FUNCTION (Optimized for deep linking)
 * --------------------------------------------------------------------------- */
function send_onesignal_notification($headings, $contents, $filters = [], $data = [], $image = '')
{
    if (empty(ONESIGNAL_API_KEY)) {
        error_log('Hiraaj OneSignal API key is not configured.');
        return false;
    }
    $fields = [
        'app_id' => ONESIGNAL_APP_ID,
        'headings' => ['en' => $headings, 'ar' => $headings],
        'contents' => ['en' => $contents, 'ar' => $contents],
        'filters' => $filters,
        'target_channel' => 'push',
        'data' => $data,
    ];
    if (!empty($image)) {
        $fields['big_picture'] = $image;
        $fields['ios_attachments'] = ['id1' => $image];
    }
    $response = wp_remote_post("https://api.onesignal.com/notifications?c=push", [
        'headers' => [
            'Content-Type' => 'application/json; charset=utf-8',
            'Authorization' => 'Key ' . ONESIGNAL_API_KEY
        ],
        'body' => json_encode($fields),
        'timeout' => 30,
        'sslverify' => true,
    ]);

    if (is_wp_error($response)) {
        return $response->get_error_message();
    }

    $status = wp_remote_retrieve_response_code($response);
    $body = wp_remote_retrieve_body($response);
    if ($status < 200 || $status >= 300) {
        error_log('Hiraaj OneSignal error (' . $status . '): ' . $body);
    }
    return $body;
}

function hiraaj_send_notification_to_users($user_ids, $headings, $contents, $data = [], $image = '')
{
    $user_ids = array_values(array_unique(array_filter(array_map('strval', (array) $user_ids))));
    if (empty($user_ids)) {
        return false;
    }
    foreach ($user_ids as $user_id) {
        hiraaj_store_notification_for_user(
            (int) $user_id,
            $headings,
            $contents,
            $data,
            $image
        );
    }
    if (empty(ONESIGNAL_API_KEY)) {
        error_log('Hiraaj OneSignal API key is not configured; notification stored in inbox only.');
        return false;
    }

    $fields = [
        'app_id' => ONESIGNAL_APP_ID,
        'headings' => ['en' => $headings, 'ar' => $headings],
        'contents' => ['en' => $contents, 'ar' => $contents],
        'include_aliases' => ['external_id' => $user_ids],
        'target_channel' => 'push',
        'data' => $data,
    ];
    if (!empty($image)) {
        $fields['big_picture'] = $image;
        $fields['ios_attachments'] = ['image' => $image];
    }

    $response = wp_remote_post('https://api.onesignal.com/notifications?c=push', [
        'headers' => [
            'Content-Type' => 'application/json; charset=utf-8',
            'Authorization' => 'Key ' . ONESIGNAL_API_KEY,
        ],
        'body' => wp_json_encode($fields),
        'timeout' => 30,
        'sslverify' => true,
    ]);

    if (is_wp_error($response)) {
        error_log('Hiraaj OneSignal connection error: ' . $response->get_error_message());
        return false;
    }
    $status = wp_remote_retrieve_response_code($response);
    $body = wp_remote_retrieve_body($response);
    if ($status < 200 || $status >= 300) {
        error_log('Hiraaj OneSignal user notification error (' . $status . '): ' . $body);
        return false;
    }

    // OneSignal can return HTTP 200 without a message id when none of the
    // external aliases has a push subscription. Retry with the device
    // subscription IDs saved by the Flutter app for legacy/race conditions.
    $decoded = json_decode($body, true);
    if (empty($decoded['id'])) {
        $subscription_ids = [];
        foreach ($user_ids as $user_id) {
            $subscription_id = sanitize_text_field(
                get_user_meta((int) $user_id, 'onesignal_player_id', true)
            );
            if ($subscription_id !== '') {
                $subscription_ids[] = $subscription_id;
            }
        }
        $subscription_ids = array_values(array_unique($subscription_ids));
        if (!empty($subscription_ids)) {
            unset($fields['include_aliases'], $fields['target_channel']);
            $fields['include_subscription_ids'] = $subscription_ids;
            $fallback = wp_remote_post('https://api.onesignal.com/notifications?c=push', [
                'headers' => [
                    'Content-Type' => 'application/json; charset=utf-8',
                    'Authorization' => 'Key ' . ONESIGNAL_API_KEY,
                ],
                'body' => wp_json_encode($fields),
                'timeout' => 30,
                'sslverify' => true,
            ]);
            if (is_wp_error($fallback)) {
                error_log('Hiraaj OneSignal subscription fallback error: ' . $fallback->get_error_message());
                return false;
            }
            $fallback_status = wp_remote_retrieve_response_code($fallback);
            $fallback_body = wp_remote_retrieve_body($fallback);
            if ($fallback_status < 200 || $fallback_status >= 300) {
                error_log('Hiraaj OneSignal subscription fallback failed (' . $fallback_status . '): ' . $fallback_body);
                return false;
            }
            return $fallback_body;
        }
        error_log('Hiraaj OneSignal accepted the request but found no subscribed recipient for users: ' . implode(',', $user_ids));
        return false;
    }
    return $body;
}
/* ---------------------------------------------------------------------------
 * 4. NOTIFICATION TRIGGERS
 * --------------------------------------------------------------------------- */
// A. New Order -> Vendor (Targeted by user_id tag)
add_action('woocommerce_checkout_order_created', 'notify_vendor_new_order', 20, 1);
add_action('woocommerce_payment_complete', 'notify_vendor_new_order', 20, 1);
function notify_vendor_new_order($order_or_id)
{
    $order = is_a($order_or_id, 'WC_Order') ? $order_or_id : wc_get_order($order_or_id);
    if (!$order || $order->get_meta('_hiraaj_new_order_notifications_sent') === 'yes') {
        return;
    }
    $order_id = $order->get_id();
    $notified_vendors = [];
    foreach ($order->get_items() as $item) {
        $product = $item->get_product();
        if (!$product)
            continue;

        $vendor_id = get_post_field('post_author', $product->get_id());

        // Avoid duplicate notifications if order has multiple products from same vendor
        if (in_array($vendor_id, $notified_vendors))
            continue;
        hiraaj_send_notification_to_users(
            [$vendor_id],
            '🛒 طلب جديد!',
            $order->get_total() > 0
                ? 'لديك طلب جديد للمنتج "' . $product->get_name() . '"'
                : 'لديك طلب جديد بدون سعر محدد. تواصل مع المشتري لتحديد السعر.',
            ['type' => 'order_vendor', 'id' => (string) $order_id],
            get_the_post_thumbnail_url($product->get_id(), 'full')
        );
        $notified_vendors[] = $vendor_id;
    }

    $buyer_id = $order->get_user_id();
    if ($buyer_id) {
        hiraaj_send_notification_to_users(
            [$buyer_id],
            '✅ تم استلام طلبك',
            'تم إرسال طلبك رقم #' . $order_id . ' إلى البائع.',
            ['type' => 'order_client', 'id' => (string) $order_id]
        );
    }
    $order->update_meta_data('_hiraaj_new_order_notifications_sent', 'yes');
    $order->save();
}
// B. Order Status -> Client
add_action('woocommerce_order_status_changed', 'notify_client_order_status', 10, 4);
function notify_client_order_status($order_id, $from, $to, $order)
{
    $user_id = $order->get_user_id();
    if (!$user_id)
        return;
    $titles = [
        'completed' => '📦 تم التسليم',
        'processing' => '✅ تم تأكيد الطلب',
        'cancelled' => '❌ تم الإلغاء',
        'shipped' => '🚚 تم الشحن'
    ];

    $bodies = [
        'completed' => 'تم توصيل طلبك رقم #' . $order_id . ' بنجاح.',
        'processing' => 'جاري تجهيز طلبك رقم #' . $order_id,
        'cancelled' => 'تم إلغاء طلبك رقم #' . $order_id,
        'shipped' => 'طلبك رقم #' . $order_id . ' في الطريق إليك!'
    ];
    if (isset($titles[$to])) {
        hiraaj_send_notification_to_users(
            [$user_id],
            $titles[$to],
            $bodies[$to],
            ['type' => 'order_client', 'id' => (string) $order_id]
        );
    }
}
// C. Product Status -> Vendor
add_action('transition_post_status', 'notify_vendor_product_status', 10, 3);
function notify_vendor_product_status($new_status, $old_status, $post)
{
    if ($post->post_type !== 'product' || $new_status === $old_status)
        return;

    $vendor_id = $post->post_author;
    $title = '';
    $body = '';
    if ($new_status == 'publish') {
        $title = '✅ تمت الموافقة';
        $body = 'تم اعتماد اعلانك "' . $post->post_title . '" بنجاح';
    } elseif ($new_status == 'draft' && $old_status == 'pending') {
        $title = '🚫 تعذر الاعتماد';
        $body = 'تم رفض اعلانك "' . $post->post_title . '". يرجى مراجعة البيانات.';
    }
    if ($title) {
        hiraaj_send_notification_to_users(
            [$vendor_id],
            $title,
            $body,
            ['type' => 'product', 'id' => (string) $post->ID],
            get_the_post_thumbnail_url($post->ID, 'full')
        );
    }
}
// D. Q&A Notifications (Vendor & Client)
add_action('comment_post', 'notify_qa_updates', 10, 3);
function notify_qa_updates($comment_id, $comment_approved, $commentdata)
{
    if (!empty($GLOBALS['hiraaj_inserting_public_bid'])) {
        return;
    }
    $comment = get_comment($comment_id);
    if (!$comment || $comment->comment_type !== 'product_question')
        return;

    $product_id = (int) $comment->comment_post_ID;
    $product = get_post($product_id);
    if (!$product)
        return;

    if ((int) $comment->comment_parent === 0) {
        // New Question -> Notify Vendor
        hiraaj_send_notification_to_users(
            [$product->post_author],
            '💬 تعليق جديد',
            'لديك تعليق جديد على إعلان "' . $product->post_title . '"',
            ['type' => 'qa_vendor', 'id' => (string) $product_id],
            get_the_post_thumbnail_url($product_id, 'full')
        );
    } else {
        // Answer -> Notify Client
        $parent_comment = get_comment($comment->comment_parent);
        if ($parent_comment && $parent_comment->user_id) {
            hiraaj_send_notification_to_users(
                [$parent_comment->user_id],
                '💬 تم الرد',
                'قام البائع بالرد على تعليقك حول "' . $product->post_title . '"',
                ['type' => 'qa_client', 'id' => (string) $product_id],
                get_the_post_thumbnail_url($product_id, 'full')
            );
        }
    }
}
// E. Followers -> Notify when vendor adds product
add_action('transition_post_status', 'notify_followers_new_product', 20, 3);
function notify_followers_new_product($new_status, $old_status, $post)
{
    if ($post->post_type !== 'product' || $new_status !== 'publish' || $old_status === 'publish')
        return;

    $vendor_id = $post->post_author;
    $vendor_name = get_the_author_meta('display_name', $vendor_id);
    $follower_ids = [];
    foreach (get_users(['fields' => 'ID']) as $user_id) {
        $followed = array_map(
            'intval',
            (array) get_user_meta($user_id, '_hiraaj_followed_vendors', true)
        );
        if (in_array((int) $vendor_id, $followed, true)) {
            $follower_ids[] = (int) $user_id;
        }
    }
    if (!empty($follower_ids)) {
        hiraaj_send_notification_to_users(
            $follower_ids,
            '🔔 إضافة جديدة من ' . $vendor_name,
            'قام ' . $vendor_name . ' بإضافة إعلان جديد: ' . $post->post_title,
            ['type' => 'followed_product', 'id' => (string) $post->ID],
            get_the_post_thumbnail_url($post->ID, 'full')
        );
    }
}

// G. Product/store rating -> Vendor
add_action('comment_post', 'hiraaj_notify_vendor_new_rating', 20, 3);
function hiraaj_notify_vendor_new_rating($comment_id, $comment_approved, $commentdata)
{
    $comment = get_comment($comment_id);
    if (!$comment || !in_array($comment->comment_type, ['review', 'dokan_store_review'], true)) {
        return;
    }

    $post = get_post($comment->comment_post_ID);
    $vendor_id = 0;
    $product_id = 0;
    if ($post && $post->post_type === 'product') {
        $vendor_id = (int) $post->post_author;
        $product_id = (int) $post->ID;
    } else {
        $vendor_id = (int) (
            get_comment_meta($comment_id, 'vendor_id', true)
            ?: get_comment_meta($comment_id, 'store_id', true)
        );
    }
    if (!$vendor_id || $vendor_id === (int) $comment->user_id) {
        return;
    }
    $rating = (int) get_comment_meta($comment_id, 'rating', true);
    hiraaj_send_notification_to_users(
        [$vendor_id],
        '⭐ تقييم جديد',
        $rating > 0 ? 'حصلت على تقييم جديد: ' . $rating . ' من 5' : 'لديك تقييم جديد',
        ['type' => 'review_vendor', 'id' => (string) $product_id]
    );
}
// F. NEW REQUEST -> Notify Service Providers in the same city
// Integration for Fluent Forms or custom request handlers
add_action('fluentform/submission_inserted', 'notify_providers_on_fluent_form', 10, 3);
function notify_providers_on_fluent_form($submissionId, $formData, $form)
{
    // You can filter by form ID if needed
    // $form_id = $form->id;

    $city = $formData['input_text_1'] ?? $formData['city'] ?? ''; // Adjust based on your form fields

    if (!empty($city)) {
        send_onesignal_notification(
            '🛠️ طلب خدمة جديد في مدينتك',
            'هناك طلب خدمة جديد متوفر الآن في ' . $city,
            [
                ['field' => 'tag', 'key' => 'role', 'relation' => '=', 'value' => 'seller'],
                ['field' => 'tag', 'key' => 'city', 'relation' => '=', 'value' => $city]
            ],
            ['type' => 'requests', 'id' => (string) $submissionId]
        );
    }
}
