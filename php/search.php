<?php

error_reporting(E_ALL);
ini_set("display_errors", 1);

/*********************** LICENSE **********************

' Name: OpenRokn
' Homepage: http://openrokn.sourceforge.net
' Description: Open source Roku channel building kit
' Author: kavulix
' 
' Copyright (C) 2013 kavulix
' 
' Licensed under the Apache License, Version 2.0 (the "License");
' you may not use this file except in compliance with the License.
' You may obtain a copy of the License at
'
' http://www.apache.org/licenses/LICENSE-2.0
'
' Unless required by applicable law or agreed to in writing, software
' distributed under the License is distributed on an "AS IS" BASIS,
' WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
' See the License for the specific language governing permissions and
' limitations under the License.

************************* USAGE ***********************

URL Parameters:

style = STRING
title = STRING
mtitle = STRING
mshortdesc = STRING
msdposter = STRING
mhdposter = STRING
sort = STRING
ztoa = BOOLEAN
strict = BOOLEAN
case = BOOLEAN
split = BOOLEAN
more = BOOLEAN
limit = INTEGER
start = INTEGER
files[] = ARRAY
types[] = ARRAY
attrs[] = ARRAY
nodes[] = ARRAY

Examples:

<item type="search"
      title="Search videos for actor"
      url="http://yoursite.com/search.php?types[]=video&attrs[]=actor1&attrs[]=actor2&attrs[]=actor3"/>

<item type="search"
      title="Search documents for author"
      url="http://yoursite.com/search.php?types[]=document&attrs[]=author"/>

**************** CUSTOMIZABLE SETTINGS ***************/

// You can modify any of the variables below but DO NOT delete any of them.

$_ROKU_DEV_ID = ""; // optional but provides better security (use genkey to get your 40 character id)
$_ENABLE_ROKU_ONLY = false; // allow access only to Roku devices - prevents someone from accessing the script from a browser
$_ENABLE_CACHING = false; // this will reduce the bandwidth required by your server
$_CACHE_EXPIRES = 1; // number of days before the cached search expires

// These are the default settings. The variables below will be replaced by the
// corresponding url parameters if available.

$_POSTER_STYLE = "flat-episodic-16x9"; // the style of the poster item containing the results - this will also be used for the more results poster item
$_POSTER_TITLE = "Results"; // the title of the poster item containing the results
$_MORE_RESULTS_TITLE = "More Results"; // the title of the poster item for more results
$_MORE_RESULTS_SHORTDESC = "Display the next set of results"; // the shortdesc of the poster item for more results
// change the urls below to the location of the images on your own server
$_MORE_RESULTS_SDPOSTER = "pkg:/images/more.gif"; // image for the more results poster item
$_MORE_RESULTS_HDPOSTER = "pkg:/images/more.gif"; // image for the more results poster item
$_SORT_BY_ATTRIBUTE = "title"; // sort the results by this attribute
$_SORT_ZTOA = false; // if true then sort in reverse order
// partial matches will be included in results by default - "el" will match "hello"
$_STRICT_SEARCH = false; // if true then "el" will NOT match "hello"
$_CASE_SENSITIVE = false; // case-sensitive comparison
$_SPLIT_KEYWORDS_BY_SPACES = false; // convert the keywords string to an array of keywords - a separate search will be performed for each keyword
$_SHOW_MORE_RESULTS = false; // include a poster item at the end of the results to display more results
$_RESULTS_LIMIT = -1; // limit the total number of results (-1 = no limit)
$_START_AT_INDEX = 0; // start the results at the specified index
$_ORML_FILES_TO_SEARCH = array("http://openrokn.sourceforge.net/primary-feed.xml");
$_ITEM_TYPES_TO_SEARCH = array("audio", "video", "slideshow", "document");
$_ATTRIBUTES_TO_SEARCH = array("title", "shortdesc", "actor1", "actor2", "actor3", "director");
$_CHILD_NODES_TO_SEARCH = array("description");

/*********** DO NOT MODIFY THE CODE BELOW ************/

function orderaz($a, $b) {
	return strcmp($a[0], $b[0]);
}

function orderza($a, $b) {
	return strcmp($a[0], $b[0]) * -1;
}

