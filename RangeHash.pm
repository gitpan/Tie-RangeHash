package Tie::RangeHash;

require 5.006;

use strict;

use warnings::register __PACKAGE__;
use Carp;

our $VERSION   = '0.72';
our @ISA       = qw( );

no integer;

BEGIN
  {

    use integer;

    # Define public constants

    *TYPE_STRING = sub () { 1 };        # Indicates value is a string
    *TYPE_NUMBER = sub () { 2 };        # Indicates value is a number
    *TYPE_USER   = sub () { 3 };        # User defined method to compare values

    # Define internal constants

    *SEPARATOR   = sub () { "," };      # Default separator character

    # Node structure indices. See _new_node() below for more details.

    *KEY_LOW     = sub () { 0 };        # Lower bound of node's key
    *KEY_HIGH    = sub () { 1 };        # Upper bound of node's key
    *NODE_LEFT   = sub () { 2 };        # Child node to the left
    *NODE_RIGHT  = sub () { 3 };        # Child node to the right
    *COUNT_LEFT  = sub () { 4 };        # Number of children to the left
    *COUNT_RIGHT = sub () { 5 };        # Number of children to the right
    *VALUE       = sub () { 6 };        # Value of the node

    # Object indices. Perhaps this is a moot optimization?

    *ROOT_NODE   = sub () { 0 };        # Root node of the tree
    *CMP_SUB     = sub () { 1 };        # Comparison subroutine for values
    *SPLIT_REGEX = sub () { 2 };        # Regexp used to split keys
    *CMP_TYPE    = sub () { 3 };        # Comparison type (optional)
    *SPLIT_TEXT  = sub () { 4 };        # Separator text (optional)

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

sub _join_bounds

# Generate a 'low,high' key from bounds (used mainly for error messages)

  {
    my $self = shift;
    join($self->[SPLIT_TEXT], @_);
  }


sub _split_bounds

# Split a 'low,high' key into bounds. If only one value is given, we use
# 'key,key'. A key in the form of 'high,low' is changed to 'low,high' and
# a warning is given (maybe it should be fatal?).

# If called with an array reference instead of a string, use the first
# two elements as low, high keys. (Added in v0.51)

  {
    my ($self, $key) = @_;

    my ($lower_bound, $upper_bound, $extra_stuff, $cmp);

    # Is it a string or is it an array reference? Handle appropriately.

    my $key_ref = ref($key);

    if (!$key_ref)
      {
	($lower_bound, $upper_bound, $extra_stuff) =
	  split( $self->[SPLIT_REGEX], $key );
      }
    elsif ($key_ref eq "ARRAY")
      {
	($lower_bound, $upper_bound, $extra_stuff) = @$key;
      }
    else
      {
	croak "I don\'t know how to handle keys of type \`$key_ref\'";
      }

    # If only one value, treat it as 'key,key'.

    if (!defined($upper_bound))
      {
	return ($lower_bound, $lower_bound);
      }

    # While it's faster to ignore extra stuff altogether, it's better for
    # users of the module to get warnings for the few times they need them.
    # If speed is an issue, comment this out.

    elsif ( (defined($extra_stuff)) and (warnings::enabled) )
      {
	if (ref($key) eq "ARRAY") { $key = $self->_join_bounds(@$key); }
	warnings::warn
	  "Multiple separators: only the first two bounds will be used in \`$key\'";
      }

    # Make sure $lower_bound <= $upper_bound

    $cmp = $self->[CMP_SUB];

    if (&{$cmp}($lower_bound, $upper_bound) > 0)
      {
	warnings::warn "Lower and upper bounds reversed",
	  if (warnings::enabled);
	return ($upper_bound, $lower_bound);
      }

    return ($lower_bound, $upper_bound);
  }


sub _new_node

# Create a new node given lower and upper key bounds and a value.  (The node is
# an anonymous array with each value stored in the indices defined in the BEGIN
# block above.) The node's structure is as follows:
#
# KEY_LOW, KEY_HIGH are the node's lower and upper key bounds, respectively.
#
# NODE_LEFT, NODE_RIGHT are the node's children. KEY_HIGH on NODE_LEFT must
# be less than KEY_LOW, and KEY_LOW on NODE_RIGHT must be greater than
# KEY_HIGH.
#
# COUNT_LEFT, COUNT_RIGHT are the count of children on the left and
# right nodes respectively. We use these values for keeping the tree
# balanced.  See comments in _add_node() for a description of the
# tree-balancing algorithm used.
#
# VALUE is the node's value.

  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;

    unless ( (defined($lower_bound)) and (defined($upper_bound)))
      {
	croak "Cannot create a node without valid keys";
      }

    # Caveat: if we change the order of the index constants then we need
    #         to change the order here (pseudo-hashes would be nicer but
    #         they're slow, and defining each array element as different
    #         lines would probably slow down adding nodes slightly...)

    return [
	    $lower_bound, # KEY_LOW
	    $upper_bound, # KEY_HIGH
	    undef,        # NODE_LEFT
	    undef,        # NODE_RIGHT
	    0,            # COUNT_LEFT
	    0,            # COUNT_RIGHT
	    $value        # VALUE
	   ];

  }

