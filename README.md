# hiraajsahm

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

proudct url :https://hiraajsahm.com/wp-json/wc/v3/products?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54
categpries url :https://hiraajsahm.com/wp-json/wc/v3/products/categories?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54
orders url :https://hiraajsahm.com/wp-json/wc/v3/orders?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54

<!-- for  about us & termas......etc -->

pages url :https://hiraajsahm.com/wp-json/wp/v2/pages?consumer_key=ck_78ec6d3f6325ae403400781192045474f592b24a&consumer_secret=cs_0accb11f98ea7516ab4630e521748e73ce3d3b54

Your App ID: 9f9ed559-2c77-43e5-9c47-473043f2e6d4

<!-- petwithhit -->

ck:ck_21d20bb6427faaaf7f9aeb49a6e0cd5e96efa801
cs:cs_b9eaac1870c64b2ea3935a5d2296bdf93a73b4ce

/////////////
and on the logged user vendor profile there is no location viwed add it and add a description that the logged vendor can edit and link it with wordpress

/////////////////////////////////////////////

/\*\*

- Force WordPress Customer Registration
- Disable Dokan Vendor Registration on My Account
- - Interactive Map for Location (Leaflet)
- - Service Providers System (Admin + Frontend)
    \*/

add_action( 'init', function () {

    // Hide vendor option (frontend)
    add_action( 'wp_head', function () {
        if ( ! is_account_page() ) return;
        ?>
        <style>
            .dokan-become-vendor, .dokan-vendor-role,
            input[value="seller"], label[for*="seller"],
            .user-role input, .user-role label { display: none !important; }
        </style>
        <?php
    });

    // Force role = customer
    add_filter( 'woocommerce_new_customer_data', function ( $data ) {
        $data['role'] = 'customer';
        return $data;
    });

    // Extra safety
    add_action( 'user_register', function ( $user_id ) {
        $user = get_user_by( 'ID', $user_id );
        if ( $user && in_array( 'seller', (array) $user->roles, true ) ) {
            $user->remove_role( 'seller' );
            $user->add_role( 'customer' );
        }
    }, 20 );

});

