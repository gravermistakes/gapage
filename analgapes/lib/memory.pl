#!/usr/bin/env perl
# Memory Curator: 4-typed persistence (SQLite or JSON fallback)
# Types: short_term (7d TTL), long_term, structural, cautionable
# Usage: perl memory.pl [store|list|search|forget|init] [args...]

use strict;
use warnings;
use utf8;
use 5.036;

use JSON::PP;
use File::Spec;
use File::Basename;

my $SCRIPT_DIR = dirname(__FILE__);
my $DATA_DIR = File::Spec->catdir($SCRIPT_DIR, File::Spec->updir(), 'data');
mkdir $DATA_DIR unless -d $DATA_DIR;
my $DB_FILE = File::Spec->catfile($DATA_DIR, 'nexus.db');
my $JSON_FILE = File::Spec->catfile($DATA_DIR, 'memory.json');

my $VALID_TABLES = { map { $_ => 1 } qw(short_term long_term structural cautionable) };

# Detect SQLite availability
my $HAS_SQLITE = 0;
eval {
    require DBI;
    $HAS_SQLITE = 1;
};

sub now {
    my @t = gmtime();
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
}

# ─── JSON Backend (fallback when DBI unavailable) ───
sub _json_load {
    return {} unless -f $JSON_FILE;
    open my $fh, '<:encoding(UTF-8)', $JSON_FILE or return {};
    my $content = do { local $/; <$fh> };
    close $fh;
    return eval { decode_json($content) } // {};
}

sub _json_save {
    my ($data) = @_;
    open my $fh, '>:encoding(UTF-8)', $JSON_FILE or die "Cannot write $JSON_FILE: $!";
    print $fh encode_json($data);
    close $fh;
}

sub _json_store {
    my ($table, $content, $source, $confidence) = @_;
    my $data = _json_load();
    $data->{$table} //= [];
    push @{$data->{$table}}, {
        id => scalar(@{$data->{$table}}) + 1,
        content => $content, source => $source // 'nexus',
        confidence => $confidence // 0.9,
        created_at => now(),
    };
    _json_save($data);
}

