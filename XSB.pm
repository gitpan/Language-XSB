package Language::XSB;

our $VERSION = '0.03';

use strict;
use warnings;

use Carp;

require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'query' => [ qw( xsb_setquery
				      xsb_clearquery
				      xsb_query
				      xsb_next
				      xsb_result
				      xsb_cut
				      xsb_findall ) ]);

our @EXPORT_OK = ( qw(xsb_nreg),
		   map { @{$EXPORT_TAGS{$_}} } keys(%EXPORT_TAGS));
our @EXPORT = ();

use Language::Prolog::Types qw(F L C isV);
use Language::XSB::Config;
use Language::XSB::Base;

sub xsb_nreg () { 7 };

sub callback_perl {
    my $cmd;
    while(defined($cmd=getreg_int(0))) {
	# use Language::XSB::Register;
	# print STDERR "callback_perl 0 regs: @XsbReg\n";
	if ($cmd==4) {
	    my $sub=getreg(3);
	    my $args=getreg(4);
	    go();
	    # print STDERR "callback_perl 1 regs: @XsbReg\n";
	    my $result;
	    eval {
		ref($sub) and
		    die "subroutine name '$sub' is not a string";
		UNIVERSAL::isa($args, 'ARRAY') or
			die "args '$args' is not a list";
		# print STDERR "calling sub $sub ( @{$args} )\n";
		package main;
		no strict 'refs';
		$result=[$sub->(@{$args})];
	    };
	    my $exception=$@;
	    while(defined(getreg_int(0))) {
		carp "query '".eval{getreg(1)}."' still open, closing";
		xsb_cut();
	    };
	    setreg_int(0, 5);
	    go();
	    # print STDERR "callback_perl 2 regs: @XsbReg\n";
	    getreg_int(0)==6 or
		die "unexpected command sequence";
	    if(defined $result) {
		setreg(5, $result);
	    }
	    else {
		setreg(6, $exception);
	    }
	    go();
	    # print STDERR "callback_perl 3 regs: @XsbReg\n";
	}
	else {
	    die "unexpected command sequence, expecting 4 or none, found $cmd";
	}
    }
}

sub ok {
    go();
    callback_perl();
    regtype(1)!=1
}

sub xsb_setquery (@) {
    defined getreg_int(0) and
	die "unexpected command sequence";
    while (regtype(1)!=1) {
	carp "query '".eval{getreg(1)}."' still open, closing";
	xsb_cut();
    }
    return grep { isV $_ } @{setreg(1,C(',',@_))};
}

sub xsb_query () {
    getreg(1);
}

sub xsb_next () {
    defined getreg_int(0) and
	die "unexpected command sequence";
    regtype(1)==1 and
	croak "not in a query";
    setreg_int(0, 1);
    ok()
}

sub xsb_result () {
    defined getreg_int(0) and
	die "unexpected command sequence";
    regtype(1)==1 and
	croak "not in a query";
    my $r2=regtype(2);
    $r2==3 and return ();
    $r2==7
	or croak "result is not ready, call xsb_next first";
    getreg(2)->fargs
}

sub xsb_clearquery () {
    defined getreg_int(0) and
	die "unexpected command sequence";
    regtype(1)==1 and
	croak "query not set";
    setreg_int(0, 2);
    ok();
}

sub xsb_cut () {
    defined getreg_int(0) and
	die "unexpected command sequence";
    regtype(1)==1 and
	croak "not in a query";
    setreg_int(0, 2);
    ok();
}

sub xsb_findall (@) {
  my @r;
  xsb_setquery(@_);
  push (@r, L(xsb_result)) while xsb_next;
  return @r
}

my $perlcallxsb;
for my $path (@INC) {
    next if ref $path;
    my $name=$path.'/Language/XSB/xsblib/perlcallxsb';
    $perlcallxsb=$name, last if -f $name.'.O';
}

xsb_init($perlcallxsb||'perlcallxsb');
callback_perl();

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Language::XSB - use XSB from Perl.