sub _count_left

# Updates the count of children on the left node. Assumes the counts on the
# left node are updated.

  {
    my ($node) = @_;

    return $node->[COUNT_LEFT] = ($node->[NODE_LEFT]) ?
      1 + $node->[NODE_LEFT]->[COUNT_LEFT] +
	$node->[NODE_LEFT]->[COUNT_RIGHT] : 0;
  }

sub _count_right

# Updates the count of children on the right node. Assumes the counts on the
# right node are updated.

  {
    my ($node) = @_;

    return $node->[COUNT_RIGHT] = ($node->[NODE_RIGHT]) ?
      1 + $node->[NODE_RIGHT]->[COUNT_LEFT] +
	$node->[NODE_RIGHT]->[COUNT_RIGHT] : 0;
  }

sub _add_node

# Recursively add a node to the tree, then balance the child nodes if needed.
# We return the value of the 'root' that we're adding the node to.  This
# simplifies adding and balancing the tree.

  {
    # use integer;

    my ($self, $root, $node) = @_;

    unless ($node)
      {
	croak "Cannot add a NULL node";
      }

    unless ($root) { return $node; }

    my $cmp = $self->[CMP_SUB];

    if ( &{$cmp}($node->[KEY_HIGH],  $root->[KEY_LOW] ) < 0)
      {
	$root->[NODE_LEFT] = $self->_add_node( $root->[NODE_LEFT], $node );
	$root->[COUNT_LEFT]++;
      }
    elsif (&{$cmp}($node->[KEY_LOW], $root->[KEY_HIGH]) > 0)
      {
	$root->[NODE_RIGHT] = $self->_add_node( $root->[NODE_RIGHT], $node );
	$root->[COUNT_RIGHT]++;
      }
    else
      {
	# Hmmm... should we warn or die here?
	warnings::warn
	  ("Overlapping key range: cannot add range \`" .
	   $self->_join_bounds($node->[KEY_LOW], $node->[KEY_HIGH]) .
	   "\' because there exists \`" .
	   $self->_join_bounds($root->[KEY_LOW], $root->[KEY_HIGH]) . "\'"),
	     if (warnings::enabled);

      }

	# Use a bastardized AVL algorithm to keep the tree balanced, so that
	#                   1        3            2
        # branches such as:  2  or  2   become:  1 3
	#                     3    1
	#
	my $balance = $root->[COUNT_RIGHT] - $root->[COUNT_LEFT];

	if ($balance > 1)
	  {
	    my $right = $root->[NODE_RIGHT];

	    $root->[NODE_RIGHT] = $right->[NODE_LEFT];
	    $right->[NODE_LEFT] = $root;

	    _count_right( $root );
	    _count_left( $right );

	    return $right;
	  }
	elsif ($balance < -1)
	  {
	    my $left = $root->[NODE_LEFT];

	    $root->[NODE_LEFT]  = $left->[NODE_RIGHT];
	    $left->[NODE_RIGHT] = $root;

	    _count_left( $root );
	    _count_right( $left );

	    return $left;
	  }

    return $root;
  }

sub _add_new_node

# Add a new node to the root of the tree (a wrapper for _add_node, actually)

  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;
    # Caveats: assumes $lower_bound < $upper_bound!

    $self->[ROOT_NODE] = $self->_add_node(
        $self->[ROOT_NODE],
        $self->_new_node( $lower_bound, $upper_bound, $value )
    );
  }

sub _find_node_parent

