package DBIx::Raw;
use strict;
use Mouse;
use DBI;
use Config::Any;
use Gantry::Utils::Crypt;

#have an errors file to write to
has 'dsn'    => ( is => 'rw', isa => 'Any', default => undef);
has 'user'    => ( is => 'rw', isa => 'Any', default => undef);
has 'password'    => ( is => 'rw', isa => 'Any', default => undef);
has 'conf'    => ( is => 'ro', isa => 'Any', default => undef);
has 'crypt_salt'    => ( is => 'rw', isa => 'Str', default => 'xfasdfa8823423sfasdfalkj!@#$$CCCFFF!09xxxxlai3847lol13234408!!@#$_+-083dxje380-=0');

has 'crypt'    => ( 
	is => 'ro', 
	isa => 'Gantry::Utils::Crypt', 
	lazy => 1,
	default => sub { 
		my ($self) = @_;
		return Gantry::Utils::Crypt->new ( { secret => $self->crypt_salt });
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

=head1 SUBROUTINES/METHODS

=head2 raw

=cut

sub raw {
	my ($self, %params) = @_;
	my ($return_value, $return_array, @return_values);

	my $sth = $self->dbh->prepare($params{'query'}) or $self->_perish(\%params);

	#if user asked for values to be encrypted
	if($params{'encrypt'}) {
		for my $index (@{$params{'encrypt'}}) {
			#pointers????????
    		@{$params{'vals'}}[$index] = $self->_encrypt( @{$params{'vals'}}[$index] );
		}
	}


	if($params{'vals'}) {
  		$sth->execute(@{$params{'vals'}}) or $self->_perish(\%params);
	}
	else {
		$sth->execute() or $self->_perish(\%params);
	}

	return $sth if $params{'ret_sth'};
	#return $sth->fetchrow_hashref if $params{'href'};

	if($params{'query'} =~ /^(\n*?| *?|\r*?)UPDATE /si){
  		$return_value = $sth->rows();
	}
	elsif (($params{'query'} =~ /SELECT /sig) || ($params{'query'} =~ /SHOW /sig)) {
  		unless($params{'query'}=~/INSERT INTO (.*?)SELECT /sig){
  			if($params{'hashref'}) { #DOCUMENTATION?????
  				my $href = $sth->fetchrow_hashref;
	  			if($params{'decrypt'}) { 
					for my $key (@{$params{'decrypt'}}) {
			    		$href->{$key} = $self->_decrypt($href->{$key}) if $href->{$key};
					} 	
	  			}

  				return $href;
			}

    		@return_values = $sth->fetchrow_array() or $self->_perish(\%params);

			if($params{'decrypt'}) {
				for my $index (@{$params{'decrypt'}}) {
		    		$return_values[$index] = $self->_decrypt( $return_values[$index] ) if $return_values[$index];
				}
			}
    
    		if($#return_values <= 0) {
      			$return_value = $return_values[0];
    		}
			else {
      			$return_array = 1;
			}
		} 
	} 

	my $rcf = $sth->finish or $self->_perish(\%params);

	unless($return_array) {
  		return $return_value;
	}
	else{
  		return @return_values;
	}
}

sub _perish { 
	my ($self, $params) = @_;
	die "ERROR: Can't prepare query.\n\n$DBI::errstr\n\nquery='" . $params->{query} . "'\n";
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
