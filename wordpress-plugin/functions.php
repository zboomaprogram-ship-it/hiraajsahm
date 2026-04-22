<?php
// أضف هذا الكود في ملف functions.php
add_action('woocommerce_order_status_completed', 'auto_upgrade_customer_to_vendor_on_subscription', 10, 1);

function auto_upgrade_customer_to_vendor_on_subscription($order_id)
{
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
            </table>
            <?php submit_button(); ?>
        </form>
    </div>
    <?php
}
