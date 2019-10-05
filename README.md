# NAME

DBIx::Raw - Maintain control of SQL queries while still having a layer of abstraction above DBI

# SYNOPSIS

DBIx::Raw allows you to have complete control over your SQL, while still providing useful functionality so you don't have to deal directly with [DBI](https://metacpan.org/pod/DBI).

    use DBIx::Raw;
    my $db = DBIx::Raw->new(dsn => $dsn, user => $user, password => $password);

    #alternatively, use a conf file
    my $db = DBIx::Raw->new(conf => '/path/to/conf.pl');

    #get single values in scalar context
    my $name = $db->raw("SELECT name FROM people WHERE id=1");

    #get multiple values in list context
    my ($name, $age) = $db->raw("SELECT name, age FROM people WHERE id=1");

    #or
    my @person = $db->raw("SELECT name, age FROM people WHERE id=1");

    #get hash when using scalar context but requesting multiple values
    my $person = $db->raw("SELECT name, age FROM people where id=1");
    my $name = $person->{name};
    my $age = $person->{age};

    #also get hash in scalar context when selecting multiple values using '*'
    my $person = $db->raw("SELECT * FROM people where id=1");
    my $name = $person->{name};
    my $age = $person->{age};

    #insert a record
    $db->raw("INSERT INTO people (name, age) VALUES ('Sally', 26)");

    #insert a record with bind values to help prevent SQL injection
    $db->raw("INSERT INTO people (name, age) VALUES (?, ?)", 'Sally', 26);

    #update records
    my $num_rows_updated = $db->raw("UPDATE people SET name='Joe',age=34 WHERE id=1");

    #use bind values to help prevent SQL injection
    my $num_rows_updated = $db->raw("UPDATE people SET name=?,age=? WHERE id=?", 'Joe', 34, 1);

    #also use bind values when selecting
    my $name = $db->raw("SELECT name FROM people WHERE id=?", 1);

    #get multiple records as an array of hashes
    my $people = $db->aoh("SELECT name, age FROM people");

    for my $person (@$people) {
        print "$person->{name} is $person->{age} years old\n";
    }

    #update a record easily with a hash
    my %update = (
        name => 'Joe',
        age => 34,
    );

    #record with id=1 now has name=Joe an age=34
    $db->update(href=>\%update, table => 'people', id=>1);

    #use alternate syntax to encrypt and decrypt data
    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=? WHERE id=1", vals => ['Joe'], encrypt => [0]);

    my $decrypted_name = $db->raw(query => "SELECT name FROM people WHERE id=1", decrypt => [0]);

    #when being returned a hash, use names of field for decryption
    my $decrypted_person = $db->raw(query => "SELECT name, age FROM people WHERE id=1", decrypt => ['name']);
    my $decrypted_name = $decrypted_person->{name};

# INITIALIZATION

