package Tie::RangeHash;

require 5.005;

use strict;
use warnings;

require Carp;
require Tie::Hash;

use vars qw($VERSION $SEPARATOR @ISA);

$VERSION = '0.30';

@ISA = qw(Tie::Hash);

sub TYPE_NUMBER { return 1; }           # Some internal constants
sub TYPE_STRING { return 2; }

# Default separator character ... Ceveat: use of this outside of the
# module is deprecated! Define the SEPARATOR when using tie instead.
$SEPARATOR; BEGIN { *SEPARATOR = \ ","; }

sub _join_bounds                        # generate a key from bounds
  {
    my ($self, $lower_bound, $upper_bound) = @_;
    join($self->{SEPARATOR}, $lower_bound, $upper_bound);
  }

sub _split_bounds                       # generate bounds from a key
  {
    my ($self, $key) = @_;

    my ($lower_bound, $upper_bound, $extra_stuff);
    if ($key =~ $self->{SPLIT})
      {
	($lower_bound, $upper_bound, $extra_stuff) =
	  split( $self->{SPLIT}, $key );

	if (defined($extra_stuff))
	  {
	    Carp::carp "Multiple separators in \`$key\' will be ignored";
	  }

	if (&{$self->{COMPARE}}($lower_bound, $upper_bound) > 0)
	  # make sure $lower_bound < $upper_bound
	  {
	    Carp::carp "Lower and upper bounds reversed";
	    ($lower_bound, $upper_bound) = ($upper_bound, $lower_bound);
	  }
      }
    else
      {
	return ($key, $key);
      }

    return ($lower_bound, $upper_bound);
  }

sub _new_node                           # Create a new node
  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;

    return {
      KEY_LOW    => $lower_bound,       # lower bound
      KEY_HIGH   => $upper_bound,       # upper bound
      VALUE      => $value,             # value of the node
      NODE_LEFT  => undef,              # left node (lower than lower bound)
      NODE_RIGHT => undef,              # right node (higher than upper bound)
      COUNT_LEFT => 0,                  # count of child nodes to left
      COUNT_RIGHT => 0,                 # count of child nodes to right
    };
  }


sub _count_left                         # Update count of children on left
  {
    my ($node) = @_;
    $node->{COUNT_LEFT} = ($node->{NODE_LEFT}) ?
      1 + $node->{NODE_LEFT}->{COUNT_LEFT} +
	$node->{NODE_LEFT}->{COUNT_RIGHT} : 0;
  }

sub _count_right                        # Update count of children on left
  {
    my ($node) = @_;
    $node->{COUNT_RIGHT} = ($node->{NODE_RIGHT}) ?
      1 + $node->{NODE_RIGHT}->{COUNT_LEFT} +
	$node->{NODE_RIGHT}->{COUNT_RIGHT} : 0;
  }

sub _add_node                           # Recursively add a new node to tree
  {
    my ($self, $root, $node) = @_;

    unless ($root) { return $node; }

    if ( &{$self->{COMPARE}}($node->{KEY_HIGH},  $root->{KEY_LOW} ) < 0)
      {
	$root->{NODE_LEFT} = _add_node( $self, $root->{NODE_LEFT}, $node );
	_count_left($root);
      }
    elsif (&{$self->{COMPARE}}($node->{KEY_LOW}, $root->{KEY_HIGH}) > 0)
      {
	$root->{NODE_RIGHT}  = _add_node( $self, $root->{NODE_RIGHT}, $node );
	_count_right($root);
      }
    else
      {
	#Hmm... should it carp or croak? Smart thing to do: if the nodes have
	# different values, croak, otherwise just carp.
	Carp::carp "Overlapping key range: cannot add range '`" .
	  $self->_join_bounds( $node->{KEY_LOW}, $node->{KEY_HIGH}) .
	  "\' because there exists \`" .
	  $self->_join_bounds( $root->{KEY_LOW}, $root->{KEY_HIGH}) . "\'";
      }

#    unless ($self->{UNBALANCED}) # disable tree balancing...
#      {
	# Use a bastardized AVL algorithm to keep the tree balanced, so that
	#                   1        3            2
        # branches such as:  2  or  2   become:  1 3
	#                     3    1
	#
	my $balance = $root->{COUNT_RIGHT} - $root->{COUNT_LEFT};

	if ($balance > 1)
	  {
	    my $right = $root->{NODE_RIGHT};

	    $root->{NODE_RIGHT} = $right->{NODE_LEFT};
	    $right->{NODE_LEFT} = $root;

	    _count_right($root);
	    _count_left($right);

	    return $right;
	  }
	elsif ($balance < -1)
	  {
	    my $left = $root->{NODE_LEFT};

	    $root->{NODE_LEFT}  = $left->{NODE_RIGHT};
	    $left->{NODE_RIGHT} = $root;

	    _count_left($root);
	    _count_right($left);
	    
	    return $left;
	  }
#      }

    return $root;
  }

sub _add_new_node                       # Add a new node from the root
  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;
    # Caveats: assumes $lower_bound < $upper_bound!

    $self->{ROOT} = _add_node($self, $self->{ROOT},
        _new_node($self, $lower_bound, $upper_bound, $value)
    );
  }


