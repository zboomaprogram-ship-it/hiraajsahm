<?php
// أضف هذا الكود في ملف functions.php
add_action('woocommerce_order_status_completed', 'auto_upgrade_customer_to_vendor_on_subscription', 10, 1);

function auto_upgrade_customer_to_vendor_on_subscription($order_id)
{
    if (!$order_id)
        return;

    // Guard against double processing
    if (get_post_meta($order_id, '_hiraaj_subscription_processed', true)) {
        return;
    }

    $order = wc_get_order($order_id);
    $user_id = $order->get_user_id();

    // 1. تأكد أن الطلب لمستخدم مسجل
    if (!$user_id)
        return;

    // 2. تحقق من أن المستخدم حالياً "زبون" (Customer)
    $user = new WP_User($user_id);
    if (!in_array('customer', (array) $user->roles))
        return;

    // 3. قائمة بمعرفات منتجات الاشتراك (Bronze, Silver, Gold IDs)
    // استبدل الأرقام بمعرفات الباقات الحقيقية لديك
    $subscription_pack_ids = array( 29026, 29028, 29030, 29318 );

    $found_subscription = false;
    $target_pack_id = null;

    // 4. ابحث في الطلب: هل اشترى باقة اشتراك؟
    foreach ($order->get_items() as $item) {
        if (in_array($item->get_product_id(), $subscription_pack_ids)) {
            $found_subscription = true;
            $target_pack_id = $item->get_product_id();
            break;
        }
    }

    // 5. إذا وجدنا الباقة، قم بالترقية فوراً
    if ($found_subscription) {
        // حذف رتبة الزبون
        $user->remove_role('customer');

        // إضافة رتبة البائع (Vendor/Seller)
        $user->add_role('seller');

        // تفعيل خصائص Dokan للبائع الجديد
        update_user_meta($user_id, 'dokan_enable_selling', 'yes');
        update_user_meta($user_id, 'dokan_publishing', 'yes'); // اختياري: للسماح بالنشر مباشرة

        update_user_meta($user_id, 'product_package_id',    $target_pack_id);
        update_user_meta($user_id, 'product_pack_startdate', current_time('mysql'));
        update_user_meta($user_id, 'product_pack_enddate',   'unlimited');

        if ($target_pack_id == 29318) {
            update_user_meta($user_id, 'sacrifices_verified', 'yes');
        }

        update_post_meta($order_id, '_hiraaj_subscription_processed', '1');
    }
}

// ============================================================
// Hiraaj Sahm General Settings Page (App API Configs)
// ============================================================
add_action('admin_menu', 'hiraaj_sahm_register_settings_page');
function hiraaj_sahm_register_settings_page() {
    add_options_page(
        'Hiraaj Sahm APIs',         // Page Title
        'Hiraaj Sahm Settings',     // Menu Title
        'manage_options',           // Capability
        'hiraaj-sahm-settings',     // Menu Slug
        'hiraaj_sahm_render_settings_page' // Callback
    );
}

add_action('admin_init', 'hiraaj_sahm_register_settings');
function hiraaj_sahm_register_settings() {
    register_setting('hiraaj_sahm_options_group', 'telr_store_id');
    register_setting('hiraaj_sahm_options_group', 'telr_auth_key');
    register_setting('hiraaj_sahm_options_group', 'telr_test_mode');
    register_setting('hiraaj_sahm_options_group', 'onesignal_app_id');
    register_setting('hiraaj_sahm_options_group', 'onesignal_api_key');
    register_setting('hiraaj_sahm_options_group', 'hiraaj_apple_shared_secret'); // 🍎 Apple IAP
}

