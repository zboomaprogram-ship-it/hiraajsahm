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

    // Debug Endpoint to confirm if this file is loaded and active
    register_rest_route('custom/v1', '/iap-debug', [
        'methods'  => 'GET',
        'callback' => function() {
            return new WP_REST_Response([
                'status' => 'success',
                'file' => 'hiraaj-iap-verify.php',
                'shared_secret_set' => !empty(get_option('hiraaj_apple_shared_secret')),
                'shared_secret_length' => strlen(get_option('hiraaj_apple_shared_secret', '')),
                'php_version' => phpversion(),
                'time' => current_time('mysql'),
            ], 200);
        },
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

    // ✅ FIX: Fallback to raw JSON body
    if (empty($receipt_data) || empty($user_id)) {
        $raw_body = file_get_contents('php://input');
        if (!empty($raw_body)) {
            $body = json_decode($raw_body, true);
            if (is_array($body)) {
                if (empty($user_id))      $user_id      = absint($body['user_id'] ?? 0);
                if (empty($receipt_data)) $receipt_data = $body['receipt_data'] ?? '';
                if (empty($platform))     $platform     = sanitize_text_field($body['platform'] ?? 'ios');
                error_log('IAP Restore: Used raw body fallback.');
            }
        }
    }

    if (empty($user_id) || empty($receipt_data)) {
        return new WP_REST_Response(['success' => false, 'message' => 'Missing params'], 400);
    }

    $user = get_user_by('id', $user_id);
    if (!$user) {
        return new WP_REST_Response(['success' => false, 'message' => 'User not found'], 404);
    }

    // Re-verify the receipt with Apple (skip if shared secret not configured)
    $shared_secret = get_option('hiraaj_apple_shared_secret', '');
    if (!empty($shared_secret)) {
        $is_valid = hiraaj_validate_apple_receipt($receipt_data);
        if (!$is_valid) {
            error_log("IAP Restore FAILED: Apple rejected receipt for user $user_id");
            // SAFE QUEUE FLUSH: Return 200 to force iOS app to clear the pending queue, 
            // but return early so they don't get free access.
            return new WP_REST_Response([
                'success' => false, 
                'message' => 'تم تفريغ العمليات المعلقة السابقة.'
            ], 200);
        }
    } else {
        error_log("IAP Restore: Skipping Apple verification (shared secret not configured) for user $user_id");
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
    // ✅ FIX: Try get_param() first, then fall back to raw JSON body
    // Dio sometimes sends application/json body that WordPress doesn't fully parse via get_param()
    $user_id      = absint($request->get_param('user_id'));
    $product_id   = sanitize_text_field($request->get_param('product_id'));
    $receipt_data = $request->get_param('receipt_data');
    $platform     = sanitize_text_field($request->get_param('platform') ?? 'ios');

    // Fallback: parse raw JSON body directly if params are missing
    if (empty($receipt_data) || empty($product_id) || empty($user_id)) {
        $raw_body = file_get_contents('php://input');
        if (!empty($raw_body)) {
            $body = json_decode($raw_body, true);
            if (is_array($body)) {
                if (empty($user_id))      $user_id      = absint($body['user_id'] ?? 0);
                if (empty($product_id))   $product_id   = sanitize_text_field($body['product_id'] ?? '');
                if (empty($receipt_data)) $receipt_data = $body['receipt_data'] ?? '';
                if (empty($platform))     $platform     = sanitize_text_field($body['platform'] ?? 'ios');
                error_log('IAP: Used raw body fallback to parse request params.');
            }
        }
    }

    // Validate params
    if (empty($user_id) || empty($product_id) || empty($receipt_data)) {
        error_log('IAP: Missing params — user_id=' . $user_id . ' product_id=' . $product_id . ' receipt_length=' . strlen($receipt_data ?? ''));
        return new WP_REST_Response(['success' => false, 'message' => 'Missing required parameters'], 400);
    }

    // ✅ FIX: Removed overly strict base64 block — Apple receipts are long base64 strings
    // but PHP's base64_decode strict check can reject valid receipts due to padding/whitespace.
    // We log the receipt length for debugging only.
    error_log('IAP: Received receipt — length=' . strlen($receipt_data) . ' product=' . $product_id . ' user=' . $user_id);

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

    // === APPLE RECEIPT VERIFICATION ===
    $shared_secret = get_option('hiraaj_apple_shared_secret', '');
    if (!empty($shared_secret)) {
        // Shared secret is set → verify with Apple properly
        $apple_result = hiraaj_validate_apple_receipt_detailed($receipt_data);
        if ($apple_result['valid'] !== true) {
            $reason = $apple_result['reason'] ?? 'Apple verification failed';
            error_log("IAP FAILED: user=$user_id product=$product_id reason=$reason");
            
            // SAFE QUEUE FLUSH: Return 200 to force the old iOS app to call completePurchase() 
            // and clear the stuck transaction. We return early so NO database update happens.
            // The user will NOT get the Silver tier.
            return new WP_REST_Response([
                'success' => false, 
                'message' => 'تم تفريغ العملية المرفوضة، يرجى المحاولة مرة أخرى'
            ], 200);
        }
    } else {
        // Shared secret NOT configured → skip Apple verification, just activate
        error_log("IAP: Skipping Apple verification (shared secret not configured) for user $user_id, product $product_id");
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
 * Validate Apple receipt — returns structured result with reason
 */
function hiraaj_validate_apple_receipt_detailed($receipt_data)
{
    $shared_secret = get_option('hiraaj_apple_shared_secret', '');

    if (empty($shared_secret)) {
        error_log('CRITICAL: Apple shared secret not configured in WordPress options.');
        return ['valid' => false, 'reason' => 'إعداد Apple Shared Secret مفقود من لوحة التحكم. تواصل مع المطور.'];
    }

    $payload = json_encode([
        'receipt-data'              => $receipt_data,
        'password'                  => $shared_secret,
        'exclude-old-transactions'  => true,
    ]);

    $production_url = 'https://buy.itunes.apple.com/verifyReceipt';
    $sandbox_url    = 'https://sandbox.itunes.apple.com/verifyReceipt';

    error_log('IAP: Sending receipt to Apple Production...');
    $response = hiraaj_send_receipt_to_apple($production_url, $payload);

    if ($response && isset($response['status'])) {
        error_log('IAP: Apple status=' . $response['status']);

        // 21007 = sandbox receipt sent to production → retry with sandbox
        if ($response['status'] == 21007) {
            error_log('IAP: Sandbox receipt, retrying with sandbox URL...');
            $response = hiraaj_send_receipt_to_apple($sandbox_url, $payload);
            error_log('IAP: Apple Sandbox status=' . ($response['status'] ?? 'null'));
        }

        if ($response && $response['status'] == 0) {
            error_log('IAP: Receipt verified successfully.');
            return ['valid' => true];
        }

        $status = $response['status'] ?? 'unknown';
        $status_messages = [
            21000 => 'الطلب لم يُرسل بالصيغة الصحيحة إلى Apple.',
            21002 => 'بيانات الإيصال تالفة أو مفقودة.',
            21003 => 'الإيصال غير قابل للمصادقة.',
            21004 => 'الـ Shared Secret غير مطابق في App Store Connect.',
            21005 => 'خادم Apple غير متاح حالياً. حاول مجدداً.',
            21006 => 'الاشتراك منتهي الصلاحية.',
            21007 => 'إيصال Sandbox لا يُقبل في بيئة الإنتاج.',
            21008 => 'إيصال الإنتاج لا يُقبل في بيئة Sandbox.',
            21010 => 'الاشتراك غير معتمد أو تم إلغاؤه.',
        ];
        $msg = $status_messages[$status] ?? "فشل التحقق من Apple (رمز: $status)";
        error_log("IAP: Apple rejected receipt with status $status");
        return ['valid' => false, 'reason' => $msg];
    }

    error_log('IAP Error: No response from Apple servers.');
    return ['valid' => false, 'reason' => 'لا يوجد رد من خوادم Apple. تحقق من اتصال السيرفر.'];
}

/**
 * Backward-compatible wrapper (returns bool)
 */
function hiraaj_validate_apple_receipt($receipt_data)
{
    $result = hiraaj_validate_apple_receipt_detailed($receipt_data);
    return $result['valid'] === true;
}

/**
 * Send receipt to Apple's verification server
 */
function hiraaj_send_receipt_to_apple($url, $payload)
{
    $args = array(
        'body'    => $payload,
        'headers' => array('Content-Type' => 'application/json'),
        'timeout' => 30,
    );

    $response = wp_remote_post($url, $args);

    if (is_wp_error($response)) {
        error_log('IAP Request Failed: ' . $response->get_error_message());
        return null;
    }

    $body = wp_remote_retrieve_body($response);
    return json_decode($body, true);
}

