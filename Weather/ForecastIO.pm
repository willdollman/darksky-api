#!/usr/bin/perl

package Weather::ForecastIO;

use warnings;
use strict;

use Carp;
use Data::Dumper;
use DateTime;
use Exporter qw( import );
use IO::Socket::SSL;
use JSON;
use Mojo::UserAgent;
use Readonly;
use Scalar::Util qw(looks_like_number);

our @EXPORT_OK = qw( is_web_request get_location get_weather is_rain_next_hour get_weather_at_hour parse_query_string get_hourly_summary );

# Quick config
Readonly my $DEBUG => 0; # show debug messages
$\ = "\n";

# could use an error-printing function which croaks/returns json based on is_web_request

sub is_web_request {
    return ( (defined $ENV{'QUERY_STRING'}) ? 1 : 0);
}

# Get latitude and longitude
sub get_location {
    my $ARGV = shift @_;
    my $is_web_request = shift @_;
    my %query;

    if ($is_web_request) {
        %query = parse_query_string();
        if ( !looks_like_number($query{lat}) || !looks_like_number($query{lon}) ) {
            print to_json( { "error" => "invalid latitude/longitude" });
            croak "Invalid location ($query{lat}/$query{lon})";
        }
    }
    else {
        (($query{lat}, $query{lon}) = @{$ARGV}) || croak "Incorrect arguments (@{$ARGV})";
        if ( !looks_like_number($query{lat}) || !looks_like_number($query{lon}) ) {
            croak "Invalid latitude/longitude\n";
        }
    }
    my $location = "$query{lat},$query{lon}";

    return $location;
}

# Get some weather data
sub get_weather {
    my $location = shift @_ || croak "No location supplied";
    my $api_key  = shift @_ || croak "No API key supplied";
    my $local_file = shift @_;

    croak "Invalid API key" if (length $api_key != 32);

    my $weather;
    if ($local_file) {
        print "[using local cache]" if $DEBUG;
        open(FILE, $local_file);
        $weather = from_json(<FILE>);
    }
    else {
        print "[fetching from darksky]" if $DEBUG;
        my $ua = Mojo::UserAgent->new;
        $weather = $ua->get('https://api.forecast.io/forecast/' . $api_key . '/' . $location)->res->json;
        print "location is $location" if $DEBUG;
    }

    # check that the response contains hyperlocal weather data
    if (!defined $weather->{minutely}->{data}) {
        print to_json( { "error" => "Unable to get hyperlocal forecast - perhaps your area is not yet supported?" } );
        croak "Can't get hyperlocal forecast data from response";
    }

    return $weather;
}

# Will it rain in the next hour?
sub is_rain_next_hour {
    my $weather = shift @_;

    my $is_rain = 0;
    foreach my $minute (@{$weather->{minutely}->{data}}) {
        print "<br>data: " . $minute->{time} . " at " . $minute->{precipIntensity} if $DEBUG == 2;
        if ($minute->{precipIntensity} > 0 && !$is_rain) {
            print "<br>Yes. It will rain at " . scalar localtime($minute->{time}) . "<br>" if $DEBUG;
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
        return ($hour->{precipIntensity}, $hour->{summary})
            if $hour->{time} == $target_epoch;
    }
    carp "Could not find $target_hour in response";
    return (-1, -1);
}

# return hourly summary (scope is next 24 hours)
sub get_hourly_summary {
    my $weather = shift @_;

    return $weather->{hourly}->{summary};
}

# Convert integer hour to unix epoch timestamp
# eg 17 -> 17:00 today
# will return a timestamp for tomorrow if input hour has already passed
sub hour_to_epoch {
    my $target_hour = shift @_;
    croak "$target_hour is not between 0 and 23" if ($target_hour < 0 || $target_hour > 23);

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
