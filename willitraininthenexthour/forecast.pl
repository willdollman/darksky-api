#!/usr/bin/perl

use warnings;
use strict;

use Weather::ForecastIO qw( is_web_request get_location get_weather is_rain_next_hour );
use JSON;

# Quick config
my $api_key   = "your api key here";
my $local_file = "./api-responses/bristol-20130529-1955.json";
$\ = "\n";

print "Content-type: text/html\n\n";

my $is_web_request = is_web_request();
my $location = get_location(\@ARGV, $is_web_request);
my $weather  = get_weather($location, $api_key);
my $is_rain  = is_rain_next_hour($weather);

print to_json( { "rain" => "$is_rain" } );