sub _find_node                          # Recursively find a node
  {
    my ($self, $root, $lower_bound, $upper_bound) = @_;

    unless ($root) { return; }

    if (&{$self->{COMPARE}}($upper_bound, $root->{KEY_LOW})<0)
      {
	return _find_node($self, $root->{NODE_LEFT},
			  $lower_bound, $upper_bound);
      }
    elsif (&{$self->{COMPARE}}($lower_bound, $root->{KEY_HIGH})>0)
      {
	return _find_node($self, $root->{NODE_RIGHT},
			  $lower_bound, $upper_bound);
      }
    else
      {

	# The speed improvement of not checking $lower_bound and $upper_bound
	# for range overlaps is negligible compared to the advantage of having
	# a warning reported

	if ((&{$self->{COMPARE}}($lower_bound, $upper_bound))
	  and (
	       (&{$self->{COMPARE}}($lower_bound, $root->{KEY_LOW}) < 0)
	       or (&{$self->{COMPARE}}($upper_bound, $root->{KEY_HIGH}) > 0)
	      ) )
	  {
	    Carp::carp( "Key range \`", 
		  _join_bounds($self, $lower_bound, $upper_bound),
		  "\' exceeds defined key range \`",
		  _join_bounds($self, $root->{KEY_LOW}, $root->{KEY_HIGH}),
		  "\'" );
	    return;
	  }
	return $root->{VALUE};
      }
  }


sub TIEHASH                             # Tie::RangeHash constructor
  {
    my ($class, $attributes) = @_;

    my $self = {
      ROOT      => undef,                               # root node
      SPLIT     => $attributes->{Separator} ||          # default Regexp
		     qr/$SEPARATOR/,
      SEPARATOR => $SEPARATOR,                          # separator string
      TYPE      => $attributes->{Type}  || TYPE_STRING, # comparison type
      COMPARE   => $attributes->{Comparison},           # compairson subroutine
#     UNBALANCED => $attributes->{Unblanaced},          # disable balanced tree
    };

    my $split_ref = ref($self->{SPLIT});
    if ($split_ref eq "")
      {
	# escape Regexp special characters
	$self->{SEPARATOR} = $self->{SPLIT};
	$self->{SPLIT}     =~ s/([\.\?\*\+\{\}\[\]\(\)\\\=\$\^])/\\$1/g;
	$self->{SPLIT}     = qr/$self->{SPLIT}/o;
      }
    elsif ($split_ref eq "Regexp")
      {
	$self->{SEPARATOR} = $SEPARATOR; # so we have at least something! 
      }
    else
      {	
	Carp::croak
	  "\`Separator\' attribute must be a Regexp";
      }

    if (defined($self->{COMPARE}))
      {
	if (ref($self->{COMPARE}) ne "CODE")
	  {
	    Carp::croak "\`Comparison\' must be a CODE reference";
	  }
      }
    else
      {
	if ($self->{TYPE} == TYPE_NUMBER)
	  {
	    $self->{COMPARE} = sub { ($_[0] <=> $_[1]); };
	  }
	elsif ($self->{TYPE} == TYPE_STRING)
	  {
	    $self->{COMPARE} = sub { ($_[0] cmp $_[1]); };
	  }
	else
	  {
	    die "Unknown comparison Type";
	  }
      }

    bless $self, $class;
  }

sub FETCH                               # Retrieve a node from tree
  {
    my ($self, $key) = @_;

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
    # (it will use the lower bound as the search key, and then compare
    # the upper bound when it finds the key... if the upper bound is
    # out of range, it will return an error).

    _find_node($self, $self->{ROOT}, _split_bounds($self, $key));

  }

sub EXISTS                              # Check if a node exists
  {
    my ($self, $key) = @_;
    defined( FETCH $self, $key );       # if it's fetchable...
  }

sub STORE                               # Add a node
  {
    my ($self, $key, $value) = @_;
    _add_new_node($self, _split_bounds($self, $key), $value);
  }

sub CLEAR                               # Wipe tree
  {
    my ($self) = @_;
    $self->{ROOT} = undef;
  }


1;
__END__

=head1 NAME

Tie::RangeHash - Implements "range hashes" in Perl

=head1 REQUIREMENTS

C<Tie::RangeHash> is written for Perl 5.005_62 or 5.6.0 and tested on the
latter. It should work in Perl 5.005, although I have not tested it.

It uses the following modules:

  Carp                  # this may change in the future
  Tie::Hash
  Time::HiRes           # for test.pl

=head2 Installation

Installation is pretty standard:

  perl Makefile.PL
  make
  make test
  make install

=head1 SYNOPSIS

  use Tie::RangeHash;

  tie %hash, Tie::RangeHash;

  $hash{'A,C'} = 1;
  $hash{'D,F'} = 2;
  $hash{'G,K'} = 3;

  $hash{'E'};           # returns '2'
  $hash{'BB'};          # returns '1'

  $hash{'KL'};          # returns nothing ('undef')

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
will use the default comma ',' separator.

Duplicate and overlapping ranges are not supported. Once a range is defined,
it exists for the lifetime of the hash. (Future versions may allow you to
change this behavior.)

Internally, the hash is actually a binary tree. Values are retrieved by
searching the tree for nodes that where the key is within range.

=head1 CAVEATS

The binary-tree code is spontaneously written and has a very simple
tree-banacing scheme. (It needs some kind of scheme since sorted data
will produce a very lopsided tree which is no more efficient than an
array.) It appears to work, but has not been fully tested.

A future version of this module may use an improved binary-tree algorithm.
Or it may use something else.

This module is incomplete... It needs the DELETE, FIRSTKEY, NEXTKEY,
and (maybe) DESTROY methods.

=head1 AUTHOR

Robert Rothenberg <rrwo@cpan.org>

=head1 LICENSE

Copyright (c) 2000 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