function searchString($needle, $haystack) {
	$kwarray = $needle;
	$ktype = gettype($kwarray);
	if ($ktype == "string") {
		$kwarray = array($needle);
	}

	if (!$GLOBALS['_CASE_SENSITIVE']) {
		$haystack = strtolower($haystack);
	}

	foreach ($kwarray as $kw) {
		if ($GLOBALS['_STRICT_SEARCH']) {
			return (preg_match("/\b$kw\b/", $haystack) === 1);
		} else {
			return (strpos($haystack, $kw) !== false);
		}
	}
	return false;
}

function getMoreResultsUrl($itemsTotal) {
	if (isset($_SERVER['HTTP_HOST'])) {
		$serverip = $_SERVER['HTTP_HOST'];
	} elseif (isset($_SERVER['SERVER_ADDR'])) {
		$serverip = $_SERVER['SERVER_ADDR'];
	} elseif (isset($_SERVER['SERVER_NAME'])) {
		$serverip = $_SERVER['SERVER_NAME'];
	} else {
		return "";
	}

	if (isset($_SERVER['PHP_SELF'])) {
		$scriptpath = $_SERVER['PHP_SELF'];
	} elseif (isset($_SERVER['SCRIPT_NAME'])) {
		$scriptpath = $_SERVER['SCRIPT_NAME'];
	} elseif (isset($_SERVER['REQUEST_URI'])) {
		// strip the query string from the path
		$tmp = parse_url($_SERVER['REQUEST_URI']);
		$scriptpath = $tmp['path'];
	} else {
		return "";
	}

	if ($GLOBALS['_SHOW_MORE_RESULTS'] && $GLOBALS['_RESULTS_LIMIT'] > -1 && $GLOBALS['_START_AT_INDEX'] + $GLOBALS['_RESULTS_LIMIT'] < $itemsTotal) {
		$params = $_REQUEST;
		$params['start'] = $GLOBALS['_START_AT_INDEX'] + $GLOBALS['_RESULTS_LIMIT'];
		$url = "http://" . $serverip . $scriptpath . "?" . http_build_query($params);
		// the url string will contain the numeric index for all parameter arrays
		// so we use preg_replace to remove them before returning the url
		// example: files[0] should be files[]
		$url = preg_replace("/\%5B\d+\%5D\=/", "%5B%5D=", $url);
		return $url;
	}
	return "";
}

function validateProp($obj, $prop, $default) {
	if (!isset($obj[$prop]) || empty($obj[$prop])) return $default;
	$dtype = gettype($default);
	$ptype = gettype($obj[$prop]);
	if ($dtype == $ptype) return $obj[$prop];
	if ($ptype != "string") return $default;
	// the default and parameter types don't match but
	// the parameter is a string so we'll try to convert
	// its type before returning the default value
	if ($dtype == "boolean") {
		if ($obj[$prop] === "true" || $obj[$prop] === "1") return true;
		if ($obj[$prop] === "false" || $obj[$prop] === "0") return false;
	} elseif ($dtype == "integer") {
		// intval will return 0 on error. since 0 is a valid
		// value for the START_AT_INDEX variable we have to test
		// for 0 as a string prior to converting to an integer.
		if ($obj[$prop] === "0") return 0;
		$pint = intval($obj[$prop]);
		if ($pint !== 0) return $pint;
	} elseif ($dtype == "array") {
		return array($obj[$prop]);
	}
	return $default;
}

if ($_ENABLE_ROKU_ONLY) {
	$ua = validateProp($_SERVER, "HTTP_USER_AGENT", "");
	$devid = validateProp($_SERVER, "HTTP_X_ROKU_RESERVED_DEV_ID", "");
	if (strpos($ua, "Roku/DVP") === false || strlen($devid) != 40 || (strlen($_ROKU_DEV_ID) == 40 && $_ROKU_DEV_ID != $devid)) {
		echo "You do not have permission to access this script.";
		exit;
	}
}

if ($_ENABLE_CACHING) {
	$ruri = validateProp($_SERVER, "REQUEST_URI", "");
	if (!empty($ruri)) {
		$rurihash = sha1($ruri);
		$cachepath = "rocache/$rurihash.xml";
		if (file_exists($cachepath)) {
			$lmsec = date("U", filemtime($cachepath));
			$nowsec = date("U");
			if ($nowsec - $lmsec < $_CACHE_EXPIRES * 86400) {
				header("Content-type: application/xml");
				readfile($cachepath);
				exit;
			}
		}
	}
}

$keywords = validateProp($_REQUEST, "keywords", "");
if (empty($keywords)) {
	echo "You must specify at least one search term.";
	exit;
}

