<?php

if ($_SERVER['REQUEST_METHOD'] == 'POST')
{
	$postdata = file_get_contents("php://input");
	$file = "/tmp/crash-".date("U").".txt";

	$fp = fopen($file,"w+");
	fwrite($fp, $postdata);
	fclose($fp);
	print "OK";
}
else
{
	if(isset($_GET["id"]))
	{
		$id = strval($_GET["id"]);
		echo "<html><header><title>crash_".$id."</title></header><body><pre>";
		include("/tmp/crash-".$id.".txt");
		echo "</pre></body></html>";
	}
	else
	{
		include("/var/www/crashlog/report.html");
	}
}

?>
