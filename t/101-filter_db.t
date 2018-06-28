use strict;
use warnings;
use Test::More tests => 23;
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
    email    => { data_type => 'varchar', size => 50, default_value => 'a@b.com' },
    city     => { data_type => 'varchar', size => 10 },
    state    => { data_type => 'varchar', size => 3 },
    code1    => { data_type => 'decimal', size => [8,2] },
    created  => { data_type => 'datetime', is_nullable => 1 },
);

__PACKAGE__->set_primary_key('user_id');
__PACKAGE__->add_unique_constraint(['email']);
__PACKAGE__->has_many(
    pets => 'MyDDPTest::Schema::Result::Pet'
);

sub do_something {}

1;

package MyDDPTest::Schema::Result::BadSize;
use strict; use warnings;
use base 'DBIx::Class::Core';
__PACKAGE__->table('bad_size');
__PACKAGE__->add_columns(
    foo => { data_type => 'varchar(2)', size => 3 },
);
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
        skip 'DBD::SQLite not available', 15 unless eval "use DBD::SQLite; 1";
        skip 'DBIx::Class not available', 15 unless eval "$packages";
        package main;
        my $schema;
        skip 'could not connect with DBIx::Class + SQLite: '. $@, 15, unless eval {
            MyDDPTest::Schema->load_classes({
                'MyDDPTest::Schema::Result' => [qw(Pet BigPet User)]
            });
            $schema = MyDDPTest::Schema->connect(
                'dbi:SQLite(RaiseError=1):dbname=:memory:'
            );
            $schema->deploy({ add_drop_table => 1 });
            $schema->load_classes({ 'MyDDPTest::Schema::Result' => ['BadSize'] });
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
    loaded sources: BadSize, BigPet, Pet, User
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
    loaded sources: BadSize, BigPet, Pet, User
}',
            'schema dump with show_handle'
        );
        $ddp = Data::Printer::Object->new(
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
        $ddp = Data::Printer::Object->new(
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
                schema => { show_handle => 0, loaded_sources => 'details' }
            }
        );
        is(
            $ddp->parse($schema),
q|MyDDPTest::Schema {
    connection: SQLite Database Handle (connected)
    loaded sources:
        BadSize ResultSource {
            table: "bad_size"
            columns:
                foo varchar(2) (meta size as 3)
        },
        BigPet ResultSource (Virtual View) {
            table: "bigpet"
            columns:
                name (unknown data type),
                size (unknown data type)
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
                created datetime null,
                email varchar(50) default "a@b.com",
                identity integer,
                state varchar(3)
            non-primary uniques:
                (email) as 'user_email'
        }
}|,
            'schema dump with loaded_sources => details'
        );

        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
            filter_db => {
                schema => { show_handle => 0, loaded_sources => 'details' },
                column_info => 'names',
            }
        );
        is(
            $ddp->parse($schema),
q|MyDDPTest::Schema {
    connection: SQLite Database Handle (connected)
    loaded sources:
        BadSize ResultSource {
            table: "bad_size"
            columns: foo
        },
        BigPet ResultSource (Virtual View) {
            table: "bigpet"
            columns: name, size
        },
        Pet ResultSource {
            table: "pet"
            columns: name (primary), size (primary), user
        },
        User ResultSource {
            table: "user"
            columns: user_id (primary), city, code1, created, email, identity, state
            non-primary uniques:
                (email) as 'user_email'
        }
}|,
            'schema dump with loaded_sources => details and column_info => names'
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
        created datetime null,
        email varchar(50) default "a@b.com",
        identity integer,
        state varchar(3)
    non-primary uniques:
        (email) as 'user_email'
}|, 'single ResultSource dump'
        );

        my $rs = $schema->resultset('User');
        $ddp =  Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is ($ddp->parse($rs), 'User ResultSet {
    current search parameters: -
    as query:
        (SELECT me.user_id, me.identity, me.email, me.city, me.state, me.code1, me.created FROM user me)
}', 'empty resultset');

         my $db_user = $rs->new({
            identity => 123,
            email    => 'test@example.com',
            city     => 'berlin',
            state    => 'xx',
            code1    => 12.3,
            created  => undef,
        });
        $ddp = Data::Printer::Object->new(
            colored => 0,
            filters => ['DB'],
        );
        is ($ddp->parse($rs), 'User ResultSet {
    current search parameters: -
    as query:
        (SELECT me.user_id, me.identity, me.email, me.city, me.state, me.code1, me.created FROM user me)
}', 'still empty after creation');

        is($ddp->parse($db_user), 'User Row (NOT in storage) {
    city:     "berlin"
    code1:    12.3
    created:  undef
    email:    "test@example.com"
    identity: 123
    state:    "xx"
}', 'db user after new() NOT in storage and  no user_id ');
        $db_user->insert;
        is ($ddp->parse($db_user), 'User Row (in storage) {
    city:     "berlin"
    code1:    12.3
    created:  undef
    email:    "test@example.com"
    identity: 123
    state:    "xx"
    user_id:  1
}', 'db user after insert');

    $ddp = Data::Printer::Object->new(
        colored => 0,
        filters => ['DB'],
    );

    $db_user->city('rio');
    is ($ddp->parse($db_user), 'User Row (in storage) {
    city:     "rio" (updated)
    code1:    12.3
    created:  undef
    email:    "test@example.com"
    identity: 123
    state:    "xx"
    user_id:  1
}', 'dirty db user');

    $db_user->update;
    is ($ddp->parse($db_user), 'User Row (in storage) {
    city:     "rio"
    code1:    12.3
    created:  undef
    email:    "test@example.com"
    identity: 123
    state:    "xx"
    user_id:  1
}', 'updated db user');

    $rs = $rs->search(
        {
            'email'     => { like => 'foo%' },
            'state'     => ['CA','NY'],
            'pets.name' => { -in => [qw(Rex Mewmew)] },
        },
        {
            '+select' => ['pets.name'],
            '+as'     => ['pet_name'],
            join      => ['pets'],
            order_by  => { -desc => ['city'] }
        }
    );
    $ddp =  Data::Printer::Object->new(
        colored => 0,
        filters => ['DB'],
    );
    is ($ddp->parse($rs), 'User ResultSet {
    current search parameters: {
        email       {
            like   "foo%"
        },
        pets.name   {
            -in   [
                [0] "Rex",
                [1] "Mewmew"
            ]
        },
        state       [
            [0] "CA",
            [1] "NY"
        ]
    }
    as query:
        (SELECT me.user_id, me.identity, me.email, me.city, me.state, me.code1, me.created, pets.name FROM user me LEFT JOIN pet pets ON pets.user = me.user_id WHERE ( ( email LIKE ? AND pets.name IN ( ?, ? ) AND ( state = ? OR state = ? ) ) ) ORDER BY city DESC)
        foo% (varchar)
        Rex (varchar(10))
        Mewmew (varchar(10))
        CA (varchar)
        NY (varchar)
}', 'resultset with search');

    my $from_db = $schema->resultset('User')->search(
        { user_id => 1 },
        {
            '+select' => [ { LENGTH => 'identity', -as => 'meep' } ],
            '+as'     => ['length_test'],
        }
    )->single;
    $ddp =  Data::Printer::Object->new(
        colored => 0,
        filters => ['DB'],
    );
    my $code1 = $from_db->code1; # OpenBSD sometimes says 12.3000000000000007
    is ($ddp->parse($from_db), qq(User Row (in storage) {
    city:        "rio"
    code1:       $code1
    created:     undef
    email:       "test\@example.com"
    identity:    123
    length_test: 3 (extra)
    state:       "xx"
    user_id:     1
}), 'db entry with extra col');
    # TODO: test some ->all() with prefetch
    };
}