function hiraaj_sahm_render_settings_page() {
    ?>
    <div class="wrap">
        <h2>إعدادات ربط التطبيق (Hiraaj Sahm API Settings)</h2>
        <form method="post" action="options.php">
            <?php settings_fields('hiraaj_sahm_options_group'); ?>
            <table class="form-table">
                <tr valign="top">
                    <th scope="row">Telr Store ID</th>
                    <td><input type="text" name="telr_store_id" value="<?php echo esc_attr(get_option('telr_store_id', '34762')); ?>" class="regular-text" /></td>
                </tr>
                <tr valign="top">
                    <th scope="row">Telr Mobile Auth Key</th>
                    <td><input type="text" name="telr_auth_key" value="<?php echo esc_attr(get_option('telr_auth_key', 'mKnQf-HrCvD@StZK')); ?>" class="regular-text" /></td>
                </tr>
                <tr valign="top">
                    <th scope="row">Telr Test Mode (Live = 0)</th>
                    <td>
                        <select name="telr_test_mode">
                            <option value="0" <?php selected(get_option('telr_test_mode'), false); ?>>Live</option>
                            <option value="1" <?php selected(get_option('telr_test_mode'), true); ?>>Test</option>
                        </select>
                    </td>
                </tr>
                <tr valign="top">
                    <th scope="row">OneSignal App ID</th>
                    <td><input type="text" name="onesignal_app_id" value="<?php echo esc_attr(get_option('onesignal_app_id', '9f9ed559-2c77-43e5-9c47-473043f2e6d4')); ?>" class="regular-text" /></td>
                </tr>
                <tr valign="top">
                    <th scope="row">OneSignal API Key</th>
                    <td><input type="text" name="onesignal_api_key" value="<?php echo esc_attr(get_option('onesignal_api_key', 'os_v2_app_t6pnkwjmo5b6lhchi4yeh4xg2ssu6244cxtustmk6cejgwg65kqv3y433om47zx3wljkb54lqexmptcciinbzv7ig7kxcpattlgag3a')); ?>" class="regular-text" /></td>
                </tr>
                <tr valign="top">
                    <th scope="row">🍎 Apple IAP Shared Secret</th>
                    <td>
                        <input type="password" name="hiraaj_apple_shared_secret"
                               value="<?php echo esc_attr(get_option('hiraaj_apple_shared_secret', '')); ?>"
                               class="regular-text" placeholder="من App Store Connect" />
                        <p class="description">
                            من <strong>App Store Connect</strong> → تطبيقك → <strong>General</strong> → <strong>App-Specific Shared Secret</strong>.<br>
                            <?php if (empty(get_option('hiraaj_apple_shared_secret'))): ?>
                                <span style="color:red;">⚠️ غير مضبوط — الاشتراكات عبر Apple لن تعمل حتى يتم إدخال هذه القيمة!</span>
                            <?php else: ?>
                                <span style="color:green;">✅ تم الضبط.</span>
                            <?php endif; ?>
                        </p>
                    </td>
                </tr>
            </table>
            <?php submit_button(); ?>
        </form>
    </div>
    <?php
}

// ============================================================
// 🔄 One-Time: Update Subscription Tier Prices & Descriptions
// Runs once automatically when you save this file on the server.
// ============================================================
add_action('admin_init', 'hiraaj_update_subscription_packs_once');
function hiraaj_update_subscription_packs_once() {
    // Guard: only run once
    if (get_option('hiraaj_packs_updated_v3')) return;

    $packs = [
        // 🥉 Bronze - Free
        29026 => [
            'price'       => '0',
            'regular_price' => '0',
            'name'        => 'العضوية البرونزية',
            'description' => '<ul>
<li>عضوية أساسية بدون رسوم.</li>
<li>إعلان واحد في اليوم.</li>
<li>السعي %0.5.</li>
<li>لا يمكن الاستفادة من الخدمات.</li>
</ul>',
        ],
        // 🥈 Silver - 30 SAR/month  ← PRICE FIX (was 99)
        29028 => [
            'price'       => '30',
            'regular_price' => '30',
            'name'        => 'العضوية الفضية',
            'description' => '<ul>
<li>برسوم اشتراك 30 ريال شهري.</li>
<li>ثلاث إعلانات يومياً.</li>
<li>لا يوجد سعي.</li>
<li>يمكن الاستفادة من الخدمات.</li>
</ul>',
        ],
        // 🥇 Gold - Package months
        29030 => [
            'price'       => '0',
            'regular_price' => '0',
            'name'        => 'العضوية الذهبية',
            'description' => '<ul>
<li>برسوم اشتراك باقة أشهر.</li>
<li>خمس إعلانات يومياً.</li>
<li>لا يوجد سعي.</li>
<li>يمكن الاستفادة من الخدمات وتخفيضها.</li>
<li>امتلاك علامة ثقة من الموقع.</li>
</ul>',
        ],
        // 🐑 Zabayeh / Services
        29318 => [
            'price'       => '50',
            'regular_price' => '50',
            'name'        => 'عضوية الخدمات والذبائح',
            'description' => '<ul>
<li>التقديم على خدمات النقل والمعاينة.</li>
<li>رسوم شهرية 50 ريال للنقل.</li>
<li>رسوم قسم الذبائح 50 ريال شهري.</li>
<li>تقديم إعلان بخدمات ما بعد الذبح.</li>
</ul>',
        ],
    ];

    foreach ($packs as $product_id => $data) {
        $product = wc_get_product($product_id);
        if (!$product) continue;

        $product->set_name($data['name']);
        $product->set_description($data['description']);
        $product->set_price($data['price']);
        $product->set_regular_price($data['regular_price']);
        $product->save();

        error_log("✅ Hiraaj: Updated product $product_id ({$data['name']}) — price={$data['price']}");
    }

    // Mark as done so this never runs again
    update_option('hiraaj_packs_updated_v3', true);
    error_log('✅ Hiraaj: Subscription packs updated (v2). This will not run again.');
}

