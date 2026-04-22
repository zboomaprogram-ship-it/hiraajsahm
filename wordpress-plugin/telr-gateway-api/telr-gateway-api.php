<?php
/**
 * Plugin Name: Telr Gateway API for Hiraaj Sahm
 * Description: REST API endpoints for Telr Mobile SDK integration (V4.0.1 Compatible).
 * Version: 3.0.0
 * Author: Hiraaj Sahm Dev
 */

if (!defined('ABSPATH'))
    exit;

// ============ TELR CONFIGURATION ============
define('TELR_STORE_ID', get_option('telr_store_id', '34762'));
define('TELR_MOBILE_AUTH_KEY', get_option('telr_auth_key', 'mKnQf-HrCvD@StZK'));
define('TELR_TEST_MODE', (bool) get_option('telr_test_mode', false));
define('TELR_API_URL', 'https://secure.telr.com/api/v1/orders'); // ✔ OK: REST API URL

/**
 * 1. NUCLEAR JWT BYPASS (FOR CUSTOM NON-REST ENDPOINT)
 */
add_action('init', function () {
    if (isset($_GET['telr_order_check'])) {
        hiraaj_telr_handle_custom_order_check();
    }
}, 1);

function hiraaj_telr_handle_custom_order_check()
{
    $ck = $_GET['consumer_key'] ?? '';
    $cs = $_GET['consumer_secret'] ?? '';

    if (empty($ck) || empty($cs)) {
        wp_send_json_error(['message' => 'Missing security keys'], 401);
    }

    global $wpdb;
    $key = $wpdb->get_row($wpdb->prepare(
        "SELECT consumer_secret FROM {$wpdb->prefix}woocommerce_api_keys WHERE consumer_key = %s",
        wc_api_hash($ck)
    ));

    if (!$key || !hash_equals($key->consumer_secret, $cs)) {
        wp_send_json_error(['message' => 'Invalid security keys'], 401);
    }

    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    $order_ref = $_GET['order_ref'] ?? '';
    if (empty($order_ref) && preg_match('/Bearer\s+(.*)/i', $auth_header, $matches)) {
        $order_ref = trim($matches[1]);
    }

    if (empty($order_ref)) {
        wp_send_json_error(['message' => 'order_ref is required'], 400);
    }

    $result = hiraaj_telr_perform_check($order_ref);
    if (is_wp_error($result)) {
        wp_send_json_error(['message' => $result->get_error_message()], 500);
    }

    wp_send_json($result);
    exit;
}

/**
 * Perform Order Check via REST API v1
 */
function hiraaj_telr_perform_check($order_ref)
{
    if (empty($order_ref)) {
        return new WP_Error('missing_ref', 'Order reference is empty');
    }

    $auth_string = base64_encode(TELR_STORE_ID . ':' . TELR_MOBILE_AUTH_KEY);

    $response = wp_remote_get(TELR_API_URL . '/' . urlencode($order_ref), [
        'headers' => [
            'Authorization' => 'Basic ' . $auth_string,
            'Accept' => 'application/json',
        ],
        'timeout' => 30,
    ]); // ✅ FIXED: Removed sslverify: false (PHP-5)

    if (is_wp_error($response))
        return $response;

    $body = json_decode(wp_remote_retrieve_body($response), true);
    $status_string = strtoupper($body['status'] ?? ''); // ✅ FIXED: Status is a string (PHP-4)

    if ($status_string === 'PAID') { // ✅ FIXED: Check against 'PAID' (PHP-4)
        $cart_id = $body['cartId'] ?? null; // ✅ FIXED: camelCase (PHP-4)
        if ($cart_id && function_exists('wc_get_order')) {
            $wc_order = wc_get_order($cart_id);
            if ($wc_order && !$wc_order->is_paid()) {
                $wc_order->payment_complete($order_ref);
                $wc_order->add_order_note('Telr payment confirmed via REST API');
            }
        }
    }

    return [
        'ref' => $body['ref'] ?? $order_ref,
        'cartId' => $body['cartId'] ?? null,
        'status' => $status_string,
        'amount' => $body['amount'] ?? null,
    ];
}

