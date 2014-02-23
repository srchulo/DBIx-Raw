package dbixtest;
use strict;
use warnings;
use Exporter;

our @ISA= qw( Exporter );

our @EXPORT_OK = qw( dns user password create_table load_db get_db people crypt_salt prepare);
our @EXPORT = qw( dsn user password create_table load_db get_db people crypt_salt prepare);

sub dsn { 'dbi:SQLite:dbname=:memory:' }

sub user { 'root' }

sub password { '' }

sub create_table { 
	my ($db) = @_;
	$db->raw(query=>"CREATE TABLE dbix_raw ( id INTEGER PRIMARY KEY ASC, name varchar(255), age int, favorite_color varchar(255))");
	return 1;
}

sub people { [[qw/Adam 21 blue/], [qw/Dan 23 green/]] }

sub crypt_salt { 'xfasdfa8823423sfasdfalkj!@#$$CCCFFF!09xxxxlai3847lol13234408!!@#$_+-083dxje380-=0' }

sub load_db { 
	my ($db) = @_;
	create_table($db);

	for(@{people()}) {
		$db->raw(query=>"INSERT INTO dbix_raw(name,age,favorite_color) VALUES(?, ?, ?)", vals => $_);
	}
}

sub prepare { 
	my $db = get_db();
	load_db($db);
	return $db;
}

sub get_db { 
	use Cwd 'abs_path';
	my $abs_path = abs_path('t/dbix_conf.pl');
	return DBIx::Raw->new(conf => $abs_path);
}

1;
