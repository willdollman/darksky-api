#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
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

my ($location, $is_web_request) = get_location();
my $weather = get_weather($location);
my $is_rain = is_rain_next_hour($weather);

print to_json( { "rain" => "$is_rain" } ) if $is_web_request;

# Get latitude and longitude
sub get_location {
    my %query;
    my $is_web_request;

    if (%query = parse_query_string()) {
        $is_web_request = 1;

        if ( !looks_like_number($query{lat}) || !looks_like_number($query{lon}) ) {
            print to_json( { "error" => "invalid latitude/longitude" });
            die "Invalid location ($query{lat}/$query{lon})";
        }
    }
    else {
        (($query{lat}, $query{lon}) = @ARGV) || die "Incorrect arguments";
        $is_web_request = 0;
    }
    my $location = "$query{lat},$query{lon}";

    return ($location, $is_web_request);
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
        print to_json( { "error" => "unable to get hyperlocal forecast - perhaps your area is not yet supported?" } );
        die "Can't get hyperlocal forecast data from response";
    }

    return $weather;
}

# Will it rain in the next hour?
sub is_rain_next_hour {
    my $weather = shift @_;

    my $is_rain = 0;
    foreach my $minute (@{$weather->{minutely}->{data}}) {
        print "<br>data: " . $minute->{time} . " at " . $minute->{precipIntensity} if $debug;
        if ($minute->{precipIntensity} > 0 && !$is_rain) {
            print "<br>Yes. It will rain at " . scalar localtime($minute->{time}) . "<br>" if $debug;
            $is_rain = 1;
        }
    }

    return $is_rain;
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
