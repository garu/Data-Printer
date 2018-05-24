use strict;
use warnings;
use Test::More tests => 9;
use Data::Printer::Object;

test_dbi();
test_dbic();

sub test_dbi {
    SKIP: {
        my $dbh;
        skip 'DBI not available', 8 unless eval 'use DBI; 1';
        skip 'unable to test DBI', 8 unless eval {
            $dbh = DBI->connect('dbi:Mem(RaiseError=1):');
            1;
        };
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is(
            $ddp->parse($dbh),
            'Mem Database Handle (connected) {
    Auto Commit: 1
    Statement Handles: 0
    Last Statement: -
}',
            'DBH output'
        );

        my $sth = $dbh->prepare('CREATE TABLE foo ( bar TEXT, baz TEXT )');
        is(
            $ddp->parse($dbh),
            'Mem Database Handle (connected) {
    Auto Commit: 1
    Statement Handles: 1 (0 active)
    Last Statement: CREATE TABLE foo ( bar TEXT, baz TEXT )
}',
            'DBH output (after setting statement)'
        );
        is(
            $ddp->parse($sth),
            'CREATE TABLE foo ( bar TEXT, baz TEXT )',
            'STH output (before execute)'
        );
        skip 'error running query', 5 unless eval { $sth->execute; 1 };
        is(
            $ddp->parse($sth),
            'CREATE TABLE foo ( bar TEXT, baz TEXT )',
            'STH output (after execute)'
        );

        my $sth2 = $dbh->prepare('SELECT * FROM foo WHERE bar = ?');
        is(
            $ddp->parse($dbh),
            'Mem Database Handle (connected) {
    Auto Commit: 1
    Statement Handles: 2 (0 active)
    Last Statement: SELECT * FROM foo WHERE bar = ?
}',
            'DBH output (after new statement)'
        );
        $sth2->execute(42);
        is(
            $ddp->parse($sth2),
            'SELECT * FROM foo WHERE bar = ?  (bindings unavailable)',
            'STH-2 output'
        );
        is(
            $ddp->parse($dbh),
            'Mem Database Handle (connected) {
    Auto Commit: 1
    Statement Handles: 2 (1 active)
    Last Statement: SELECT * FROM foo WHERE bar = ?
}',
            'DBH output (after executing new statement)'
        );

        undef $sth;
        $dbh->disconnect;

        is(
            $ddp->parse($dbh),
            'Mem Database Handle (disconnected) {
    Auto Commit: 1
    Statement Handles: 1 (1 active)
    Last Statement: SELECT * FROM foo WHERE bar = ?
}',
            'DBH output (after disconnecting and undefining sth)'
        );
    };
}

sub test_dbic {
    my $packages = <<'EOPACKAGES';
package MyDDPTest::Schema;
use base 'DBIx::Class::Schema';
__PACKAGE__->load_namespaces;

1;

package MyDDPTest::Schema::Result::User;
use base 'DBIx::Class::Core';
__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    user_id => {
      data_type         => 'integer',
      is_nullable       => 0,
      is_numeric        => 1,
      is_auto_increment => 1,
    },
    identity => { data_type => 'integer' },
    email    => { data_type => 'varchar(50)' },
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(['email']);
__PACKAGE__->has_many(
    pets => 'MyDDPTest::Schema::Result::Pet'
);

sub do_something {}

1;

package MyDDPTest::Schema::Result::Pet;
use base 'DBIx::Class::Core';
__PACKAGE__->table('pet');
__PACKAGE__->add_columns(
    name => { data_type => 'varchar(10)', is_nullable => 0 },
    size => { data_type => 'integer', default_value => 10 },
    user => { data_type => 'integer', is_nullable => 1 },
);
__PACKAGE__->set_primary_key('name', 'size');

__PACKAGE__->belongs_to(
    user => 'MyDDPTest::Schema::Result::User'
);

sub sleep {}
sub _nap {}

1;

package MyDDPTest::Schema::Result::BigPet;
use base 'DBIx::Class::Core';
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('bigpet');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(
    'SELECT name,size from pet where size > 10'
);

sub my_virtual_sub {}

1;

EOPACKAGES

    SKIP: {
        skip 'DBIx::Class not available', 1 unless eval "$packages";
        package main;
        my $schema;
        skip 'could not connect with DBIx::Class + SQLite', 1, unless eval {
            $schema = MyDDPTest::Schema->connect(
                'dbi:SQLite(RaiseError=1):dbname=:memory:'
            );
        };
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is(
            $ddp->parse($schema),
            'MyDDPTest::Schema DBIC Schema with SQLite Database Handle (connected) {
    dbname: :memory:
    Auto Commit: 1
    Statement Handles: 0
    Last Statement: -
}',
            'dumping DBIC schema'
        );

    };
}
