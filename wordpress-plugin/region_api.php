<?php
/**
 * Hiraaj Sahm: Regions & Cities API (App Compatible)
 * 
 * Provides GET /custom/v1/regions for the Flutter app.
 * Matches the logic of the website's geo_filter_bar while ensuring
 * the JSON structure works with the existing Flutter RegionModel.
 */

if (!defined('ABSPATH')) exit;

add_action('rest_api_init', function () {
    register_rest_route('custom/v1', '/regions', [
        'methods'             => 'GET',
        'callback'            => 'hiraaj_get_regions_app_compatible',
        'permission_callback' => '__return_true',
    ]);
});

function hiraaj_get_regions_app_compatible(WP_REST_Request $request) {
    $result = [];

    // 1. Try to fetch from ACF
    if (function_exists('acf_get_fields')) {
        $group_key = 'group_69d225ffc3c07';
        $fields = acf_get_fields($group_key);

        if (!empty($fields)) {
            $city_field = null;
            $area_fields = [];

            foreach ($fields as $field) {
                if ($field['name'] === 'areas') {
                    $city_field = $field;
                } else {
                    $parent_city = $field['conditional_logic'][0][0]['value'] ?? null;
                    if ($parent_city) {
                        $area_fields[$parent_city] = $field;
                    }
                }
            }

            if ($city_field && !empty($city_field['choices'])) {
                foreach ($city_field['choices'] as $city_value => $city_label) {
                    $cities = [];
                    if (isset($area_fields[$city_value])) {
                        foreach ($area_fields[$city_value]['choices'] as $area_value => $area_label) {
                            $cities[] = (string) $area_label;
                        }
                    }

                    $result[] = [
                        'name'   => (string) $city_value,
                        'label'  => (string) $city_label,
                        'cities' => $cities,
                    ];
                }
            }
        }
    }

    // 2. Fallback: If ACF is missing or returns nothing, use hardcoded Saudi regions
    if (empty($result)) {
        $result = [
            [
                'name' => 'riyadh_region',
                'label' => 'منطقة الرياض',
                'cities' => ['الرياض', 'الخرج', 'المجمعة', 'الدوادمي', 'وادي الدواسر', 'الزلفي', 'شقراء']
            ],
            [
                'name' => 'makkah_region',
                'label' => 'منطقة مكة المكرمة',
                'cities' => ['مكة المكرمة', 'جدة', 'الطائف', 'القنفذة', 'الليث', 'رابغ']
            ],
            [
                'name' => 'madinah_region',
                'label' => 'منطقة المدينة المنورة',
                'cities' => ['المدينة المنورة', 'ينبع', 'العلا', 'بدر', 'خيبر']
            ],
            [
                'name' => 'eastern_region',
                'label' => 'المنطقة الشرقية',
                'cities' => ['الدمام', 'الخبر', 'الظهران', 'الأحساء', 'حفر الباطن', 'الجبيل', 'القطيف', 'الخفجي']
            ],
            [
                'name' => 'qassim_region',
                'label' => 'منطقة القصيم',
                'cities' => ['بريدة', 'عنيزة', 'الرس', 'المذنب', 'البكيرية']
            ],
            [
                'name' => 'asir_region',
                'label' => 'منطقة عسير',
                'cities' => ['أبها', 'خميس مشيط', 'بيشة', 'النماص', 'محايل عسير']
            ],
            [
                'name' => 'tabuk_region',
                'label' => 'منطقة تبوك',
                'cities' => ['تبوك', 'الوجه', 'ضباء', 'تيماء', 'أملج']
            ],
            [
                'name' => 'hail_region',
                'label' => 'منطقة حائل',
                'cities' => ['حائل', 'بقعاء', 'الغزالة']
            ],
            [
                'name' => 'northern_region',
                'label' => 'منطقة الحدود الشمالية',
                'cities' => ['عرعر', 'رفحاء', 'طريف']
            ],
            [
                'name' => 'jazan_region',
                'label' => 'منطقة جازان',
                'cities' => ['جازان', 'صبيا', 'أبو عريش', 'صامطة']
            ],
            [
                'name' => 'najran_region',
                'label' => 'منطقة نجران',
                'cities' => ['نجران', 'شرورة']
            ],
            [
                'name' => 'baha_region',
                'label' => 'منطقة الباحة',
                'cities' => ['الباحة', 'بلجرشي', 'المندق']
            ],
            [
                'name' => 'jouf_region',
                'label' => 'منطقة الجوف',
                'cities' => ['سكاكا', 'القريات', 'دومة الجندل']
            ],
        ];
    }

    // Return the list directly to match RegionsService expectations
    return new WP_REST_Response($result, 200);
}
