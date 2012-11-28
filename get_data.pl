#!/usr/bin/env perl
use 5.014;
use strict;

use DBI;
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new;
my $url = 'http://www.guardian.co.uk/books/table/2011/apr/21/literary-clock';

#	SQLite database
my $dbh = DBI->connect('dbi:SQLite:dbname=clock_data.db', undef, undef, {sqlite_unicode => 1, RaiseError => 1});

#	Get link
my $res = $ua->get($url)->res;

#	Parse response
if ( $res->is_status_class(200) ) {
	$res->dom('div#content table tbody tr')->each( sub {
		#	Parse table's rows		
		my $time = $_->td->[0]->text or next;
		my $quote = encode_utf8( $_->td->[1]->text );
		my $book_title = encode_utf8( $_->td->[2]->text );
		my $author = encode_utf8( $_->td->[3]->text );
		my $username = encode_utf8( $_->td->[4]->text );
		
		#	Clear time from unwanted symbols
		$time =~ s/h//gi;
		
		#	Calculate checksum
		my $checksum = md5_hex( $time . $quote . $book_title . $author );
		
		#	Check if quote already exists
		next if $dbh->selectrow_array(
			'SELECT 1 FROM `quotes` WHERE quote_checksum = ?', undef, $checksum
		);
		
		#	Save in the db		
		$dbh->do(
			'INSERT INTO `quotes` (time_string, quote, book_title, author, submited_by, submited_on, quote_checksum)
			 VALUES (?, ?, ?, ?, ?, datetime(\'now\'), ? )',
			undef,
			$time, $quote, $book_title, $author, $username, $checksum
		) or die $dbh->errstr;
	});
}
else {
	say 'Cannot get the data!';
}
