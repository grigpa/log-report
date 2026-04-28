package LogParser;

use strict;
use warnings;
use Digest::SHA qw(sha256_hex);

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub parse_line {
    my ($self, $line) = @_;

    return (undef, 'Empty line') if !defined $line || $line =~ /^\s*$/;

    my ($event_date, $event_time, $level, $message) =
        $line =~ /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(INFO|WARN|ERROR)\s+(.+)$/;

    return (undef, 'Line does not match expected format')
        unless $event_date && $event_time && $level;

    my %fields = $self->_parse_key_values($message);

    return ({
        event_hash => sha256_hex($line),
        event_date => $event_date,
        event_time => $event_time,
        level      => $level,
        user_id    => $fields{user_id},
        action     => $fields{action},
        status     => $fields{status},
        message    => $fields{message} || $message,
        raw_line   => $line,
    }, undef);
}

sub _parse_key_values {
    my ($self, $text) = @_;

    my %result;

    while ($text =~ /(\w+)=("([^"]*)"|[^\s]+)/g) {
        my $key   = $1;
        my $value = defined $3 ? $3 : $2;

        $value =~ s/^"//;
        $value =~ s/"$//;

        $result{$key} = $value;
    }

    return %result;
}

1;