// -----------------------------------------------
// 1️⃣ تحميل ملفات الخريطة (Leaflet Map Resources)
// -----------------------------------------------
add_action('wp_enqueue_scripts', function() {
// تحميل مكتبة Leaflet CSS و JS فقط في صفحة التسجيل لتقليل الحمل
if ( is_account_page() || is_checkout() ) {
wp_enqueue_style( 'leaflet-css', 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css' );
wp_enqueue_script( 'leaflet-js', 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js', [], '1.9.4', true );
}
});

// -----------------------------------------------
// 2️⃣ إضافة الحقول + الخريطة في التسجيل
// -----------------------------------------------
// -----------------------------------------------
// 2️⃣ إضافة الحقول + الخريطة في التسجيل (تم إصلاح أيقونة الدبوس)
// -----------------------------------------------
function custom_user_registration_fields() {
?>

<p class="form-row form-row-wide">
<label for="city"><?php _e('المدينة', 'your-text-domain'); ?> <span class="required">\*</span></label>
<input type="text" name="city" id="city" required />
</p>

    <p class="form-row form-row-wide">
        <label for="area"><?php _e('المنطقة', 'your-text-domain'); ?> <span class="required">*</span></label>
        <input type="text" name="area" id="area" required />
    </p>

    <p class="form-row form-row-wide">
        <label for="map-container"><?php _e('حدد موقعك على الخريطة (اضغط لتحديد المكان)', 'your-text-domain'); ?> <span class="required">*</span></label>

        <div id="registration-map" style="height: 300px; width: 100%; border: 2px solid #ddd; border-radius: 8px; z-index: 1;"></div>

        <input type="hidden" name="location" id="location_coords" required />
        <span style="font-size: 12px; color: #666;">تم تحديد: <span id="location-status">لم يتم التحديد بعد</span></span>
    </p>

    <script>
    document.addEventListener('DOMContentLoaded', function() {
        if (typeof L === 'undefined') return;

        // 🔴🔴 إصلاح مشكلة اختفاء الدبوس (Fix Broken Marker) 🔴🔴
        delete L.Icon.Default.prototype._getIconUrl;
        L.Icon.Default.mergeOptions({
            iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
            iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
            shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
        });

        // 1. إعداد الخريطة
        var map = L.map('registration-map').setView([24.7136, 46.6753], 10);

        // 2. تحميل الخريطة
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);

        var marker;
        var inputField = document.getElementById('location_coords');
        var statusText = document.getElementById('location-status');

        // 3. عند الضغط
        map.on('click', function(e) {
            var lat = e.latlng.lat;
            var lng = e.latlng.lng;

            if (marker) {
                map.removeLayer(marker);
            }

            marker = L.marker([lat, lng]).addTo(map);

            var coords = lat + ',' + lng;
            inputField.value = coords;

            statusText.innerText = "تم التقاط الإحداثيات بنجاح ✅";
            statusText.style.color = "green";
        });

        setTimeout(function(){ map.invalidateSize();}, 400);
    });
    </script>
    <?php

}
add_action('woocommerce_register_form', 'custom_user_registration_fields');

// -----------------------------------------------
// 3️⃣ حفظ بيانات العميل (المدينة، المنطقة، اللوكيشن)
// -----------------------------------------------
function save_custom_user_registration_fields($user_id) {
    if (isset($\_POST['city'])) update_user_meta($user_id, 'city', sanitize_text_field($\_POST['city']));
if (isset($_POST['area'])) update_user_meta($user_id, 'area', sanitize_text_field($_POST['area']));
    if (isset($\_POST['location'])) update_user_meta($user_id, 'location', sanitize_text_field($\_POST['location']));
}
add_action('woocommerce_created_customer', 'save_custom_user_registration_fields');

// -----------------------------------------------
// 4️⃣ صفحة مقدمي الخدمة (لوحة التحكم - Backend)
// -----------------------------------------------
add_action('admin_menu', 'add_service_provider_page');
function add_service_provider_page() {
add_menu_page('إضافة مقدمي الخدمة', 'مقدمي الخدمة', 'manage_options', 'service_provider', 'service_provider_page_content', 'dashicons-car', 20);
}

function service_provider_page_content() {
$edit_mode = false;
$edit_index = -1;
$current_data = [
'provider_name' => '',
'provider_phone' => '',
'provider_city' => '',
'provider_role' => 'معاين',
'provider_vehicle_details' => '',
'provider_price_kilo' => '',
'provider_image_id' => ''
];

    $providers = get_option('service_provider_data', []);

    if ( isset($_GET['action']) && $_GET['action'] == 'edit' && isset($_GET['index']) ) {
        $edit_index = intval($_GET['index']);
        if ( isset($providers[$edit_index]) ) {
            $edit_mode = true;
            $current_data = $providers[$edit_index];
        }
    }
    ?>
    <div class="wrap">
        <h1 class="wp-heading-inline"><?php echo $edit_mode ? 'تعديل بيانات السائق' : 'إضافة سائق/مقدم خدمة جديد'; ?></h1>

        <?php if($edit_mode): ?>
            <a href="<?php echo admin_url('admin.php?page=service_provider'); ?>" class="page-title-action">إلغاء التعديل</a>
        <?php endif; ?>

        <form method="post" action="<?php echo admin_url('admin-post.php'); ?>" enctype="multipart/form-data">
            <?php wp_nonce_field('save_service_provider_nonce'); ?>
            <input type="hidden" name="action" value="save_service_provider">
            <?php if($edit_mode): ?>
                <input type="hidden" name="editing_index" value="<?php echo $edit_index; ?>">
                <input type="hidden" name="existing_image_id" value="<?php echo esc_attr($current_data['provider_image_id']); ?>">
            <?php endif; ?>

            <div style="background: #fff; padding: 20px; border: 1px solid #ccd0d4; margin-top: 20px; max-width: 800px;">

                <p class="form-row">
                    <label>صورة المركبة (أو السائق)</label>
                    <?php
                    if($current_data['provider_image_id']) {
                        echo wp_get_attachment_image($current_data['provider_image_id'], 'thumbnail', false, ['style' => 'max-width:100px; display:block; margin-bottom:10px;']);
                    }
                    ?>
                    <input type="file" name="provider_image" accept="image/*">
                </p>

                <div style="display: flex; gap: 20px;">
                    <p class="form-row" style="flex:1;">
                        <label>اسم السائق</label>
                        <input type="text" name="provider_name" value="<?php echo esc_attr($current_data['provider_name']); ?>" required>
                    </p>
                    <p class="form-row" style="flex:1;">
                        <label>رقم التواصل (واتساب/اتصال)</label>
                        <input type="text" name="provider_phone" value="<?php echo esc_attr($current_data['provider_phone']); ?>" required>
                    </p>
                </div>

                <div style="display: flex; gap: 20px;">
                    <p class="form-row" style="flex:1;">
                        <label>المدينة</label>
                        <input type="text" name="provider_city" value="<?php echo esc_attr($current_data['provider_city']); ?>" required>
                    </p>
                    <p class="form-row" style="flex:1;">
                        <label>نوع العمل</label>
                        <select name="provider_role">
                            <option value="معاين" <?php selected($current_data['provider_role'], 'معاين'); ?>>معاين</option>
                            <option value="ناقل" <?php selected($current_data['provider_role'], 'ناقل'); ?>>ناقل</option>
                        </select>
                    </p>
                </div>

                <div style="display: flex; gap: 20px;">
                    <p class="form-row" style="flex:2;">
                        <label>تفاصيل المركبة (موديل، لون، نوع)</label>
                        <input type="text" name="provider_vehicle_details" value="<?php echo esc_attr(isset($current_data['provider_vehicle_details']) ? $current_data['provider_vehicle_details'] : ''); ?>" placeholder="مثال: تويوتا هايلكس 2023 - بيضاء" required>
                    </p>
                    <p class="form-row" style="flex:1;">
                        <label>السعر بالكيلو (ريال)</label>
                        <input type="number" step="0.01" name="provider_price_kilo" value="<?php echo esc_attr(isset($current_data['provider_price_kilo']) ? $current_data['provider_price_kilo'] : ''); ?>" placeholder="مثال: 5">
                    </p>
                </div>

                <div style="margin-top: 20px;">
                    <button class="button button-primary button-large"><?php echo $edit_mode ? 'حفظ التعديلات' : 'إضافة السائق'; ?></button>
                </div>
            </div>
        </form>

        <hr style="margin: 30px 0;">
        <h2>قائمة السائقين الحاليين</h2>
        <?php display_service_providers_table($providers); ?>
    </div>
    <?php

}

// -----------------------------------------------
// 5️⃣ حفظ البيانات (مع معالجة الصور)
// -----------------------------------------------
add_action('admin_post_save_service_provider', 'save_service_provider_fields');

function save_service_provider_fields() {
if ( ! current_user_can('manage_options') ) return;
if ( ! isset($_POST['_wpnonce']) || ! wp_verify_nonce($\_POST['_wpnonce'], 'save_service_provider_nonce') ) return;

    // معالجة رفع الصورة
    $image_id = '';

    if ( isset($_POST['existing_image_id']) ) {
        $image_id = sanitize_text_field($_POST['existing_image_id']);
    }

    if ( ! empty($_FILES['provider_image']['name']) ) {
        require_once( ABSPATH . 'wp-admin/includes/image.php' );
        require_once( ABSPATH . 'wp-admin/includes/file.php' );
        require_once( ABSPATH . 'wp-admin/includes/media.php' );

        $attachment_id = media_handle_upload('provider_image', 0);

        if ( ! is_wp_error($attachment_id) ) {
            $image_id = $attachment_id;
        }
    }

    $providers = get_option('service_provider_data', []);

    $new_data = [
        'provider_name'            => sanitize_text_field($_POST['provider_name']),
        'provider_phone'           => sanitize_text_field($_POST['provider_phone']),
        'provider_city'            => sanitize_text_field($_POST['provider_city']),
        'provider_role'            => sanitize_text_field($_POST['provider_role']),
        'provider_vehicle_details' => sanitize_text_field($_POST['provider_vehicle_details']),
        'provider_price_kilo'      => sanitize_text_field($_POST['provider_price_kilo']),
        'provider_image_id'        => $image_id,
    ];

    if ( isset($_POST['editing_index']) && $_POST['editing_index'] !== '' ) {
        $index = intval($_POST['editing_index']);
        if ( isset($providers[$index]) ) {
            $providers[$index] = $new_data;
        }
    } else {
        $providers[] = $new_data;
    }

    update_option('service_provider_data', $providers);
    wp_redirect(admin_url('admin.php?page=service_provider'));
    exit;

}

// -----------------------------------------------
// 6️⃣ حذف مقدم الخدمة
// -----------------------------------------------
add_action('admin_post_delete_service_provider', 'delete_service_provider_action');
function delete_service_provider_action() {
if ( ! current_user_can('manage_options') ) return;
if ( ! isset($_GET['_wpnonce']) || ! wp_verify_nonce($\_GET['_wpnonce'], 'delete_provider_nonce') ) wp_die('Invalid Nonce');

    if ( isset($_GET['index']) ) {
        $index = intval($_GET['index']);
        $providers = get_option('service_provider_data', []);
        if ( isset($providers[$index]) ) {
            unset($providers[$index]);
            $providers = array_values($providers);
            update_option('service_provider_data', $providers);
        }
    }
    wp_redirect(admin_url('admin.php?page=service_provider'));
    exit;

}

// -----------------------------------------------
// 7️⃣ دالة عرض الجدول في لوحة التحكم
// -----------------------------------------------
function display_service_providers_table($providers) {
    if ( empty($providers) ) {
echo '<div class="notice notice-info inline"><p>لا توجد بيانات.</p></div>';
return;
}
echo '<table class="wp-list-table widefat fixed striped">';
echo '<thead><tr>

<th width="80">الصورة</th>
<th>اسم السائق</th>
<th>نوع العمل</th>
<th>تفاصيل المركبة</th>
<th>السعر/كم</th>
<th>المدينة</th>
<th width="140">الإجراءات</th>
</tr></thead><tbody>';

    foreach ($providers as $index => $provider) {
        $edit_url = admin_url('admin.php?page=service_provider&action=edit&index=' . $index);
        $delete_url = wp_nonce_url(admin_url('admin-post.php?action=delete_service_provider&index=' . $index), 'delete_provider_nonce');

        $img = $provider['provider_image_id'] ? wp_get_attachment_image($provider['provider_image_id'], [50, 50], false, ['style'=>'border-radius:4px;']) : '<span class="dashicons dashicons-format-image" style="font-size:30px; color:#ccc;"></span>';
        $vehicle = isset($provider['provider_vehicle_details']) ? $provider['provider_vehicle_details'] : '-';
        $price = isset($provider['provider_price_kilo']) ? $provider['provider_price_kilo'] . ' ريال' : '-';

        echo '<tr>
                <td>'.$img.'</td>
                <td><strong>'.esc_html($provider['provider_name']).'</strong></td>
                <td>'.esc_html($provider['provider_role']).'</td>
                <td>'.esc_html($vehicle).'</td>
                <td>'.esc_html($price).'</td>
                <td>'.esc_html($provider['provider_city']).'</td>
                <td>
                    <a href="'.$edit_url.'" class="button button-small">✏️ تعديل</a>
                    <a href="'.$delete_url.'" class="button button-small button-link-delete" onclick="return confirm(\'حذف نهائي؟\');" style="color:#a00;">🗑️ حذف</a>
                </td>
              </tr>';
    }
    echo '</tbody></table>';

}

// -----------------------------------------------
// 8️⃣ دالة عرض السلايدر في الموقع (Frontend)
// -----------------------------------------------
function display_service_providers_slider() {
$providers = get_option('service_provider_data', []);
    if ( empty($providers) ) return;

    $current_user_id = get_current_user_id();
    $user_city = get_user_meta( $current_user_id, 'city', true );
    $user_city = trim($user_city);

    echo '<div class="service-provider-wrapper"><div class="service-provider-slider">';

    $found_match = false;
    foreach ( $providers as $provider ) {
        $p_city  = isset($provider['provider_city']) ? trim($provider['provider_city']) : '';
        if ( ! empty($user_city) && $p_city !== $user_city ) continue;

        $found_match = true;
        $p_name  = $provider['provider_name'];
        $p_role  = $provider['provider_role'];
        $p_phone = $provider['provider_phone'];
        $p_vehicle = isset($provider['provider_vehicle_details']) ? $provider['provider_vehicle_details'] : '';
        $p_price = isset($provider['provider_price_kilo']) && $provider['provider_price_kilo'] ? $provider['provider_price_kilo'] . ' ريال/كم' : '';

        // جلب الصورة
        $img_html = '';
        if ( !empty($provider['provider_image_id']) ) {
            $img_html = wp_get_attachment_image($provider['provider_image_id'], 'medium', false, ['class' => 'provider-real-img']);
        } else {
            $img_html = '<div class="provider-placeholder"><span class="dashicons dashicons-car"></span></div>';
        }

        ?>
        <div class="provider-card">
            <div class="provider-img-container">
                <?php echo $img_html; ?>
                <span class="p-role badge"><?php echo esc_html($p_role); ?></span>
            </div>

            <div class="provider-info">
                <h3 class="p-name"><?php echo esc_html($p_name); ?></h3>

                <?php if($p_vehicle): ?>
                <div class="p-detail">
                    <span class="dashicons dashicons-car"></span> <?php echo esc_html($p_vehicle); ?>
                </div>
                <?php endif; ?>

                <?php if($p_price): ?>
                <div class="p-detail">
                    <span class="dashicons dashicons-money-alt"></span> <?php echo esc_html($p_price); ?>
                </div>
                <?php endif; ?>

                <div class="p-detail city">
                    <span class="dashicons dashicons-location"></span> <?php echo esc_html($p_city); ?>
                </div>
            </div>

            <div class="provider-actions">
                <a href="tel:<?php echo esc_attr($p_phone); ?>" class="action-btn call-btn">
                    <span class="dashicons dashicons-phone"></span> اتصال
                </a>
                <a href="https://wa.me/<?php echo esc_attr($p_phone); ?>" target="_blank" class="action-btn whatsapp-btn">
                    <span class="dashicons dashicons-whatsapp"></span> واتساب
                </a>
            </div>
        </div>
        <?php
    }

    if ( ! $found_match && ! empty($user_city) ) {
        echo '<div class="no-providers-msg">عذراً، لا يوجد سائقين متاحين في ' . esc_html($user_city) . ' حالياً.</div>';
    }
    echo '</div></div>';

}

// تشغيل السلايدر في صفحة المنتج
add_action( 'woocommerce_after_single_product_summary', function() {
if ( ! is_user_logged_in() ) return;
$user_city = get_user_meta( get_current_user_id(), 'city', true );
    if ( empty($user_city) ) return;

    echo '<div class="product-service-providers" style="margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">';
    echo '<h3>📍 سائقين ومعاينين متاحين في منطقتك (' . esc_html($user_city) . ')</h3>';
    display_service_providers_slider();
    echo '</div>';

}, 15 );

// -----------------------------------------------
// 9️⃣ CSS (لوحة التحكم + واجهة الموقع)
// -----------------------------------------------
add_action('admin_head', function () {
?>

<style>
.wrap { padding: 20px; }
.form-row { margin-bottom: 15px; }
.form-row label { display: block; font-weight: bold; margin-bottom: 5px; }
.form-row input[type=text], .form-row input[type=number], .form-row select {
width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px;
}
.wp-list-table th, .wp-list-table td { text-align: center; vertical-align: middle; }
.wp-list-table th { background-color: #f1f1f1; font-weight: bold; }
</style>
<?php
});

add_action('wp_head', function () {
?>
<style>
.service-provider-wrapper { position: relative; padding: 20px 0; overflow: hidden; }
.service-provider-slider { display: flex; gap: 20px; overflow-x: auto; padding: 10px 5px 30px 5px; scrollbar-width: thin; }

    .provider-card {
        flex: 0 0 auto; width: 260px; background: #fff;
        border-radius: 12px; overflow: hidden;
        box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        border: 1px solid #f0f0f0; transition: transform 0.3s;
    }
    .provider-card:hover { transform: translateY(-5px); box-shadow: 0 10px 25px rgba(0,0,0,0.12); }

    /* حاوية الصورة */
    .provider-img-container {
        width: 100%; height: 160px; background: #f9f9f9;
        position: relative; overflow: hidden;
        display: flex; align-items: center; justify-content: center;
    }
    .provider-real-img { width: 100%; height: 100%; object-fit: cover; }
    .provider-placeholder { font-size: 50px; color: #ddd; }

    /* البادج (الوظيفة) */
    .p-role.badge {
        position: absolute; top: 10px; right: 10px;
        background: rgba(0,0,0,0.7); color: #fff;
        padding: 4px 12px; border-radius: 20px; font-size: 11px;
    }

    .provider-info { padding: 15px; text-align: right; }
    .p-name { margin: 0 0 10px; font-size: 16px; font-weight: bold; color: #333; }

    .p-detail { font-size: 13px; color: #666; margin-bottom: 6px; display: flex; align-items: center; gap: 6px; }
    .p-detail .dashicons { font-size: 16px; width: 16px; height: 16px; color: #0073aa; }

    .provider-actions { padding: 15px; border-top: 1px solid #eee; display: flex; gap: 10px; }
    .action-btn {
        flex: 1; padding: 8px; border-radius: 6px; text-decoration: none;
        font-size: 12px; font-weight: bold; display: flex; align-items: center; justify-content: center; gap: 4px; color: #fff !important;
    }
    .call-btn { background: #3498db; }
    .whatsapp-btn { background: #25D366; }
    </style>

    <?php

});

// -----------------------------------------------
// 🔟 إظهار بيانات العنوان والخريطة في صفحة "تعديل العضو" (Admin Profile)
// -----------------------------------------------

add_action( 'show_user_profile', 'show_custom_user_profile_fields' );
add_action( 'edit_user_profile', 'show_custom_user_profile_fields' );

function show_custom_user_profile_fields( $user ) {
?>

<h3>📍 بيانات الموقع والعنوان (مخصص)</h3>
<table class="form-table">
<tr>
<th><label for="city">المدينة</label></th>
<td>
<input type="text" name="city" id="city" value="<?php echo esc_attr( get_user_meta( $user->ID, 'city', true ) ); ?>" class="regular-text" />
</td>
</tr>
<tr>
<th><label for="area">المنطقة</label></th>
<td>
<input type="text" name="area" id="area" value="<?php echo esc_attr( get_user_meta( $user->ID, 'area', true ) ); ?>" class="regular-text" />
</td>
</tr>
<tr>
<th><label for="location">إحداثيات الموقع (Location)</label></th>
<td>
<input type="text" name="location" id="location" value="<?php echo esc_attr( get_user_meta( $user->ID, 'location', true ) ); ?>" class="regular-text" />
<p class="description">الإحداثيات بصيغة: خط العرض، خط الطول (مثال: 24.713,46.675)</p>

                <?php
                $loc = get_user_meta( $user->ID, 'location', true );
                if( !empty($loc) ) {
                    // تم إصلاح الخطأ البرمجي هنا
                    echo '<br><a href="https://www.google.com/maps/search/?api=1&query=' . esc_attr($loc) . '" target="_blank" class="button">🗺️ فتح الموقع على Google Maps</a>';
                }
                ?>
            </td>
        </tr>
    </table>
    <?php

}

// حفظ التعديلات من لوحة التحكم
add_action( 'personal_options_update', 'save_custom_user_profile_fields' );
add_action( 'edit_user_profile_update', 'save_custom_user_profile_fields' );

function save_custom_user_profile_fields( $user_id ) {
if ( !current_user_can( 'edit_user', $user_id ) ) {
return false;
}

    if( isset($_POST['city']) ) update_user_meta( $user_id, 'city', sanitize_text_field( $_POST['city'] ) );
    if( isset($_POST['area']) ) update_user_meta( $user_id, 'area', sanitize_text_field( $_POST['area'] ) );
    if( isset($_POST['location']) ) update_user_meta( $user_id, 'location', sanitize_text_field( $_POST['location'] ) );

}

///////////