// validate all url parameters
$_POSTER_STYLE = validateProp($_REQUEST, "style", $_POSTER_STYLE);
$_POSTER_TITLE = validateProp($_REQUEST, "title", $_POSTER_TITLE);
$_MORE_RESULTS_TITLE = validateProp($_REQUEST, "mtitle", $_MORE_RESULTS_TITLE);
$_MORE_RESULTS_SHORTDESC = validateProp($_REQUEST, "mshortdesc", $_MORE_RESULTS_SHORTDESC);
$_MORE_RESULTS_SDPOSTER = validateProp($_REQUEST, "msdposter", $_MORE_RESULTS_SDPOSTER);
$_MORE_RESULTS_HDPOSTER = validateProp($_REQUEST, "mhdposter", $_MORE_RESULTS_HDPOSTER);
$_SORT_BY_ATTRIBUTE = validateProp($_REQUEST, "sort", $_SORT_BY_ATTRIBUTE);
$_SORT_ZTOA = validateProp($_REQUEST, "ztoa", $_SORT_ZTOA);
$_STRICT_SEARCH = validateProp($_REQUEST, "strict", $_STRICT_SEARCH);
$_CASE_SENSITIVE = validateProp($_REQUEST, "case", $_CASE_SENSITIVE);
$_SPLIT_KEYWORDS_BY_SPACES = validateProp($_REQUEST, "split", $_SPLIT_KEYWORDS_BY_SPACES);
$_SHOW_MORE_RESULTS = validateProp($_REQUEST, "more", $_SHOW_MORE_RESULTS);
$_RESULTS_LIMIT = validateProp($_REQUEST, "limit", $_RESULTS_LIMIT);
$_START_AT_INDEX = validateProp($_REQUEST, "start", $_START_AT_INDEX);
$_ORML_FILES_TO_SEARCH = validateProp($_REQUEST, "files", $_ORML_FILES_TO_SEARCH);
$_ITEM_TYPES_TO_SEARCH = validateProp($_REQUEST, "types", $_ITEM_TYPES_TO_SEARCH);
$_ATTRIBUTES_TO_SEARCH = validateProp($_REQUEST, "attrs", $_ATTRIBUTES_TO_SEARCH);
$_CHILD_NODES_TO_SEARCH = validateProp($_REQUEST, "nodes", $_CHILD_NODES_TO_SEARCH);

// remove whitespace at beginning and end of string
$keywords = trim($keywords);

// convert to lower case if this is not a case-sensitive search
if (!$_CASE_SENSITIVE) {
	$keywords = strtolower($keywords);
}

// convert keywords to an array of strings
if ($_SPLIT_KEYWORDS_BY_SPACES && strpos($keywords, " ") !== false) {
	$kwarray = explode(" ", $keywords);
} else {
	$kwarray = array($keywords);
}

// store item elements in an array so they can be sorted later
$itemsArray = array();

$results = new DOMDocument("1.0", "UTF-8");
$results->formatOutput = true;
$orml = $results->createElement("orml");
$orml->setAttribute("version", "1.2");
$orml->setAttribute("xmlns", "http://sourceforge.net/p/openrokn/home/ORML");
$results->appendChild($orml);
$channel = $results->createElement("channel");
$orml->appendChild($channel);
$poster = $results->createElement("item");
$poster->setAttribute("type", "poster");
$poster->setAttribute("style", $_POSTER_STYLE);
$poster->setAttribute("title", $_POSTER_TITLE);
$channel->appendChild($poster);