// ============ AUTH HELPER ============
/**
 * 🔒 Validate WooCommerce API Keys
 */
function hiraaj_telr_verify_wc_keys(WP_REST_Request $request)
{
    // ✅ FIXED: Removed route-based bypass (PHP-3)
    $ck = $request->get_param('consumer_key');
    $cs = $request->get_param('consumer_secret');

    if (empty($ck) || empty($cs)) {
        return false;
    }

    global $wpdb;
    $key = $wpdb->get_row($wpdb->prepare(
        "SELECT consumer_secret FROM {$wpdb->prefix}woocommerce_api_keys WHERE consumer_key = %s",
        wc_api_hash($ck)
    ));

    return ($key && hash_equals($key->consumer_secret, $cs));
}

add_filter('jwt_auth_whitelist', function ($endpoints) {
    if (!is_array($endpoints))
        $endpoints = [];
    $endpoints[] = '/hiraajsahm/v1/telr/.*';
    return $endpoints;
});

// ============ REGISTER ROUTES ============
add_action('rest_api_init', function () {
    register_rest_route('hiraajsahm/v1', '/telr/token', [
        'methods' => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_token',
        'permission_callback' => 'hiraaj_telr_verify_wc_keys', // ✅ FIXED: Enforced (PHP-3)
    ]);
    register_rest_route('hiraajsahm/v1', '/telr/order', [
        'methods' => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_order_check',
        'permission_callback' => 'hiraaj_telr_verify_wc_keys', // ✅ FIXED: Enforced (PHP-3)
    ]);
    register_rest_route('hiraajsahm/v1', '/telr/callback', [
        'methods' => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_callback',
        'permission_callback' => '__return_true',
    ]);
});

/**
 * Token Generation Endpoint via REST API with Mobile SDK Support
 */
function hiraaj_telr_token(WP_REST_Request $request)
{
    $order_id = $request->get_param('order_id');
    $amount = $request->get_param('amount');
    $currency = $request->get_param('currency') ?: 'SAR';

    if (empty($order_id) || empty($amount))
        return new WP_Error('missing_params', 'order_id and amount are required', ['status' => 400]);

    $name_parts = explode(' ', $request->get_param('customer_name') ?: 'Guest User', 2);
    $fname = trim($name_parts[0] ?? 'Guest');
    $sname = trim($name_parts[1] ?? 'User');

    // ✅ FIXED: Clean payload as per Rahul's instructions (PHP-2, PHP-5)
    $telr_payload = [
        'cartId' => strval($order_id), // camelCase
        'test' => TELR_TEST_MODE,
        'transactionType' => 'SALE',
        'amount' => [
            'value' => number_format((double) $amount, 2, '.', ''),
            'currency' => $currency
        ],
        'description' => "Order {$order_id}",
        // 'mobile' => true, // ❌ REMOVED: (PHP-5)
        // 'sdk' => true,    // ❌ REMOVED: (PHP-5)
        'customer' => [
            'email' => $request->get_param('customer_email') ?: 'test@test.com',
            'name' => [
                'forenames' => $fname,
                'surname' => $sname
            ]
        ]
    ];

    $auth_string = base64_encode(TELR_STORE_ID . ':' . TELR_MOBILE_AUTH_KEY);

    $response = wp_remote_post(TELR_API_URL, [
        'headers' => [
            'Authorization' => 'Basic ' . $auth_string,
            'Content-Type' => 'application/json', // ✅ FIXED: application/json (PHP-2)
            'Accept' => 'application/json',       // ✅ FIXED: application/json (PHP-2)
        ],
        'body' => json_encode($telr_payload),
        'timeout' => 30,
        // 'sslverify' => false, // ❌ REMOVED: Security Risk (PHP-5)
    ]);

    $raw_body = wp_remote_retrieve_body($response);
    $body = json_decode($raw_body, true);

    $status_code = wp_remote_retrieve_response_code($response);
    $order_ref = $body['ref'] ?? null;

    if (is_wp_error($response))
        return new WP_Error('telr_error', 'Failed to connect to Telr API', ['status' => 500]);

    if ($status_code !== 201 || empty($order_ref)) {
        return new WP_Error(
            'telr_error',
            "Telr API Error ({$status_code}): " . ($body['message'] ?? 'Unknown Error'),
            ['status' => 500]
        );
    }

    if (function_exists('wc_get_order') && $order_id) {
        $order = wc_get_order($order_id);
        if ($order) {
            $order->update_meta_data('_telr_order_ref', $order_ref); // ✔ OK: Save ref (PHP-2)
            $order->save();
        }
    }

    // ✅ FIXED: Rahul's Exact Correct Response Pattern (PHP-2)
    wp_send_json([
        'tokenUrl' => $body['_links']['auth']['href'] ?? '', // auth URL
        'orderUrl' => $body['_links']['self']['href'] ?? '', // order URL
        'ref' => $order_ref
    ]);
    exit;
}

