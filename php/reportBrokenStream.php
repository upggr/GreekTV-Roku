<?php

$url = $_REQUEST['url'];
if (empty($url)) {
	echo "The report could not be sent.";
	return;
}

$ua = $_SERVER['HTTP_USER_AGENT'];
$devid = $_SERVER['HTTP_X_ROKU_RESERVED_DEV_ID'];
if (empty($ua) || strpos($ua, "Roku/DVP") === false ||
    empty($devid) || strlen($devid) != 40) {
	echo "The report could not be sent.";
	return;
}

// insert your code here to handle the submitted url
// $params = print_r($_REQUEST, true);
// echo $params;

// the message that you output should indicate whether the operation
// was successful. it will be displayed to the user in a popup dialog
// window.

// success
echo "Thank you for your report.";
// fail
// echo "The report could not be submitted. Please try again later.";

?>