// ============================================================
// Fix JWT Token Expiring (Extended to 1 Year)
// ============================================================

// Method 1: Override the 'exp' claim directly in the JWT payload before signing.
// This is the most reliable approach — works regardless of how the plugin
// applies the jwt_auth_expire filter.
add_filter('jwt_auth_token_before_sign', function($token, $user) {
    $token['exp'] = time() + (DAY_IN_SECONDS * 365); // 1 year from now
    return $token;
}, 10, 2);

// Method 2: Hook jwt_auth_expire as a safety net.
// Some JWT plugins pass 1 arg (expire timestamp), others pass 2 (expire, issued_at).
// We accept 2 but only rely on time() to be safe either way.
add_filter('jwt_auth_expire', function($expire, $issued_at = null) {
    return time() + (DAY_IN_SECONDS * 365); // 1 year from now
}, 10, 2);

// ============================================================
// Fix Standard WP Auth Cookie Expiring in 48 Hours (2 Days)
// ============================================================
add_filter('auth_cookie_expiration', function($length) {
    return DAY_IN_SECONDS * 365; // 1 year
}, 10, 1);

// ============================================================
// Silent Token Refresh Endpoint
// Allows the app to get a fresh JWT token using the current valid token,
// so users never need to re-enter their password.
// POST /wp-json/hiraajsahm/v1/token/refresh
// Header: Authorization: Bearer <current_valid_token>
// ============================================================
add_action('rest_api_init', function() {
    register_rest_route('hiraajsahm/v1', '/token/refresh', [
        'methods'  => 'POST',
        'callback' => 'hiraaj_sahm_refresh_token',
        'permission_callback' => function() {
            return is_user_logged_in();
        },
    ]);
});

function hiraaj_sahm_refresh_token(WP_REST_Request $request) {
    $user = wp_get_current_user();
    if (!$user || !$user->ID) {
        return new WP_Error('not_authenticated', 'Invalid or expired token', ['status' => 401]);
    }

    // Generate a fresh JWT token for this user
    $issued_at = time();
    $expire    = $issued_at + (DAY_IN_SECONDS * 365);

    $token_data = [
        'iss'  => get_bloginfo('url'),
        'iat'  => $issued_at,
        'nbf'  => $issued_at,
        'exp'  => $expire,
        'data' => [
            'user' => [
                'id' => $user->ID,
            ],
        ],
    ];

    // Allow other plugins to modify the token payload
    $token_data = apply_filters('jwt_auth_token_before_sign', $token_data, $user);

    // Get the JWT secret key from wp-config.php or the plugin's option
    $secret_key = defined('JWT_AUTH_SECRET_KEY') ? JWT_AUTH_SECRET_KEY : false;
    if (!$secret_key) {
        return new WP_Error('jwt_auth_missing_secret', 'JWT secret key is not configured', ['status' => 500]);
    }

    // Use Firebase JWT if available (bundled with the JWT Auth plugin)
    if (!class_exists('Firebase\JWT\JWT')) {
        // Try to load from the JWT Auth plugin
        $jwt_plugin_path = WP_PLUGIN_DIR . '/jwt-authentication-for-wp-rest-api/vendor/autoload.php';
        if (file_exists($jwt_plugin_path)) {
            require_once $jwt_plugin_path;
        }
    }

    if (class_exists('Firebase\JWT\JWT')) {
        $algorithm = defined('JWT_AUTH_ALGORITHM') ? JWT_AUTH_ALGORITHM : 'HS256';
        $token = \Firebase\JWT\JWT::encode($token_data, $secret_key, $algorithm);
    } else {
        return new WP_Error('jwt_auth_missing_library', 'JWT library not available', ['status' => 500]);
    }

    return new WP_REST_Response([
        'success' => true,
        'token'   => $token,
        'user_email'        => $user->user_email,
        'user_display_name' => $user->display_name,
        'user_nicename'     => $user->user_nicename,
        'expires_in'        => DAY_IN_SECONDS * 365,
    ], 200);
}

