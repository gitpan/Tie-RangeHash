package List::SkipList::StringRangeNode;

require 5.006;

use strict;
use warnings; ## ::register __PACKAGE__;

use Carp;
no Carp::Assert;

our @ISA = qw( List::SkipList::Node );

sub key_cmp {
  my $self = shift;
  assert( UNIVERSAL::isa($self, __PACKAGE__) ), if DEBUG;

  my $left  = $self->key;
  my $right = shift;

  unless (defined $left) { return -1; }

  if ($right =~ /,/) {

    my ($lo, $hi) = map { $_ || "" } split /,/, $left;
    $hi = "", unless (defined $hi);
    my ($lr, $hr) = map { $_ || "" } split /,/, $right;
    $hr = "", unless (defined $hr);

    my $lo_cmp = ($hr eq "") ?
      (($lo ne "") ? -1 : -1 ) : # ?
      (($lo ne "") ? ($lo cmp $hr) : -1);
    my $lr_cmp = ($lr eq "") ? 
      (($lo ne "") ? 1 : 0 ) :
      (($lo ne "") ? ($lo cmp $lr) : -1);
    my $hi_cmp = ($lr eq "") ? 
      (($hi ne "") ? 1 : 1 ) :
      (($hi ne "") ? ($hi cmp $lr) : 1);
    my $hr_cmp = ($hr eq "") ?
      (($hi ne "") ? -1 : 0 ) :
      (($hi ne "") ? ($hi cmp $hr) : 1);

    if ( (($lo_cmp==-1) && ($hi_cmp==1) && (!$lr_cmp) && (!$hr_cmp)) ||
         ((!$lo_cmp) && (!$hi_cmp) && (!$lr_cmp) && (!$hr_cmp)) ){
      return 0;
    } elsif  (($lo_cmp==1) && ($hi_cmp==1) &&
	      ($lr_cmp==1) && ($hr_cmp==1)) {
      return 1;
    } elsif  (($lo_cmp==-1) && ($hi_cmp==-1) &&
	      ($lr_cmp==-1) && ($hr_cmp==-1)) {
      return -1;
    } else {
      confess "Overlapping ranges";
    }

  } else {

    my ($lo, $hi) = split /,/, $left;

    my $lo_cmp = ($lo ne "") ? ($lo cmp $right) : -1;
    my $hi_cmp = ($hi ne "") ? ($hi cmp $right) : 1;

    assert( $hi_cmp >= $lo_cmp ), if DEBUG;

    if (($lo_cmp <= 0) && ($hi_cmp >= 0)) {
      return 0;
    } elsif ($hi_cmp < 0) {
      return -1;
    } elsif ($lo_cmp > 0) {
      return 1;
    }
  }
}

sub validate_key {
  my $self = shift;
  assert( UNIVERSAL::isa($self, __PACKAGE__) ), if DEBUG;

  return 1;
}

1;

package List::SkipList::NumericRangeNode;

require 5.006;

use strict;
use warnings; # ::register __PACKAGE__;

use Carp;
no Carp::Assert;

our @ISA = qw( List::SkipList::Node );

