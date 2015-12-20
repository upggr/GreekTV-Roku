<?php

$id = $_REQUEST['id'];
$email = $_REQUEST['email'];
if (empty($id) || empty($email)) {
	echo "The email could not be sent.";
	return;
}

// validate email
$email = filter_var($email, FILTER_VALIDATE_EMAIL);
if ($email === false) {
	die("The email could not be sent.");
}

$ua = $_SERVER['HTTP_USER_AGENT'];
$devid = $_SERVER['HTTP_X_ROKU_RESERVED_DEV_ID'];
if (empty($ua) || strpos($ua, "Roku/DVP") === false ||
    empty($devid) || strlen($devid) != 40) {
	echo "The email could not be sent.";
	return;
}

// insert your code here to handle the media id and email address
// $params = print_r($_REQUEST, true);
// echo $params;

// the message that you output should indicate whether the operation
// was successful. it will be displayed to the user in a popup dialog
// window.

// success
echo "The information requested has been emailed to the address you provided.";
// fail
// echo "The email could not be sent at this time. Please try again later.";

?>
