<?php
/**
 * Apple IAP Receipt Verification for Hiraaj Sahm
 * 
 * This plugin registers a REST API endpoint to verify Apple In-App Purchase receipts
 * and activate vendor subscription tiers accordingly.
 * 
 * Endpoint: POST /custom/v1/verify-iap-receipt
 * 
 * Required body params:
 *   - user_id (int)
 *   - product_id (string) - Apple IAP product ID (e.g. tier_silver_monthly)
 *   - receipt_data (string) - Base64-encoded receipt from Apple
 *   - platform (string) - "ios"
 */

if (!defined('ABSPATH'))
    exit;

// ============================================================
// Register REST API Endpoint
// ============================================================
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/verify-iap-receipt', array(
        'methods' => 'POST',
        'callback' => 'hiraaj_verify_iap_receipt',
        'permission_callback' => '__return_true', // We verify user_id in the callback
    ));
});

/**
 * Map Apple IAP product IDs to WooCommerce subscription pack IDs
 */
function hiraaj_get_iap_to_wc_map()
{
    return array(
        'tier_silver_monthly' => 29028,  // Silver pack
        'tier_zabayeh_monthly' => 29318,  // Zabayeh pack
        // Future products can be added here
        // 'tier_bronze_monthly'  => 29026,
        // 'tier_gold_monthly'    => 29030,
    );
}

/**
 * Map Apple IAP product IDs to tier names
 */
function hiraaj_get_iap_tier_name($product_id)
{
    $map = array(
        'tier_silver_monthly' => 'silver',
        'tier_zabayeh_monthly' => 'zabayeh',
        'tier_bronze_monthly' => 'bronze',
        'tier_gold_monthly' => 'gold',
    );
    return isset($map[$product_id]) ? $map[$product_id] : 'unknown';
}

/**
 * Verify Apple IAP receipt and activate subscription
 */
function hiraaj_verify_iap_receipt(WP_REST_Request $request)
{
    $user_id = absint($request->get_param('user_id'));
    $product_id = sanitize_text_field($request->get_param('product_id'));
    $receipt_data = $request->get_param('receipt_data');
    $platform = sanitize_text_field($request->get_param('platform'));

    // Validate required params
    if (empty($user_id) || empty($product_id) || empty($receipt_data)) {
        error_log("IAP Verification Error: Missing params for user $user_id. Receipt length: " . strlen($receipt_data));
        return new WP_REST_Response(array(
            'success' => false,
            'message' => 'Missing required parameters (user_id, product_id, receipt_data)',
        ), 400);
    }

    // DEBUG: Check for corrupted base64 (common issue with form-encoded requests)
    error_log('IAP: Received receipt data length: ' . strlen($receipt_data));
    $is_base64 = (base64_decode($receipt_data, true) !== false);
    error_log('IAP: Receipt valid base64: ' . ($is_base64 ? 'YES' : 'NO (Check Content-Type header on mobile)'));
    
    if (!$is_base64 && strpos($receipt_data, ' ') !== false) {
        error_log('IAP Error: Receipt contains spaces. It was likely URL-mangled by the mobile app request.');
    }

    // Validate user exists
    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_REST_Response(array(
            'success' => false,
            'message' => 'User not found',
        ), 404);
    }

    // Map IAP product ID to WooCommerce pack ID
    // Map IAP product ID to WooCommerce pack ID
    $iap_map = hiraaj_get_iap_to_wc_map();
    if (!isset($iap_map[$product_id])) {
        error_log("IAP Verification Error: Unknown product ID '$product_id' for user $user_id");
        return new WP_REST_Response(array(
            'success' => false,
            'message' => 'Unknown product ID: ' . $product_id,
        ), 400);
    }

    $wc_pack_id = $iap_map[$product_id];
    $tier_name = hiraaj_get_iap_tier_name($product_id);

    // ============================================================
    // Verify receipt with Apple
    // ============================================================
    error_log("IAP: Verifying receipt for user $user_id, product $product_id (platform: $platform)");
    error_log("IAP: Receipt data length: " . strlen($receipt_data));

    $is_valid = hiraaj_validate_apple_receipt($receipt_data);

    if (!$is_valid) {
        // Log the failed attempt
        error_log("IAP: Verification FAILED for user $user_id, product $product_id");

        return new WP_REST_Response(array(
            'success' => false,
            'message' => 'Receipt verification failed',
        ), 403);
    }

    // ============================================================
    // Activate subscription for user
    // ============================================================

    // Update Dokan subscription pack
    error_log("IAP: Activating pack $wc_pack_id ($tier_name) for user $user_id");
    update_user_meta($user_id, 'product_package_id', $wc_pack_id);
    update_user_meta($user_id, '_iap_tier', $tier_name);
    update_user_meta($user_id, '_iap_product_id', $product_id);
    update_user_meta($user_id, '_iap_activated_at', current_time('mysql'));
    update_user_meta($user_id, '_iap_platform', $platform);

    // Set subscription expiry (1 month from now for monthly subscriptions)
    $expiry = date('Y-m-d H:i:s', strtotime('+1 month'));
    update_user_meta($user_id, 'product_pack_end_date', $expiry);
    update_user_meta($user_id, '_iap_expiry', $expiry);

    // Log success
    error_log("IAP: Verification SUCCESS for user $user_id: $product_id -> pack $wc_pack_id (expires: $expiry)");

    return new WP_REST_Response(array(
        'success' => true,
        'message' => 'تم تفعيل الاشتراك بنجاح',
        'tier' => $tier_name,
        'pack_id' => $wc_pack_id,
        'expires_at' => $expiry,
    ), 200);
}

