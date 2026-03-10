<?php
/**
 * Plugin Name: Telr Gateway API for Hiraaj Sahm
 * Description: REST API endpoints for Telr Mobile SDK integration.
 * Version: 2.0.0
 * Author: Hiraaj Sahm Dev
 */

if (!defined('ABSPATH')) exit;

/**
 * 1. NUCLEAR JWT BYPASS (FOR CUSTOM NON-REST ENDPOINT)
 * We handle the order check via a custom query parameter on the homepage.
 * This naturally bypasses the JWT plugin which usually only targets /wp-json/.
 */
add_action('init', function() {
    if (isset($_GET['telr_order_check'])) {
        hiraaj_telr_handle_custom_order_check();
    }
}, 1);

function hiraaj_telr_handle_custom_order_check() {
    $ck = $_GET['consumer_key'] ?? '';
    $cs = $_GET['consumer_secret'] ?? '';
    
    // Security Check
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
    
    // Extract Order Ref from Header (SDK Behavior)
    $auth_header = $_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '');
    if (!$auth_header && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $auth_header = $headers['Authorization'] ?? ($headers['authorization'] ?? '');
    }
    
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

function hiraaj_telr_perform_check($order_ref) {
    if (empty($order_ref)) {
        return new WP_Error('missing_ref', 'Order reference is empty');
    }

    $telr_data = [
        'method'  => 'check',
        'store'   => TELR_STORE_ID,
        'authkey' => TELR_AUTH_KEY,
        'order'   => ['ref' => $order_ref],
    ];

    $response = wp_remote_post(TELR_API_URL, [
        'headers' => ['Content-Type' => 'application/json'],
        'body'    => json_encode($telr_data),
        'timeout' => 30,
    ]);

    if (is_wp_error($response)) return $response;
    
    $body = json_decode(wp_remote_retrieve_body($response), true);
    
    if (empty($body) || isset($body['error'])) {
        return new WP_Error('telr_error', $body['error']['message'] ?? 'Unknown Telr error');
    }

    // Update WC order status if paid
    $status = $body['order']['status']['code'] ?? -1;
    if ($status == 3) {
        $cart_id = $body['order']['cartid'] ?? null;
        if ($cart_id && function_exists('wc_get_order')) {
            $wc_order = wc_get_order($cart_id);
            if ($wc_order && !$wc_order->is_paid()) {
                $wc_order->payment_complete($order_ref);
                $wc_order->add_order_note('Telr payment confirmed via SDK.');
            }
        }
    }

    // FIX 5.0: REFINED STRUCTURE FOR SDK VALIDATOR
    // UI parses the amount labels correctly, but the click validator needs the object.
    if (isset($body['order']['amount'])) {
        $raw_amount = $body['order']['amount'];
        $amount_double = (double)$raw_amount;
        $amount_string = number_format($amount_double, 2, '.', '');
        $currency = $body['order']['currency'] ?? 'SAR';
        
        // The SDK's Amount model likely expects "value" as a STRING.
        $amount_obj = [
            'value'    => $amount_string,
            'amount'   => $amount_string,
            'currency' => $currency
        ];
        
        // Root 'amount' must be the object to prevent NPE on getAmount().getValue()
        $body['order']['amount'] = $amount_obj;
        
        // Flat keys for UI display fallbacks
        $body['order']['amt']    = $amount_string;
        $body['order']['total']  = $amount_string;
        
        // Global fallbacks
        $body['amount'] = $amount_obj;
    }

    // Return the full body from Telr (SDK expects the 'order' key to be present)
    return $body;
}

// ============ TELR CONFIGURATION ============
define('TELR_STORE_ID', '34762');
define('TELR_AUTH_KEY', '5QFj~s5rDH#KpBnQ');
define('TELR_MOBILE_AUTH_KEY', 'K8nTm^WSVK@pQ.');
define('TELR_TEST_MODE', 1); // 1 = Test, 0 = Live
define('TELR_API_URL', 'https://secure.telr.com/gateway/order.json');

