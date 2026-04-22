<?php
/**
 * نظام حراج سهم: مقدمي الخدمة مع مطابقة المدن الذكية وفلترة الباقات (الفضية والذهبية فقط)
 * تم التحديث: إضافة قائمة المدن و REST API لتطبيق الجوال.
 */

if (!defined('ABSPATH'))
    exit;

// ============================================================
// 1. Saudi Arabia Cities List (Arabic)
// ============================================================
function hsp_get_sa_cities()
{
    return array(
        'الرياض',
        'جدة',
        'مكة المكرمة',
        'المدينة المنورة',
        'الدمام',
        'الخبر',
        'الظهران',
        'الطائف',
        'تبوك',
        'بريدة',
        'حائل',
        'أبها',
        'خميس مشيط',
        'نجران',
        'جازان',
        'ينبع',
        'الجبيل',
        'الأحساء',
        'القطيف',
        'حفر الباطن',
        'عرعر',
        'سكاكا',
        'الباحة',
        'بيشة',
        'الخرج',
        'عنيزة',
        'الدوادمي',
        'المجمعة',
        'الزلفي',
        'شقراء',
        'الأفلاج',
        'وادي الدواسر',
        'رفحاء',
        'طريف',
        'تربة',
        'الليث',
        'القنفذة',
        'رابغ',
        'المذنب',
        'الرس',
        'البكيرية',
        'رأس تنورة',
        'صفوى',
        'بقيق',
        'النعيرية',
        'القريات',
    );
}

// 1️⃣ تسجيل نوع المنشور (مقدمي الخدمة)
add_action('init', function () {
    register_post_type('service_provider', [
        'labels' => [
            'name' => 'مقدمي الخدمة',
            'singular_name' => 'مقدم خدمة',
            'add_new' => 'إضافة مقدم خدمة جديد',
            'add_new_item' => 'إضافة مقدم خدمة جديد',
            'edit_item' => 'تعديل بيانات مقدم الخدمة',
            'new_item' => 'مقدم خدمة جديد',
            'view_item' => 'عرض مقدم الخدمة',
            'search_items' => 'البحث عن مقدمين',
            'not_found' => 'لا يوجد مقدمي خدمة حالياً',
        ],
        'public' => true,
        'menu_icon' => 'dashicons-car',
        'supports' => ['title', 'thumbnail'],
        'has_archive' => false,
    ]);
});

// 2️⃣ لوحة التحكم (Metabox) لبيانات السائقين
add_action('add_meta_boxes', function () {
    add_meta_box('prov_details', '📋 تفاصيل بيانات مقدم الخدمة', 'render_hiraaj_pro_metabox', 'service_provider', 'normal', 'high');
});

function render_hiraaj_pro_metabox($post)
{
    wp_nonce_field('hsp_save_meta', 'hsp_nonce');

    $role = get_post_meta($post->ID, '_p_role', true);
    $city = get_post_meta($post->ID, '_p_city', true);
    $v_det = get_post_meta($post->ID, '_v_details', true);
    $price = get_post_meta($post->ID, '_p_km', true);
    $phone = get_post_meta($post->ID, '_c_phone', true);

    $cities = hsp_get_sa_cities();
    ?>
    <style>
        .hiraaj-box {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            padding: 10px;
        }

        .hiraaj-field label {
            display: block;
            font-weight: bold;
            margin-bottom: 5px;

            color: #2271b1;
        }

        .hiraaj-field input,
        .hiraaj-field select {
            width: 100%;
            padding: 8px;
            border-radius: 4px;
            border: 1px solid #ccc;
            background: #fff;
        }

        .hiraaj-full {
            grid-column: span 2;
            background: #f0f6fb;
            padding: 15px;
            border-radius: 8px;
            border-right: 4px solid #2271b1;
        }
    </style>
    <div class="hiraaj-box">
        <div class="hiraaj-field hiraaj-full">
            <label>نوع الخدمة:</label>
            <select name="p_role" required>
                <option value="transporter" <?php selected($role, 'transporter'); ?>     <?php if (empty($role))
                            echo 'selected'; ?>>🚛 ناقل (نقل مركبات)</option>
                <option value="inspector" <?php selected($role, 'inspector'); ?>>🔍 معاين (فحص مركبات)</option>
            </select>
        </div>
        <div class="hiraaj-field">
            <label>📍 المدينة:</label>
            <select name="p_city" required>
                <option value="">— اختر المدينة —</option>
                <?php foreach ($cities as $c): ?>
                    <option value="<?php echo esc_attr($c); ?>" <?php selected($city, $c); ?>><?php echo esc_html($c); ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <p class="description">مطلوب تحديد المدينة ليتطابق مع موقع العميل.</p>
        </div>
        <div class="hiraaj-field">
            <label>🚘 تفاصيل المركبة:</label>
            <input type="text" name="v_det" value="<?php echo esc_attr($v_det); ?>" placeholder="سطحة هيدروليك">
        </div>
        <div class="hiraaj-field">
            <label>💰 السعر التقريبي (ريال/كم):</label>
            <input type="number" step="0.1" name="p_km" value="<?php echo esc_attr($price); ?>">
        </div>
        <div class="hiraaj-field">
            <label>📞 رقم التواصل:</label>
            <input type="text" name="c_num" value="<?php echo esc_attr($phone); ?>" placeholder="05xxxxxxxx" dir="ltr">
        </div>
    </div>
    <?php
}

