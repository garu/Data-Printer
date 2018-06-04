use strict;
use warnings;
use Test::More tests => 16;
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
package MyDDPTest::Schema::Result::User;
use strict; use warnings;
use base 'DBIx::Class::Core';
__PACKAGE__->load_components('InflateColumn::DateTime');
__PACKAGE__->table('user');
__PACKAGE__->add_columns(
    user_id => {
      data_type         => 'integer',
      is_nullable       => 0,
      is_numeric        => 1,
      is_auto_increment => 1,
    },
    identity => { data_type => 'integer' },
    email    => { data_type => 'varchar(50)', size => 50, default_value => 'a@b.com' },
    city     => { data_type => 'varchar', size => 10 },
    state    => { data_type => 'varchar(2)', size => 3 },
    code1    => { data_type => 'decimal(8,2)', size => [8,2] },
    created  => { data_type => 'datetime', default_value => \'now()' },
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(['email']);
__PACKAGE__->has_many(
    pets => 'MyDDPTest::Schema::Result::Pet'
);

sub do_something {}

1;

package MyDDPTest::Schema::Result::Pet;
use strict; use warnings;
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
use strict; use warnings;
use base 'DBIx::Class::Core';
__PACKAGE__->table_class('DBIx::Class::ResultSource::View');
__PACKAGE__->table('bigpet');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(
    'SELECT name,size from pet where size > 10'
);

__PACKAGE__->add_columns(qw(name size));

sub my_virtual_sub {}

1;

package MyDDPTest::Schema;
use strict; use warnings;
use base 'DBIx::Class::Schema';

1;
EOPACKAGES

    SKIP: {
        skip 'DBIx::Class not available', 3 unless eval "$packages";
        package main;
        my $schema;
        skip 'could not connect with DBIx::Class + SQLite: '. $@, 3, unless eval {
            MyDDPTest::Schema->load_classes({
                'MyDDPTest::Schema::Result' => [qw(Pet BigPet User)]
            });
            $schema = MyDDPTest::Schema->connect(
                'dbi:SQLite(RaiseError=1):dbname=:memory:'
            );
            1;
        };
        my $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        $schema->storage->dbh; # <-- force connection;
        is(
            $ddp->parse($schema),
'MyDDPTest::Schema {
    connection: SQLite Database Handle (connected)
    loaded sources: BigPet, Pet, User
}',
            'basic schema dump'
        );
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
            filter_db => {
                schema => { show_handle => 1 }
            }
        );
        is(
            $ddp->parse($schema),
'MyDDPTest::Schema {
    connection: SQLite Database Handle (connected) {
        dbname: :memory:
        Auto Commit: 1
        Statement Handles: 0
        Last Statement: -
    }
    loaded sources: BigPet, Pet, User
}',
            'schema dump with show_handle'
        );
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
            filter_db => {
                schema => { loaded_sources => 'none' }
            }
        );
        is(
            $ddp->parse($schema),
'MyDDPTest::Schema {
    connection: SQLite Database Handle (connected)
}',
            'schema dump with loaded_sources => none'
        );
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
            filter_db => {
                schema => { expand => 0 }
            }
        );
        is(
            $ddp->parse($schema),
            'MyDDPTest::Schema (SQLite - connected)',
            'schema dump with expand => 0'
        );
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
            filter_db => {
                schema => { show_handle => 0, loaded_sources => 'expand' }
            }
        );
        is(
            $ddp->parse($schema),
q|MyDDPTest::Schema {
    connection: SQLite Database Handle (connected)
    loaded sources:
        BigPet ResultSource (Virtual View) {
            table: "bigpet"
        },
        Pet ResultSource {
            table: "pet"
            columns:
                name varchar(10) not null (primary),
                size integer default 10 (primary),
                user integer null
        },
        User ResultSource {
            table: "user"
            columns:
                user_id integer not null auto_increment (primary),
                city varchar(10),
                code1 decimal(8,2),
                created datetime default now(),
                email varchar(50) default "a@b.com",
                identity integer,
                state varchar(2) (meta size as 3)
            non-primary uniques:
                (email) as 'user_email'
        }
}|,
            'schema dump with loaded_sources => expand'
        );

        my $user_source = $schema->source('User');
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is ($ddp->parse($user_source),
q|User ResultSource {
    table: "user"
    columns:
        user_id integer not null auto_increment (primary),
        city varchar(10),
        code1 decimal(8,2),
        created datetime default now(),
        email varchar(50) default "a@b.com",
        identity integer,
        state varchar(2) (meta size as 3)
    non-primary uniques:
        (email) as 'user_email'
}|, 'single ResultSource dump'
        );

    TODO: {
        local $TODO = 'not implemented yet!';

        my $rs = $schema->resultset('User');
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is ($ddp->parse($rs), '', 'empty resultset');
        $rs = $rs->search(
            {
                email      => { like => 'foo%' },
                state      => 'CA',
                'pet.name' => { -in => [qw(Rex Mewmew)] },
            },
            {
                join => ['pets'],
                order_by => { -desc => ['created'] }
            }
        );
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is ($ddp->parse($rs), '', 'resultset with search');
    };

=pod

'Pet Row (DBIx::Class::Row) {
    name: "rex"
    size: 10 (updated) <-- show_updated_label, colorize_updated
    foo: 321 (extra)   <-- show_extra_label, colorize_extra
    user -> User Row (DBIx::Class::Row) { <-- or "not fetched" only expands if fetched
        user_id: 123
        identity: 321
        email: "user@example.com"
    }
    methods: foo, bar <-- follows class.*, but can be overriden by filter_db.class.*
}'

'MyDDPTest::ResultSet::Pet (DBIx::Class::ResultSet) {
    columns from table "pet":        <-- filter_db.show_resultset_columns
        name varchar(10) not null,   <-- filter_db.describe_columns = 1
        size integer default 10,
        user integer null,
    primary key: name,size           <-- filter_db.show_primary_key
    belongs to: user (User) on foreign.user_id=self.user, <-- filter_db.show_relationships
    public methods: sleep
    current source alias: me
    current search parameters:
        me.name => { -like => "Test%" },
        me.size => 23,
    joins:
    prefetches:
    select query:
    current result count: 
    first 10 results:
}'

=cut

    };
}
