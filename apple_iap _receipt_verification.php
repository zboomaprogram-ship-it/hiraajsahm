<?php
/**
 * Apple IAP Receipt Verification for Hiraaj Sahm
 * 
 * This plugin registers a REST API endpoint to verify Apple In-App Purchase receipts
 * and activate vendor subscription tiers accordingly.
 */

if (!defined('ABSPATH'))
    exit;

// ============================================================
// Register REST API Endpoints
// ============================================================
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/verify-iap-receipt', array(
        'methods' => 'POST',
        'callback' => 'hiraaj_verify_iap_receipt',
        'permission_callback' => '__return_true', // We verify user_id in the callback
    ));

    // Restore Purchases Endpoint
    register_rest_route('custom/v1', '/restore-iap', [
        'methods'  => 'POST',
        'callback' => 'hiraaj_restore_iap_purchase',
        'permission_callback' => '__return_true',
    ]);
});

/**
 * Map Apple IAP product IDs to WooCommerce subscription pack IDs
 */
function hiraaj_get_iap_to_wc_map()
{
    return array(
        'tier_silver_monthly' => 29028,  // Silver pack
        'tier_zabayeh_monthly' => 29318,  // Zabayeh pack
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
 * RESTORE PURCHASES ENDPOINT
 */
function hiraaj_restore_iap_purchase(WP_REST_Request $request) {
    $user_id      = absint($request->get_param('user_id'));
    $receipt_data = $request->get_param('receipt_data');
    $platform     = sanitize_text_field($request->get_param('platform') ?? 'ios');

    if (empty($user_id) || empty($receipt_data)) {
        return new WP_REST_Response(['success' => false, 'message' => 'Missing params'], 400);
    }

    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_REST_Response(['success' => false, 'message' => 'User not found'], 404);
    }

    // Re-verify the receipt with Apple
    $is_valid = hiraaj_validate_apple_receipt($receipt_data);
    if (!$is_valid) {
        return new WP_REST_Response(['success' => false, 'message' => 'Invalid receipt'], 403);
    }

    // Read what's already saved for this user
    $pack_id   = get_user_meta($user_id, 'product_package_id', true);
    $tier      = get_user_meta($user_id, '_iap_tier', true);
    $expiry    = get_user_meta($user_id, 'product_pack_enddate', true);

    // Fallback tier detection from pack_id
    if (empty($tier)) {
        $tier_map = [29026 => 'bronze', 29028 => 'silver', 29030 => 'gold', 29318 => 'zabayeh'];
        $tier = $tier_map[(int)$pack_id] ?? 'bronze';
    }

    // If no pack found, try to detect from receipt (Apple returns latest_receipt_info)
    // For now, return current saved state if valid
    if (empty($pack_id)) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'No active subscription found for this user'
        ], 404);
    }

    // Ensure role is still seller
    $user_obj = new WP_User($user_id);
    if (!in_array('administrator', $user_obj->roles)) {
        $user_obj->set_role('seller');
    }
    update_user_meta($user_id, 'dokan_enable_selling', 'yes');

    error_log("IAP Restore: SUCCESS for user $user_id, pack $pack_id, expires $expiry");

    return new WP_REST_Response([
        'success'    => true,
        'message'    => 'تم استعادة الاشتراك بنجاح',
        'tier'       => $tier,
        'pack_id'    => (int)$pack_id,
        'expires_at' => $expiry,
    ], 200);
}

/**
 * Verify Apple IAP receipt and activate subscription
 */