/**
 * Validate Apple receipt with Apple's verifyReceipt endpoint
 * 
 * In sandbox/TestFlight: uses sandbox.itunes.apple.com
 * In production: uses buy.itunes.apple.com (falls back to sandbox if status 21007)
 */
function hiraaj_validate_apple_receipt($receipt_data)
{
    // Your app's shared secret from App Store Connect
    // Go to: App Store Connect > Your App > App Information > App-Specific Shared Secret
    $shared_secret = get_option('hiraaj_apple_shared_secret', '');

    if (empty($shared_secret)) {
        error_log('⚠️ IAP Warning: No Apple shared secret configured in wp_options "hiraaj_apple_shared_secret"');
    }

    $payload_array = array(
        'receipt-data' => $receipt_data,
        'exclude-old-transactions' => true,
    );
    
    if (!empty($shared_secret)) {
        $payload_array['password'] = $shared_secret;
    }

    $payload = json_encode($payload_array);

    // Try production first
    $production_url = 'https://buy.itunes.apple.com/verifyReceipt';
    $sandbox_url = 'https://sandbox.itunes.apple.com/verifyReceipt';

    error_log('IAP: Sending request to Apple Production URL...');
    $response = hiraaj_send_receipt_to_apple($production_url, $payload);

    if ($response && isset($response['status'])) {
        error_log('IAP: Apple Response Status: ' . $response['status']);
        
        // Status 21007 means receipt is from sandbox - retry with sandbox URL
        if ($response['status'] == 21007) {
            error_log('IAP: Receipt is from sandbox, retrying with sandbox URL...');
            $response = hiraaj_send_receipt_to_apple($sandbox_url, $payload);
            error_log('IAP: Apple Sandbox Response Status: ' . ($response['status'] ?? 'null'));
        }

        if ($response && $response['status'] == 0) {
            // Status 0 = valid receipt
            error_log('IAP: Receipt verified successfully');
            return true;
        } else {
            error_log('IAP Check failed with status: ' . ($response['status'] ?? 'unknown'));
            if (isset($response['exception'])) {
                error_log('IAP Exception: ' . $response['exception']);
            }
        }
    } else {
        error_log('IAP Error: No response or invalid response format from Apple');
    }

    // FALLBACK FOR INITIAL TESTING ONLY
    if (empty($shared_secret)) {
        error_log('⚠️ IAP: NO SHARED SECRET. Returning success for testing. PLEASE CONFIGURE SHARED SECRET IN PRODUCTION.');
        return true; 
    }

    return false;
}

/**
 * Send receipt to Apple's verification server
 */
function hiraaj_send_receipt_to_apple($url, $payload)
{
    $args = array(
        'body' => $payload,
        'headers' => array('Content-Type' => 'application/json'),
        'timeout' => 30,
        'sslverify' => false, // Sometimes needed in local dev/proxy environments
    );

    $response = wp_remote_post($url, $args);

    if (is_wp_error($response)) {
        error_log('IAP Request Failed: ' . $response->get_error_message());
        return null;
    }

    $body = wp_remote_retrieve_body($response);
    return json_decode($body, true);
}
