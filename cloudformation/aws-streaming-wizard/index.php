<?php
require './vendor/autoload.php'; // Include AWS SDK for PHP

use Aws\S3\S3Client;

// AWS credentials and region
$credentials = new Aws\Credentials\Credentials('', '');
$region = 'eu-west-2';

putenv('AWS_ACCESS_KEY_ID=');
putenv('AWS_SECRET_ACCESS_KEY=');

// Create S3 client
$s3Client = new S3Client([
    'version' => 'latest',
    'region' => $region,
    'credentials' => $credentials
]);

$ip = $_SERVER['REMOTE_ADDR'];
$logfile = "ip_log.txt";
$blockThreshold = 10; 

$ipLogs = file($logfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);

$ipCount = 0;
foreach ($ipLogs as $ipLog) {
    list($loggedIP, $timestamp) = explode("|", $ipLog);
    if ($loggedIP == $ip && (time() - $timestamp) < 60 * 5) {
        $ipCount++;
    }
}

#if ($ipCount >= $blockThreshold) {
#    echo "Too many requests from your IP. Please try again later.";
#    exit;
#}

file_put_contents($logfile, "$ip|" . time() . "\n", FILE_APPEND);


// Handle form submission
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    $viewerCount = $_POST["viewerCount"];
    $publisherCount = $_POST["publisherCount"];

    $C5_XLARGE_EDGE_LIMIT = 150;
    $C5_4XLARGE_EDGE_LIMIT = $C5_XLARGE_EDGE_LIMIT*4;
    $C5_9XLARGE_EDGE_LIMIT = $C5_XLARGE_EDGE_LIMIT*7;

    $C5_XLARGE_ORIGIN_LIMIT = 40;
    $C5_4XLARGE_ORIGIN_LIMIT = $C5_XLARGE_ORIGIN_LIMIT*4;
    $C5_9XLARGE_ORIGIN_LIMIT = $C5_XLARGE_ORIGIN_LIMIT*9;

    if (is_numeric($viewerCount)) {
        if ($viewerCount >= 1 && $viewerCount <= $C5_XLARGE_EDGE_LIMIT*10) {
                $edgeCount =  ceil($viewerCount/$C5_XLARGE_EDGE_LIMIT);   
            $edgeType = "c5.xlarge";
        } 
        elseif ($viewerCount >= $C5_XLARGE_EDGE_LIMIT*10 + 1 && $viewerCount <= $C5_4XLARGE_EDGE_LIMIT * 10) {
                $edgeCount = ceil($viewerCount/$C5_4XLARGE_EDGE_LIMIT);
            $edgeType = "c5.4xlarge";
        } 
        elseif ($viewerCount >= $C5_4XLARGE_EDGE_LIMIT * 10 + 1) {
            $edgeCount = ceil($viewerCount/$C5_9XLARGE_EDGE_LIMIT);
            $edgeType = "c5.9xlarge";
        }

    } else {
        echo "Please enter a numeric value";
    }

    if (is_numeric($publisherCount)) {
        if ($publisherCount >= 1 && $publisherCount <= $C5_XLARGE_ORIGIN_LIMIT*3) {
            $originCount = ceil($publisherCount/$C5_XLARGE_ORIGIN_LIMIT);
            $originType = "c5.xlarge";
        } 
        elseif ($publisherCount >= $C5_XLARGE_ORIGIN_LIMIT*3 + 1 && $publisherCount <= $C5_4XLARGE_ORIGIN_LIMIT*3) {
            $originCount = ceil($publisherCount/$C5_4XLARGE_ORIGIN_LIMIT);
            $originType = "c5.4xlarge";
        } 
        elseif ($publisherCount >= $C5_4XLARGE_ORIGIN_LIMIT*3 + 1) {
            $originCount = ceil($publisherCount/$C5_9XLARGE_ORIGIN_LIMIT);
            $originType = "c5.9xlarge";
        }
    } else {
        echo "Please enter a numeric value";
    }

        // Verify reCAPTCHA v3 response
    $recaptchaSecretKey = ''; // Replace with your reCAPTCHA v3 secret key
    $recaptchaResponse = $_POST['g-recaptcha-response'];

    // Make a POST request to Google reCAPTCHA verification endpoint
    $recaptchaVerificationUrl = 'https://www.google.com/recaptcha/api/siteverify';
    $recaptchaVerificationData = [
        'secret' => $recaptchaSecretKey,
        'response' => $recaptchaResponse
    ];

    $recaptchaVerificationOptions = [
        'http' => [
            'method' => 'POST',
            'header' => 'Content-Type: application/x-www-form-urlencoded',
            'content' => http_build_query($recaptchaVerificationData)
        ]
    ];

    $recaptchaVerificationContext = stream_context_create($recaptchaVerificationOptions);
    $recaptchaVerificationResult = file_get_contents($recaptchaVerificationUrl, false, $recaptchaVerificationContext);

    $recaptchaVerificationData = json_decode($recaptchaVerificationResult);

    if (!$recaptchaVerificationData->success) {
        // reCAPTCHA v3 verification failed
        echo "reCAPTCHA verification failed.";
        exit; // Stop processing further
    }


