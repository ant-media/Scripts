<?php

require 'vendor/autoload.php';

use Aws\ElasticBeanstalk\ElasticBeanstalkClient;

function getRegion()
{
    $tokenRequest = curl_init();
    curl_setopt($tokenRequest, CURLOPT_URL, "http://169.254.169.254/latest/api/token");
    curl_setopt($tokenRequest, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($tokenRequest, CURLOPT_CUSTOMREQUEST, "PUT");
    curl_setopt($tokenRequest, CURLOPT_HTTPHEADER, array("X-aws-ec2-metadata-token-ttl-seconds: 3600"));

    $token = curl_exec($tokenRequest);
    curl_close($tokenRequest);

    $regionRequest = curl_init();
    curl_setopt($regionRequest, CURLOPT_URL, "http://169.254.169.254/latest/meta-data/placement/region");
    curl_setopt($regionRequest, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($regionRequest, CURLOPT_HTTPHEADER, array("X-aws-ec2-metadata-token: $token"));

    $region = curl_exec($regionRequest);
    curl_close($regionRequest);

    return trim($region); 
}

function updateHtmlContentForEnvironments($region)
{
    $elasticBeanstalkClient = new ElasticBeanstalkClient([
        'version' => 'latest',
        'region' => $region,
    ]);

    $environmentsResult = $elasticBeanstalkClient->describeEnvironments([]);

    foreach ($environmentsResult['Environments'] as $environment) {
        $envName = $environment['EnvironmentName'];
        $endpointUrl = $environment['EndpointURL'];

        $htmlFilePath = 'samples/publish_webrtc.html';
        $htmlContent = file_get_contents($htmlFilePath);

        $htmlContent = str_replace('aws-elb-web-socket-url', $endpointUrl, $htmlContent);

        file_put_contents($htmlFilePath, $htmlContent);
    }
}

function checkAndCreate($status_url, $create_url) {
    $curl = curl_init();
    curl_setopt($curl, CURLOPT_URL, $status_url);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($curl, CURLOPT_HEADER, false);
    $status_data = curl_exec($curl);

    $status_data_array = json_decode($status_data, true);

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

$status_url = getenv('STATUS_URL');
$create_url = getenv('CREATE_URL');

$region = getRegion();

updateHtmlContentForEnvironments($region);
checkAndCreate($status_url, $create_url);

?>