// ============================================================
// Product Image Watermark
// ============================================================
if (!defined('HIRAAJ_WATERMARK_URL')) {
    define('HIRAAJ_WATERMARK_URL', 'https://hiraajsahm.com/wp-content/uploads/2026/05/%D8%AD%D8%B1%D8%A7%D8%AC-%D8%B3%D9%87%D9%85-1-3-1.png');
}
if (!defined('HIRAAJ_WATERMARK_SIZE')) {
    define('HIRAAJ_WATERMARK_SIZE', 0.16);
}
if (!defined('HIRAAJ_WATERMARK_MARGIN')) {
    define('HIRAAJ_WATERMARK_MARGIN', 40);
}
if (!defined('HIRAAJ_WATERMARK_META')) {
    define('HIRAAJ_WATERMARK_META', '_hiraaj_watermarked');
}

add_filter('wp_handle_upload', 'hiraaj_sahm_watermark_product_upload');
add_action('woocommerce_process_product_meta', 'hiraaj_sahm_watermark_product_images_on_save', 10, 1);
add_action('woocommerce_rest_insert_product_object', 'hiraaj_sahm_watermark_product_images_on_rest_save', 10, 3);

function hiraaj_sahm_watermark_product_upload($upload) {
    if (!hiraaj_sahm_is_product_upload_context()) {
        return $upload;
    }

    return hiraaj_sahm_apply_watermark_to_upload($upload);
}

function hiraaj_sahm_watermark_product_images_on_save($product_id) {
    $thumbnail_id = get_post_thumbnail_id($product_id);
    if ($thumbnail_id) {
        hiraaj_sahm_watermark_attachment((int) $thumbnail_id);
    }

    $gallery_ids = get_post_meta($product_id, '_product_image_gallery', true);
    if (!empty($gallery_ids)) {
        foreach (explode(',', $gallery_ids) as $attachment_id) {
            hiraaj_sahm_watermark_attachment((int) trim($attachment_id));
        }
    }
}

function hiraaj_sahm_watermark_product_images_on_rest_save($product, $request, $creating) {
    if (!is_a($product, 'WC_Product')) {
        return;
    }

    $image_ids = array_filter(array_merge(
        [(int) $product->get_image_id()],
        array_map('absint', (array) $product->get_gallery_image_ids())
    ));

    foreach ($image_ids as $attachment_id) {
        hiraaj_sahm_watermark_attachment((int) $attachment_id);
    }
}

function hiraaj_sahm_is_product_upload_context() {
    $post_id = (int) ($_REQUEST['post_id'] ?? $_REQUEST['post'] ?? 0);

    if ($post_id && get_post_type($post_id) === 'product') {
        return true;
    }

    return false;
}