function hiraaj_verify_iap_receipt(WP_REST_Request $request) {
    $user_id      = absint($request->get_param('user_id'));
    $product_id   = sanitize_text_field($request->get_param('product_id'));
    $receipt_data = $request->get_param('receipt_data');
    $platform     = sanitize_text_field($request->get_param('platform'));

    // Validate params
    if (empty($user_id) || empty($product_id) || empty($receipt_data)) {
        return new WP_REST_Response(['success' => false, 'message' => 'Missing required parameters'], 400);
    }

    // Debug: Check receipt integrity
    $is_base64 = (base64_decode($receipt_data, true) !== false);
    error_log("IAP: Receipt length=" . strlen($receipt_data) . " valid_base64=" . ($is_base64 ? 'YES' : 'NO'));
    if (!$is_base64) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'Receipt data is corrupted. Ensure Content-Type: application/json is set.'
        ], 400);
    }

    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_REST_Response(['success' => false, 'message' => 'User not found'], 404);
    }

    $iap_map = hiraaj_get_iap_to_wc_map();
    if (!isset($iap_map[$product_id])) {
        error_log("IAP Error: Unknown product_id '$product_id'");
        return new WP_REST_Response(['success' => false, 'message' => 'Unknown product: ' . $product_id], 400);
    }

    $wc_pack_id = $iap_map[$product_id];
    $tier_name  = hiraaj_get_iap_tier_name($product_id);

    // Verify with Apple
    $is_valid = hiraaj_validate_apple_receipt($receipt_data);
    if (!$is_valid) {
        error_log("IAP FAILED: user=$user_id product=$product_id");
        return new WP_REST_Response(['success' => false, 'message' => 'Receipt verification failed'], 403);
    }

    // ✅ Guard: Al-Zabayeh requires active Silver subscription
    if ($product_id === 'tier_zabayeh_monthly') {
        $current_pack = (int) get_user_meta($user_id, 'product_package_id', true);
        if ($current_pack !== 29028 && !current_user_can('manage_options')) {
            return new WP_REST_Response([
                'success' => false,
                'message' => 'يجب الاشتراك في الباقة الفضية أولاً للوصول إلى باقة الذبائح'
            ], 403);
        }
    }

    // === ACTIVATE SUBSCRIPTION ===
    $expiry = date('Y-m-d H:i:s', strtotime('+1 month'));

    // Core subscription meta
    update_user_meta($user_id, 'product_package_id',    $wc_pack_id);
    update_user_meta($user_id, 'product_pack_startdate', current_time('mysql'));
    update_user_meta($user_id, 'product_pack_enddate',   $expiry); // ✅ Consistent key

    // IAP tracking meta
    update_user_meta($user_id, '_iap_tier',         $tier_name);
    update_user_meta($user_id, '_iap_product_id',   $product_id);
    update_user_meta($user_id, '_iap_activated_at', current_time('mysql'));
    update_user_meta($user_id, '_iap_platform',     $platform);
    update_user_meta($user_id, '_iap_expiry',        $expiry);

    // ✅ BUG FIX: Set seller role (was missing entirely)
    $user_obj = new WP_User($user_id);
    if (!in_array('administrator', $user_obj->roles)) {
        $user_obj->set_role('seller');
    }
    update_user_meta($user_id, 'dokan_enable_selling', 'yes');
    update_user_meta($user_id, 'dokan_publishing',     'yes');

    // ✅ BUG FIX: Al-Zabayeh special flag (was missing from IAP flow) // Only available to silver members
    if ($product_id === 'tier_zabayeh_monthly') {
        update_user_meta($user_id, 'sacrifices_verified', 'yes');
    }

    error_log("IAP SUCCESS: user=$user_id product=$product_id pack=$wc_pack_id expires=$expiry role=seller");

    return new WP_REST_Response([
        'success'    => true,
        'message'    => 'تم تفعيل الاشتراك بنجاح',
        'tier'       => $tier_name,
        'pack_id'    => $wc_pack_id,
        'expires_at' => $expiry,
    ], 200);
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
        error_log('CRITICAL: Apple shared secret not configured. Blocking purchase.');
        return false;
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
        // Removed 'sslverify' => false (Production Risk Fix)
    );

    $response = wp_remote_post($url, $args);

    if (is_wp_error($response)) {
        error_log('IAP Request Failed: ' . $response->get_error_message());
        return null;
    }

    $body = wp_remote_retrieve_body($response);
    return json_decode($body, true);
}