There are three ways to intialize a [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object:

## dsn, user, password

You can initialize a [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object by passing in the dsn, user, and password connection information.

    my $db = DBIx::Raw->new(dsn => 'dbi:mysql:test:localhost:3306', user => 'user', password => 'password');

## dbh

You can also initialize a [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object by passing in an existing database handle.

    my $db = DBIx::Raw->new(dbh => $dbh);

## conf

If you're going to using the same connection information a lot, it's useful to store it in a configuration file and then
use that when creating a [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object.

    my $db = DBIx::Raw->new(conf => '/path/to/conf.pl');

See [CONFIGURATION FILE](https://metacpan.org/pod/DBIx::Raw#CONFIGURATION-FILE) for more information on how to set up a configuration file.

# CONFIGURATION FILE

You can use a configuration file to store settings for [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) instead of passing them into new or setting them.
[DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) uses [Config::Any](https://metacpan.org/pod/Config::Any), so you can use any configuration format that is acceptable for [Config::Any](https://metacpan.org/pod/Config::Any). Variables
that you might want to store in your configuration file are `dsn`, `user`, `password`, and ["crypt\_key"](#crypt_key).

Below is an example configuration file in perl format:

## conf.pl

    {
        dsn => 'dbi:mysql:test:localhost:3306',
        user => 'root',
        password => 'password',
        crypt_key => 'lxsafadsfadskl23239210453453802xxx02-487900-=+1!:)',
    }

## conf.yaml

    ---
    dsn: 'dbi:mysql:test:localhost:3306'
    user: 'root'
    password: 'password'
    crypt_key: 'lxsafadsfadskl23239210453453802xxx02-487900-=+1!:)'

Note that you do not need to include ["crypt\_key"](#crypt_key) if you just want to use the file for configuration settings.

# SYNTAXES

DBIx::Raw provides two different possible syntaxes when making queries.

## SIMPLE SYNTAX

Simple syntax is an easy way to write queries. It is always in the format:

    ("QUERY");

or

    ("QUERY", "VAL1", "VAL2", ...);

Below are some examples:

    my $num_rows_updated = $db->raw("UPDATE people SET name='Fred'");

    my $name = $db->raw("SELECT name FROM people WHERE id=1");

DBIx::Raw also supports ["Placeholders and Bind Values" in DBI](https://metacpan.org/pod/DBI#Placeholders-and-Bind-Values) for [DBI](https://metacpan.org/pod/DBI). These can be useful to help prevent SQL injection. Below are
some examples of how to use placeholders and bind values with ["SIMPLE SYNTAX"](#simple-syntax).

    my $num_rows_updated = $db->raw("UPDATE people SET name=?", 'Fred');

    my $name = $db->raw("SELECT name FROM people WHERE id=?", 1);

    $db->raw("INSERT INTO people (name, age) VALUES (?, ?)", 'Frank', 44);

Note that ["SIMPLE SYNTAX"](#simple-syntax) cannot be used for ["hoh"](#hoh), ["hoaoh"](#hoaoh), ["hash"](#hash), or ["update"](#update) because of the extra parameters that they require.

## ADVANCED SYNTAX

Advanced syntax is used whenever a subroutine requires extra parameters besides just the query and bind values, or whenever you need to use ["encrypt"](#encrypt)
or ["decrypt"](#decrypt). A simple example of the advanced syntax is:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name='Fred'");

This is equivalent to:

    my $num_rows_updated = $db->raw("UPDATE people SET name='Fred'");

A slightly more complex example adds in bind values:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?", vals => ['Fred']);

This is equivalent to the simple syntax:

    my $num_rows_updated = $db->raw("UPDATE people SET name=?", 'Fred');

Also, advanced syntax is required whenevery you want to ["encrypt"](#encrypt) or ["decrypt"](#decrypt) values.

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?", vals => ['Fred'], encrypt => [0]);

    my $decrypted_name = $db->raw(query => "SELECT name FROM people WHERE id=1", decrypt => [0]);

Note that ["ADVANCED SYNTAX"](#advanced-syntax) is required for ["hoh"](#hoh), ["hoaoh"](#hoaoh), ["hash"](#hash), or ["update"](#update) because of the extra parameters that they require.

# ENCRYPT AND DECRYPT

You can use [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) to encrypt values when putting them into the database and decrypt values when removing them from the database.
Note that in order to store an encrypted value in the database, you should have the field be of type `VARCHAR(255)` or some type of character
or text field where the encryption will fit. In order to encrypt and decrypt your values, [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) requires a ["crypt\_key"](#crypt_key). It contains a default
key, but it is recommended that you change it either by having a different one in your ["conf"](#conf) file, or passing it in on creation with `new` or setting it using the
["crypt\_key"](#crypt_key) method. It is recommended that you use a module like [Crypt::Random](https://metacpan.org/pod/Crypt::Random) to generate a secure key.
One thing to note is that both ["encrypt"](#encrypt) and ["decrypt"](#decrypt) require ["ADVANCED SYNTAX"](#advanced-syntax).

## encrypt

In order to encrypt values, the values that you want to encrypt must be in the bind values array reference that you pass into `vals`. Note that for the values that you want to
encrypt, you should put their index into the encrypt array that you pass in. For example:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?,age=?,height=? WHERE id=1", vals => ['Zoe', 24, "5'11"], encrypt => [0, 2]);

In the above example, only `name` and `height` will be encrypted. You can easily encrypt all values by using '\*', like so:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?,height=? WHERE id=1", vals => ['Zoe', "5'11"], encrypt => '*');

And this will encrypt both `name` and `height`.

The only exception to the ["encrypt"](#encrypt) syntax that is a little different is for ["update"](#update). See ["update encrypt"](#update-encrypt) for how to encrypt when using ["update"](#update).

## decrypt

When decrypting values, there are two possible different syntaxes.

### DECRYPT LIST CONTEXT

If your query is returning a single value or values in a list context, then the array reference that you pass in for decrypt will contain the indices for the
order that the columns were listed in. For instance:

    my $name = $db->raw(query => "SELECT name FROM people WHERE id=1", decrypt => [0]);

    my ($name, $age) = $db->raw(query => "SELECT name, age FROM people WHERE id=1", decrypt => [0,1]);

### DECRYPT HASH CONTEXT

When your query has [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) return your values in a hash context, then the columns that you want decrypted must be listed by name in the array reference:

    my $person = $db->raw(query => "SELECT name, age FROM people WHERE id=1", decrypt => ['name', 'age'])

    my $aoh = $db->aoh(query => "SELECT name, age FROM people", decrypt => ['name', 'age']);

Note that for either ["LIST CONTEXT"](#list-context) or ["HASH CONTEXT"](#hash-context), it is possible to use '\*' to decrypt all columns:

    my ($name, $height) = $db->raw(query => "SELECT name, height FROM people WHERE id=1", decrypt => '*');

## crypt\_key

[DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) uses ["crypt\_key"](#crypt_key) to encrypt and decrypt all values. You can set the crypt key when you create your
[DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object by passing it into ["new"](#new), providing it to [CONFIGURATION FILE](https://metacpan.org/pod/DBIx::Raw#CONFIGURATION-FILE),
or by setting it with its setter method:

    $db->crypt_key("1234");

It is strongly recommended that you do not use the default ["crypt\_key"](#crypt_key). The ["crypt\_key"](#crypt_key) should be the appropriate length
for the ["crypt"](#crypt) that is set. The default ["crypt"](#crypt) uses [Crypt::Mode::CBC::Easy](https://metacpan.org/pod/Crypt::Mode::CBC::Easy), which uses [Crypt::Cipher::Twofish](https://metacpan.org/pod/Crypt::Cipher::Twofish), which
allows key sizes of 128/192/256 bits.

## crypt

The [Crypt::Mode::CBC::Easy](https://metacpan.org/pod/Crypt::Mode::CBC::Easy) object to use for encryption. Default is the default [Crypt::Mode::CBC::Easy](https://metacpan.org/pod/Crypt::Mode::CBC::Easy) object
created with the key ["crypt\_key"](#crypt_key).

## use\_old\_crypt

In version 0.16 [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) started using [Crypt::Mode::CBC::Easy](https://metacpan.org/pod/Crypt::Mode::CBC::Easy) instead of [DBIx::Raw::Crypt](https://metacpan.org/pod/DBIx::Raw::Crypt). Setting this to 1 uses the old encryption instead.
Make sure to set ["old\_crypt\_key"](#old_crypt_key) if you previously used ["crypt\_key"](#crypt_key) for encryption.

## old\_crypt\_key

This sets the crypt key to use if ["use\_old\_crypt"](#use_old_crypt) is set to true. Default is the previous crypt key.

# SUBROUTINES/METHODS

## raw

["raw"](#raw) is a very versitile subroutine, and it can be called in three contexts. ["raw"](#raw) should only be used to make a query that
returns values for one record, or a query that returns no results (such as an INSERT query). If you need to have multiple
results returned, see one of the subroutines below.

### SCALAR CONTEXT

["raw"](#raw) can be called in a scalar context to only return one value, or in a undef context to return no value. Below are some examples.

    #select
    my $name = $db->raw("SELECT name FROM people WHERE id=1");

    #update with number of rows updated returned
    my $num_rows_updated = $db->raw("UPDATE people SET name=? WHERE id=1", 'Frank');

    #update in undef context, nothing returned.
    $db->raw("UPDATE people SET name=? WHERE id=1", 'Frank');

    #insert
    $db->raw("INSERT INTO people (name, age) VALUES ('Jenny', 34)");

Note that to ["decrypt"](#decrypt) for ["SCALAR CONTEXT"](#scalar-context) for ["raw"](#raw), you would use ["DECRYPT LIST CONTEXT"](#decrypt-list-context).

### LIST CONTEXT

["raw"](#raw) can also be called in a list context to return multiple columns for one row.

    my ($name, $age) = $db->raw("SELECT name, age FROM people WHERE id=1");

    #or
    my @person = $db->raw("SELECT name, age FROM people WHERE id=1");

Note that to ["decrypt"](#decrypt) for ["LIST CONTEXT"](#list-context) for ["raw"](#raw), you would use ["DECRYPT LIST CONTEXT"](#decrypt-list-context).

### HASH CONTEXT

["raw"](#raw) will return a hash if you are selecting more than one column for a single record.

    my $person = $db->raw("SELECT name, age FROM people WHERE id=1");
    my $name = $person->{name};
    my $age = $person->{age};

Note that ["raw"](#raw)'s ["HASH CONTEXT"](#hash-context) works when using \* in your query.

    my $person = $db->raw("SELECT * FROM people WHERE id=1");
    my $name = $person->{name};
    my $age = $person->{age};

Note that to ["decrypt"](#decrypt) for ["HASH CONTEXT"](#hash-context) for ["raw"](#raw), you would use ["DECRYPT HASH CONTEXT"](#decrypt-hash-context).

## aoh (array\_of\_hashes)

["aoh"](#aoh) can be used to select multiple rows from the database. It returns an array reference of hashes, where each row is a hash in the array.

    my $people = $db->aoh("SELECT * FROM people");

    for my $person (@$people) {
        print "$person->{name} is $person->{age} years old\n";
    }

Note that to ["decrypt"](#decrypt) for ["aoh"](#aoh), you would use ["DECRYPT HASH CONTEXT"](#decrypt-hash-context).

## aoa (array\_of\_arrays)

["aoa"](#aoa) can be used to select multiple rows from the database. It returns an array reference of array references, where each row is an array within the array.

    my $people = $db->aoa("SELECT name,age FROM people");

    for my $person (@$people) {
        my $name = $person->[0];
        my $age = $person->[1];
        print "$name is $age years old\n";
    }

Note that to ["decrypt"](#decrypt) for ["aoa"](#aoa), you would use ["DECRYPT LIST CONTEXT"](#decrypt-list-context).

## hoh (hash\_of\_hashes)

- **query (required)** - the query
- **key (required)** - the name of the column that will serve as the key to access each row
- **href (optional)** - the hash reference that you would like to have the results added to

["hoh"](#hoh) can be used when you want to be able to access an individual row behind a unique key, where each row is represented as a hash. For instance,
this subroutine can be useful if you would like to be able to access rows by their id in the database. ["hoh"](#hoh) returns a hash reference of hash references.

    my $people = $db->hoh(query => "SELECT id, name, age FROM people", key => "id");

    for my $key(keys %$people) {
        my $person = $people->{$key};
        print "$person->{name} is $person->{age} years old\n";
    }

    #or
    while(my ($key, $person) = each %$people) {
        print "$person->{name} is $person->{age} years old\n";
    }

So if you wanted to access the person with an id of 1, you could do so like this:

    my $person1 = $people->{1};
    my $person1_name = $person1->{name};
    my $person1_age = $person1->{age};

Also, with ["hoh"](#hoh) it is possible to add to a previous hash of hashes that you alread have by passing it in with the `href` key:

    #$people was previously retrieved, and results will now be added to $people
    $db->hoh(query => "SELECT id, name, age FROM people", key => "id", href => $people);

Note that you must select whatever column you want to be the key. So if you want to use "id" as the key, then you must select id in your query.
Also, keys must be unique or the records will overwrite one another. To retrieve multiple records and access them by the same key, see ["hoaoh" in "hoaoh (hash\_of\_array\_of\_hashes)"](https://metacpan.org/pod/&#x22;hoaoh&#x20;\(hash_of_array_of_hashes\)&#x22;#hoaoh).
To ["decrypt"](#decrypt) for ["hoh"](#hoh), you would use ["DECRYPT HASH CONTEXT"](#decrypt-hash-context).

## hoa (hash\_of\_arrays)

- **query (required)** - the query
- **key (required)** - the name of the column that will serve as the key to store the values behind
- **val (required)** - the name of the column whose values you want to be stored behind key
- **href (optional)** - the hash reference that you would like to have the results added to

["hoa"](#hoa) is useful when you want to store a list of values for one column behind a key. For instance,
say that you wanted the id's of all people who have the same name grouped together. You could perform that query like so:

    my $hoa = $db->hoa(query => "SELECT id, name FROM people", key => "name", val => "id");

    for my $name (%$hoa) {
        my $ids = $hoa->{$name};

        print "$name has ids ";
        for my $id (@$ids) {
            print " $id,";
        }

        print "\n";
    }

Note that you must select whatever column you want to be the key. So if you want to use "name" as the key, then you must select name in your query.
To ["decrypt"](#decrypt) for ["hoa"](#hoa), you would use ["DECRYPT LIST CONTEXT"](#decrypt-list-context).

## hoaoh (hash\_of\_array\_of\_hashes)

- **query (required)** - the query
- **key (required)** - the name of the column that will serve as the key to store the array of hashes behind
- **href (optional)** - the hash reference that you would like to have the results added to

["hoaoh"](#hoaoh) can be used when you want to store multiple rows behind a key that they all have in common. For
example, say that we wanted to have access to all rows for people that have the same name. That could be
done like so:

    my $hoaoh = $db->hoaoh(query => "SELECT id, name, age FROM people", key => "name");

    for my $name (keys %$hoaoh) {
        my $people = $hoaoh->{$name};

        print "People named $name: ";
        for my $person (@$people) {
            print "  $person->{name} is $person->{age} years old\n";
        }

        print "\n";
    }

So to get the array of rows for all people named Fred, we could simply do:

    my @freds = $hoaoh->{Fred};

    for my $fred (@freds) { ... }

Note that you must select whatever column you want to be the key. So if you want to use "name" as the key, then you must select name in your query.
To ["decrypt"](#decrypt) for ["hoaoh"](#hoaoh), you would use ["DECRYPT HASH CONTEXT"](#decrypt-hash-context).

## array

["array"](#array) can be used for selecting one value from multiple rows. Say for instance that we wanted all the ids for anyone named Susie.
We could do that like so:

    my $ids = $db->array("SELECT id FROM people WHERE name='Susie'");

    print "Susie ids: \n";
    for my $id (@$ids) {
        print "$id\n";
    }

To ["decrypt"](#decrypt) for ["array"](#array), you would use ["DECRYPT LIST CONTEXT"](#decrypt-list-context).

## hash

- **query (required)** - the query
- **key (required)** - the name of the column that will serve as the key
- **val (required)** - the name of the column that will be stored behind the key
- **href (optional)** - the hash reference that you would like to have the results added to

["hash"](#hash) can be used if you want to map one key to one value for multiple rows. For instance, let's say
we wanted to map each person's id to their name:

    my $ids_to_names = $db->hash(query => "SELECT id, name FROM people", key => "id", val => "name");

    my $name_1 = $ids_to_names->{1};

    print "$name_1\n"; #prints 'Fred'

To have ["hash"](#hash) add to an existing hash, just pass in the existing hash with `href`:

    $db->hash(query => "SELECT id, name FROM people", key => "id", val => "name", href => $ids_to_names);

To ["decrypt"](#decrypt) for ["hash"](#hash), you would use ["DECRYPT HASH CONTEXT"](#decrypt-hash-context).

## insert

- **href (required)** - the hash reference that will be used to insert the row, with the columns as the keys and the new values as the values
- **table (required)** - the name of the table that the row will be inserted into

["insert"](#insert) can be used to insert a single row with a hash. This can be useful if you already have the values you need
to insert the row with in a hash, where the keys are the column names and the values are the new values. This function
might be useful for submitting forms easily.

    my %person_to_insert = (
        name => 'Billy',
        age => '32',
        favorite_color => 'blue',
    );

    $db->insert(href => \%person_to_insert, table => 'people');

If you need to have literal SQL into your insert query, then you just need to pass in a scalar reference. For example:

    "INSERT INTO people (name, update_time) VALUES('Billy', NOW())"

If we had this:

    my %person_to_insert = (
        name => 'Billy',
        update_time => 'NOW()',
    );

    $db->insert(href => \%person_to_insert, table => 'people');

This would effectively evaluate to:

    $db->raw(query => "INSERT INTO people (name, update_time) VALUES(?, ?)", vals => ['Billy', 'NOW()']);

However, this will not work. Instead, we need to do:

    my %person_to_insert = (
        name => 'Billy',
        update_time => \'NOW()',
    );

    $db->insert(href => \%person_to_insert, table => 'people');

Which evaluates to:

    $db->raw(query => "INSERT INTO people (name, update_time) VALUES(?, NOW())", vals => ['Billy']);

And this is what we want.

### insert encrypt

When encrypting for insert, because a hash is passed in you need to have the encrypt array reference contain the names of the columns that you want to encrypt
instead of the indices for the order in which the columns are listed:

    my %person_to_insert = (
        name => 'Billy',
        age => '32',
        favorite_color => 'blue',
    );

    $db->insert(href => \%person_to_insert, table => 'people', encrypt => ['name', 'favorite_color']);

Note we do not ecnrypt age because it is most likely stored as an integer in the database.

## update

- **href (required)** - the hash reference that will be used to update the row, with the columns as the keys and the new values as the values
- **table (required)** - the name of the table that the updated row is in
- **id (optional)** - specifies the id of the item that we are updating (note, column must be called "id"). Should not be used if `pk` is used
- **pk (optional)** - A hash reference of the form `{name => 'column_name', val => 'unique_val'}`. Can be used instead of `id`. Should not be used if `id` is used
- **where (optional)** - A where clause to help decide what row to update. Any bind values can be passed in with `vals`

["update"](#update) can be used to update a single row with a hash, and returns the number of rows updated. This can be useful if you already have the values you need
to update the row with in a hash, where the keys are the column names and the values are the new values. This function
might be useful for submitting forms easily.

    my %updated_person = (
        name => 'Billy',
        age => '32',
        favorite_color => 'blue',
    );

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', id => 1);

    # or in list context
    my ($num_rows_updated) = $db->update(href => \%updated_person, table => 'people', id => 1);

Note that above for "id", the column must actually be named id for it to work. If you have a primary key or unique
identifying column that is named something different than id, then you can use the `pk` parameter:

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', pk => {name => 'person_id', val => 1});

If you need to specify more constraints for the row that you are updating instead of just the id, you can pass in a where clause:

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', where => 'name=? AND favorite_color=? AND age=?', vals => ['Joe', 'green', 61]);

Note that any bind values used in a where clause can just be passed into the `vals` as usual. It is possible to use a where clause and an id or pk together:

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', where => 'name=? AND favorite_color=? AND age=?', vals => ['Joe', 'green', 61], id => 1);

Alternatively, you could just put the `id` or `pk` in your where clause.

If you need to have literal SQL into your update query, then you just need to pass in a scalar reference. For example:

    "UPDATE people SET name='Billy', update_time=NOW() WHERE id=1"

If we had this:

    my %updated_person = (
        name => 'Billy',
        update_time => 'NOW()',
    );

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', id => 1);

This would effectively evaluate to:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?, update_time=? WHERE id=?", vals => ['Billy', 'NOW()', 1]);

However, this will not work. Instead, we need to do:

    my %updated_person = (
        name => 'Billy',
        update_time => \'NOW()',
    );

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', id => 1);

Which evaluates to:

    my $num_rows_updated = $db->raw(query => "UPDATE people SET name=?, update_time=NOW() WHERE id=?", vals => ['Billy', 1]);

And this is what we want.

### update encrypt

When encrypting for update, because a hash is passed in you need to have the encrypt array reference contain the names of the columns that you want to encrypt
instead of the indices for the order in which the columns are listed:

    my %updated_person = (
        name => 'Billy',
        age => '32',
        favorite_color => 'blue',
    );

    my $num_rows_updated = $db->update(href => \%updated_person, table => 'people', id => 1, encrypt => ['name', 'favorite_color']);

Note we do not ecnrypt age because it is most likely stored as an integer in the database.

## insert\_multiple

- **rows (required)** - the array reference of array references, where each inner array reference holds the values to be inserted for one row
- **table (required)** - the name of the table that the rows are to be inserted into
- **columns (required)** - The names of the columns that values are being inserted for

["insert\_multiple"](#insert_multiple) can be used to insert multiple rows with one query. For instance:

    my $rows = [
        [
            1,
            'Joe',
            23,
        ],
        [
            2,
            'Ralph,
            50,
        ],
    ];

    $db->insert_multiple(table => 'people', columns => [qw/id name age/], rows => $rows);

This can be translated into the SQL query:

    INSERT INTO people (id, name, age) VALUES (1, 'Joe', 23), (2, 'Ralph', 50);

Note that ["insert\_multiple"](#insert_multiple) does not yet support encrypt. I'm planning to add this feature later. If you need it now, please shoot me an email and I will
try to speed things up!

## sth

["sth"](#sth) returns the statement handle from the previous query.

    my $sth = $db->sth;

This can be useful if you need a statement handle to perform a function, like to get
the id of the last inserted row.

## dbh

["dbh"](#dbh) returns the database handle that [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) is using.

    my $dbh = $db->dbh;

["dbh"](#dbh) can also be used to set a new database handle for [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) to use.

    $db->dbh($new_dbh);

## dsn

["dsn"](#dsn) returns the dsn that was provided.

    my $dsn = $db->dsn;

["dsn"](#dsn) can also be used to set a new `dsn`.

    $db->dsn($new_dsn);

When setting a new `dsn`, it's likely you'll want to use ["connect"](#connect).

## user

["user"](#user) returns the user that was provided.

    my $user = $db->user;

["user"](#user) can also be used to set a new `user`.

    $db->user($new_user);

When setting a new `user`, it's likely you'll want to use ["connect"](#connect).

## password

["password"](#password) returns the password that was provided.

    my $password = $db->password;

["password"](#password) can also be used to set a new `password`.

    $db->password($new_password);

When setting a new `password`, it's likely you'll want to use ["connect"](#connect).

## conf

["conf"](#conf) returns the conf file that was provided.

    my $conf = $db->conf;

["conf"](#conf) can also be used to set a new `conf` file.

    $db->conf($new_conf);

When setting a new `conf`, it's likely you'll want to use ["connect"](#connect).

## connect

["connect"](#connect) can be used to keep the same [DBIx::Raw](https://metacpan.org/pod/DBIx::Raw) object, but get a new ["dbh"](#dbh). You can call connect to get a new dbh with the same settings that you have provided:

    #now there is a new dbh with the same DBIx::Raw object using the same settings
    $db->connect;

Or you can change the connect info.
For example, if you update `dsn`, `user`, `password`:

    $db->dsn('new_dsn');
    $db->user('user');
    $db->password('password');

    #get new dbh but keep same DBIx::Raw object
    $db->connect;

Or if you update the conf file:

    $db->conf('/path/to/new_conf.pl');

    #get new dbh but keep same DBIx::Raw object
    $db->connect;

# AUTHOR

Adam Hopkins, `<srchulo at cpan.org>`

# BUGS

Please report any bugs or feature requests to `bug-dbix-raw at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Raw](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Raw).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Raw

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

    [http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Raw](http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Raw)

- AnnoCPAN: Annotated CPAN documentation

    [http://annocpan.org/dist/DBIx-Raw](http://annocpan.org/dist/DBIx-Raw)

- CPAN Ratings

    [http://cpanratings.perl.org/d/DBIx-Raw](http://cpanratings.perl.org/d/DBIx-Raw)

- Search CPAN

    [http://search.cpan.org/dist/DBIx-Raw/](http://search.cpan.org/dist/DBIx-Raw/)

# ACKNOWLEDGEMENTS

Special thanks to Jay Davis who wrote a lot of the original code that this module is based on.

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