function hiraaj_telr_order_check(WP_REST_Request $request)
{
    $order_ref = '';
    $auth_header = $request->get_header('authorization');

    // ✅ FIXED: Priority to Bearer token, fallback to param
    if (preg_match('/Bearer\s+(.*)/i', $auth_header, $matches)) {
        $order_ref = trim($matches[1]);
    }

    if (empty($order_ref)) {
        $order_ref = $request->get_param('order_ref');
    }

    $result = hiraaj_telr_perform_check($order_ref);
    return is_wp_error($result) ? $result : rest_ensure_response($result);
}

function hiraaj_telr_callback(WP_REST_Request $request)
{
    $status = $request->get_param('status');
    $order_id = $request->get_param('order_id');
    if (!empty($order_id) && function_exists('wc_get_order')) {
        $order = wc_get_order($order_id);
        if ($order) {
            if ($status === 'success')
                $order->payment_complete();
            else
                $order->update_status('failed', 'Telr payment declined.');
        }
    }
    $safe_status = esc_html(sanitize_text_field($status));
    echo '<!DOCTYPE html><html><body><h2>Payment ' . ucfirst($safe_status) . '</h2><p>You can close this page.</p></body></html>';
    exit;
}

/**
 * 🚀 AUTO-UPGRADE: Process Subscription automatically on payment completion
 * This ensures users are upgraded even if they kill the app during the flow.
 */
add_action('woocommerce_payment_complete', 'hiraaj_telr_auto_upgrade_subscription', 20, 1);

function hiraaj_telr_auto_upgrade_subscription($order_id)
{
    if (!$order_id)
        return;

    $order = wc_get_order($order_id);
    if (!$order)
        return;

    $user_id = $order->get_user_id();
    if (!$user_id)
        return;

    $items = $order->get_items();
    $is_subscription = false;
    $target_pack_id = null;
    $is_al_zabayeh = false;

    foreach ($items as $item) {
        $product_id = $item->get_product_id();
        // 29026: Bronze, 29028: Silver, 29030: Gold, 29318: Al-Zabayeh
        if (in_array($product_id, [29026, 29028, 29030, 29318]) || has_term(122, 'product_cat', $product_id)) {
            $is_subscription = true;
            $target_pack_id = $product_id;
            if ($product_id == 29318) {
                $is_al_zabayeh = true;
            }
        }
    }

    if ($is_subscription) {
        // 1. Update User Meta for App Discovery
        update_user_meta($user_id, 'product_package_id', $target_pack_id);
        update_user_meta($user_id, 'product_pack_startdate', current_time('mysql'));
        update_user_meta($user_id, 'product_pack_enddate', 'unlimited');

        if ($is_al_zabayeh) {
            update_user_meta($user_id, 'sacrifices_verified', 'yes');
        }

        // 2. Set Role to Vendor (Seller)
        $user = new WP_User($user_id);
        if (in_array('customer', (array) $user->roles)) {
            $user->remove_role('customer');
        }
        if (!in_array('seller', (array) $user->roles) && !in_array('administrator', $user->roles)) {
            $user->add_role('seller');
        }

        // 3. Mark Order as Completed
        $order->update_status('completed', 'Auto-processed subscription upgrade.');
    }
}