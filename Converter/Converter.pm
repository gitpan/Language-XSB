package Language::XSB::Converter;

our $VERSION='0.01';

use strict;
use warnings;

use Carp;
use Language::Prolog::Types qw(F A L);

my %conv=( ARRAY => 'array2prolog',
	   HASH => 'hash2prolog',
	   SCALAR => 'scalar2prolog',
	   GLOB => 'glob2prolog',
	   CODE => 'code2prolog',
	   '' => 'term2prolog');

sub perl_ref2prolog {
    my ($class, $ref)=@_;
    my $method=$conv{ref($ref)} || 'object2prolog';
    my $r=$class->$method($ref);
    warn ("prolog term: $r\n");
    $r
}

sub term2prolog { A($_[1]) }

sub array2prolog { L(@{$_[1]}) }

sub hash2prolog {
    my $h=$_[1];
    L(map { F('=>', $_, $h->{$_}) } keys %{$h}) }

sub scalar2prolog { F("\\", $ {$_[1]}) }

sub glob2prolog { A($ {$_[1]}) }

sub code2prolog { A($_[1]) }

sub object2prolog {
    my ($class, $obj)=@_;
    UNIVERSAL::can($obj, "convert2prolog_term") and
	return $obj->convert2prolog_term;

    UNIVERSAL::isa($obj, 'ARRAY') and
	return F('perl_object', ref($obj), L(@{$obj}));

    UNIVERSAL::isa($obj, 'HASH') and
	return F('perl_object', ref($obj), $class->hash2prolog($obj));

    UNIVERSAL::isa($obj, 'SCALAR') and
	return F('perl_object', ref($obj), $class->scalar2prolog($obj));

    UNIVERSAL::isa($obj, 'GLOB') and
	return F('perl_object', ref($obj), $class->glob2prolog($obj));

    UNIVERSAL::isa($obj, 'CODE') and
        return F('perl_object', ref($obj), $class->code2prolog($obj));

    croak "unable to convert reference '".ref($obj)."' to prolog term";
}

__END__

=head1 NAME

Language::XSB::Converter - Converts from Perl objects to Prolog terms

=head1 SYNOPSIS

  package MyModule;

  use Language::XSB::Converter;
  our @ISA=qw(Language::XSB::Converter);

  sub hash2prolog {
      ...
  }

  sub scalar2prolog {
      ...
  }

  etc.

=head1 ABSTRACT

This module implements functions used internally by
Language::XSB::Base to convert from Perl objects and references to
Prolog terms.

=head1 DESCRIPTION

You should only use this module if you want to change the default
conversions performed when passing data between Perl and Prolog.

To override the default conversions, you have to create a new class
with the method C<perl_ref2prolog> and set
C<$Language::XSB::Base::converter> to one instance of your class.

If you make your converter class inherit L<Language::XSB::Converter>,
you can change conversions only for selected types overriding those
methods:

=over 4

=item C<$conv-E<gt>hash2prolog($hash_ref)>

converts a Perl hash reference to a Prolog term.

It creates a list of functors '=>/2' with the key/value pairs as
arguments:

  [ '=>'(key0, value0), '=>'(key1, value1), ... ]


=item C<$conv-E<gt>scalar2prolog($scalar_ref)>

converts a Perl scalar reference to a Prolog term.

=item C<$conv-E<gt>glob2prolog($glob_ref)>

converts a Perl glob reference to a Prolog term.

=item C<$conv-E<gt>code2prolog($code_ref)>

converts a Perl sub reference to a Prolog term.

=item C<$conv-E<gt>object2prolog($object_ref)>

converts any other Perl object to a Prolog term.

Default implementation looks for a method called
C<convert2prolog_term> in the object class.

If this fails, it reverts to dump the internal representation of the
object as the functor:

  perl_object(class, state)

C<state> is the conversion of the perl datatype used to represent the
object (array, hash, scalar, glob or sub).

=back


=head2 EXPORT

None by default. This module has an OO interface.



=head1 SEE ALSO

L<Language::XSB::Base>, L<Language::Prolog::Types>

=head1 AUTHOR

Salvador Fandiño, E<lt>sfandino@yahoo.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Salvador Fandiño

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
