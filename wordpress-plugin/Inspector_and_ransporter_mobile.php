<?php
add_action('rest_api_init', function () {
    // Register the custom route: POST /wp-json/custom/v1/submit-fluent-form
    register_rest_route('custom/v1', '/submit-fluent-form', [
        'methods' => 'POST',
        'callback' => 'handle_custom_fluent_submission',
        'permission_callback' => '__return_true', // Open to public (or add auth logic)
    ]);
});

function handle_custom_fluent_submission($request) {
    $params = $request->get_params();
    
    // 1. Get Form ID
    if (isset($_POST['form_id'])) {
        $form_id = intval($_POST['form_id']);
    } elseif (isset($params['form_id'])) {
        $form_id = intval($params['form_id']);
    } else {
        $form_id = 0;
    }

    if (!$form_id) {
        return new WP_Error('missing_form_id', 'Form ID is required', ['status' => 400]);
    }

    // 2. Prepare Data for Fluent Forms (Map exact keys from screenshots)
    $submissionData = [
        'input_text'    => isset($_POST['input_text']) ? $_POST['input_text'] : '',     // Name
        'input_text_1'  => isset($_POST['input_text_1']) ? $_POST['input_text_1'] : '', // City
        'input_text_2'  => isset($_POST['input_text_2']) ? $_POST['input_text_2'] : '', // Region
        'numeric_field' => isset($_POST['input_text_3']) ? $_POST['numeric_field'] : '', // Plate
        'phone'         => isset($_POST['phone']) ? $_POST['phone'] : '',               // Mobile
        'input_radio'   => isset($_POST['input_radio']) ? $_POST['input_radio'] : '',   // Radio
    ];

    // 3. Handle File Uploads
    $files = $request->get_file_params();

    $handle_upload = function ($file_key) use ($files) {
        if (!isset($files[$file_key])) return null;
        require_once(ABSPATH . 'wp-admin/includes/image.php');
        require_once(ABSPATH . 'wp-admin/includes/file.php');
        require_once(ABSPATH . 'wp-admin/includes/media.php');
        $attachment_id = media_handle_upload($file_key, 0);
        return is_wp_error($attachment_id) ? null : wp_get_attachment_url($attachment_id);
    };

    // --- CRITICAL FIX: Map Flutter Keys to Fluent Form Keys ---
    
    // Map 'vehicle_image' from Flutter -> 'image-upload' in Fluent Forms (Screenshot 1)
    if (isset($files['vehicle_image'])) {
        $url = $handle_upload('vehicle_image');
        if ($url) $submissionData['image-upload'] = $url; 
    }

    // Map 'license_image' from Flutter -> 'image-upload_1' in Fluent Forms (Screenshot 2)
    if (isset($files['license_image'])) {
        $url = $handle_upload('license_image');
        if ($url) $submissionData['image-upload_1'] = $url;
    }

    // 4. Insert into Database
    try {
        $insertData = [
            'form_id'      => $form_id,
            'user_id'      => get_current_user_id() ?: 0,
            'status'       => 'unread',
            'is_favourite' => 0,
            'total_pages'  => 1,
            'response'     => json_encode($submissionData, JSON_UNESCAPED_UNICODE),
            'source_url'   => 'Mobile App',
            'ip'           => $_SERVER['REMOTE_ADDR'] ?? '',
            'browser'      => 'Mobile App',
            'device'       => 'Mobile',
            'created_at'   => current_time('mysql'),
            'updated_at'   => current_time('mysql'),
        ];

        $submissionId = wpFluent()->table('fluentform_submissions')->insert($insertData);
        // FIXED ACTION HOOK:
        $form = wpFluent()->table('fluentforms')->find($form_id);
        do_action('fluentform/submission_inserted', $submissionId, $submissionData, $form);

        return new WP_REST_Response([
            'success' => true,
            'message' => 'Form submitted successfully',
            'submission_id' => $submissionId
        ], 200);

    } catch (Exception $e) {
        return new WP_Error('submission_failed', $e->getMessage(), ['status' => 500]);
    }
}