sub key_cmp {
  my $self = shift;
  assert( UNIVERSAL::isa($self, __PACKAGE__) ), if DEBUG;

  my $left  = $self->key;
  my $right = shift;

  unless (defined $left) { return -1; }

  if ($right =~ /,/) {

    my ($lo, $hi) = map { $_ || "" } split /,/, $left;
    $hi = "", unless (defined $hi);
    my ($lr, $hr) = map { $_ || "" } split /,/, $right;
    $hr = "", unless (defined $hr);

    my $lo_cmp = ($hr eq "") ?
      (($lo ne "") ? -1 : -1 ) : # ?
      (($lo ne "") ? ($lo <=> $hr) : -1);
    my $lr_cmp = ($lr eq "") ? 
      (($lo ne "") ? 1 : 0 ) :
      (($lo ne "") ? ($lo <=> $lr) : -1);
    my $hi_cmp = ($lr eq "") ? 
      (($hi ne "") ? 1 : 1 ) :
      (($hi ne "") ? ($hi <=> $lr) : 1);
    my $hr_cmp = ($hr eq "") ?
      (($hi ne "") ? -1 : 0 ) :
      (($hi ne "") ? ($hi <=> $hr) : 1);

#    print join(" ", $hi, $hr, $lo_cmp, $lr_cmp, $hi_cmp, $hr_cmp), "\n"; 

    if ( (($lo_cmp==-1) && ($hi_cmp==1) && (!$lr_cmp) && (!$hr_cmp)) ||
         ((!$lo_cmp) && (!$hi_cmp) && (!$lr_cmp) && (!$hr_cmp)) ){
      return 0;
    } elsif  (($lo_cmp==1) && ($hi_cmp==1) &&
	      ($lr_cmp==1) && ($hr_cmp==1)) {
      return 1;
    } elsif  (($lo_cmp==-1) && ($hi_cmp==-1) &&
	      ($lr_cmp==-1) && ($hr_cmp==-1)) {
      return -1;
    } else {
      confess "Overlapping ranges";
    }

  } else {

    my ($lo, $hi) = split /,/, $left;

    my $lo_cmp = ($lo ne "") ? ($lo <=> $right) : -1;
    my $hi_cmp = ($hi ne "") ? ($hi <=> $right) : 1;

    assert( $hi_cmp >= $lo_cmp ), if DEBUG;

    if (($lo_cmp <= 0) && ($hi_cmp >= 0)) {
      return 0;
    } elsif ($hi_cmp < 0) {
      return -1;
    } elsif ($lo_cmp > 0) {
      return 1;
    }
  }
}

sub validate_key {
  my $self = shift;
  assert( UNIVERSAL::isa($self, __PACKAGE__) ), if DEBUG;
  my $key = shift;
  return ($key =~ /\-?\d+(\.\d+)?(,\-?\d+(\.\d+)?)?/);
}

1;

package Tie::RangeHash;

require 5.006;

use strict;
use warnings; # ::register __PACKAGE__;

use Carp;
no Carp::Assert;
use List::SkipList 0.40;

our $VERSION   = '1.00_2';

BEGIN
  {

    # Define public constants

    *TYPE_STRING = sub () { return 'List::SkipList::StringRangeNode'; };
    *TYPE_NUMBER = sub () { return 'List::SkipList::NumericRangeNode'; };
}

sub import

# A rudimentary 'import' method for the module (Some day we''ll do something
# more important with this)

  {
    my $class       = shift;
    my $version_req = shift || 0;
    if ($version_req gt $VERSION)
      {
	croak "Using Tie::RangeHash $VERSION when $version_req was requested";
      }
  }


sub new {
  my $class = shift;


  my $self = {
    SKIPLIST  => undef,
    NODECLASS => TYPE_STRING,
  };

  bless $self, $class;

  {
    my %ARGLIST = ( map { $_ => 1 } qw( Type ) );
    my %args;

    if (ref($_[0]) eq "HASH") {
      %args = %{$_[0]};
    } else {
      %args = @_;
    }

    foreach my $arg_name (keys %args) {
      if ($ARGLIST{$arg_name}) {
	my $method = "_set_" . $arg_name;
	$self->$method( $args{ $arg_name } );
      } else {
	croak "Invalid parameter name: ``$arg_name\'\'";
      }
    }
  }

  $self->{SKIPLIST} = new List::SkipList( 
    node_class => $self->{NODECLASS},
  );

  return $self;
}

sub _set_Type {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;

  my $node_class = shift;
  my $node = new $node_class;
  assert( UNIVERSAL::isa($node, "List::SkipList::Node" ) ), if DEBUG;

  $self->{NODECLASS} = $node_class;
}

sub fetch {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  my $key = shift;
  return $self->{SKIPLIST}->find( $key );
}

sub fetch_key {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;

  my $key = shift;
  my ($x, $update_ref) = $self->{SKIPLIST}->_search($key);
  if ($x->key_cmp($key) == 0) {
    return (wantarray) ? ($x->key => $x->value) : $x->key;
  } else {
    return;
  }
}

sub key_exists {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  my $key = shift;
  $self->{SKIPLIST}->exists($key);
}