foreach ($_ORML_FILES_TO_SEARCH as $url) {
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, $url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
	curl_setopt($ch, CURLOPT_USERAGENT, "OpenRokn/0.3.1");
	curl_setopt($ch, CURLOPT_REFERER, "http://openrokn.sourceforge.net");
	$doc = curl_exec($ch);
	$curlCode = curl_errno($ch);
	$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	$mimeType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
	curl_close($ch);

	if (!is_int($httpCode) || $httpCode != 200 || $curlCode != 0 || $mimeType != "application/xml" || empty($doc)) {
		continue;
	}

	libxml_use_internal_errors(true);
	$xml = new DOMDocument();
	$xml->preserveWhiteSpace = false;
	$xml->loadXML($doc);
	$items = $xml->getElementsByTagName("item");
	$rows = $xml->getElementsByTagName("row");
	if (count($items) < 1 && count($rows) < 1) continue;

	foreach ($items as $item) {
		$itype = $item->getAttribute("type");
		if ($itype == "poster" && $item->hasAttribute("feedurl") && !$item->hasAttribute("usetemplate")) {
			$furl = $item->getAttribute("feedurl");
			if (!empty($furl)) array_push($_ORML_FILES_TO_SEARCH, $furl);
			continue;
		}

		if (array_search($itype, $_ITEM_TYPES_TO_SEARCH, true) === false) continue;

		$kwFound = false;
		foreach ($_ATTRIBUTES_TO_SEARCH as $attr) {
			if (!$item->hasAttribute($attr)) continue;
			$val = $item->getAttribute($attr);
			if (empty($val)) continue;

			$kwFound = searchString($kwarray, $val);
			if ($kwFound) {
				$sortByVal = "";
				if ($item->hasAttribute($_SORT_BY_ATTRIBUTE)) {
					$sortByVal = $item->getAttribute($_SORT_BY_ATTRIBUTE);
				}
				$itemsArray[] = array(strtolower($sortByVal), $item);
				// there's no point in searching the other attributes if a
				// match has already been found for this item. doing so would
				// create duplicates.
				break;
			}
		}
		// there's no point in searching the child node values if a
		// match has already been found for this item. doing so would
		// create duplicates.
		if ($kwFound) continue;

		foreach ($_CHILD_NODES_TO_SEARCH as $node) {
			if (!$item->hasChildNodes()) continue;
			$val = "";
			$cnodes = $item->childNodes;
			foreach ($cnodes as $cnode) {
				if ($cnode->nodeName == $node) {
					$val = $cnode->nodeValue;
					break;
				}
			}
			if (empty($val)) continue;

			$kwFound = searchString($kwarray, $val);
			if ($kwFound) {
				$sortByVal = "";
				if ($item->hasAttribute($_SORT_BY_ATTRIBUTE)) {
					$sortByVal = $item->getAttribute($_SORT_BY_ATTRIBUTE);
				}
				$itemsArray[] = array(strtolower($sortByVal), $item);
				// there's no point in searching the other child nodes if a
				// match has already been found for this item. doing so would
				// create duplicates.
				break;
			}
		}
	}

	foreach ($rows as $row) {
		if ($row->hasAttribute("feedurl") && !$row->hasAttribute("usetemplate")) {
			$furl = $row->getAttribute("feedurl");
			if (!empty($furl)) array_push($furl, $_ORML_FILES_TO_SEARCH);
			continue;
		}
	}
}

// sort items
if ($_SORT_ZTOA) {
	usort($itemsArray, "orderza");
} else {
	usort($itemsArray, "orderaz");
}

// get total number of search results / item elements
$itemsTotal = count($itemsArray);

// generate the item elements
$limit = ($_RESULTS_LIMIT < 0 || $_START_AT_INDEX + $_RESULTS_LIMIT > $itemsTotal) ? $itemsTotal : $_START_AT_INDEX + $_RESULTS_LIMIT;
for ($i = $_START_AT_INDEX; $i < $limit; $i++) {
	// $itemsArray[$i][0] = the attribute to sort by
	// $itemsArray[$i][1] = the item element
	$poster->appendChild($results->importNode($itemsArray[$i][1], true));
}

// add poster item for more results
if ($_SHOW_MORE_RESULTS && $i < $itemsTotal) {
	$moreurl = getMoreResultsUrl($itemsTotal);
	if (!empty($moreurl)) {
		$moreResults = $results->createElement("item");
		$moreResults->setAttribute("type", "poster");
		$moreResults->setAttribute("style", $_POSTER_STYLE);
		$moreResults->setAttribute("title", $_MORE_RESULTS_TITLE);
		$moreResults->setAttribute("shortdesc", $_MORE_RESULTS_SHORTDESC);
		$moreResults->setAttribute("sdposterurl", $_MORE_RESULTS_SDPOSTER);
		$moreResults->setAttribute("hdposterurl", $_MORE_RESULTS_HDPOSTER);
		$moreResults->setAttribute("feedurl", $moreurl);
		$poster->appendChild($moreResults);
	}
}

if ($_ENABLE_CACHING && !empty($cachepath)) {
	if (!file_exists("rocache")) {
		mkdir("rocache", 0744);
	} elseif (!is_dir("rocache")) {
		unlink("rocache");
		mkdir("rocache", 0744);
	} elseif (!is_readable("rocache") || !is_writable("rocache")) {
		chmod("rocache", 0744);
	}
	file_put_contents($cachepath, $results->saveXML());
}

header("Content-type: application/xml");
echo $results->saveXML();

?>
