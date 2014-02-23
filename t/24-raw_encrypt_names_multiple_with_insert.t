#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;
use lib './t';
use dbixtest;

plan tests => 2;

use_ok( 'DBIx::Raw' ) || print "Bail out!\n";

my $people = people();
my $db = prepare();
$db->raw(query=>"INSERT INTO dbix_raw (name,favorite_color) VALUES ('Adam',?)", vals=>[$people->[0]->[2]], encrypt=>['favorite_color']);

my $id = $db->dbh->sqlite_last_insert_rowid();

my ($name,$encrypted_color) = $db->raw("SELECT name,favorite_color FROM dbix_raw WHERE id=?", $id);

is($name, $people->[0]->[0], 'Encrypt Name with insert');
isnt($encrypted_color, $people->[0]->[2], 'Encrypt Color with insert');
