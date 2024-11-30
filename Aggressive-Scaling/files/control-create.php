<?php

require 'vendor/autoload.php';

use Aws\ElasticBeanstalk\ElasticBeanstalkClient;

// Function to retrieve the AWS region from EC2 instance metadata
function getRegion()
{
    $tokenRequest = curl_init();
    curl_setopt($tokenRequest, CURLOPT_URL, "http://169.254.169.254/latest/api/token");
    curl_setopt($tokenRequest, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($tokenRequest, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_setopt($tokenRequest, CURLOPT_HTTPHEADER, array("X-aws-ec2-metadata-token-ttl-seconds: 3600"));

    $token = curl_exec($tokenRequest);
    curl_close($tokenRequest);

    // Use the token to request the region from the EC2 metadata service
    $regionRequest = curl_init();
    curl_setopt($regionRequest, CURLOPT_URL, "http://169.254.169.254/latest/meta-data/placement/region");
    curl_setopt($regionRequest, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($regionRequest, CURLOPT_HTTPHEADER, array("X-aws-ec2-metadata-token: $token"));

    $region = curl_exec($regionRequest);
    curl_close($regionRequest);

    return trim($region); 
}

// Function to update HTML content with Elastic Beanstalk environment details
function updateHtmlContentForEnvironments($region)
{
    $elasticBeanstalkClient = new ElasticBeanstalkClient([
        'version' => 'latest',
        'region' => $region,
    ]);

    // Describe environments and update HTML content for each environment
    $environmentsResult = $elasticBeanstalkClient->describeEnvironments([]);

    foreach ($environmentsResult['Environments'] as $environment) {
        $envName = $environment['EnvironmentName'];
        $endpointUrl = $environment['EndpointURL'];

        $htmlFilePath = 'samples/publish_webrtc.html';
        $htmlContent = file_get_contents($htmlFilePath);

        // Replace placeholder in HTML content with the environment's endpoint URL
        $htmlContent = str_replace('aws-elb-web-socket-url', $endpointUrl, $htmlContent);
        
        // Save the updated HTML content
        file_put_contents($htmlFilePath, $htmlContent);
    }
}

// Function to check status and create if necessary
function checkAndCreate($status_url, $create_url) {
    $curl = curl_init();
    curl_setopt($curl, CURLOPT_URL, $status_url);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_HEADER, false);
    $status_data = curl_exec($curl);

    $status_data_array = json_decode($status_data, true);
    
    // If the status is 500, initiate the creation process
    if ($status_data_array && isset($status_data_array['statusCode']) && $status_data_array['statusCode'] == 500) {
        $create_curl = curl_init();
        curl_setopt($create_curl, CURLOPT_URL, $create_url);
        curl_setopt($create_curl, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($create_curl, CURLOPT_HEADER, false);
        $create_response = curl_exec($create_curl);
        curl_close($create_curl);

        $create_response_array = json_decode($create_response, true);
        sleep(20);
                
    }

    curl_close($curl);
}

// Get environment variables for status and create URLs from Cloudformation
$status_url = getenv('STATUS_URL');
$create_url = getenv('CREATE_URL');

// Get the AWS region
$region = getRegion();

// Update HTML content for Elastic Beanstalk environments
updateHtmlContentForEnvironments($region);

// Check status and initiate creation if needed
checkAndCreate($status_url, $create_url);

?>
