package ReportStorage;

use strict;
use warnings;
use DBI;
use File::Basename qw(dirname);
use File::Path qw(make_path);

sub new {
    my ($class, $db_file) = @_;

    my $dir = dirname($db_file);
    make_path($dir) if $dir && !-d $dir;

    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_file",
        '',
        '',
        {
            RaiseError     => 1,
            AutoCommit     => 1,
            sqlite_unicode => 1,
        }
    );

    return bless { dbh => $dbh }, $class;
}

sub init_schema {
    my ($self) = @_;
    my $dbh = $self->{dbh};

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_hash TEXT NOT NULL UNIQUE,
            event_date TEXT NOT NULL,
            event_time TEXT NOT NULL,
            level TEXT NOT NULL,
            user_id INTEGER,
            action TEXT,
            status TEXT,
            message TEXT,
            raw_line TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    });

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS parse_errors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            raw_line TEXT NOT NULL,
            error_message TEXT NOT NULL,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    });

    $dbh->do(q{CREATE INDEX IF NOT EXISTS idx_events_level ON events(level)});
    $dbh->do(q{CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date)});
    $dbh->do(q{CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id)});
    $dbh->do(q{CREATE INDEX IF NOT EXISTS idx_events_level_date ON events(level, event_date)});
}

sub insert_events_batch {
    my ($self, $events) = @_;
    return 0 unless $events && @$events;

    my $dbh = $self->{dbh};
    my $inserted = 0;

    my $sth = $dbh->prepare(q{
        INSERT OR IGNORE INTO events (
            event_hash,
            event_date,
            event_time,
            level,
            user_id,
            action,
            status,
            message,
            raw_line
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    });

    $dbh->begin_work;

    eval {
        for my $event (@$events) {
            $sth->execute(
                $event->{event_hash},
                $event->{event_date},
                $event->{event_time},
                $event->{level},
                $event->{user_id},
                $event->{action},
                $event->{status},
                $event->{message},
                $event->{raw_line},
            );
            $inserted += $sth->rows;
        }
        $dbh->commit;
        1;
    } or do {
        my $error = $@ || 'Unknown database error';
        eval { $dbh->rollback };
        die $error;
    };

    return $inserted;
}

sub insert_parse_error {
    my ($self, $raw_line, $error_message) = @_;

    my $sth = $self->{dbh}->prepare(q{
        INSERT INTO parse_errors (raw_line, error_message)
        VALUES (?, ?)
    });

    $sth->execute($raw_line, $error_message);
}

sub count_by_level {
    my ($self) = @_;

    return $self->{dbh}->selectall_arrayref(q{
        SELECT level, COUNT(*) AS total
        FROM events
        GROUP BY level
        ORDER BY total DESC
    }, { Slice => {} });
}

sub top_users {
    my ($self, $limit) = @_;

    return $self->{dbh}->selectall_arrayref(q{
        SELECT user_id, COUNT(*) AS total
        FROM events
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        ORDER BY total DESC
        LIMIT ?
    }, { Slice => {} }, $limit);
}

sub errors_by_day {
    my ($self) = @_;

    return $self->{dbh}->selectall_arrayref(q{
        SELECT event_date, COUNT(*) AS total
        FROM events
        WHERE level = 'ERROR'
        GROUP BY event_date
        ORDER BY event_date
    }, { Slice => {} });
}

sub latest_errors {
    my ($self, $limit) = @_;

    return $self->{dbh}->selectall_arrayref(q{
        SELECT event_date, event_time, user_id, action, status, message
        FROM events
        WHERE level = 'ERROR'
        ORDER BY event_date DESC, event_time DESC
        LIMIT ?
    }, { Slice => {} }, $limit);
}

sub latest_parse_errors {
    my ($self, $limit) = @_;

    return $self->{dbh}->selectall_arrayref(q{
        SELECT raw_line, error_message, created_at
        FROM parse_errors
        ORDER BY id DESC
        LIMIT ?
    }, { Slice => {} }, $limit);
}

1;