# Given a root node and lower and upper bounds, it returns a list with a
# reference to the node and its parent if a node is found where the lower
# and upper bounds are within the lower and upper bounds of that node,
# or it returns 'undef' if no node is found.
#
# Caveats: assumes $parent is actually the parent node of $root; use
# 'undef' when searching from the root node.
#
# The reason we return the parent node as well is to allow the DELETE
# method to use this routine, rather than having two similar routines
# or keeping a pointer to each node's parent (which makes adding and
# balancing more cumbersome). The performance hit for this is minimal.

  {
    my ($self, $root, $parent, $lower_bound, $upper_bound) = @_;

    # use integer;

    unless ($root) { return; }

    # We're using a local variable to 'alias' $self->[CMP_SUB]. Now,
    # if the compiler had a smart optimizer, this wouldn't be
    # necessary....

    my $cmp = $self->[CMP_SUB];

    # The tree search has been rewritten in v0.70 to be iterative
    # rather than recursive. This is *slightly* faster, but more
    # imporantly it's less intensive on the stack.

    my ($lo_cmp, $hi_cmp) = (-1, 1);

    while (($root) and (($lo_cmp<0) or ($hi_cmp>0)))
    {
      $lo_cmp = &{$cmp}($upper_bound, $root->[KEY_LOW]);
      $hi_cmp = &{$cmp}($lower_bound, $root->[KEY_HIGH]);

      if ($lo_cmp<0)
	{
	  $parent = $root;
	  $root   = $root->[NODE_LEFT];
	}
      elsif ($hi_cmp>0)
	{
	  $parent = $root;
	  $root   = $root->[NODE_RIGHT];
	}
      else
	{
	  # The speed improvement of not checking $lower_bound and
	  # $upper_bound for range overlaps is negligible compared to
	  # the advantage of having a warning reported

	  if ((&{$cmp}($lower_bound, $upper_bound))
	      and (
		   (&{$cmp}($lower_bound, $root->[KEY_LOW]) < 0)
		   or (&{$cmp}($upper_bound, $root->[KEY_HIGH]) > 0)
		  ) ) {
	    warnings::warn
		("Key range \`" . 
		 $self->_join_bounds($lower_bound, $upper_bound) .
		 "\' exceeds defined key range \`" .
		 $self->_join_bounds($root->[KEY_LOW], $root->[KEY_HIGH]) .
		 "\'" ),
		   if (warnings::enabled);
	    return;
	  }
	}

    }

    # _find_node_parent() now returns the node as opposed to the value;
    # aside from making the function's name more accurate as to what it
    # does, it also allows us to properly handle the case where:
    #
    #   $hash{'low,high'} = undef
    #
    # Previously, EXISTS would get the value and say the key did not
    # exist.

    return ($root, $parent);

  }


sub _process_args

# Takes an anon hash of args, an anon array of required fields,
# an optional anon array of optional args, and an optional
# anon hash of defaults.  Returns an array of the determined
# values.
#
# Snarfed from
#   http://www.perlmonks.org/index.pl?displaytype=displaycode&node_id=43323

  {

    # use integer;

    my $args    = shift;
    my $req     = shift;
    my $opt     = shift || [];
    my $default = shift || {};
    my @res;
    foreach my $arg (@$req)
      {
	if (exists $args->{$arg}) {
	  push @res, $args->{$arg};
	  delete $args->{$arg};
	}
	else
	  {
	    croak("Missing required argument $arg");
	  }
      }
    foreach my $arg (@$opt)
      {
	if (exists $args->{$arg})
	  {
	    push @res, $args->{$arg};
	    delete $args->{$arg};
	  }
	else
	  {
	    push @res, $default->{$arg};
	  }
      }

  if (%$args)
    {
      my $bad = join ", ", sort keys %$args;
      croak("Unrecognized arguments: $bad\n");
    }
  else
    {
      return @res;
    }
}


sub new

