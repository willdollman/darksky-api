#!/usr/bin/perl

use warnings;
use strict;

use lib '/home/will/Dropbox/code/darksky/';

use Weather::ForecastIO qw( is_web_request get_location get_weather is_rain_next_hour );
use JSON;

# Quick config
my $api_key   = "your api key here";
my $local_file = "./api-responses/bristol-20130529-1955.json";
$\ = "\n";

print "Content-type: text/html\n\n";

# this is only being called from the web, so the is_web_request stuff is a bit unecessary

my $is_web_request = is_web_request();
my $location = get_location(\@ARGV, $is_web_request);
my $weather = get_weather($location, $api_key, $local_file);
my $is_rain = is_rain_next_hour($weather);

my $time = 21;
my ($precip, $summary) = get_weather_at_hour($weather, $time);
print "At $time it'll be ", lc $summary, " ($precip)\n";

print to_json( { "rain" => "$is_rain" } ) if $is_web_request;
#print "Yes, it will rain in the next hour" if $debug && $is_rain;
