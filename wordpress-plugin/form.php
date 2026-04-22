<?php
add_action('rest_api_init', function () {
    register_rest_route('hiraajsahm/v1', '/submit-entry', [
        'methods' => 'POST',
        'callback' => 'handle_dual_form_submission',
        'permission_callback' => '__return_true',
    ]);
});

function handle_dual_form_submission($request)
{
    global $wpdb;
    $params = $request->get_json_params();

    $required = ['phone', 'address', 'livestock_type'];
    foreach ($required as $field) {
        if (empty($params[$field])) {
            return new WP_REST_Response(['success' => false, 'message' => "Missing: $field"], 400);
        }
    }
    $params = array_map('sanitize_text_field', $params);

    // 1. DETERMINE FORM ID & MAPPING
    // ---------------------------------------------------------
    $req_type = $params['request_type'] ?? 'inspection'; // default

    if ($req_type === 'inspection' || $req_type === 'معاينة') {
        // --- SETUP FOR INSPECTION (المعاينة) ---
        $form_id = 3;

        // ⚠️ CHECK FIELD NAMES FOR FORM 3 IN EDITOR!
        $submission_data = [
            'input_text' => $params['livestock_type'],
            'input_text_1' => $params['owner_price'],
            'numeric_field' => $params['price_per_kg'],
            'address_1' => $params['address'],
            'phone' => $params['phone'],
            'hidden_input' => 'Inspection Request'
        ];

    } else {
        // --- SETUP FOR DELIVERY (النقل) ---
        $form_id = 4;

        // ⚠️ CHECK FIELD NAMES FOR FORM 4 IN EDITOR!
        $submission_data = [
            'input_text' => $params['livestock_type'],
            'input_text_1' => $params['owner_price'],
            'numeric_field' => $params['price_per_kg'],
            'address_1' => $params['address'],
            'phone' => $params['phone'],
            'hidden_input' => 'Delivery Request'
        ];
    }
    // ---------------------------------------------------------

    // 2. PREPARE DATABASE DATA
    $table_name = $wpdb->prefix . 'fluentform_submissions';

    // Debug Note
    $debug_note = "Type: $req_type\nID: $form_id\nData:\n" . print_r($submission_data, true);

    $data_to_insert = [
        'form_id' => $form_id,
        'user_id' => get_current_user_id() ?? 0,
        'status' => 'unread',
        'is_favourite' => 0,
        'total_pages'  => 1,
        'response' => json_encode($submission_data, JSON_UNESCAPED_UNICODE),
        'source_url' => 'Mobile App - ' . $req_type,
        'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
        'browser' => 'Mobile App',
        'device' => 'Mobile',
        'created_at' => current_time('mysql'),
        'updated_at' => current_time('mysql'),
    ];

    // 3. INSERT INTO DB
    $result = $wpdb->insert($table_name, $data_to_insert);

    if ($result === false) {
        return new WP_Error('db_insert_failed', 'DB Error', ['status' => 500]);
    }

    $entry_id = $wpdb->insert_id;

    // 4. SAVE DEBUG NOTE
    $wpdb->insert($wpdb->prefix . 'fluentform_entry_details', [
        'form_id' => $form_id,
        'submission_id' => $entry_id,
        'field_name' => 'submission_note',
        'field_value' => $debug_note
    ]);

    // 5. TRIGGER EMAILS
    $form = wpFluent()->table('fluentforms')->find($form_id);
    do_action('fluentform/submission_inserted', $entry_id, $submission_data, $form);

    return new WP_REST_Response([
        'success' => true,
        'entry_id' => $entry_id,
        'form_used' => $form_id,
        'message' => 'Saved successfully.'
    ], 200);
}