# This is the Tie::RangeHash constructor (or what's called when you say
# tie %hash, 'Tie::RangeHash')

  {
    my ($class, $attributes) = @_;

    my $DEFAULT_SEPARATOR = SEPARATOR;

    my @args = _process_args(
       $attributes,
       [ ],
       [ qw( Separator Type Comparison ) ],
       {
	Separator  => qr/$DEFAULT_SEPARATOR/,
	Type       => TYPE_STRING,
        Comparison => undef,
       }
    );

    my $self = [
       undef,      # ROOT_NODE
       $args[2],   # CMP_SUB
       $args[0],   # SPLIT_REGEX
       $args[1],   # CMP_TYPE
       &SEPARATOR, # SPLIT_TEXT
    ];

    my $split_ref = ref($self->[SPLIT_REGEX]);
    if ($split_ref eq "") # scalar (string)?
      {
	# escape Regexp special characters
	$self->[SPLIT_TEXT]  = $self->[SPLIT_REGEX];
	$self->[SPLIT_REGEX] =~ s/([\.\?\*\+\{\}\[\]\(\)\\\=\$\^])/\\$1/g;
	$self->[SPLIT_REGEX] = qr/$self->[SPLIT_REGEX]/o;
      }
    elsif ($split_ref eq "Regexp")
      {
	$self->[SPLIT_TEXT] = &SEPARATOR; # so we have at least something! 
      }
    else
      {
	croak
	  "\`Separator\' attribute must be a SCALAR or Regexp";
      }

    if (defined($self->[CMP_SUB]) or ($self->[CMP_TYPE] == TYPE_USER))
      {
	if (ref($self->[CMP_SUB]) ne "CODE")
	  {
	    croak
	      "\`Comparison\' must be a CODE reference";
	  }
	$self->[CMP_TYPE] = TYPE_USER;
      }
    else
      {
	if ($self->[CMP_TYPE] == TYPE_NUMBER)
	  {	    
	    $self->[CMP_SUB] = sub { ($_[0] <=> $_[1]); };
	  }
	elsif ($self->[CMP_TYPE] == TYPE_STRING)
	  {
	    $self->[CMP_SUB] = sub { ($_[0] cmp $_[1]); };
	  }
	else
	  {
	    croak "Unknown comparison Type";
	  }
      }

    bless $self, $class;
  }


sub fetch

# Retrieve a node's value, based on the key using _find_node_parent()

  {
    my ($self, $key) = @_;

    # use integer;

    # We need to split the key in case FETCH is called with 'low,high'
    # instead of a single key. Why? Say you have code which does this:
    #
    #   $hash{10,12}->{A} = 1;
    #   $hash{10,12}->{B} = 2;
    #
    # If you're using TYPE_NUMBER keys, you'll get a warning because Perl
    # is FETCHing that key and can't compare a string 'low,high' with a
    # number.
    #
    # So we've modified _find_node() to handle lower and upper bounds
    # (it will use both bounds when searching the keys, and if the bounds
    # are different it will check if the bounds are out of the node's
    # range.)

    my $node = ( $self->_find_node_parent($self->[ROOT_NODE], undef,
				   $self->_split_bounds($key)) )[0];
    return ($node) ? $node->[VALUE] : undef;
  }

sub fetch_key

# Like fetch, but returns the key range that matched. If called in an array
# context, returns a key/value pair.

  {
    my ($self, $key) = @_;

    my $node = ( $self->_find_node_parent($self->[ROOT_NODE], undef,
				   $self->_split_bounds($key)) )[0];
    if ($node)
      {
	my $key = $self->_join_bounds($node->[KEY_LOW], $node->[KEY_HIGH]);
	if (wantarray)
	  {
	    return ($key => $node->[VALUE]);
	  }
	else
	  {
	    return $key;
	  }
      }
    else
      {
	return;
      }
  }

sub key_exists

# Does a node exist?

  {
    my ($self, $key) = @_;
    my $node = ( $self->_find_node_parent($self->[ROOT_NODE], undef,
				   _split_bounds($self, $key)) )[0];
    return (defined($node));
  }

sub add

# Add a new node to the tree

  {
    my ($self, $key, $value) = @_;
    $self->_add_new_node($self->_split_bounds($key), $value);
  }

sub clear

# Cut down the tree

  {
    my ($self) = @_;
    $self->[ROOT_NODE] = undef;
  }

sub remove