sub _json_list {
    my ($table, $limit) = @_;
    $limit //= 20;
    my $data = _json_load();
    my @tables = $table && $VALID_TABLES->{$table} ? ($table) : keys %$VALID_TABLES;
    for my $t (@tables) {
        print "\n## $t ##\n";
        my @entries = @{$data->{$t} // []};
        @entries = reverse @entries;
        @entries = @entries[0 .. $limit - 1] if @entries > $limit;
        for my $e (@entries) {
            printf "  [%d] %s (conf: %.2f, src: %s)\n",
                $e->{id}, $e->{content}, $e->{confidence}, $e->{source};
        }
        print "  (empty)\n" unless @entries;
    }
}

sub _json_search {
    my ($query, $limit) = @_;
    $limit //= 10;
    my $data = _json_load();
    for my $table (keys %$VALID_TABLES) {
        my @matches = grep { $_->{content} =~ /\Q$query\E/i } @{$data->{$table} // []};
        @matches = reverse @matches;
        @matches = @matches[0 .. $limit - 1] if @matches > $limit;
        for my $e (@matches) {
            printf "  [$table:%d] %s (conf: %.2f)\n", $e->{id}, $e->{content}, $e->{confidence};
        }
    }
}

sub _json_forget {
    my ($table, $id) = @_;
    my $data = _json_load();
    return unless $data->{$table};
    @{$data->{$table}} = grep { $_->{id} != $id } @{$data->{$table}};
    _json_save($data);
}

# ─── SQLite Backend ───
sub init_db_sqlite {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE", '', '', { RaiseError => 1 });
    for my $sql (
        q{CREATE TABLE IF NOT EXISTS short_term (id INTEGER PRIMARY KEY, content TEXT, source TEXT, confidence REAL, created_at TEXT DEFAULT (datetime('now')), expires_at TEXT DEFAULT (datetime('now','+7 days')))},
        q{CREATE TABLE IF NOT EXISTS long_term (id INTEGER PRIMARY KEY, content TEXT, source TEXT, confidence REAL, created_at TEXT DEFAULT (datetime('now')))},
        q{CREATE TABLE IF NOT EXISTS structural (id INTEGER PRIMARY KEY, content TEXT, source TEXT, confidence REAL, created_at TEXT DEFAULT (datetime('now')))},
        q{CREATE TABLE IF NOT EXISTS cautionable (id INTEGER PRIMARY KEY, content TEXT, source TEXT, trigger_count INTEGER DEFAULT 1, confidence REAL, created_at TEXT DEFAULT (datetime('now')))},
        q{CREATE TABLE IF NOT EXISTS seeds (sid TEXT PRIMARY KEY, hypothesis TEXT, attack_vector TEXT, falsifiability TEXT, status TEXT, entropy REAL, timestamp TEXT, iteration INTEGER DEFAULT 0)},
        q{CREATE TABLE IF NOT EXISTS threat_intel (tid TEXT PRIMARY KEY, source_url TEXT, ioc_type TEXT, value TEXT, confidence REAL, ttp TEXT, timestamp TEXT)},
    ) {
        $dbh->do($sql);
    }
    $dbh->disconnect;
}

sub store_sqlite {
    my ($table, $content, $source, $confidence) = @_;
    $source //= 'nexus'; $confidence //= 0.9;
    init_db_sqlite() unless -f $DB_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE", '', '', { RaiseError => 1 });
    $dbh->do("INSERT INTO $table (content, source, confidence) VALUES (?, ?, ?)",
        undef, $content, $source, $confidence);
    $dbh->disconnect;
}

sub list_sqlite {
    my ($table, $limit) = @_;
    $limit //= 20;
    init_db_sqlite() unless -f $DB_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE", '', '', { RaiseError => 1 });
    my @tables = $table && $VALID_TABLES->{$table} ? ($table) : keys %$VALID_TABLES;
    for my $t (@tables) {
        print "\n## $t ##\n";
        my $where = $t eq 'short_term' ? "WHERE expires_at > datetime('now')" : '';
        my $sth = $dbh->prepare("SELECT id, content, source, confidence, created_at FROM $t $where ORDER BY created_at DESC LIMIT ?");
        $sth->execute($limit);
        my $found = 0;
        while (my $row = $sth->fetchrow_hashref) {
            printf "  [%d] %s (conf: %.2f, src: %s)\n", $row->{id}, $row->{content}, $row->{confidence}, $row->{source};
            $found = 1;
        }
        print "  (empty)\n" unless $found;
    }
    $dbh->disconnect;
}

sub search_sqlite {
    my ($query, $limit) = @_;
    $limit //= 10;
    init_db_sqlite() unless -f $DB_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE", '', '', { RaiseError => 1 });
    for my $table (keys %$VALID_TABLES) {
        my $sth = $dbh->prepare("SELECT id, content, source, confidence, created_at FROM $table WHERE content LIKE ? ORDER BY created_at DESC LIMIT ?");
        $sth->execute("%$query%", $limit);
        while (my $row = $sth->fetchrow_hashref) {
            printf "  [$table:%d] %s (conf: %.2f)\n", $row->{id}, $row->{content}, $row->{confidence};
        }
    }
    $dbh->disconnect;
}

sub forget_sqlite {
    my ($table, $id) = @_;
    init_db_sqlite() unless -f $DB_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$DB_FILE", '', '', { RaiseError => 1 });
    $dbh->do("DELETE FROM $table WHERE id = ?", undef, $id);
    $dbh->disconnect;
}

# ─── Dispatch ───
sub store { $HAS_SQLITE ? store_sqlite(@_) : _json_store(@_) }
sub list_memories { $HAS_SQLITE ? list_sqlite(@_) : _json_list(@_) }
sub search { $HAS_SQLITE ? search_sqlite(@_) : _json_search(@_) }
sub forget { $HAS_SQLITE ? forget_sqlite(@_) : _json_forget(@_) }

# ─── MAIN ───
my $cmd = shift @ARGV // 'list';
if ($cmd eq 'store') {
    my ($table, $content, $source, $conf) = @ARGV;
    die "Unknown table: $table\n" unless $VALID_TABLES->{$table};
    die "Missing content\n" unless $content;
    store($table, $content, $source, $conf);
    print "Stored in $table: $content\n";
} elsif ($cmd eq 'list') {
    list_memories(@ARGV);
} elsif ($cmd eq 'search') {
    search(@ARGV);
} elsif ($cmd eq 'forget') {
    my ($table, $id) = @ARGV;
    die "Unknown table: $table\n" unless $VALID_TABLES->{$table};
    forget($table, $id);
    print "Forgotten $table id=$id\n";
} elsif ($cmd eq 'init') {
    if ($HAS_SQLITE) {
        init_db_sqlite();
        print "SQLite database initialized at $DB_FILE\n";
    } else {
        _json_save({});
        print "JSON backend initialized at $JSON_FILE (install DBI for SQLite)\n";
    }
} else {
    print "Usage: memory.pl [store TABLE CONTENT [SOURCE] [CONF] | list [TABLE] [LIMIT] | search QUERY [LIMIT] | forget TABLE ID | init]\n";
}
