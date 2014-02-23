#!/usr/bin/perl
use Gantry::Utils::Crypt;
my $c = 'asdfasdfa';
		 	my $crypt = Gantry::Utils::Crypt->new (
			        		{ 
								secret => $c
							}
			    		);
			    
			 my $crypted = $crypt->encrypt( 'hello' ) . "\n"; 
			 print "$crypted\n";
			 print $crypt->decrypt($crypted) . "\n";

			 $crypted = $crypt->encrypt("YO");

			 print "$crypted\n";
			 print $crypt->decrypt($crypted) . "\n";