// ============ AUTH HELPER ============
function hiraaj_telr_verify_wc_keys(WP_REST_Request $request) {
    $ck = $request->get_param('consumer_key');
    $cs = $request->get_param('consumer_secret');

    if (empty($ck) || empty($cs)) return false;

    global $wpdb;
    $key = $wpdb->get_row(
        $wpdb->prepare(
            "SELECT consumer_secret FROM {$wpdb->prefix}woocommerce_api_keys WHERE consumer_key = %s",
            wc_api_hash($ck)
        )
    );

    if (!$key || !hash_equals($key->consumer_secret, $cs)) return false;
    return true;
}

// Whitelist Telr endpoints (second layer of protection)
add_filter('jwt_auth_whitelist', function ($endpoints) {
    if (!is_array($endpoints)) $endpoints = [];
    $endpoints[] = '/hiraajsahm/v1/telr/.*';
    return $endpoints;
});

// ============ REGISTER ROUTES ============
add_action('rest_api_init', function () {
    // Token endpoint — SDK calls this to create a payment session
    register_rest_route('hiraajsahm/v1', '/telr/token', [
        'methods'  => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_token',
        'permission_callback' => 'hiraaj_telr_verify_wc_keys',
    ]);

    // Order status endpoint — SDK calls this to check if payment completed
    register_rest_route('hiraajsahm/v1', '/telr/order', [
        'methods'  => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_order_check',
        'permission_callback' => 'hiraaj_telr_verify_wc_keys',
    ]);

    // Callback endpoint — Telr redirects here after payment
    register_rest_route('hiraajsahm/v1', '/telr/callback', [
        'methods'  => ['GET', 'POST'],
        'callback' => 'hiraaj_telr_callback',
        'permission_callback' => '__return_true',
    ]);

    // Keep legacy endpoint for backward compatibility
    register_rest_route('hiraajsahm/v1', '/telr/create-order', [
        'methods'  => 'POST',
        'callback' => 'hiraaj_telr_token',
        'permission_callback' => 'hiraaj_telr_verify_wc_keys',
    ]);
});

// ============ TOKEN ENDPOINT ============
/**
 * Creates a Telr payment order and returns JSON for the Mobile SDK.
 *
 * POST body: { order_id, amount, currency, description, customer_email, customer_name,
 *              billing_address, billing_city, billing_country, billing_phone }
 *
 * Returns JSON: { order: { ref, url }, ... }
 */