// 3️⃣ حفظ بيانات السائقين
add_action('save_post', function ($post_id) {
    if (get_post_type($post_id) !== 'service_provider')
        return;
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE)
        return;
    if (!isset($_POST['hsp_nonce']) || !wp_verify_nonce($_POST['hsp_nonce'], 'hsp_save_meta'))
        return;

    $fields = ['p_role' => '_p_role', 'p_city' => '_p_city', 'v_det' => '_v_details', 'p_km' => '_p_km', 'c_num' => '_c_phone'];
    foreach ($fields as $key => $meta) {
        if (isset($_POST[$key])) {
            update_post_meta($post_id, $meta, sanitize_text_field($_POST[$key]));
        }
    }
});

// 4️⃣ REST API Endpoint (تطبيق الجوال)
/* DISBLED IN PHASE 3 - MOVED TO get_service_provider_api.php
add_action('rest_api_init', function () {
    // Standardizing to hiraajsahm/v1 to match app config
    register_rest_route('hiraajsahm/v1', '/service-providers', array(
        'methods' => 'GET',
        'callback' => 'hiraaj_rest_get_providers',
        'permission_callback' => '__return_true',
    ));
});
*/

function hiraaj_rest_get_providers($request)
{
    $city = $request->get_param('city');

    $args = array(
        'post_type' => 'service_provider',
        'post_status' => 'publish',
        'posts_per_page' => -1,
    );

    $query = new WP_Query($args);
    $providers = array();

    if ($query->have_posts()) {
        while ($query->have_posts()) {
            $query->the_post();
            $id = get_the_ID();

            $p_city = get_post_meta($id, '_p_city', true);

            // Logic: Improved matching for "User Map" addresses
            $is_match = true;
            if (!empty($city)) {
                $is_match = false;
                $search = trim(mb_strtolower($city));
                $p_city_clean = trim(mb_strtolower($p_city));

                // Match if search string contains provider city (e.g. "Riyadh, KSA" vs "Riyadh")
                // OR if provider city contains search string (e.g. "Riyadh" vs "Riya")
                if (
                    mb_strpos($search, $p_city_clean) !== false ||
                    mb_strpos($p_city_clean, $search) !== false
                ) {
                    $is_match = true;
                }
            }

            if ($is_match) {
                $image_url = '';
                if (has_post_thumbnail($id)) {
                    $image_url = get_the_post_thumbnail_url($id, 'medium');
                }

                $providers[] = array(
                    'id' => $id,
                    'name' => get_the_title(),
                    'phone' => get_post_meta($id, '_c_phone', true),
                    'city' => $p_city,
                    'role' => get_post_meta($id, '_p_role', true) === 'transporter' ? 'نقل' : 'فحص',
                    'vehicle_details' => get_post_meta($id, '_v_details', true),
                    'price_per_kilo' => get_post_meta($id, '_p_km', true),
                    'image_url' => $image_url,
                );
            }
        }
        wp_reset_postdata();
    }

    return rest_ensure_response($providers);
}

// 5️⃣ وظيفة العرض (The Slider Logic)
add_action('woocommerce_after_single_product', function () {
    echo hiraaj_render_service_providers();
}, 15);

