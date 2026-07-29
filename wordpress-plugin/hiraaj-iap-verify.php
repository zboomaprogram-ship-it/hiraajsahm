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
        'permission_callback' => function () {
            return is_user_logged_in();
        },
    ));

    // Restore Purchases Endpoint
    register_rest_route('custom/v1', '/restore-iap', [
        'methods'  => 'POST',
        'callback' => 'hiraaj_restore_iap_purchase',
        'permission_callback' => function () {
            return is_user_logged_in();
        },
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
        'permission_callback' => function () {
            return current_user_can('manage_options');
        },
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
    $user_id      = get_current_user_id();
    $receipt_data = $request->get_param('receipt_data');
    $platform     = sanitize_text_field($request->get_param('platform') ?? 'ios');

    if (empty($receipt_data)) {
        $raw_body = file_get_contents('php://input');
        if (!empty($raw_body)) {
            $body = json_decode($raw_body, true);
            if (is_array($body)) {
                if (empty($receipt_data)) $receipt_data = $body['receipt_data'] ?? '';
                if (empty($platform))     $platform     = sanitize_text_field($body['platform'] ?? 'ios');
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

    if (empty(get_option('hiraaj_apple_shared_secret', ''))) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'Apple receipt verification is not configured',
        ], 503);
    }

    $apple_result = hiraaj_validate_apple_receipt_detailed($receipt_data);
    if ($apple_result['valid'] !== true) {
        return new WP_REST_Response([
            'success' => false,
            'message' => $apple_result['reason'] ?? 'Apple rejected receipt',
        ], 422);
    }

    $product_id = sanitize_text_field($apple_result['product_id'] ?? '');
    $iap_map = hiraaj_get_iap_to_wc_map();
    if (!isset($iap_map[$product_id])) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'No supported active subscription was found',
        ], 422);
    }

    // Restoring Al-Zabayeh is allowed for an existing Zabayeh subscriber or
    // for a user who currently has the prerequisite Silver package.
    if ($product_id === 'tier_zabayeh_monthly') {
        $current_pack = (int) get_user_meta($user_id, 'product_package_id', true);
        if (
            $current_pack !== 29028
            && $current_pack !== 29318
            && !current_user_can('manage_options')
        ) {
            return new WP_REST_Response([
                'success' => false,
                'message' => 'يجب الاشتراك في الباقة الفضية أولاً للوصول إلى باقة الذبائح',
            ], 403);
        }
    }

    $claim = hiraaj_claim_iap_transaction(
        $user_id,
        $apple_result['original_transaction_id'] ?? $apple_result['transaction_id'] ?? ''
    );
    if (is_wp_error($claim)) {
        return $claim;
    }

    $pack_id = (int) $iap_map[$product_id];
    $tier = hiraaj_get_iap_tier_name($product_id);
    $expiry = wp_date('Y-m-d H:i:s', (int) $apple_result['expires_at']);
    update_user_meta($user_id, 'product_package_id', $pack_id);
    update_user_meta($user_id, 'product_pack_enddate', $expiry);
    update_user_meta($user_id, '_iap_tier', $tier);
    update_user_meta($user_id, '_iap_product_id', $product_id);
    update_user_meta($user_id, '_iap_transaction_id', sanitize_text_field($apple_result['transaction_id'] ?? ''));
    update_user_meta($user_id, '_iap_original_transaction_id', sanitize_text_field($apple_result['original_transaction_id'] ?? ''));
    update_user_meta($user_id, '_iap_expiry', $expiry);

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
    $user_id      = get_current_user_id();
    $product_id   = sanitize_text_field($request->get_param('product_id'));
    $receipt_data = $request->get_param('receipt_data');
    $platform     = sanitize_text_field($request->get_param('platform') ?? 'ios');

    // Fallback: parse raw JSON body directly if params are missing
    if (empty($receipt_data) || empty($product_id)) {
        $raw_body = file_get_contents('php://input');
        if (!empty($raw_body)) {
            $body = json_decode($raw_body, true);
            if (is_array($body)) {
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
    if (empty(get_option('hiraaj_apple_shared_secret', ''))) {
        return new WP_REST_Response([
            'success' => false,
            'message' => 'Apple receipt verification is not configured',
        ], 503);
    }

    $apple_result = hiraaj_validate_apple_receipt_detailed($receipt_data, $product_id);
    if ($apple_result['valid'] !== true) {
        $reason = $apple_result['reason'] ?? 'Apple verification failed';
        error_log("IAP FAILED: user=$user_id product=$product_id reason=$reason");
        return new WP_REST_Response([
            'success' => false,
            'message' => $reason,
        ], 422);
    }

    $claim = hiraaj_claim_iap_transaction(
        $user_id,
        $apple_result['original_transaction_id'] ?? $apple_result['transaction_id'] ?? ''
    );
    if (is_wp_error($claim)) {
        return $claim;
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
    $expiry = wp_date('Y-m-d H:i:s', (int) $apple_result['expires_at']);

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
    update_user_meta($user_id, '_iap_transaction_id', sanitize_text_field($apple_result['transaction_id'] ?? ''));
    update_user_meta($user_id, '_iap_original_transaction_id', sanitize_text_field($apple_result['original_transaction_id'] ?? ''));

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
function hiraaj_validate_apple_receipt_detailed($receipt_data, $expected_product_id = '')
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
            $transactions = [];
            if (!empty($response['latest_receipt_info']) && is_array($response['latest_receipt_info'])) {
                $transactions = $response['latest_receipt_info'];
            } elseif (!empty($response['receipt']['in_app']) && is_array($response['receipt']['in_app'])) {
                $transactions = $response['receipt']['in_app'];
            }

            $supported_products = array_keys(hiraaj_get_iap_to_wc_map());
            $now_ms = (int) round(microtime(true) * 1000);
            $active = [];
            foreach ($transactions as $transaction) {
                $transaction_product = sanitize_text_field($transaction['product_id'] ?? '');
                $expires_ms = (int) ($transaction['expires_date_ms'] ?? 0);
                if (!in_array($transaction_product, $supported_products, true)) {
                    continue;
                }
                if (!empty($expected_product_id) && $transaction_product !== $expected_product_id) {
                    continue;
                }
                if (!empty($transaction['cancellation_date_ms']) || $expires_ms <= $now_ms) {
                    continue;
                }
                $active[] = $transaction;
            }

            if (empty($active)) {
                return ['valid' => false, 'reason' => 'No active matching subscription was found'];
            }

            usort($active, function ($a, $b) {
                return ((int) ($b['expires_date_ms'] ?? 0)) <=> ((int) ($a['expires_date_ms'] ?? 0));
            });
            $verified = $active[0];

            return [
                'valid' => true,
                'product_id' => sanitize_text_field($verified['product_id'] ?? ''),
                'transaction_id' => sanitize_text_field($verified['transaction_id'] ?? ''),
                'original_transaction_id' => sanitize_text_field($verified['original_transaction_id'] ?? ''),
                'expires_at' => (int) floor(((int) $verified['expires_date_ms']) / 1000),
            ];
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
 * Bind an App Store original transaction to a single WordPress account.
 */
function hiraaj_claim_iap_transaction($user_id, $transaction_id)
{
    $transaction_id = sanitize_text_field($transaction_id);
    if (empty($transaction_id)) {
        return new WP_Error('missing_transaction', 'Apple transaction ID is missing', ['status' => 422]);
    }

    $option_key = 'hiraaj_iap_owner_' . hash('sha256', $transaction_id);
    $owner = (int) get_option($option_key, 0);
    if ($owner > 0 && $owner !== (int) $user_id) {
        return new WP_Error('receipt_already_used', 'This purchase belongs to another account', ['status' => 409]);
    }
    if ($owner === 0) {
        add_option($option_key, (int) $user_id, '', false);
        $owner = (int) get_option($option_key, 0);
        if ($owner !== (int) $user_id) {
            return new WP_Error('receipt_already_used', 'This purchase belongs to another account', ['status' => 409]);
        }
    }

    return true;
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
