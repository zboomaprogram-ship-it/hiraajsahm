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
/* ---------------------------------------------------------------------------
 * 2. ONESIGNAL CONFIGURATION
 * --------------------------------------------------------------------------- */
if (!defined('ONESIGNAL_APP_ID')) {
    define('ONESIGNAL_APP_ID', get_option('onesignal_app_id', '9f9ed559-2c77-43e5-9c47-473043f2e6d4'));
}
if (!defined('ONESIGNAL_API_KEY')) {
    define('ONESIGNAL_API_KEY', get_option('onesignal_api_key', 'os_v2_app_t6pnkwjmo5b6lhchi4yeh4xg2ssu6244cxtustmk6cejgwg65kqv3y433om47zx3wljkb54lqexmptcciinbzv7ig7kxcpattlgag3a'));
}
/* ---------------------------------------------------------------------------
 * 3. HELPER FUNCTION (Optimized for deep linking)
 * --------------------------------------------------------------------------- */
function send_onesignal_notification($headings, $contents, $filters = [], $data = [], $image = '')
{
    $fields = [
        'app_id' => ONESIGNAL_APP_ID,
        'headings' => ['en' => $headings, 'ar' => $headings],
        'contents' => ['en' => $contents, 'ar' => $contents],
        'filters' => $filters,
        'data' => $data,
    ];
    if (!empty($image)) {
        $fields['big_picture'] = $image;
        $fields['ios_attachments'] = ['id1' => $image];
    }
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://onesignal.com/api/v1/notifications");
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json; charset=utf-8',
        'Authorization: Basic ' . ONESIGNAL_API_KEY
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($ch, CURLOPT_HEADER, FALSE);
    curl_setopt($ch, CURLOPT_POST, TRUE);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fields));
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, TRUE);
    $response = curl_exec($ch);
    curl_close($ch);
    return $response;
}
/* ---------------------------------------------------------------------------
 * 4. NOTIFICATION TRIGGERS
 * --------------------------------------------------------------------------- */
// A. New Order -> Vendor (Targeted by user_id tag)
add_action('woocommerce_payment_complete', 'notify_vendor_new_order');
function notify_vendor_new_order($order_id)
{
    $order = wc_get_order($order_id);
    $notified_vendors = [];
    foreach ($order->get_items() as $item) {
        $product = $item->get_product();
        if (!$product)
            continue;

        $vendor_id = get_post_field('post_author', $product->get_id());

        // Avoid duplicate notifications if order has multiple products from same vendor
        if (in_array($vendor_id, $notified_vendors))
            continue;
        send_onesignal_notification(
            '🛒 طلب جديد!',
            'لديك طلب جديد للمنتج "' . $product->get_name() . '"',
            [['field' => 'tag', 'key' => 'user_id', 'relation' => '=', 'value' => (string) $vendor_id]],
            ['type' => 'order_vendor', 'id' => (string) $order_id],
            get_the_post_thumbnail_url($product->get_id(), 'full')
        );
        $notified_vendors[] = $vendor_id;
    }
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
        send_onesignal_notification(
            $titles[$to],
            $bodies[$to],
            [['field' => 'tag', 'key' => 'user_id', 'relation' => '=', 'value' => (string) $user_id]],
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
        send_onesignal_notification(
            $title,
            $body,
            [['field' => 'tag', 'key' => 'user_id', 'relation' => '=', 'value' => (string) $vendor_id]],
            ['type' => 'product', 'id' => (string) $post->ID],
            get_the_post_thumbnail_url($post->ID, 'full')
        );
    }
}
// D. Q&A Notifications (Vendor & Client)
add_action('comment_post', 'notify_qa_updates', 10, 3);
function notify_qa_updates($comment_id, $comment_approved, $commentdata)
{
    if (isset($commentdata['comment_type']) && $commentdata['comment_type'] !== 'product_question')
        return;

    $product_id = $commentdata['comment_post_ID'];
    $product = get_post($product_id);
    if (!$product)
        return;

    if ($commentdata['comment_parent'] == 0) {
        // New Question -> Notify Vendor
        send_onesignal_notification(
            '❓ سؤال جديد',
            'لديك استفسار جديد حول اعلان "' . $product->post_title . '"',
            [['field' => 'tag', 'key' => 'user_id', 'relation' => '=', 'value' => (string) $product->post_author]],
            ['type' => 'qa_vendor', 'id' => (string) $product_id],
            get_the_post_thumbnail_url($product_id, 'full')
        );
    } else {
        // Answer -> Notify Client
        $parent_comment = get_comment($commentdata['comment_parent']);
        if ($parent_comment && $parent_comment->user_id) {
            send_onesignal_notification(
                '💬 تم الرد',
                'قام التاجر بالرد على سؤالك حول "' . $product->post_title . '"',
                [['field' => 'tag', 'key' => 'user_id', 'relation' => '=', 'value' => (string) $parent_comment->user_id]],
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
    send_onesignal_notification(
        '🔔 إضافة جديدة من ' . $vendor_name,
        'قام ' . $vendor_name . ' بإضافة اعلان جديد: ' . $post->post_title,
        [['field' => 'tag', 'key' => 'vendor_' . $vendor_id, 'relation' => '=', 'value' => '1']],
        ['type' => 'product', 'id' => (string) $post->ID],
        get_the_post_thumbnail_url($post->ID, 'full')
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