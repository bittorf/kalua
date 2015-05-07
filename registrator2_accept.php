<?php

$node	= strval($_GET["node"]);
$mac	= strval($_GET["mac"]);
$hash	= strval($_GET["hash"]);
$remote = $_SERVER["REMOTE_ADDR"];

$script = "./registrator2_accept.sh 'remote=\"".$remote."\";node=\"".$node."\";mac=\"".$mac."\";hash=\"".$hash."\"'";

print "";	// enforces correct headers via php

system($script);

?>
