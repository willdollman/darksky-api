#!/usr/bin/perl

use warnings;
use strict;

use Mojo::UserAgent;
use Weather::ForecastIO qw( get_location get_weather is_rain_next_hour get_weather_at_hour get_hourly_summary );

my $api_key = "your api key here";
my $local_file = "./api-responses/bristol-20130529-1955.json";
$\ = "\n";

my @target_hours = qw(7 17);

my $location = get_location(\@ARGV);
my $weather = get_weather($location, $api_key);

my $target_weather;
# get weather for target hours
foreach my $hour (@target_hours) {
    $target_weather->{$hour} = {};
    my $condition = $target_weather->{$hour};

    ($condition->{intensity}, $condition->{summary})
        = get_weather_at_hour($weather, $hour);
}

my $print_hours = "";
my $print_intensity  = "";
my $is_ok_weather = 1;
# Form printable statement containing conditions
foreach my $hour (@target_hours) {
    my $condition     = $target_weather->{$hour};
    $print_hours     .= " $hour - " . $condition->{summary} . ",";
    $print_intensity .= $condition->{intensity} . ", ";
    $is_ok_weather    = 0 if ($condition->{intensity} > 0.017);
}
chop $print_hours;
chop $print_intensity; chop $print_intensity;

# Create title and messsage
my $notif_title   = $is_ok_weather ? "(" : ")";
my $notif_message = "$print_hours. ($print_intensity). " . get_hourly_summary($weather);

# Send notification
my $notif_app_key  = "app key here";
my $notif_user_key = "user key here";
send_notification($notif_app_key, $notif_user_key, $notif_title, $notif_message);

sub send_notification {
    my $app_key  = shift @_;
    my $user_key = shift @_;
    my $title    = shift @_;
    my $message  = shift @_;

    my $ua = Mojo::UserAgent->new;
    my $pushover_response = $ua->post(
        'https://api.pushover.net/1/messages.json' =>
        form => {
            token => $app_key,
            user  => $user_key,
            title => $title,
            message => $message,
        }
    );

    print "$title: $message";
}