=head1 SYNOPSIS

    use Language::XSB ':query';
    use Language::Prolog::Types::overload;
    use Language::Prolog::Sugar vars=>[qw(X Y Z)],
                                functors=>{equal => '='},
                                functors=>[qw(is)],
                                chains=>{plus => '+',
					 orn => ';'};

    xsb_setquery( equal(X, 34),
                  equal(Y, -12),
                  is(Z, plus( X,
			      Y,
			      1000 )));

    while(xsb_next()) {
	printf("X=%d, Y=%d, Z=%d\n", xsb_result())
    }

    print join("\n", xsb_findall(orn(equal(X, 27),
				     equal(X, 45))));

=head1 ABSTRACT

Language::XSB provides a bidirectional interface to XSB
(L<http://xsb.sourceforge.net>).

=head1 DESCRIPTION

From the XSB manual:

  XSB is a research-oriented Logic Programming and Deductive
  Database System developed at SUNY Stony Brook.  In addition to
  providing all the functionality of Prolog, it contains
  features not usually found in Logic Programming Systems such
  as evaluation according to the Well Founded Semantics through
  full SLG resolution, constraint handling for tabled programs,
  a compiled HiLog implementation, unification factoring and
  interfaces to other systems such as ODBC, C, Java, Perl, and
  Oracle

This package implements a bidirectional interface to XSB, thats
means that Perl can call XSB that can call Perl back that can
call XSB again, etc.:

  Perl -> XSB -> Perl -> XSB -> ...

(Unfortunately, you have to start from Perl, C<XSB-E<gt>Perl-E<gt>...>
is not possible.)

The interface to XSB is based on the objects created by the
package L<Language::Prolog::Types>. You can also use
L<Language::Prolog::Sugar> package, a front end for the types
package to improve the look of your source (just some syntactic
sugar).

To make queries to XSB you have to set first the query term with
the function C<xsb_setquery>, and then use C<xsb_next> and
C<xsb_result> to iterate over it and get the results back.

Only one query can be open at any time, unless when Perl is
called back from XSB, but then the old query is not visible.

=head2 EXPORT_TAGS

In this versions there is only one tag to import all the
soubrutines in your script or package:

=over 4

=item C<:query>

=over 4

=item C<xsb_setquery(@terms)>

sets the query term, if multiple terms are passed, then the are
first chained with the ','/2 functor and the result stored as
the query.

It returns the free variables found in the query.

=item C<xsb_query()>

returns the current query, variables are bound to its current value if
C<xsb_next> has been called with success.

=item C<xsb_next()>

iterates over the query and returns a true value if a new
solution is found.

=item C<xsb_result()>

after calling xsb_next, this soubrutine returns the values
assigned to the free variables in the query.

=item C<xsb_cut()>

ends an unfinished query, similar to XSB (or Prolog) cut
C<!>. As the real cut in XSB, special care should be taken to
not cut over tables.

=item C<xsb_findall(@terms)>

does it all in one call (set the query, iterate over it and
return a list of lists with the results found).

=item C<xsb_clearquery()>

an alias for C<xsb_cut>.

=back

=back

=head2 BUGS

This is alpha software so there should be some of them.

clpr is not callable from Perl, an FPE signal will raise.

no threads support.


=head1 SEE ALSO

L<Language::Prolog::Types>, L<Language::Prolog::Types::overload>
and L<Language::Prolog::Sugar> for instructions on creating
Prolog (or XSB) terms from Perl.

For XSB and Prolog information see L<xsb(1)>, the XSB website at
L<Sourceforge|http://xsb.sourceforge.net>, the FAQ of
L<comp.lang.prolog|news:comp.lang.prolog> and any good Prolog
book, I personally recommend you Ivan Bratko L<PROLOG
Programming for Artificial Intelligence> as an introduction to
Prolog.

If you want to look at the inners details of this package then
take a look at L<Language::XSB::Base> and
L<Language::XSB::Register>.


=head1 AUTHOR

Salvador Fandiño, E<lt>sfandino@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Salvador Fandiño

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
