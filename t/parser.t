use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

use LogParser;

my $parser = LogParser->new();

my ($event, $error) = $parser->parse_line(
    '2026-04-28 12:31:02 ERROR user_id=18 action=upload status=failed message="file too large"'
);

ok($event, 'valid line parsed');
is($event->{event_date}, '2026-04-28', 'date parsed');
is($event->{event_time}, '12:31:02', 'time parsed');
is($event->{level}, 'ERROR', 'level parsed');
is($event->{user_id}, 18, 'user_id parsed');
is($event->{action}, 'upload', 'action parsed');
is($event->{status}, 'failed', 'status parsed');
is($event->{message}, 'file too large', 'quoted message parsed');
ok($event->{event_hash}, 'hash generated');

my ($bad_event, $bad_error) = $parser->parse_line('broken line');
ok(!$bad_event, 'invalid line rejected');
like($bad_error, qr/expected format/, 'parse error returned');

done_testing();