$errorMessages = array(); // Initialize an array to store error messages

$minValue = 1000; // Minimum value (4-digit number)
$maxValue = 9999; // Maximum value (4-digit number)
$randomNumber = rand($minValue, $maxValue);
$randomDomainName = "ams-cf-".$randomNumber . ".antmedia.cloud";

if ($_SERVER["REQUEST_METHOD"] === "POST") {
    if (isset($_POST["checkbox"])) {
        // Code to run when the checkbox is checked
        $output = [];
        $returnCode = 0;

        // Adjust the actual command based on your requirements and paths
#	sleep(10);
        $command = "certbot certonly --dns-route53 --agree-tos --register-unsafely-without-email -d $randomDomainName --config-dir ./certificates --work-dir ./ --logs-dir ./logs 2>&1 >/dev/null";
#        $command = 'echo "test"';

        // Execute Certbot command and capture output
        exec($command, $output, $returnCode);


    // Output the results (including errors)
        if ($returnCode !== 0) {
            $errorMessage = "Error creating certificates. Please check the error output below:";
            $errorMessages = $output; // Store error messages for display
        } else {
            $successMessage = "Certificates have been successfully created.\n Domain Name: $randomDomainName";
        }

    }
}


if (isset($_POST["checkbox"])) {
    // Specify the path to the existing CloudFormation template file
    $templateFile = './template-custom-cert.yaml'; 
    $certificateFile = "./certificates/live/$randomDomainName/cert.pem"; 
    $privateKeyFile = "./certificates/live/$randomDomainName/privkey.pem"; 
    $chainFile = "./certificates/live/$randomDomainName/chain.pem"; 

    // Read the contents of the existing template file
    $templateContent = file_get_contents($templateFile);

    // Replace the desired values in the template content
    $updatedTemplateContent = str_replace('c5.4xlarge', $edgeType, $templateContent);
    $updatedTemplateContent = str_replace('c5.2xlarge', $originType, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('MinSizeEdge', $edgeCount, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('MinSizeOrigin', $originCount, $updatedTemplateContent);

    $certificateContent = file_get_contents($certificateFile);
    $privateKeyContent = file_get_contents($privateKeyFile);
    $chainContent = file_get_contents($chainFile);

    // Add 8 spaces to the beginning of each line
    $lines = explode("\n", $certificateContent);
    $formattedCertificateContent = '';
    foreach ($lines as $line) {
        $formattedCertificateContent .= str_repeat(' ', 8) . $line . "\n";
    }

    $lines = explode("\n", $privateKeyContent);
    $formattedPrivateKeyContent = '';
    foreach ($lines as $line) {
    $formattedPrivateKeyContent .= str_repeat(' ', 8) . $line . "\n";
    }

    $lines = explode("\n", $chainContent);
        $formattedChainContent = '';
        foreach ($lines as $line) {
                $formattedChainContent .= str_repeat(' ', 8) . $line . "\n";
        }

    $updatedTemplateContent = str_replace('---CertificateBody---', $formattedCertificateContent, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('---PrivateKey---', $formattedPrivateKeyContent, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('---CertificaChain---', $formattedChainContent, $updatedTemplateContent);

// Now you can use or save the updated template content

    }
else {
// Specify the path to the existing CloudFormation template file
    $templateFile = './template.yaml'; // Replace with your existing template file path

    // Read the contents of the existing template file
    $templateContent = file_get_contents($templateFile);

    // Replace the desired values in the template content
    $updatedTemplateContent = str_replace('c5.4xlarge', $edgeType, $templateContent);
    $updatedTemplateContent = str_replace('c5.2xlarge', $originType, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('MinSizeEdge', $edgeCount, $updatedTemplateContent);
    $updatedTemplateContent = str_replace('MinSizeOrigin', $originCount, $updatedTemplateContent);
}

// Generate a unique filename for the modified template
$filename = 'antmedia-aws-autoscale-' . uniqid() . '.yaml';

// Upload the modified template file to S3
$bucketName = ''; // Replace with your S3 bucket name
$s3Client->putObject([
    'Bucket' => $bucketName,
    'Key' => $filename,
    'Body' => $updatedTemplateContent,
]);

$bucketPolicy = [
    'Version' => '2012-10-17',
    'Statement' => [
        [
            'Sid' => 'PublicRead',
            'Effect' => 'Allow',
            'Principal' => '*',
            'Action' => 's3:GetObject',
            'Resource' => "arn:aws:s3:::{$bucketName}/*"
        ]
    ]
];

$s3Client->putBucketPolicy([
    'Bucket' => $bucketName,
    'Policy' => json_encode($bucketPolicy)
]);

$publicUrl = "https://{$bucketName}.s3.amazonaws.com/{$filename}";

// Generate a download link for the modified CloudFormation template file
$downloadLink = $s3Client->getObjectUrl($bucketName, $filename);

// Display a download link to the user
//    echo '<a href="' . $downloadLink . '">Download Modified CloudFormation Template</a>';
//    echo "$publicUrl";
}
?>