sub add {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  my ($key, $value) = @_;
  $self->{SKIPLIST}->insert($key, $value);
}

sub clear {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  $self->{SKIPLIST}->clear;
}

sub remove {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  my $key = shift;

  # We could simply call $self->{SKIPLIST}->delete( $key ), but we
  # want to make sure that the user has specified the exact key that
  # is used (to keep compatability with previous versions)

  my ($x, $update_ref) = $self->{SKIPLIST}->_search($key);
  if ($x->key eq $key) {
    return $self->{SKIPLIST}->delete( $key );
  } else {
    return;
  }
}

sub first_key {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  return $self->{SKIPLIST}->first_key;
}

sub next_key {
  my $self = shift;
  assert( UNIVERSAL::isa($self, "Tie::RangeHash") ), if DEBUG;
  my $last_key = shift;
  return $self->{SKIPLIST}->next_key( $last_key );
}

BEGIN
  {
    # make aliases to methods...
    no strict;
    *TIEHASH = \&new;
    *STORE   = \&add;
    *FETCH   = \&fetch;
    *EXISTS  = \&key_exists;
    *CLEAR   = \*clear;
    *DELETE  = \*remove;
    *FIRSTKEY = \*first_key;
    *NEXTKEY = \*next_key;
  }

1;

__END__

=head1 NAME

Tie::RangeHash - Allows hashes to associate values with a range of keys

=head1 REQUIREMENTS

C<Carp::Assert> and C<List::SkipList> are required.  Otherwise it uses
standard modules.

=head2 Installation

Installation is pretty standard:

  perl Makefile.PL
  make
  make test
  make install

Note that when you run the tests, you will see warnings. That is intentional.

=head1 SYNOPSIS

  use Tie::RangeHash;

  tie %hash, 'Tie::RangeHash';

  $hash{'A,C'} = 1;
  $hash{'D,F'} = 2;
  $hash{'G,K'} = 3;

  $hash{'E'};           # returns '2'
  $hash{'BB'};          # returns '1'

  $hash{'KL'};          # returns nothing ('undef')

There is also an object-oriented interface:

  $hash = new Tie::RangeHash;

  $hash->add('A,C', 1);
  $hash->add('G,I', 2);

  $hash->fetch('H');    # returns '2'

=head1 DESCRIPTION

This module allows hashes to associate a value with a I<range> of keys rather
than a single key.

For example, you could pass date ranges to the hash and then query it with
a specific date, like so:

  $cost{'1999-12-15,2000-01-14'} = 150;
  $cost{'2000-01-15,2000-02-14'} = 103;
  $cost{'2000-02-15,2000-03-14'} =  97;

and then query the cost on a specific date:

  $this_cost = $cost{'2000-02-08'};

Numeric key ranges can also be used:

  tie %hash, 'Tie::RangeHash', {
    Type => Tie::RangeHash::TYPE_NUMBER
  };

  $hash{'1.4,1.8'}      = 'Jim';
  $hash{'1.0,1.399999'} = 'Ned';
  $hash{'1.800001,2.0'} = 'Boo';

Custom comparison routines to support alternate datatypes can be
implemented by specifying a new node type for C<List::SkipList>.

I<Information to be added>.

=head2 Object-Oriented Interface

C<Tie::RangeHash> has an object-oriented interface as an alternative to
using a tied hash.

=over

=item new

Creates a new object.

  $OBJ = Tie::RangeHash->new( %ATTR );

C<%ATTR> is a hash containing the attributes described above. This is the same
as the C<TIEHASH> method used for tied hashes.

=item add

Adds a new key/value pair to the object.

  $OBJ->add( $KEY, $VALUE );

C<$KEY> may be a string value in the form of C<low,high> or an array reference
in the form of C<[ low, high ]>. This is the same as the C<STORE> method used
for tied hashes.

=item fetch

  $VALUE = $OBJ->fetch( $KEY );

Returns the value associated with C<$KEY>. (C<$KEY> may be in the form of
C<low,high> or a key between C<low> and C<high>.) This is the same as the
C<FETCH> method used for tied hashes.

