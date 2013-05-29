#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use DateTime;
use IO::Socket::SSL;
use JSON;
use Mojo::UserAgent;
use Scalar::Util qw(looks_like_number);

my $local_file = "./api-responses/bristol-20130529-1955.json";

# Quick config
my $use_cache = 0; # use a cached API response to for debugging
my $debug     = 0; # show debug messages
my $api_key   = "your api key here";
$\ = "\n";

print "Content-type: text/html\n\n";

my $is_web_request = is_web_request();
my $location = get_location($is_web_request);
my $weather = get_weather($location);
my $is_rain = is_rain_next_hour($weather);

print to_json( { "rain" => "$is_rain" } ) if $is_web_request;
print "Yes, it will rain in the next hour" if $debug && $is_rain;

sub is_web_request {
    return (parse_query_string() ? 1 : 0);
}

# Get latitude and longitude
sub get_location {
    my $is_web_request = shift @_;
    my %query;

    if ($is_web_request) {
        %query = parse_query_string();
        if ( !looks_like_number($query{lat}) || !looks_like_number($query{lon}) ) {
            print to_json( { "error" => "invalid latitude/longitude" });
            die "Invalid location ($query{lat}/$query{lon})";
        }
    }
    else {
        (($query{lat}, $query{lon}) = @ARGV) || die "Incorrect arguments";
    }
    my $location = "$query{lat},$query{lon}";

    return $location;
}

# Get some weather data
sub get_weather {
    my $location = shift @_;

    my $weather;
    if ($use_cache) {
        print "[using local cache]" if $debug;
        open(FILE, $local_file);
        $weather = from_json(<FILE>);
    }
    else {
        print "[fetching from darksky]" if $debug;
        my $ua = Mojo::UserAgent->new;
        $weather = $ua->get('https://api.forecast.io/forecast/' . $api_key . '/' . $location)->res->json;
        print "location is $location\n";
    }

    # check that the response contains hyperlocal weather data
    if (!defined $weather->{minutely}->{data}) {
        print to_json( { "error" => "Unable to get hyperlocal forecast - perhaps your area is not yet supported?" } );
        die "Can't get hyperlocal forecast data from response";
    }

    return $weather;
}

# Will it rain in the next hour?
sub is_rain_next_hour {
    my $weather = shift @_;

    my $is_rain = 0;
    foreach my $minute (@{$weather->{minutely}->{data}}) {
        print "<br>data: " . $minute->{time} . " at " . $minute->{precipIntensity} if $debug == 2;
        if ($minute->{precipIntensity} > 0 && !$is_rain) {
            print "<br>Yes. It will rain at " . scalar localtime($minute->{time}) . "<br>" if $debug;
            $is_rain = 1;
        }
    }

    return $is_rain;
}

sub get_weather_at_hour {
    my $weather = shift @_;
    my $target_hour = shift @_;
    my $target_epoch = hour_to_epoch($target_hour);

    foreach my $hour (@{$weather->{hourly}->{data}}) {
        print "found " . $hour->{time} . ": precip is ". $hour->{precipIntensity} . " (" . $hour->{summary} . ")"
            if $hour->{time} == $target_epoch;
        return ($hour->{precipIntensity}, $hour->{summary})
            if $hour->{time} == $target_epoch;
    }
}

# Convert integer hour to unix epoch timestamp
# eg 17 -> 17:00 today
# will return a timestamp for tomorrow if input hour has already passed
sub hour_to_epoch {
    my $target_hour = shift @_;

    # DateTime handles BST. Phew!
    my $timezone = 'Europe/London';
    my $dt = DateTime->now( time_zone => $timezone );

    # You probably mean for tomorrow
    if ($target_hour < $dt->hour) {
        $dt->add( days => 1 );
    }

    # Set time to the target hour
    $dt->set_hour($target_hour);
    $dt->set_minute(0);
    $dt->set_second(0);

    return $dt->epoch;
}

# feels like there should be a builtin for this...
sub parse_query_string {
    my %in;
    if (length ($ENV{'QUERY_STRING'}) > 0){
        my $buffer = $ENV{'QUERY_STRING'};
        my @pairs = split(/&/, $buffer);
        foreach my $pair (@pairs){
            my ($name, $value) = split(/=/, $pair);
            $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
            $in{$name} = $value; 
        }
    }
    return %in;
}