# Remove a node from the tree, but re-add the child nodes to the parent

  {
    my ($self, $key) = @_;

    my ($lower_bound, $upper_bound) = $self->_split_bounds($key);
    my ($node, $parent) =
      $self->_find_node_parent($self->[ROOT_NODE], undef,
			       $lower_bound, $upper_bound);

    # Caveat: if $parent is not the parent of $node, you've got a problem!

    unless ($node) { return; } # if node not found, nothing to delete

    my $cmp = $self->[CMP_SUB];

    if ((&{$cmp}($lower_bound, $node->[KEY_LOW])) or
	(&{$cmp}($upper_bound, $node->[KEY_HIGH])))
      {
	warnings::warn 
	  ("Key range \`" .
	   $self->_join_bounds($lower_bound, $upper_bound) .
	   "\' is not a defined key range (found \`" .
	   $self->_join_bounds($node->[KEY_LOW], $node->[KEY_HIGH]) .
	   "\')" ),
	     if (warnings::enabled);
	return;
      }

    if ($parent)
      {
	if (&{$cmp}($parent->[KEY_HIGH], $node->[KEY_LOW])<0)
	  {

	    $parent->[NODE_RIGHT] = $node->[NODE_RIGHT];

	    $parent->[NODE_RIGHT] =
	      $self->_add_node($parent->[NODE_RIGHT], $node->[NODE_LEFT]),
	        if ($node->[NODE_LEFT]);
	      }
	elsif (&{$cmp}($parent->[KEY_LOW],
				   $node->[KEY_HIGH])>0)
	  {

	    $parent->[NODE_LEFT] = $node->[NODE_LEFT];

	    $parent->[NODE_LEFT] =
	      $self->_add_node($parent->[NODE_LEFT], $node->[NODE_RIGHT]),
	        if ($node->[NODE_RIGHT]);
	  }
      }
    else
      {	
	$self->[ROOT_NODE] = $node->[NODE_LEFT];
	$self->[ROOT_NODE] = $self->_add_node( $self->[ROOT_NODE],
				       $node->[NODE_RIGHT]),
	  if ($node->[NODE_RIGHT]);
      }
    return $node->[VALUE];
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
  }

1;

__END__

=head1 NAME

Tie::RangeHash - Allows hashes to associate values with a range of keys

=head1 REQUIREMENTS

C<Tie::RangeHash> is written for and tested on Perl 5.6.0.

It uses only standard modules.

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

If string or numeric comparisons are not appropriate for the keys you need,
a custom comparison routine can be specified:

  sub reverse_compare {
    my ($A, $B) = @_;
    return ($B cmp $A);
  }

  tie %hash, 'Tie::RangeHash', {
    Comparison => \&reverse_compare
  };

The comparison routine should work the same as custom sort subroutines do
(A < B returns -1, A=B returns 0, A > B returns 1). Your keys must also be
representable as a string (a future version of this module may add filters
to overcome that limitation).

If you need to define your own separator, you can do so:

  tie %hash, 'Tie::RangeHash', {
    Separator => '..'
   };

or

  tie %hash, 'Tie::RangeHash', {
    Separator => qr/\s/
   };

Note that if you define it as a regular expression, warnings and errors
will use the default comma ',' separator (since there is no way to "reverse"
a regular expression).

You can also specify array references for keys and do away with separators:

  $hash{ [ qw( A C ) ] } = 1;

=head2 Object-Oriented Interface

C<Tie::RangeHash> has an object-oriented interface as an alternative to
using a tied hash.

=over

=item new

Creates a new object.

  $OBJ = Tie::RangeHash->new( \%ATTR );

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

=back

=head2 Implementation Notes

Internally, the hash is actually a binary tree. Values are retrieved by
searching the tree for nodes that where the key is within range.  I<This
module has nothing to do with "range trees".>

The binary-tree code is spontaneously written and has a very simple
tree-banacing scheme. It appears to work, but has not been fully
tested.

A future version of this module may use an improved binary-tree algorithm.
Or it may use something else.

=head1 KNOWN ISSUES

Duplicate and overlapping ranges are not supported. Once a range is defined,
it exists until you delete it or clear the hash.

Warnings are now disabled by default unless you run Perl with the -W flag.
In theory, you should also be able to say

  use warnings 'Tie::RangeHash';

but this does not always seem to work. (Apparently something is broken
with warnings in Perl 5.6.0.)

This module is incomplete for a tied hash: it has no C<FIRSTKEY> or C<NEXTKEY>
methods (pending my figuring out a good way to implement them).

=head1 SEE ALSO

A module with similar functionality for numerical values is C<Array::IntSpan>.

=head1 AUTHOR

Robert Rothenberg <rrwo@cpan.org>

=head2 Acknowledgements

Charles Huff <charleshuff@decisionresearch.com> for suggestions and
bug reports.

Sam Tregar <sam@tregar.com> for optimization suggestions.

Various Perl Monks <http://www.perlmonks.org> for advice and code snippets.

=head2 Suggestions and Bug Reporting

Feedback is always welcome.  Please use the CPAN Request Tracker at
L<http://rt.cpan.org> to submit bug reports.

=head1 LICENSE

Copyright (c) 2000-2002 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
