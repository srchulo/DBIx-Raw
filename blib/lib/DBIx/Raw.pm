package DBIx::Raw;
use strict;
use Mouse;
use DBI;
use Config::Any;
use lib './lib'; #REMOVE
use DBIx::Raw::Crypt;

#have an errors file to write to
has 'dsn'    => ( is => 'rw', isa => 'Any', default => undef);
has 'user'    => ( is => 'rw', isa => 'Any', default => undef);
has 'password'    => ( is => 'rw', isa => 'Any', default => undef);
has 'conf'    => ( is => 'ro', isa => 'Any', default => undef);
has 'crypt_salt'    => ( is => 'rw', isa => 'Str', default => 'xfasdfa8823423sfasdfalkj!@#$$CCCFFF!09xxxxlai3847lol13234408!!@#$_+-083dxje380-=0');

has 'crypt'    => ( 
	is => 'ro', 
	isa => 'DBIx::Raw::Crypt', 
	lazy => 1,
	default => sub { 
		my ($self) = @_;
		return DBIx::Raw::Crypt->new ( { secret => $self->crypt_salt });
	},
);

has 'sth'    => ( is => 'rw', isa => 'Any', default => undef); #LAST STH USED

#find out what DBH is specifically
has 'dbh'    => ( 
	is => 'rw', 
	isa => 'Any', 
	lazy => 1, 
	default => sub { 
		my ($self) = @_;
		my $dbh = DBI->connect($self->dsn, $self->user, $self->password) or die $DBI::errstr;
		return $dbh;
});

has 'keys' => (
	is => 'ro', 
	isa=>'HashRef[Str]',
	default => sub { {
		query => 1,
		vals => 1,
		encrypt => 1,
		decrypt => 1,
		key => 1,
	} },
);

sub BUILD {
	my ($self) = @_;

	#load in configuration if it exists
	if($self->conf) { 
		my $config = Config::Any->load_files({files =>[$self->conf],use_ext => 1  }); 

		for my $c (@$config){
  			for my $file (keys %$c){
     			for my $attribute (keys %{$c->{$file}}){
					if($self->can($attribute)) { 
						$self->$attribute($c->{$file}->{$attribute});
					}
   				}
  			}
		}
	}

	die "Need to specify 'dsn', 'user', and 'password' either when you create the object or by passing in a configuration file in 'conf'!" 
		unless defined $self->dsn and defined $self->user and defined $self->password;
}

=head1 NAME

DBIx::Raw - The great new DBIx::Raw!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use DBIx::Raw;

    my $foo = DBIx::Raw->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

crypt_salt

=head1 SUBROUTINES/METHODS

=head2 raw

$db->raw([]);
$db->raw(query=>);
decrypt * 
encrypt *
=cut

sub raw {
	my $self = shift;

	my $params = $self->_params(@_);

	my (@return_values, $return_type);
	$self->sth($self->dbh->prepare($params->{query})) or $self->_perish($params);

	#if user asked for values to be encrypted
	if($params->{encrypt}) {
		$self->_crypt($params);
	}

	$self->_query($params);

	if(not defined wantarray) { 
		$self->sth->finish or $self->_perish($params);
		return;
	}
	elsif(wantarray) { 
		$return_type = 'array';	
	}
	else { 
		$return_type = 'scalar';	

		if($params->{query} =~ /SELECT\s+(.*?)\s+FROM/i) { 
			my $match = $1;
			my $num_commas=()= $match =~ /,/g;
			my $num_stars=()= $match =~ /\*/g;

			if($num_commas > 0 or $num_stars > 0) { $return_type = 'hash' }
		}
	}

	if($params->{query} =~ /^(\n*?| *?|\r*?)UPDATE /si) {
  		my $return_value = $self->sth->rows();
		push @return_values, $return_value;
	}
	elsif(($params->{query} =~ /SELECT /sig) || ($params->{query} =~ /SHOW /sig)) {
  		unless($params->{query} =~ /INSERT INTO (.*?)SELECT /sig) {
  			if($return_type eq 'hash') {
				$params->{href} = $self->sth->fetchrow_hashref;
				$self->_crypt($params);

  				push @return_values, $params->{href};
			}
			else {
				@return_values = $self->sth->fetchrow_array() or $self->_perish($params);

				if($params->{decrypt}) {
					$params->{return_values} = \@return_values;
					$self->_crypt($params);
				}
			}
		} 
	} 

	$self->sth->finish or $self->_perish($params);

	unless($return_type eq 'array') {
  		return $return_values[0];
	}
	else {
  		return @return_values;
	}
}

=head2 array

=cut

sub array {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($r,@a);

	# Get the Array of results:
	$self->_query($params);
	while(($r) = $self->sth->fetchrow_array()){
		if($params->{decrypt}) { 
	  		$r = $self->_decrypt($r);
		} 	
	
		push @a, $r;
	}

	return \@a;
}

sub aoh {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href,@a);

	$self->_query($params);
	while($href=$self->sth->fetchrow_hashref){
		$params->{href} = $href;
		$self->_crypt($params);
  		push @a, $href;
	}

	return \@a;
}

=head2 hash_of_hashes

#pass in href and add to it
=cut

sub hoh {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href);

	my $hoh = $params->{href}; #if hashref is passed it, it will just add to it

	$self->_query($params);

	while($href=$self->sth->fetchrow_hashref){
		$params->{href} = $href;
		$self->_crypt($params);
		$hoh->{$href->{$params->{key}}} = $href;
	}

	return $hoh;
} 

sub hoaoh {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href);

	my $hoa = $params->{href}; #if hashref is passed it, it will just add to it

	$self->_query($params);

	while($href=$self->sth->fetchrow_hashref){
		$params->{href} = $href;
		$self->_crypt($params);
		push @{$hoa->{$href->{$params->{key}}}},$href;
	}

	return $hoa;
}