function hiraaj_telr_token(WP_REST_Request $request) {
    $order_id    = $request->get_param('order_id');
    $amount      = $request->get_param('amount');
    $currency    = $request->get_param('currency') ?: 'SAR';
    $description = $request->get_param('description') ?: "Order #{$order_id}";
    $email       = $request->get_param('customer_email') ?: '';
    $name        = $request->get_param('customer_name') ?: '';

    // Billing address fields (to pre-fill Telr form & skip address entry)
    $bill_addr   = $request->get_param('billing_address') ?: '';
    $bill_city   = $request->get_param('billing_city') ?: '';
    $bill_country = $request->get_param('billing_country') ?: 'SA';
    $bill_phone  = $request->get_param('billing_phone') ?: '';

    if (empty($order_id) || empty($amount)) {
        return new WP_Error('missing_params', 'order_id and amount are required', ['status' => 400]);
    }

    // Split name into first/last
    $name_parts = explode(' ', $name, 2);
    $first_name = $name_parts[0] ?? '';
    $last_name  = $name_parts[1] ?? '';

    // Build Telr API request
    $telr_data = [
        'method'  => 'create',
        'store'   => TELR_STORE_ID,
        'authkey' => TELR_AUTH_KEY,
        'framed'  => 2,
        'order'   => [
            'cartid'      => strval($order_id),
            'test'        => TELR_TEST_MODE,
            'amount'      => strval($amount),
            'currency'    => $currency,
            'description' => $description,
        ],
        'return'  => [
            'authorised' => home_url("/wp-json/hiraajsahm/v1/telr/callback?status=success&order_id={$order_id}"),
            'declined'   => home_url("/wp-json/hiraajsahm/v1/telr/callback?status=failed&order_id={$order_id}"),
            'cancelled'  => home_url("/wp-json/hiraajsahm/v1/telr/callback?status=cancelled&order_id={$order_id}"),
        ],
        'customer' => [
            'email' => $email,
            'name'  => [
                'forenames' => $first_name,
                'surname'   => $last_name,
            ],
            'address' => [
                'line1'   => $bill_addr ?: 'N/A',
                'city'    => $bill_city ?: 'N/A',
                'country' => $bill_country,
            ],
            'phone'   => $bill_phone,
        ],
    ];

    // Call Telr API
    $response = wp_remote_post(TELR_API_URL, [
        'headers' => ['Content-Type' => 'application/json'],
        'body'    => json_encode($telr_data),
        'timeout' => 30,
    ]);

    if (is_wp_error($response)) {
        return new WP_Error('telr_error', 'Failed to connect to Telr: ' . $response->get_error_message(), ['status' => 500]);
    }

    $body = json_decode(wp_remote_retrieve_body($response), true);

    if (empty($body) || isset($body['error'])) {
        $error_msg = $body['error']['message'] ?? 'Unknown Telr error';
        $error_note = $body['error']['note'] ?? '';
        return new WP_Error('telr_error', "Telr Error: {$error_msg}. {$error_note}", ['status' => 500]);
    }

    $order_ref = $body['order']['ref'] ?? null;
    $order_url = $body['order']['url'] ?? null;

    // Save Telr ref to WooCommerce order
    if (function_exists('wc_get_order') && $order_id) {
        $order = wc_get_order($order_id);
        if ($order) {
            $order->update_meta_data('_telr_order_ref', $order_ref);
            $order->add_order_note("Telr payment initiated. Ref: {$order_ref}");
            $order->save();
        }
    }

    // Return the Hosted Payment Page URL for the WebView
    return rest_ensure_response([
        'order_ref' => $order_ref,
        'order_url' => $order_url
    ]);
}

// ============ ORDER CHECK ENDPOINT ============
/**
 * Checks the status of a Telr order.
 * The Telr Mobile SDK calls this to verify if payment was completed.
 *
 * POST body: { order_ref }  (the Telr order reference)
 * Returns JSON: Telr order status response
 */
function hiraaj_telr_order_check(WP_REST_Request $request) {
    $order_ref = $request->get_param('order_ref');
    if (empty($order_ref)) {
        $auth_header = $request->get_header('authorization') ?: ($_SERVER['HTTP_AUTHORIZATION'] ?? ($_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? ''));
        if (preg_match('/Bearer\s+(.*)/i', $auth_header, $matches)) {
            $order_ref = trim($matches[1]);
        }
    }
    
    $result = hiraaj_telr_perform_check($order_ref);
    if (is_wp_error($result)) return $result;
    return rest_ensure_response($result);
}

// ============ CALLBACK ENDPOINT ============
function hiraaj_telr_callback(WP_REST_Request $request) {
    $status   = $request->get_param('status');
    $order_id = $request->get_param('order_id');

    if (!empty($order_id) && function_exists('wc_get_order')) {
        $order = wc_get_order($order_id);
        if ($order) {
            switch ($status) {
                case 'success':
                    $order->payment_complete();
                    $order->add_order_note('Telr payment completed successfully.');
                    break;
                case 'failed':
                    $order->update_status('failed', 'Telr payment declined.');
                    break;
                case 'cancelled':
                    $order->update_status('cancelled', 'Telr payment cancelled by customer.');
                    break;
            }
        }
    }

    $html = '<!DOCTYPE html><html><body>';
    $html .= '<h2>' . ($status === 'success' ? 'Payment Successful' : 'Payment ' . ucfirst($status)) . '</h2>';
    $html .= '<p>You can close this page.</p>';
    $html .= '</body></html>';

    header('Content-Type: text/html');
    echo $html;
    exit;
}



//AIzaSyDl5bO63kW9ukQkEEyqdg40oSFh1R8mOSM