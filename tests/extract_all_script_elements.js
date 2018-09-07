/**
 * Created by M.MUeller-Spaeth on 07.12.15.
 * Copyright 2015 by M.Mueller-Spath, fms1961@gmail.com
 * see: https://gist.github.com/mamuesp/e08a4f9b484ab8a84748
 *
 * simplified + adopted to newer cheerio by bbittorf
 * see: https://github.com/cheeriojs/cheerio/issues/1050
 * 
 * usage: nodejs extract.js <html_file> <output_path>
 * 
 */

var fs = require('fs');
var cheerio = require('cheerio');

var inputFile = process.argv[2];
var outputPath= (process.argv[3] + "/").replace("//", "/");

function extractScripts(data) {
	var $ = cheerio.load(data);

	$('script').each(function(i, element){
		if ($(element).attr('src') === undefined) {
			console.log("[OK] direct content");
			var content = $(element).html();
		} else {
			console.log("[OK] src-element found, ignoring");
		};

		var fileName = outputPath + 'js_snippet-' + i + ".html";

		fs.writeFile(fileName, content, function (err) {
			if (err) {
				return console.log(err);
			}
			console.log("[OK] stored: " + fileName);
		});
	});
}

fs.readFile(inputFile, function (err, data) {
	if (err) throw err;
	extractScripts(data);
});