function hiraaj_sahm_watermark_attachment($attachment_id) {
    if (!$attachment_id || get_post_meta($attachment_id, HIRAAJ_WATERMARK_META, true)) {
        return false;
    }

    $mime = get_post_mime_type($attachment_id);
    if (!in_array($mime, ['image/jpeg', 'image/png', 'image/webp'], true)) {
        return false;
    }

    $file_path = get_attached_file($attachment_id);
    if (!$file_path || !file_exists($file_path)) {
        return false;
    }

    $changed = hiraaj_sahm_apply_watermark_to_file($file_path);
    $metadata = wp_get_attachment_metadata($attachment_id);

    if (!empty($metadata['sizes']) && !empty($metadata['file'])) {
        $uploads = wp_upload_dir();
        $base_dir = trailingslashit($uploads['basedir']) . trailingslashit(dirname($metadata['file']));

        foreach ($metadata['sizes'] as $size) {
            if (!empty($size['file'])) {
                $changed = hiraaj_sahm_apply_watermark_to_file($base_dir . $size['file']) || $changed;
            }
        }
    }

    if ($changed) {
        update_post_meta($attachment_id, HIRAAJ_WATERMARK_META, '1');
    }

    return $changed;
}

function hiraaj_sahm_apply_watermark_to_upload($upload) {
    if (isset($upload['file'])) {
        hiraaj_sahm_apply_watermark_to_file($upload['file']);
    }

    return $upload;
}

function hiraaj_sahm_apply_watermark_to_file($file_path) {
    if (!extension_loaded('gd') || !$file_path || !file_exists($file_path)) {
        return false;
    }

    $file_type = wp_check_filetype($file_path);
    $ext = strtolower($file_type['ext'] ?? '');

    if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp'], true)) {
        return false;
    }

    $image = hiraaj_sahm_create_image_resource($file_path, $ext);
    if (!$image) {
        return false;
    }

    $image_width = imagesx($image);
    $image_height = imagesy($image);

    if ($image_width < 150 || $image_height < 150) {
        imagedestroy($image);
        return false;
    }

    $watermark_data = wp_remote_retrieve_body(wp_remote_get(HIRAAJ_WATERMARK_URL, ['timeout' => 10]));
    if (empty($watermark_data)) {
        imagedestroy($image);
        return false;
    }

    $watermark = @imagecreatefromstring($watermark_data);
    if (!$watermark) {
        imagedestroy($image);
        return false;
    }

    $watermark_width = imagesx($watermark);
    $watermark_height = imagesy($watermark);
    $new_width = max(40, (int) round($image_width * HIRAAJ_WATERMARK_SIZE));
    $new_height = (int) round(($watermark_height / $watermark_width) * $new_width);

    $resized_watermark = imagecreatetruecolor($new_width, $new_height);
    imagealphablending($resized_watermark, false);
    imagesavealpha($resized_watermark, true);
    imagefilledrectangle(
        $resized_watermark,
        0,
        0,
        $new_width,
        $new_height,
        imagecolorallocatealpha($resized_watermark, 0, 0, 0, 127)
    );
    imagecopyresampled($resized_watermark, $watermark, 0, 0, 0, 0, $new_width, $new_height, $watermark_width, $watermark_height);

    $margin = min(HIRAAJ_WATERMARK_MARGIN, max(10, (int) round($image_width * 0.04)));
    $x = max(0, $image_width - $new_width - $margin);
    $y = max(0, $image_height - $new_height - $margin);

    imagealphablending($image, true);
    imagecopy($image, $resized_watermark, $x, $y, 0, 0, $new_width, $new_height);

    $saved = hiraaj_sahm_save_image_resource($image, $file_path, $ext);

    imagedestroy($image);
    imagedestroy($watermark);
    imagedestroy($resized_watermark);

    return $saved;
}

function hiraaj_sahm_create_image_resource($file_path, $ext) {
    if (($ext === 'jpg' || $ext === 'jpeg') && function_exists('imagecreatefromjpeg')) {
        return @imagecreatefromjpeg($file_path);
    }

    if ($ext === 'png' && function_exists('imagecreatefrompng')) {
        return @imagecreatefrompng($file_path);
    }

    if ($ext === 'webp' && function_exists('imagecreatefromwebp')) {
        return @imagecreatefromwebp($file_path);
    }

    return false;
}

function hiraaj_sahm_save_image_resource($image, $file_path, $ext) {
    if ($ext === 'jpg' || $ext === 'jpeg') {
        return imagejpeg($image, $file_path, 94);
    }

    if ($ext === 'png') {
        imagesavealpha($image, true);
        return imagepng($image, $file_path, 6);
    }

    if ($ext === 'webp' && function_exists('imagewebp')) {
        return imagewebp($image, $file_path, 90);
    }

    return false;
}