sub hash {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href);

	my $hash = $params->{href}; #if hash is passed it, it will just add to it

	$self->_query($params);

	while($href=$self->sth->fetchrow_hashref){
		$params->{href} = $href;
		$self->_crypt;
		$hash->{$href->{$params->{key}}} = $href->{$params->{val}};
	}

	return $hash;
}

sub hoa {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href);

	my $hash = $params->{href}; #if hash is passed it, it will just add to it

	$self->_query($params);

	while($href=$self->sth->fetchrow_hashref){
		$params->{href} = $href;
		$self->_crypt;
		push @{$hash->{$href->{$params->{key}}}}, $href->{$params->{val}};
	}

	return $hash;
}

#ALSO MAKE ARRAYS UPDATE
#update without using taint mode?
sub hash_update {
	my $self = shift;
	my $params = $self->_params(@_);
	my ($href);

	my @vals;
	my $string = '';
	while(my ($key,$val) = each %{$params->{hash}}) { 
		my $append = '?';
		if (ref $val eq 'SCALAR') {
			$append = $$val;
		}

		$string .= "$key=$append,";
		push @vals, $val;
	}
	$string = substr $string, 0, -1;

	push @vals, @{$params->{where_value}};

	$params->{query} = "UPDATE $params->{table} SET $string WHERE $params->{where}";
	$params->{vals} = \@vals;
	$self->_query($params);
} 

sub _params { 
	my $self = shift;

	my %params;
	unless($self->keys->{$_[0]}) {
		$params{query} = shift;
		$params{vals} = [@_];
	}
	else { 
		%params = @_;
	}

	return \%params;
}

sub _query {
	my ($self, $params) = (@_);

	$self->sth($self->dbh->prepare($params->{query})) or $self->_perish($params);

	if($params->{'vals'}){
  		$self->sth->execute(@{$params->{'vals'}}) or $self->_perish($params);
	}
	else {
  		$self->sth->execute() or $self->_perish($params);
	}
}

sub _perish { 
	my ($self, $params) = @_;
	die "ERROR: Can't prepare query.\n\n$DBI::errstr\n\nquery='" . $params->{query} . "'\n";
}

sub _crypt { 
	my ($self, $params) = @_;

	if($params->{decrypt}) { 
		my @keys;
		if($params->{decrypt} and $params->{decrypt} eq '*') { 
			if($params->{href}) { 
				@keys = keys %{$params->{href}};
			}
			else { 
				@keys = 0..$#{$params->{return_values}};
			}
		}
		else { 
			@keys = @{$params->{decrypt}};
		}

		if($params->{href}) {
			for my $key (@keys) {
				$params->{href}->{$key} = $self->_decrypt($params->{href}->{$key}) if $params->{href}->{$key};
			} 	
		}
		else { 
			for my $index (@keys) {
				$params->{return_values}->[$index] = $self->_decrypt( $params->{return_values}->[$index] ) if $params->{return_values}->[$index];
			}
		}
	}
	elsif($params->{encrypt}) { 
		my @indices; 

		if($params->{encrypt} and $params->{encrypt} eq '*') { 
			my $num_question_marks = 0;
			#don't want to encrypt where conditions! Might be buggy...should look into this more
			if($params->{query} =~ /WHERE\s+(.*)/i) { 
				$num_question_marks =()= $1 =~ /=\s*?\?/g;
			}

			@indices = 0..($#{$params->{vals}} - $num_question_marks);
		}
		else { 
			if(@{$params->{encrypt}} > 0 and $params->{encrypt}->[0] =~ /^-?\d+$/) {
				@indices = @{$params->{encrypt}};
			}
			elsif($params->{query} =~ /\s+\((.*?)\)\s+VALUES/i) { 
				my $match = $1;
				$match =~ s/\s+//g;
				my @arr = split ',', $match;

				my %hash;
				for my $i (0..$#arr) { 
					$hash{$arr[$i]} = $i;
					print "$arr[$i] is $i\n";
					#NEED COUNT HERE
					#IF MORE THAN TWO ('s, then we know! but that's as long as they're not in quotes...
					#REMOVE ANY ( or )'s that are not between '' or ""
				}

				for my $name (@{$params->{encrypt}}) { 
					push @indices, $hash{$name};
				}
			}
			elsif($params->{query} =~ /SET\s+(.*?)$/i) { 
				my $match = $1;
				$match =~ s/WHERE.*//gi;
				$match =~ s/\s+//g;
				my @arr = split ',', $match;

				my %hash;
				my $count = 0;
				for my $i (0..$#arr) { 
					$arr[$i] =~ s/=(.*)//g;
					my $temp = $1;
					$temp =~ s/\s//g;
					next unless $temp eq '?'; # if it's not in our values array, we don't care!
					$hash{$arr[$i]} = $count; 
					print "$count is $arr[$i]\n";
					$count++;
				}

				for my $name (@{$params->{encrypt}}) { 
					push @indices, $hash{$name};
				}
			}
		}

		for my $index (@indices) {
    		@{$params->{'vals'}}[$index] = $self->_encrypt( @{$params->{'vals'}}[$index] );
		}
	}
}

sub _encrypt { 
	my ($self, $text) = @_;
	return $self->crypt->encrypt($text); 
}

sub _decrypt { 
	my ($self, $text) = @_;
	return $self->crypt->decrypt($text); 
}

=head1 AUTHOR

Adam Hopkins, C<< <srchulo at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbix-raw at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBIx-Raw>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Raw


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DBIx-Raw>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Raw>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Raw>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Raw/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Adam Hopkins.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of DBIx::Raw
