#!/usr/bin/perl

use warnings;
use strict;

use 5.10.0;
use Weather::ForecastIO qw( get_location get_weather is_rain_next_hour get_weather_at_hour hour_to_epoch );

use Data::Dumper;

my $api_key = "your api key here";
my $local_file = "./api-responses/bristol-20130529-1955.json";
$\ = "\n";

my @target_hours = qw(7 17);

my $location = get_location(\@ARGV);
my $weather = get_weather($location, $api_key, $local_file);

my $conditions;

foreach my $hour (@target_hours) {
    $conditions->{$hour} = {};
    my $condition = $conditions->{$hour};

    ($condition->{intensity}, $condition->{summary})
        = get_weather_at_hour($weather, $hour);
}

my $hour_conditions = "";
my $is_ok_weather = 1;
foreach my $hour (@target_hours) {
    my $condition = $conditions->{$hour};
    $hour_conditions .= "$hour: " . lc $condition->{summary} . " (" . $condition->{intensity} . "), " ;
    $is_ok_weather = 0 if ($condition->{intensity} > 0.017);
}

if ($is_ok_weather) {
    print "OK conditions";
}
else {
    print "Bad conditions";
}
print $hour_conditions;
#print Dumper $conditions;

