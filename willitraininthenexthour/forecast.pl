#!/usr/bin/perl

use warnings;
use strict;

use Data::Dumper;
use IO::Socket::SSL;
use JSON;
use Mojo::UserAgent;
use Scalar::Util qw(looks_like_number);

my $local_file = "./api-responses/test1.json";

# Quick config
my $use_cache = 0; # use a cached API response to for debugging
my $debug     = 0; # show debug messages
my $api_key   = "your API key here";
$\ = "\n";

print "Content-type: text/html\n\n";

# Get latitude and longitude
my %query = parse_query_string();
if ( !looks_like_number($query{lat}) || !looks_like_number($query{lon}) ) {
    print to_json( { "error" => "invalid latitude/longitude" });
    die "Invalid location ($query{lat}/$query{lon})";
}
my $location = "$query{lat},$query{lon}";

# Get some weather data
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
}

# check that the response contains hyperlocal weather data
if (!defined $weather->{minutely}->{data}) {
    print to_json( { "error" => "unable to get hyperlocal forecast - perhaps your area is not yet supported?" } );
    die "Can't get hyperlocal forecast data from response";
}

my $is_rain = 0;
foreach my $minute (@{$weather->{minutely}->{data}}) {
    print "<br>data: " . $minute->{time} . " at " . $minute->{precipIntensity} if $debug;
    if ($minute->{precipIntensity} > 0 && !$is_rain) {
        print "<br>Yes. It will rain at " . scalar localtime($minute->{time}) . "<br>" if $debug;
        $is_rain = 1;
    }
}

if ( !$is_rain ) {
    print "<br>No rain expected - time to go outside<br>" if $debug;
}

print to_json( { "rain" => "$is_rain" } );


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
