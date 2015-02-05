<?php

$node		= strval($_GET["NODE"]);		// 975
$wifimac	= strval($_GET["WIFIMAC"]);		// aabb112233ff
$sshpubkey	= strval($_GET["SSHPUBKEY"]);		//
$sshpubkeyfp	= strval($_GET["SSHPUBKEYFP"]);		//

$script = "./registrator_accept.sh 'NODE=\"".$node."\";WIFIMAC=\"".$wifimac."\";SSHPUBKEYFP=\"".$sshpubkeyfp."\";SSHPUBKEY=\"".$sshpubkey."\"'";

print "";

// system("logger 'ffweimar!'");
system($script);

?>
