<?php
// تفعيل الوصول للمنيو عبر الرابط المخصص
add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/menu', array(
        'methods' => 'GET',
        'callback' => function () {
            // "our-categories" هو اسم المنيو اللي عملته
            $menu_items = wp_get_nav_menu_items('our-categories');
            if (!$menu_items)
                return [];

            $data = [];
            foreach ($menu_items as $item) {
                $data[] = [
                    'id' => $item->ID,
                    'parent' => (int) $item->menu_item_parent,
                    'title' => $item->title,
                    'url' => $item->url,
                ];
            }
            return $data;
        },
        'permission_callback' => '__return_true',
    ));
});




/**
 * Professional Geo Filter Bar [geo_filter_bar]
 * Color Theme: #004282
 */

add_shortcode('geo_filter_bar', 'render_geo_filter_premium');

function render_geo_filter_premium()
{
    $group_key = 'group_69d225ffc3c07';
    $fields = acf_get_fields($group_key);
    if (!$fields)
        return 'الرجاء التأكد من إعدادات ACF';

    ob_start();
    ?>
    <style>
        :root {
            --primary-color: #004282;
            --bg-gray: #f4f7f9;
        }

        .premium-filter-wrapper {
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 10px;
            direction: rtl;
            font-family: inherit;
        }

        .premium-filter-card {
            display: flex;
            align-items: center;
            background: #fff;
            border: 2px solid var(--primary-color);
            border-radius: 50px;
            padding: 5px 10px;
            box-shadow: 0 4px 15px rgba(0, 66, 130, 0.1);
            gap: 5px;
            width: fit-content;
            max-width: 100%;
        }

        .filter-item {
            display: flex;
            align-items: center;
            padding: 0 10px;
            position: relative;
        }

        .filter-item i {
            color: var(--primary-color);
            margin-left: 8px;
            font-size: 18px;
        }

        .premium-filter-card select {
            border: none !important;
            background: transparent !important;
            font-size: 14px;
            font-weight: 600;
            color: #333;
            cursor: pointer;
            padding: 8px 5px;
            min-width: 130px;
            outline: none !important;
            box-shadow: none !important;
        }

        .premium-filter-card .divider {
            width: 1px;
            height: 25px;
            background: #e0e0e0;
            margin: 0 5px;
        }

        .btn-premium-search {
            background: var(--primary-color);
            color: #fff !important;
            border: none;
            border-radius: 50px;
            padding: 10px 25px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .btn-premium-search:hover {
            background: #002d5a;
            transform: scale(1.02);
            box-shadow: 0 4px 10px rgba(0, 0, 0, 0.2);
        }

        /* موبايل ديزاين */
        @media (max-width: 768px) {
            .premium-filter-card {
                flex-direction: column;
                border-radius: 15px;
                width: 100%;
                padding: 15px;
            }

            .premium-filter-card .divider {
                display: none;
            }

            .filter-item {
                width: 100%;
                border-bottom: 1px solid #eee;
                margin-bottom: 10px;
            }

            .premium-filter-card select {
                width: 100%;
            }

            .btn-premium-search {
                width: 100%;
                justify-content: center;
            }
        }
    </style>

    <div class="premium-filter-wrapper">
        <form id="premium-geo-form" method="GET" class="premium-filter-card">

            <div class="filter-item">
                <span class="dashicons dashicons-location-alt" style="color:#004282"></span>
                <select name="city_filter" id="p_city_select">
                    <option value="">كل المدن</option>
                    <?php
                    foreach ($fields as $f) {
                        if ($f['name'] == 'areas') {
                            foreach ($f['choices'] as $val => $label) {
                                $selected = (isset($_GET['city_filter']) && $_GET['city_filter'] == $val) ? 'selected' : '';
                                echo '<option value="' . $val . '" ' . $selected . '>' . $label . '</option>';
                            }
                        }
                    }
                    ?>
                </select>
            </div>

            <div class="divider"></div>

            <div class="filter-item" id="p_sub_area_wrap">
                <span class="dashicons dashicons-admin-site-alt3" style="color:#004282"></span>

                <select name="area_filter" id="p_default_area">
                    <option value="">اختر الحي</option>
                </select>

                <?php
                foreach ($fields as $f) {
                    if ($f['name'] != 'areas') {
                        $c_val = $f['conditional_logic'][0][0]['value'];
                        $is_visible = (isset($_GET['city_filter']) && $_GET['city_filter'] == $c_val);

                        echo '<select name="area_filter" class="p-sub-select" id="p-area-' . $c_val . '" style="display:' . ($is_visible ? 'inline-block' : 'none') . ';">';
                        echo '<option value="">كل الأحياء</option>';
                        foreach ($f['choices'] as $v => $l) {
                            $sel = (isset($_GET['area_filter']) && $_GET['area_filter'] == $v) ? 'selected' : '';
                            echo '<option value="' . $v . '" ' . $sel . '>' . $l . '</option>';
                        }
                        echo '</select>';
                    }
                }
                ?>
            </div>

            <button type="submit" class="btn-premium-search">
                <span class="dashicons dashicons-search"></span>
                تصفية النتائج
            </button>

            <?php if (isset($_GET['city_filter'])): ?>
                <a href="<?php echo strtok($_SERVER["REQUEST_URI"], '?'); ?>" title="إعادة تعيين"
                    style="color: #e74c3c; padding: 0 10px;">
                    <span class="dashicons dashicons-trash"></span>
                </a>
            <?php endif; ?>
        </form>
    </div>

    <script>
        jQuery(document).ready(function ($) {
            $('#p_city_select').on('change', function () {
                var cityVal = $(this).val();
                $('#p_default_area').hide();
                $('.p-sub-select').hide().attr('name', '');

                if (cityVal) {
                    var target = $('#p-area-' + cityVal);
                    if (target.length) {
                        target.show().attr('name', 'area_filter');
                    } else {
                        $('#p_default_area').show().attr('name', 'area_filter');
                    }
                } else {
                    $('#p_default_area').show().attr('name', 'area_filter');
                }
            });
        });
    </script>
    <?php
    return ob_get_clean();
}

// كود الفلترة (Query) - لا تغيير فيه لضمان عمله
add_action('pre_get_posts', 'apply_geo_product_filter');
function apply_geo_product_filter($query)
{
    if (!is_admin() && $query->is_main_query() && (is_shop() || is_product_category())) {
        $meta_query = array('relation' => 'AND');
        if (!empty($_GET['city_filter'])) {
            $meta_query[] = array('key' => 'areas', 'value' => sanitize_text_field($_GET['city_filter']), 'compare' => '=');
        }
        if (!empty($_GET['area_filter'])) {
            $meta_query[] = array('key' => 'area', 'value' => sanitize_text_field($_GET['area_filter']), 'compare' => '=');
        }
        if (count($meta_query) > 1) {
            $query->set('meta_query', $meta_query);
        }
    }
}