=item fetch_key

  $REAL_KEY = $OBJ->fetch( $KEY );

  ($REAL_KEY, $VALUE) = $OBJ->fetch( $KEY );

Like C<fetch>, but it returns the I<key range> that was matched rather
than the value. If it is called in an array context, it will return the
key and value.

=item key_exists

  if ($OBJ->key_exists( $KEY )) { .. }

Returns C<true> if C<$KEY> has been defined (even if the value is C<undef>).
(C<$KEY> is in the same form as is used by the C<fetch> method.) This is the
same as the C<EXISTS> method used for tied hashes.

It is called C<key_exists> so as not to be confused with the C<exists> keyword
in Perl.

=item clear

  $OBJ->clear();

Deletes all keys and values defined in the object. This is the same as the
C<CLEAR> method used for tied hashes.

=item remove

  $VALUE = $OBJ->remove( $KEY );

Deletes the C<$KEY> from the object and returnes the associated value.
(C<$KEY> is in the same form as is used by the C<fetch> method.)  If
C<$KEY> is not the exact C<low,high> range, a warning will be emitted.
This is the same as the C<DELETE> method used for tied hashes.

It is called C<remove> so as not to be confused with the C<delete>
keyword in Perl.

=item first_key

  $KEY = $OBJ->first_key();

=item next_key

  $KEY = $OBJ->next_key($LAST_KEY);

=back

=head2 Implementation Notes

Internally, the hash uses skip lists.  Skip lists are an alternative
to binary trees.  For more information, see C<List::SkipList>.

=head1 KNOWN ISSUES

The is a new version of the module and has behaves differently
compared to older versions.  This is due to using the
C<List::SkipList> module for maintaining the underlying data rather
than re-implementing it.  While this improves the maintainability with
the code, it increases incompatability with previous versions.

Some of the changes include:

=over

=item Overlapping keys cause fatal errors instead of warnings

Because the key comparison is now performed in the skip list node,
there is no obvious way for it to give a warning and return a
meaningful result.  So instead the code dies.  If you code relies on
the possibility of using overlapping keys, then it may be more
appropriate to have it test the code:

  eval {
    $hash{'111,999'} = $value;
  };

This error can also occur by merely testing a hash, so it is important
to run some checks if you are testing hash ranges:

  eval {
    if ($hash{'111,999'} == $value) { ... }
  }

=item Keys can be redefined

Nodes can now be redefined.  For example:

  $hash{'1,3'} = $value;
  ...
  $hash{'1,3'} = $new_value;
  ...
  $hash{'2'}   = $new_value;

Note that a range is no longer required.

=item Non-range keys can be added.

When inserting a key, C<$hash{'x'}> will be treated like C<$hash{'x,x'}>.

=item Open-ended ranges are allowed.

Open ended ranges are now supported.  So the following can be added:

  $hash{',10'} = $upper_bound;
  $hash{'11,'} = $lower_bound;

=item array references can no longer be keys.

The following is I<not> supported anymore:

  $hash{ \@array ) = $value;

=item warnings no longer registered.

Warning registration is no longer used.  This may change in the future.

=item Custom separators and comparisons are not supported.

Only commas can be used as separators.

To customize separators and comparisons, you will have to specify a
custom C<List::SkipList::Node> method.

=back

See the L<Changes> file for a more complete list of incompatabilities.

If your code does not rely on these quirks, then you should be able to
substitute with no problems.

=head1 SEE ALSO

A module with similar functionality for numerical values is C<Array::IntSpan>.

C<List::SkipList> for more information on skip lists.

=head1 AUTHOR

Robert Rothenberg <rrwo at cpan.org>

=head2 Acknowledgements

Charles Huff <charleshuff atdecisionresearch.com> for suggestions and
bug reports.

Sam Tregar <sam at tregar.com> for optimization suggestions.

Various Perl Monks <http://www.perlmonks.org> for advice and code snippets.

=head2 Suggestions and Bug Reporting

Feedback is always welcome.  Please use the CPAN Request Tracker at
L<http://rt.cpan.org> to submit bug reports.

=head1 LICENSE

Copyright (C) 2000-2004 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