function hiraaj_render_service_providers()
{
    if (!is_product())
        return;

    global $product;
    if (!$product)
        return;

    // جلب بيانات الباقة لصاحب المنتج أولاً
    $vendor_id = get_post_field('post_author', $product->get_id());
    $vendor_pack_id = get_user_meta($vendor_id, 'product_package_id', true);

    $silver_id = "29028";
    $gold_id = "29030";

    $is_admin = current_user_can('manage_options');
    $is_allowed_pack = ($vendor_pack_id == $silver_id || $vendor_pack_id == $gold_id);
    $has_access = ($is_allowed_pack || (int) $vendor_id === 1 || $vendor_id === 0);

    // إذا لم يكن المنتج لتاجر (فضي/ذهبي)، لا نعرض شيئاً أبداً
    if (!$has_access && !$is_admin)
        return;

    ob_start();

    // 🛑 الحالة الأولى: إذا كان الزائر غير مسجل دخول (Guest)
    if (!is_user_logged_in()) {
        ?>
        <div class="hiraaj-guest-prompt"
            style="margin: 40px 0; padding: 35px; background: #fff; border: 2px solid #eee; border-radius: 20px; text-align: center; direction: rtl; box-shadow: 0 10px 30px rgba(0,0,0,0.05);">
            <div style="font-size: 45px; margin-bottom: 15px;">👋</div>
            <h3 style="margin: 0 0 10px 0; color: #2c3e50; font-weight: 800;">انضم إلينا لرؤية خدمات النقل والفحص!</h3>
            <p style="color: #7f8c8d; margin-bottom: 25px; font-size: 15px;">سجل دخولك الآن لتظهر لك قائمة السائقين والمعاينين
                المتوفرين في مدينتك لهذا المنتج.</p>
            <div style="display: flex; gap: 15px; justify-content: center;">
                <a href="<?php echo esc_url(wc_get_page_permalink('myaccount')); ?>"
                    style="background: #0073aa; color: #fff !important; padding: 12px 30px; border-radius: 30px; text-decoration: none; font-weight: bold; font-size: 14px;">تسجيل
                    الدخول</a>
                <a href="<?php echo esc_url(wc_get_page_permalink('myaccount')); ?>?action=register"
                    style="background: #f8f9fa; color: #333 !important; padding: 12px 30px; border-radius: 30px; text-decoration: none; font-weight: bold; border: 1px solid #ddd; font-size: 14px;">إنشاء
                    حساب جديد</a>
            </div>
        </div>
        <?php
        return ob_get_clean();
    }

    // للمسجلين: جلب بيانات المدينة
    $user_id = get_current_user_id();
    $user_address = get_user_meta($user_id, 'city', true);
    if (empty($user_address)) {
        $user_address = get_user_meta($user_id, 'billing_city', true);
    }

    // 🌟 صندوق فحص الأدمن
    if ($is_admin) {
        echo '<div style="background:#fff3cd; color:#856404; padding:15px; margin:20px 0; border:1px solid #ffeeba; border-radius:12px; direction:rtl; text-align:right; font-family:tahoma;">';
        echo '<strong>🔍 صندوق فحص الأدمن:</strong><br>';
        echo '📍 عنوانك المكتشف: <b>' . esc_html($user_address ?: 'فارغ ❌') . '</b><br>';
        echo '📦 باقة التاجر: <b>' . esc_html($vendor_pack_id ?: 'فارغ') . '</b>';
        echo '</div>';
    }

    // 🛑 الحالة الثانية: إذا كان العضو مسجل بس مش محدد مدينته
    if (empty($user_address)) {
        ?>
        <div class="hiraaj-location-prompt"
            style="margin: 40px 0; padding: 35px; background: #fff; border: 2px dashed #0073aa; border-radius: 20px; text-align: center; direction: rtl;">
            <div style="font-size: 45px; margin-bottom: 15px;">📍</div>
            <h3 style="margin: 0 0 10px 0; color: #2c3e50; font-weight: 800;">حدد موقعك لرؤية مقدمي الخدمة</h3>
            <p style="color: #7f8c8d; margin-bottom: 25px; font-size: 15px;">يرجى تحديد موقعك على الخريطة في صفحتك الشخصية لنظهر
                لك المعاينين والناقلين في منطقتك.</p>
            <a href="<?php echo esc_url(wc_get_page_permalink('myaccount')); ?>/edit-account/"
                style="display: inline-block; background: #0073aa; color: #fff !important; padding: 14px 35px; border-radius: 35px; text-decoration: none; font-weight: bold; box-shadow: 0 5px 15px rgba(0,115,170,0.3);">
                ⚙️ اذهب لتحديد موقعك الآن
            </a>
        </div>
        <?php
        return ob_get_clean();
    }

    // جلب ومطابقة السائقين
    $all_providers = get_posts([
        'post_type' => 'service_provider',
        'posts_per_page' => -1,
        'post_status' => 'publish'
    ]);

    $matched_providers = [];
    foreach ($all_providers as $provider) {
        $p_city = trim(get_post_meta($provider->ID, '_p_city', true));
        if (!empty($p_city) && mb_strpos($user_address, $p_city) !== false) {
            $matched_providers[] = $provider;
        }
    }

    // 🛑 الحالة الثالثة: المدينة محددة ولكن لا يوجد سائقين فيها
    if (empty($matched_providers)) {
        ?>
        <div class="hiraaj-no-providers"
            style="margin: 40px 0; padding: 25px; background: #f8f9fa; border-radius: 15px; text-align: center; direction: rtl; border: 1px solid #eee; color: #666;">
            🚛 عذراً، لا يوجد مقدمي خدمة (نقل أو فحص) مسجلين في مدينة <b><?php echo esc_html($user_address); ?></b> حالياً.
        </div>
        <?php
        return ob_get_clean();
    }

    // 🛑 الحالة الرابعة: عرض السلايدر
    ?>
    <style>
        .hiraaj-wrapper {
            position: relative;
            margin: 40px 0;
            padding: 20px;
            background: #fdfdfd;
            border-radius: 15px;
            border: 1px solid #eee;
            direction: rtl;
        }

        .hiraaj-title {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            color: #2c3e50;
        }

        .hiraaj-slider {
            display: flex;
            overflow-x: auto;
            gap: 15px;
            padding-bottom: 15px;
            scroll-behavior: smooth;
            -webkit-overflow-scrolling: touch;
            scrollbar-width: none;
        }

        .hiraaj-slider::-webkit-scrollbar {
            display: none;
        }

        .hiraaj-card {
            min-width: 260px;
            background: #fff;
            border-radius: 12px;
            border: 1px solid #eee;
            overflow: hidden;
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.03);
            transition: 0.3s;
        }

        .hiraaj-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.08);
        }

        .card-img {
            height: 130px;
            background-size: cover;
            background-position: center;
        }

        .card-content {
            padding: 15px;
        }

        .badge {
            font-size: 10px;
            padding: 3px 8px;
            border-radius: 5px;
            background: #f8f9fa;
            color: #666;
            border: 1px solid #eee;
        }

        .price-tag {
            color: #27ae60;
            font-weight: bold;
            font-size: 15px;
            margin: 12px 0;
        }

        .btn-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 8px;
        }

        .btn-s-card {
            text-align: center;
            padding: 10px;
            border-radius: 8px;
            text-decoration: none !important;
            font-size: 13px;
            font-weight: bold;
            color: #fff !important;
        }

        .b-call {
            background: #2ecc71;
        }

        .b-wa {
            background: #25D366;
        }

        .filter-nav {
            display: flex;
            gap: 10px;
            margin-bottom: 15px;
        }

        .f-btn {
            cursor: pointer;
            border: 1px solid #ddd;
            background: #fff;
            padding: 6px 15px;
            border-radius: 20px;
            font-size: 13px;
            transition: 0.2s;
        }

        .f-btn.active {
            background: #2271b1;
            color: #fff;
            border-color: #2271b1;
        }
    </style>

    <div class="hiraaj-wrapper">
        <div class="hiraaj-title">🚚 خدمات متاحة في منطقتك
            (<?php echo esc_html(trim(str_replace(['امارة منطقة', 'منطقة'], '', $user_address))); ?>)</div>

        <div class="filter-nav">
            <span class="f-btn active" data-f="all">الكل</span>
            <span class="f-btn" data-f="transporter">ناقل 🚛</span>
            <span class="f-btn" data-f="inspector">معاين 🔍</span>
        </div>

        <div class="hiraaj-slider" id="hProviders">
            <?php foreach ($matched_providers as $p):
                $role = get_post_meta($p->ID, '_p_role', true);
                $price = get_post_meta($p->ID, '_p_km', true);
                $phone = get_post_meta($p->ID, '_c_phone', true);
                $desc = get_post_meta($p->ID, '_v_details', true);
                $img = get_the_post_thumbnail_url($p->ID, 'medium') ?: 'https://via.placeholder.com/300x150?text=Hiraaj+Sahm';
                ?>
                <div class="hiraaj-card" data-role="<?php echo esc_attr($role); ?>">
                    <div class="card-img" style="background-image: url('<?php echo esc_url($img); ?>');"></div>
                    <div class="card-content">
                        <span class="badge"><?php echo ($role == 'transporter') ? 'ناقل 🚛' : 'معاين 🔍'; ?></span>
                        <h4 style="margin: 10px 0 5px; font-size: 16px;"><?php echo esc_html($p->post_title); ?></h4>
                        <p style="font-size: 12px; color: #7f8c8d; margin: 0; height: 18px; overflow: hidden;">
                            <?php echo esc_html($desc); ?>
                        </p>
                        <div class="price-tag">💰 <?php echo esc_html($price); ?> ريال/كم</div>
                        <div class="btn-grid">
                            <a href="tel:<?php echo esc_attr($phone); ?>" class="btn-s-card b-call">اتصال</a>
                            <a href="https://wa.me/966<?php echo ltrim($phone, '0'); ?>" target="_blank"
                                class="btn-s-card b-wa">واتساب</a>
                        </div>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function () {
            const btns = document.querySelectorAll('.f-btn');
            const cards = document.querySelectorAll('.hiraaj-card');

            btns.forEach(btn => {
                btn.addEventListener('click', function () {
                    btns.forEach(b => b.classList.remove('active'));
                    this.classList.add('active');
                    const filter = this.getAttribute('data-f');

                    cards.forEach(card => {
                        if (filter === 'all' || card.getAttribute('data-role') === filter) {
                            card.style.display = 'block';
                        } else {
                            card.style.display = 'none';
                        }
                    });
                });
            });
        });
    </script>
    <?php
    return ob_get_clean();
}

