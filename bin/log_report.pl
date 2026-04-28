#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Getopt::Long qw(GetOptionsFromArray);
use LogParser;
use ReportStorage;
use HtmlReport;

sub print_usage {
    print <<'USAGE';
Usage:
  perl bin/log_report.pl import --input data/sample.log --db data/events.db
  perl bin/log_report.pl report --db data/events.db --output reports/report.html
  perl bin/log_report.pl stats --db data/events.db

Commands:
  import    Parse log file and save events to database
  report    Generate HTML report from database
  stats     Print short statistics to console

Options:
  --input       Path to source log file
  --db          Path to SQLite database file
  --output      Path to generated HTML report
  --batch-size  Batch size for inserts, default: 500
USAGE
}

my $command = shift @ARGV || '';

if (!$command || $command eq '--help' || $command eq '-h') {
    print_usage();
    exit 0;
}

my %opts = (
    batch_size => 500,
);

GetOptionsFromArray(
    \@ARGV,
    'input=s'      => \$opts{input},
    'db=s'         => \$opts{db},
    'output=s'     => \$opts{output},
    'batch-size=i' => \$opts{batch_size},
) or die "Invalid options. Run with --help.\n";

if ($command eq 'import') {
    die "Missing --input\n" unless $opts{input};
    die "Missing --db\n"    unless $opts{db};

    my $parser  = LogParser->new();
    my $storage = ReportStorage->new($opts{db});
    $storage->init_schema();

    open my $fh, '<:encoding(UTF-8)', $opts{input}
        or die "Cannot open input file '$opts{input}': $!\n";

    my @batch;
    my $total    = 0;
    my $inserted = 0;
    my $errors   = 0;

    while (my $line = <$fh>) {
        chomp $line;
        $total++;

        my ($event, $error) = $parser->parse_line($line);

        if (!$event) {
            $storage->insert_parse_error($line, $error || 'Unknown parse error');
            $errors++;
            next;
        }

        push @batch, $event;

        if (@batch >= $opts{batch_size}) {
            $inserted += $storage->insert_events_batch(\@batch);
            @batch = ();
        }
    }

    close $fh;

    $inserted += $storage->insert_events_batch(\@batch) if @batch;

    print "Import finished\n";
    print "Total lines: $total\n";
    print "Inserted events: $inserted\n";
    print "Parse errors: $errors\n";
    exit 0;
}

if ($command eq 'report') {
    die "Missing --db\n"     unless $opts{db};
    die "Missing --output\n" unless $opts{output};

    my $storage = ReportStorage->new($opts{db});
    $storage->init_schema();

    my $stats = {
        by_level      => $storage->count_by_level(),
        top_users     => $storage->top_users(10),
        errors_by_day => $storage->errors_by_day(),
        latest_errors => $storage->latest_errors(20),
        parse_errors  => $storage->latest_parse_errors(20),
    };

    my $report = HtmlReport->new(
        template => "$FindBin::Bin/../templates/report.html.tt",
    );

    $report->render($stats, $opts{output});
    print "Report created: $opts{output}\n";
    exit 0;
}

if ($command eq 'stats') {
    die "Missing --db\n" unless $opts{db};

    my $storage = ReportStorage->new($opts{db});
    $storage->init_schema();

    print "Events by level:\n";
    for my $row (@{ $storage->count_by_level() }) {
        print "  $row->{level}: $row->{total}\n";
    }

    exit 0;
}

die "Unknown command '$command'. Run with --help.\n";
