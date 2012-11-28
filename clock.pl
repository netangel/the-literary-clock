#!/usr/bin/env perl
use utf8;
use Mojolicious::Lite;
use Mojolicious::Sessions;
use DBI;

my $config = plugin 'Config';
my $sessions = Mojolicious::Sessions->new();
$sessions->default_expiration( $config->{session_exp} );

helper dbh => sub {
	return DBI->connect('dbi:SQLite:dbname='.$config->{db_file}, undef, undef, {sqlite_unicode => 1, RaiseError => 1});
};

get '/' => sub { shift->redirect_to( '/' . $config->{language} ) };

get '/:lang' => [ lang => [qw/ ru en /] ] => sub {
	my $self = shift;
	my $lang = $self->stash('lang') || $config->{language};
	$self->session( lang => $lang );

	my $times_array = $self->dbh->selectcol_arrayref(
		'SELECT DISTINCT time_string FROM quotes WHERE language = ?',
		undef, $lang,
	) || [];

	$self->render( 'index_' . $lang, thanks => $self->session('thanks'), times_array => $times_array );
};

get '/quote' => sub {
	my $self = shift;
	my $lang = $self->param('lang') || $config->{language};
	my $time = $self->param('time') || sprintf("%02d:%02d:%02d", (localtime)[0..2]);

	my $quotes = $self->dbh->selectall_arrayref(
		"SELECT row_id, time_string, quote, author, book_title, submited_by
		 FROM `quotes` WHERE time_string = ? AND language = ? AND approved = 1",
		{ Slice => {} },
		$time, $lang
	) || [];
	
	if ( !@$quotes ) {
		$quotes = $self->dbh->selectall_arrayref(
			"SELECT row_id, time_string, quote, author, book_title, submited_by
			 FROM `quotes` WHERE time_string = ( SELECT MAX(time_string) 
				FROM `quotes` WHERE time_string < ? AND language = ? AND approved = 1 ) 
					AND language = ? AND approved = 1",
			{ Slice => {} },
			$time, $lang, $lang
		) || [];
	}
	
	my $next_time = $self->dbh->selectrow_array(
		"SELECT MIN(time_string) FROM `quotes` WHERE time_string > ? AND language = ? AND approved = 1",
		undef,
		$time, $lang
	) || $time;
	
	$self->render( json => { quotes => $quotes, next_time => $next_time } );
};

post '/add' => sub {
	my $self = shift;
	my $lang = $self->param('lang') || $config->{language};

	$self->redirect_to('/#add-quote')
		unless ( $self->param('add-quote-username') && $self->param('add-quote-title')
							&& $self->param('add-quote-author') && $self->param('add-quote-text') 
							&& $self->param('add-quote-time') );

	$self->redirect_to('/#add-quote') 
		unless $self->param('add-quote-time') =~ /(\d+)[-:](\d+)[-:]?(\d+)?/;

	my $time = sprintf( "%02d:%02d:%02d", $1, $2, $3 || 0 );

	my $title = $self->param('add-quote-title'); $title =~ s/\.$//;
	my $author = $self->param('add-quote-author'); $author =~ s/\.$//;

	$self->dbh->do(
		"INSERT INTO `quotes` (time_string, quote, author, book_title, submited_by, submited_on, language)
			VALUES ( ?, ?, ?, ?, ?, datetime('now', 'localtime'), ? )",
		undef,
		$time,
		$self->param('add-quote-text'),
		$author,
		$title,
		$self->param('add-quote-username'),
		$lang
	);

	if ( $self->param('remember_me') ) {
		$self->session( remember_me => 1 );
		$self->session( username => $self->param('add-quote-username') );
	}

	$self->session( thanks => 1 );
	$self->redirect_to( "/$lang" ); 
};

under sub {
	my $self = shift;

	if ( $self->param('admin_passwd') eq $config->{admin_passwd} ) {
		$self->session( is_admin => 1 );
	}

	return 1 if $self->session('is_admin') == 1; 
	return $self->render('authorize');
};

any '/queue' => sub {
	my $self = shift;

	my $quotes = $self->dbh->selectall_arrayref(
		'SELECT row_id, time_string, quote, author, book_title, submited_by, submited_on
		 FROM `quotes` WHERE approved = ? ORDER BY submited_on ASC',
		 { Slice => {} },
		 0
	) || [];

	return $self->render( $config->{language} eq 'ru' ? 'queue_ru' : 'queue_en', quotes => $quotes );
};

get '/queue/:action/:id' => [ action => [qw/ add delete /] ] => sub {
	my $self = shift;
	if ( $self->stash('action') eq 'add' ) {
		$self->dbh->do( 'UPDATE `quotes` SET approved = 1 WHERE row_id = ?', undef, $self->stash('id') );	
	}
	else {
		$self->dbh->do( 'DELETE FROM `quotes` WHERE row_id = ?', undef, $self->stash('id') );
	}
	$self->redirect_to('/queue');
};

app->secret( $config->{secret} );
app->start;