// 6️⃣ أعمدة مخصصة في لوحة التحكم
add_filter('manage_service_provider_posts_columns', function ($columns) {
    array_splice($columns, 2, 0, [
        'p_city' => 'المدينة',
        'p_role' => 'النوع',
        'p_phone' => 'الهاتف'
    ]);
    return $columns;
});

add_action('manage_service_provider_posts_custom_column', function ($column, $post_id) {
    if ($column === 'p_city')
        echo esc_html(get_post_meta($post_id, '_p_city', true));
    if ($column === 'p_role')
        echo get_post_meta($post_id, '_p_role', true) === 'transporter' ? 'ناقل' : 'معاين';
    if ($column === 'p_phone')
        echo esc_html(get_post_meta($post_id, '_c_phone', true));
}, 10, 2);
/**
 * 🚀 FIXED: Subscription Packages for App (PRODUCTION FIX - AGGRESSIVE)
 * Intercepts requests for category 122 and forces the correct packages to return.
 */
add_filter('woocommerce_rest_product_object_query', function ($args, $request) {
    if ($request->get_param('category') == '122') {
        // Force these specific IDs which are known to be the packages
        $args['post__in'] = array(29026, 29028, 29030, 29318);

        // Remove the category restriction so it doesn't fail if category 122 doesn't exist
        if (isset($args['tax_query'])) {
            unset($args['tax_query']);
        }

        // Ensure we only get published products
        $args['post_status'] = 'publish';

        // Disable pagination to get all packages at once
        $args['posts_per_page'] = -1;
    }
    return $args;
}, 999, 2);

/**
 * Ensures that the subscription products are always marked as purchasable and published
 * in the REST response, even if they are missing prices or other properties.
 */
add_filter('woocommerce_rest_prepare_product_object', function ($response, $post, $request) {
    $product_id = $response->get_data()['id'] ?? 0;
    if (in_array($product_id, [29026, 29028, 29030, 29318])) {
        $data = $response->get_data();
        $data['purchasable'] = true;
        $data['status'] = 'publish';
        // If price is missing, set a dummy one so WooCommerce doesn't hide it
        if (empty($data['price'])) {
            $data['price'] = '0';
        }
        $response->set_data($data);
    }
    return $response;
}, 999, 3);
